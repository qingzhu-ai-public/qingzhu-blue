---
title: 传输篇
slug: transfer
order: 40
summary: 写入指令，读回数据并解析温湿度。
---

# 传输篇　写一个字节，再读一组温湿度

在手机 A 点「请求新读数」，观察温度、湿度和原始字节。第一次预期是 26.50 °C 和 50.55% RH。

## 本篇完整代码

按文件名展开。每个文件都可以完整查看。 [跳到讲解](#walkthrough)

<details>
<summary>AndroidManifest.xml · 声明系统权限</summary>

<a id="manifest"></a>

路径 `app/src/main/AndroidManifest.xml`。

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" tools:targetApi="s" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <application android:label="蓝牙温湿度计" android:icon="@drawable/ic_thermometer"
        android:enableOnBackInvokedCallback="true" android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity android:name=".SensorActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

</details>

<details>
<summary>SensorClient.java · 扫描、连接和读写</summary>

<a id="client"></a>

路径 `app/src/main/java/guide/bluetooth/bthome/SensorClient.java`。

```java
package guide.bluetooth.bthome;

import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.BluetoothStatusCodes;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;

import java.util.function.Consumer;

@SuppressWarnings("deprecation")
final class SensorClient {
    interface View {
        void showDevice(String address, String title, String info, String reading, String bytes,
                boolean selectable, Runnable select);
        void showSample(String reading, String bytes);
        void showScanning(boolean scanning);
        void allowRequest(boolean enabled);
    }

    private enum Stage { IDLE, SCAN, PICK, CONNECT, DISCOVER, READY, WRITE, READ, CLOSED }

    private final Handler owner = new Handler(Looper.getMainLooper());
    private final Context context;
    private final BluetoothAdapter adapter;
    private final View view;
    private final Consumer<String> report;
    private final Runnable deadline = this::onTimeout;
    private BluetoothLeScanner scanner;
    private BluetoothGatt gatt;
    private BluetoothGattCharacteristic sample;
    private Stage stage = Stage.IDLE;

    SensorClient(Context context, BluetoothAdapter adapter, View view, Consumer<String> report) {
        this.context = context.getApplicationContext();
        this.adapter = adapter;
        this.view = view;
        this.report = report;
    }

    private final ScanCallback scanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            owner.post(() -> {
                if (stage != Stage.SCAN) return;
                ScanRecord record = result.getScanRecord();
                if (record == null) return;
                byte[] data = record.getServiceData(new ParcelUuid(DemoProtocol.BTHOME));
                if (data == null) return;
                boolean demo = result.isConnectable() && record.getServiceUuids() != null
                        && record.getServiceUuids().contains(new ParcelUuid(DemoProtocol.SERVICE));
                String reading;
                try {
                    reading = BthomeDecoder.decode(data).display();
                } catch (IllegalArgumentException error) {
                    reading = error.getMessage();
                }
                String address = result.getDevice().getAddress();
                String name = record.getDeviceName();
                String title = demo ? "教学温湿度计" : name == null ? "BTHome 设备" : name;
                view.showDevice(address, title, address + " · " + result.getRssi() + " dBm",
                        reading, DemoProtocol.hex(data), demo, () -> connect(result.getDevice()));
            });
        }

        @Override
        public void onScanFailed(int errorCode) {
            owner.post(() -> {
                if (stage == Stage.SCAN) fail("扫描失败，错误码 " + errorCode);
            });
        }
    };

    private final BluetoothGattCallback callback = new BluetoothGattCallback() {
        @SuppressLint("MissingPermission") // handle 捕获权限撤销时的 SecurityException。
        @Override
        public void onConnectionStateChange(BluetoothGatt source, int status, int newState) {
            handle(source, () -> {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fail("连接事件失败，status=" + status);
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    fail("连接已断开，可以重新扫描");
                } else if (stage == Stage.CONNECT && newState == BluetoothProfile.STATE_CONNECTED) {
                    enter(Stage.DISCOVER, "已连接，正在查找教学服务和特征", 10_000);
                    if (!source.discoverServices()) fail("服务发现没有受理");
                }
            });
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt source, int status) {
            handle(source, () -> {
                if (stage != Stage.DISCOVER) return;
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fail("服务发现失败，status=" + status);
                    return;
                }
                BluetoothGattService service = source.getService(DemoProtocol.SERVICE);
                sample = service == null ? null : service.getCharacteristic(DemoProtocol.SAMPLE);
                int required = BluetoothGattCharacteristic.PROPERTY_WRITE
                        | BluetoothGattCharacteristic.PROPERTY_READ;
                if (sample == null || (sample.getProperties() & required) != required) {
                    fail("找不到可读写的教学特征");
                    return;
                }
                ready("特征已找到，可以请求新读数");
            });
        }

        @SuppressLint("MissingPermission") // handle 捕获权限撤销时的 SecurityException。
        @Override
        public void onCharacteristicWrite(BluetoothGatt source, BluetoothGattCharacteristic item,
                int status) {
            handle(source, () -> {
                if (stage != Stage.WRITE || !DemoProtocol.SAMPLE.equals(item.getUuid())) return;
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fail("写入失败，status=" + status);
                    return;
                }
                enter(Stage.READ, "外设已确认写入，正在读取结果", 10_000);
                if (!source.readCharacteristic(sample)) fail("读请求没有受理");
            });
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt source, BluetoothGattCharacteristic item,
                byte[] value, int status) {
            received(source, item, value, status);
        }

        @Override
        public void onCharacteristicRead(BluetoothGatt source, BluetoothGattCharacteristic item,
                int status) {
            if (Build.VERSION.SDK_INT < 33) received(source, item, item.getValue(), status);
        }
    };

    void start() {
        scanner = adapter.getBluetoothLeScanner();
        if (scanner == null) {
            fail("BLE 扫描不可用");
            return;
        }
        enter(Stage.SCAN, "正在扫描，点列表中的教学外设连接", 12_000);
        // 使用应用层过滤，兼容仅在 Service Data 中放 FCD2 的广播。
        ScanSettings settings = new ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build();
        try {
            scanner.startScan(null, settings, scanCallback);
        } catch (SecurityException failure) {
            fail("扫描权限不可用，请检查系统设置");
        }
    }

    private void connect(BluetoothDevice device) {
        if (stage != Stage.SCAN && stage != Stage.PICK) return;
        try {
            stopScan();
            enter(Stage.CONNECT, "正在连接选中的外设", 12_000);
            gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE,
                    BluetoothDevice.PHY_LE_1M_MASK, owner);
            if (gatt == null) fail("无法创建 GATT 连接");
        } catch (SecurityException | IllegalStateException error) {
            fail("连接无法发起，" + error.getMessage());
        }
    }

    void requestSample() {
        if (stage != Stage.READY) return;
        byte[] command = {DemoProtocol.MEASURE};
        int type = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT;
        view.showSample("等待读数", "");
        enter(Stage.WRITE, "正在向教学特征写入 01", 10_000);
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                int status = gatt.writeCharacteristic(sample, command, type);
                if (status != BluetoothStatusCodes.SUCCESS) fail("写请求没有受理，code=" + status);
            } else {
                sample.setWriteType(type);
                if (!sample.setValue(command) || !gatt.writeCharacteristic(sample)) {
                    fail("写请求没有受理");
                }
            }
        } catch (SecurityException | IllegalStateException error) {
            fail("写请求无法发起，" + error.getMessage());
        }
    }

    private void received(BluetoothGatt source, BluetoothGattCharacteristic item, byte[] value,
            int status) {
        byte[] bytes = value == null ? null : value.clone();
        handle(source, () -> {
            if (stage != Stage.READ || !DemoProtocol.SAMPLE.equals(item.getUuid())) return;
            if (status != BluetoothGatt.GATT_SUCCESS) {
                fail("读取失败，status=" + status);
                return;
            }
            try {
                BthomeDecoder.Reading reading = BthomeDecoder.decode(bytes);
                if (!reading.hasTemperature || !reading.hasHumidity || reading.unsupportedId >= 0) {
                    throw new IllegalArgumentException("需要一组完整的教学读数");
                }
                view.showSample(reading.display(), DemoProtocol.hex(bytes));
                ready("收到并解析了新读数，可以再次请求");
            } catch (IllegalArgumentException error) {
                fail("无法解析读取结果，" + error.getMessage());
            }
        });
    }

    private void handle(BluetoothGatt source, Runnable action) {
        owner.post(() -> {
            if (stage == Stage.CLOSED || source != gatt) return;
            try {
                action.run();
            } catch (SecurityException | IllegalStateException error) {
                fail("GATT 操作失败，" + error.getMessage());
            }
        });
    }

    private void enter(Stage next, String message, long timeoutMs) {
        owner.removeCallbacks(deadline);
        stage = next;
        view.showScanning(next == Stage.SCAN);
        view.allowRequest(next == Stage.READY);
        report.accept(message);
        if (timeoutMs > 0) owner.postDelayed(deadline, timeoutMs);
    }

    private void ready(String message) {
        enter(Stage.READY, message, 0);
    }

    private void onTimeout() {
        if (stage == Stage.SCAN) {
            finishScan();
        } else {
            fail("操作超时，停在 " + stage);
        }
    }

    void finishScan() {
        if (stage != Stage.SCAN) return;
        stopScan();
        enter(Stage.PICK, "扫描已结束，可以选设备或重新扫描", 0);
    }

    private void stopScan() {
        if (scanner == null) return;
        try {
            scanner.stopScan(scanCallback);
        } catch (SecurityException | IllegalStateException error) {
            android.util.Log.w("GuideBthome", "stopScan", error);
        } finally {
            scanner = null;
        }
    }

    private void fail(String message) {
        close();
        report.accept(message);
    }

    void close() {
        stage = Stage.CLOSED;
        owner.removeCallbacks(deadline);
        view.showScanning(false);
        view.allowRequest(false);
        stopScan();
        if (gatt != null) {
            try {
                try {
                    gatt.disconnect();
                } finally {
                    gatt.close();
                }
            } catch (SecurityException | IllegalStateException error) {
                android.util.Log.w("GuideBthome", "close GATT", error);
            } finally {
                gatt = null;
            }
        }
    }
}
```

</details>

<details>
<summary>SensorPeripheral.java · 模拟设备并应答</summary>

<a id="peripheral"></a>

路径 `app/src/main/java/guide/bluetooth/bthome/SensorPeripheral.java`。

```java
package guide.bluetooth.bthome;

import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.AdvertiseCallback;
import android.bluetooth.le.AdvertiseData;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;

import java.util.Arrays;
import java.util.function.Consumer;

final class SensorPeripheral {
    private final Handler owner = new Handler(Looper.getMainLooper());
    private final Context context;
    private final BluetoothManager manager;
    private final BluetoothAdapter adapter;
    private final Consumer<String> report;
    private final Runnable startupTimeout = () -> fail("注册服务或启动广播超时");

    private BluetoothLeAdvertiser advertiser;
    private BluetoothGattServer server;
    private BluetoothDevice peer;
    private int temperature = 2500;
    private boolean advertisingRequested;
    private boolean closed;

    SensorPeripheral(Context context, BluetoothManager manager, BluetoothAdapter adapter,
            Consumer<String> report) {
        this.context = context.getApplicationContext();
        this.manager = manager;
        this.adapter = adapter;
        this.report = report;
    }

    private final BluetoothGattServerCallback callback = new BluetoothGattServerCallback() {
        @Override
        public void onServiceAdded(int status, BluetoothGattService service) {
            onEvent(() -> {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fail("教学服务注册失败，status=" + status);
                } else if (DemoProtocol.SERVICE.equals(service.getUuid()) && !advertisingRequested) {
                    advertise();
                }
            });
        }

        @SuppressLint("MissingPermission") // onEvent 捕获权限撤销时的 SecurityException。
        @Override
        public void onConnectionStateChange(BluetoothDevice device, int status, int state) {
            onEvent(() -> {
                if (status == BluetoothGatt.GATT_SUCCESS && state == BluetoothProfile.STATE_CONNECTED) {
                    if (peer != null && !peer.equals(device)) {
                        server.cancelConnection(device);
                        return;
                    }
                    peer = device;
                    report.accept("客户端已连接，等待测量指令");
                } else if (device.equals(peer)) {
                    peer = null;
                    temperature = 2500;
                    report.accept("客户端已断开，等待下一次连接");
                }
            });
        }

        @Override
        public void onCharacteristicWriteRequest(BluetoothDevice device, int id,
                BluetoothGattCharacteristic item, boolean prepared, boolean responseNeeded,
                int offset, byte[] value) {
            byte[] bytes = value.clone();
            onEvent(() -> {
                int status = writeStatus(device, item, prepared, responseNeeded, offset, bytes);
                if (!responseNeeded || !respond(device, id, status, offset, null)) return;
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    temperature = temperature == 2500 ? 2650 : 2500;
                    report.accept("收到 01，已生成模拟读数：" +
                            DemoProtocol.hex(DemoProtocol.sample(temperature)));
                }
            });
        }

        @Override
        public void onCharacteristicReadRequest(BluetoothDevice device, int id, int offset,
                BluetoothGattCharacteristic item) {
            onEvent(() -> {
                byte[] value = DemoProtocol.sample(temperature);
                if (!device.equals(peer) || !DemoProtocol.SAMPLE.equals(item.getUuid())) {
                    respond(device, id, BluetoothGatt.GATT_READ_NOT_PERMITTED, offset, null);
                } else if (offset < 0 || offset > value.length) {
                    respond(device, id, BluetoothGatt.GATT_INVALID_OFFSET, offset, null);
                } else if (respond(device, id, BluetoothGatt.GATT_SUCCESS, offset,
                        Arrays.copyOfRange(value, offset, value.length))) {
                    report.accept("返回模拟读数：" + DemoProtocol.hex(value));
                }
            });
        }

        @Override
        public void onExecuteWrite(BluetoothDevice device, int id, boolean execute) {
            onEvent(() -> respond(device, id, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, 0, null));
        }
    };

    private final AdvertiseCallback advertiseCallback = new AdvertiseCallback() {
        @Override
        public void onStartSuccess(AdvertiseSettings settings) {
            onEvent(() -> {
                owner.removeCallbacks(startupTimeout);
                if (peer == null) report.accept("正在广播 25.00 °C，等待客户端选择本机");
            });
        }

        @Override
        public void onStartFailure(int errorCode) {
            onEvent(() -> fail("广播启动失败，错误码 " + errorCode));
        }
    };

    @SuppressLint("MissingPermission") // Activity 授权后调用，并捕获 SecurityException。
    void start() {
        advertiser = adapter.getBluetoothLeAdvertiser();
        if (advertiser == null) {
            fail("这台手机无法作为 BLE 广播外设，可用它来扫描");
            return;
        }
        server = manager.openGattServer(context, callback);
        if (server == null) {
            fail("无法打开 GATT Server");
            return;
        }
        BluetoothGattService service = new BluetoothGattService(
                DemoProtocol.SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY);
        service.addCharacteristic(new BluetoothGattCharacteristic(
                DemoProtocol.SAMPLE,
                BluetoothGattCharacteristic.PROPERTY_READ | BluetoothGattCharacteristic.PROPERTY_WRITE,
                BluetoothGattCharacteristic.PERMISSION_READ | BluetoothGattCharacteristic.PERMISSION_WRITE));
        report.accept("正在注册教学服务");
        owner.postDelayed(startupTimeout, 15_000);
        if (!server.addService(service)) fail("注册服务没有受理");
    }

    private void advertise() {
        AdvertiseSettings settings = new AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
                .setConnectable(true)
                .build();
        // Flags 3 + 128 位 UUID 18 + BTHome Service Data 8，共 29 字节。
        AdvertiseData data = new AdvertiseData.Builder()
                .addServiceUuid(new ParcelUuid(DemoProtocol.SERVICE))
                .addServiceData(new ParcelUuid(DemoProtocol.BTHOME), DemoProtocol.broadcast())
                .build();
        advertisingRequested = true;
        advertiser.startAdvertising(settings, data, advertiseCallback);
    }

    private int writeStatus(BluetoothDevice device, BluetoothGattCharacteristic item,
            boolean prepared, boolean responseNeeded, int offset, byte[] value) {
        if (!device.equals(peer) || !DemoProtocol.SAMPLE.equals(item.getUuid())) {
            return BluetoothGatt.GATT_WRITE_NOT_PERMITTED;
        }
        if (prepared || !responseNeeded) return BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED;
        if (offset != 0) return BluetoothGatt.GATT_INVALID_OFFSET;
        if (value.length != 1) return BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH;
        if (value[0] != DemoProtocol.MEASURE) return BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED;
        return BluetoothGatt.GATT_SUCCESS;
    }

    @SuppressLint("MissingPermission") // 请求全部从 onEvent 进入。
    private boolean respond(BluetoothDevice device, int id, int status, int offset, byte[] value) {
        boolean accepted = server.sendResponse(device, id, status, offset, value);
        if (!accepted) report.accept("蓝牙系统没有受理外设回包");
        return accepted;
    }

    private void onEvent(Runnable action) {
        owner.post(() -> {
            if (closed) return;
            try {
                action.run();
            } catch (SecurityException | IllegalStateException | IllegalArgumentException failure) {
                fail("外设操作失败，" + failure.getMessage());
            }
        });
    }

    private void fail(String message) {
        close();
        report.accept(message);
    }

    boolean isClosed() {
        return closed;
    }

    void close() {
        if (closed) return;
        closed = true;
        owner.removeCallbacks(startupTimeout);
        if (advertisingRequested) {
            try {
                advertiser.stopAdvertising(advertiseCallback);
            } catch (SecurityException | IllegalStateException failure) {
                Log.w("GuideBthome", "stopAdvertising", failure);
            }
        }
        if (server != null) {
            try {
                try {
                    if (peer != null) server.cancelConnection(peer);
                } finally {
                    server.close();
                }
            } catch (SecurityException | IllegalStateException failure) {
                Log.w("GuideBthome", "close GATT Server", failure);
            }
        }
    }
}
```

</details>

<details>
<summary>DemoProtocol.java · 两端约定的编号与指令</summary>

<a id="protocol"></a>

路径 `app/src/main/java/guide/bluetooth/bthome/DemoProtocol.java`。

```java
package guide.bluetooth.bthome;

import java.util.Locale;
import java.util.UUID;

final class DemoProtocol {
    static final UUID BTHOME = UUID.fromString("0000fcd2-0000-1000-8000-00805f9b34fb");
    static final UUID SERVICE = UUID.fromString("476cdf45-6063-43a1-b8e2-8c1fbed00601");
    static final UUID SAMPLE = UUID.fromString("476cdf45-6063-43a1-b8e2-8c1fbed00602");
    static final byte MEASURE = 0x01;

    static byte[] broadcast() {
        return new byte[] {0x40, 0x02, (byte) 0xC4, 0x09}; // 25.00 °C
    }

    static byte[] sample(int temperature) {
        return new byte[] {0x40, 0x02, (byte) temperature, (byte) (temperature >> 8),
                0x03, (byte) 0xBF, 0x13}; // 50.55 % RH
    }

    static String hex(byte[] value) {
        StringBuilder output = new StringBuilder();
        for (byte b : value) {
            if (output.length() > 0) output.append(' ');
            output.append(String.format(Locale.ROOT, "%02X", b & 0xff));
        }
        return output.toString();
    }

    private DemoProtocol() {}
}
```

</details>

<details>
<summary>BthomeDecoder.java · 把原始字节换算成读数</summary>

<a id="decoder"></a>

路径 `app/src/main/java/guide/bluetooth/bthome/BthomeDecoder.java`。

```java
package guide.bluetooth.bthome;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

// 输入来自 ScanRecord.getServiceData，Android 已经取走了服务 UUID。
final class BthomeDecoder {
    static Reading decode(byte[] data) {
        if (data == null || data.length < 2) throw new IllegalArgumentException("没有测量对象");
        int header = data[0] & 0xff;
        if ((header >> 5) != 2) throw new IllegalArgumentException("需要 BTHome v2");
        if ((header & 1) != 0) throw new IllegalArgumentException("此示例只解析明文广播");

        Reading reading = new Reading();
        for (int offset = 1; offset < data.length; ) {
            int id = data[offset++] & 0xff;
            switch (id) {
                case 0x00:
                    requireBytes(data, offset, 1);
                    offset++; // 包序号不是读数
                    break;
                case 0x01:
                    requireBytes(data, offset, 1);
                    reading.fields.add((data[offset++] & 0xff) + "% 电量");
                    break;
                case 0x02:
                    requireBytes(data, offset, 2);
                    double temperature = (short) littleEndian16(data, offset) / 100.0;
                    reading.hasTemperature = true;
                    reading.fields.add(String.format(Locale.ROOT, "%.2f °C", temperature));
                    offset += 2;
                    break;
                case 0x03:
                    requireBytes(data, offset, 2);
                    reading.hasHumidity = true;
                    reading.fields.add(String.format(Locale.ROOT, "%.2f%% RH",
                            littleEndian16(data, offset) / 100.0));
                    offset += 2;
                    break;
                default:
                    // 对象没有统一的长度字段。遇到不认识的 ID 就停在这里。
                    reading.unsupportedId = id;
                    return reading;
            }
        }
        return reading;
    }

    static final class Reading {
        final List<String> fields = new ArrayList<>();
        boolean hasTemperature;
        boolean hasHumidity;
        int unsupportedId = -1;

        String display() {
            String value = fields.isEmpty() ? "无可显示的读数" : String.join(" · ", fields);
            if (unsupportedId >= 0) {
                value += String.format(Locale.ROOT, "（遇到未支持的对象 0x%02X）", unsupportedId);
            }
            return value;
        }
    }

    private static int littleEndian16(byte[] data, int offset) {
        return (data[offset] & 0xff) | ((data[offset + 1] & 0xff) << 8);
    }

    private static void requireBytes(byte[] data, int offset, int count) {
        if (data.length - offset < count) throw new IllegalArgumentException("测量数据不完整");
    }

    private BthomeDecoder() {}
}
```

</details>

<details>
<summary>SensorActivity.java · 处理点击、权限和界面</summary>

<a id="activity"></a>

路径 `app/src/main/java/guide/bluetooth/bthome/SensorActivity.java`。

```java
package guide.bluetooth.bthome;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;

import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;

@SuppressWarnings("deprecation")
public final class SensorActivity extends Activity implements SensorClient.View {
    private static final int REQUEST_PERMISSION = 1;
    private static final int REQUEST_ENABLE = 2;
    private static final int PAPER = 0xfff5f8f4;
    private static final int INK = 0xff182b24;
    private static final int MUTED = 0xff476355;
    private static final int GREEN = 0xff216045;
    private static final int PALE = 0xffe1ebe4;

    private enum Role { CLIENT, SERVER }
    private enum Page { DEVICES, READING, PERIPHERAL }

    private final Map<String, ScanRow> rows = new LinkedHashMap<>();
    private Page page;
    private TextView status;
    private TextView empty;
    private TextView sample;
    private TextView payload;
    private LinearLayout devices;
    private Button scanButton;
    private Button requestButton;
    private Button broadcastButton;
    private boolean scanning;
    private OnBackInvokedCallback backCallback;
    private Role pendingRole;
    private SensorClient client;
    private SensorPeripheral server;

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(PAPER);
        getWindow().setNavigationBarColor(PAPER);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        showDevices();
    }

    private void showDevices() {
        LinearLayout layout = openPage(Page.DEVICES, "附近设备", "扫描附近的 BTHome 设备。");
        devices = new LinearLayout(this);
        devices.setOrientation(LinearLayout.VERTICAL);
        layout.addView(devices);
        empty = text("还没有扫描结果\n也可以用第二台手机模拟温湿度计。", 16, MUTED);
        LinearLayout emptyCard = card(devices);
        emptyCard.addView(empty);
        scanButton = button(layout, "开始扫描", true, () -> {
            if (scanning && client != null) {
                client.finishScan();
            } else {
                startRole(Role.CLIENT);
            }
        });
        button(layout, "模拟温湿度计", false, this::showPeripheral);
    }

    private void showReading(String title) {
        LinearLayout layout = openPage(Page.READING, title, "正在连接并查找温湿度特征…");
        LinearLayout panel = card(layout);
        panel.addView(text("连接读数", 15, MUTED));
        sample = text("等待测量", 29, INK);
        sample.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        panel.addView(sample);
        payload = rawText("");
        panel.addView(payload);
        requestButton = button(layout, "请求新读数", true, () -> {
            if (client != null) client.requestSample();
        });
        requestButton.setEnabled(false);
    }

    private void showPeripheral() {
        stopSessions();
        LinearLayout layout = openPage(Page.PERIPHERAL, "模拟温湿度计", "等待启动广播。");
        LinearLayout panel = card(layout);
        panel.addView(text("广播温度", 15, MUTED));
        panel.addView(text("25.00 °C", 29, INK));
        panel.addView(rawText(DemoProtocol.hex(DemoProtocol.broadcast())));
        broadcastButton = button(layout, "启动广播", true, () -> {
            if (server == null) {
                startRole(Role.SERVER);
            } else {
                stopSessions();
                broadcastButton.setText("启动广播");
                showStatus("广播已停止。");
            }
        });
    }

    private LinearLayout openPage(Page next, String title, String message) {
        page = next;
        updateBackCallback();
        rows.clear();
        scanButton = null;
        requestButton = null;
        sample = null;
        payload = null;
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(PAPER);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(dp(22), dp(20), dp(22), dp(20));
        scroll.setOnApplyWindowInsetsListener((view, insets) -> {
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
                return WindowInsets.CONSUMED;
            }
            return insets;
        });
        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        TextView heading = text(title, 24, INK);
        heading.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        header.addView(heading, new LinearLayout.LayoutParams(0, -2, 1));
        if (next != Page.DEVICES) {
            Button back = new Button(this);
            styleButton(back, "返回列表", false);
            back.setOnClickListener(view -> returnToDevices());
            header.addView(back);
        }
        layout.addView(header);
        status = text(message, 14, MUTED);
        status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        addSection(layout, status, 14);
        scroll.addView(layout);
        setContentView(scroll);
        return layout;
    }

    private Button button(LinearLayout parent, String title, boolean primary, Runnable action) {
        Button button = new Button(this);
        styleButton(button, title, primary);
        button.setOnClickListener(view -> action.run());
        addSection(parent, button, 12);
        return button;
    }

    private void styleButton(Button button, String title, boolean primary) {
        button.setAllCaps(false);
        button.setText(title);
        button.setTextColor(primary ? Color.WHITE : GREEN);
        button.setTextSize(15);
        button.setMinHeight(dp(48));
        button.setBackground(rounded(primary ? GREEN : PALE));
        button.setBackgroundTintList(new ColorStateList(
                new int[][] {{-android.R.attr.state_enabled}, {}},
                new int[] {0xff7b9184, primary ? GREEN : PALE}));
        button.setPadding(dp(14), dp(8), dp(14), dp(8));
    }

    private LinearLayout card(LinearLayout parent) {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(16), dp(15), dp(16), dp(15));
        panel.setBackground(rounded(Color.WHITE));
        addSection(parent, panel, 12);
        return panel;
    }

    private void addSection(LinearLayout parent, View view, int top) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, -2);
        params.topMargin = dp(top);
        parent.addView(view, params);
    }

    private GradientDrawable rounded(int color) {
        GradientDrawable background = new GradientDrawable();
        background.setColor(color);
        background.setCornerRadius(dp(14));
        return background;
    }

    private TextView text(String value, int size, int color) {
        TextView text = new TextView(this);
        text.setText(value);
        text.setTextSize(size);
        text.setTextColor(color);
        return text;
    }

    private TextView rawText(String value) {
        TextView text = text(value, 14, GREEN);
        text.setTypeface(Typeface.MONOSPACE);
        return text;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    public void showDevice(String address, String title, String info, String reading, String bytes,
            boolean selectable, Runnable select) {
        ScanRow row = rows.get(address);
        if (row == null) {
            ((View) empty.getParent()).setVisibility(View.GONE);
            row = new ScanRow(card(devices));
            rows.put(address, row);
        }
        row.name.setText(getString(selectable ? R.string.connectable_device
                : R.string.broadcast_device, title));
        row.info.setText(info);
        row.reading.setText(reading);
        row.bytes.setText(bytes);
        row.connect.setVisibility(selectable ? View.VISIBLE : View.GONE);
        row.connect.setOnClickListener(view -> {
            showReading(title);
            select.run();
        });
    }

    private final class ScanRow {
        final TextView name = text("", 16, INK);
        final TextView info = text("", 13, MUTED);
        final TextView reading = text("", 26, INK);
        final TextView bytes = rawText("");
        final Button connect = new Button(SensorActivity.this);

        ScanRow(LinearLayout panel) {
            panel.addView(name);
            panel.addView(info);
            panel.addView(reading);
            panel.addView(bytes);
            styleButton(connect, "连接", false);
            addSection(panel, connect, 8);
        }
    }

    @Override
    public void showSample(String reading, String bytes) {
        if (sample != null) {
            sample.setText(reading);
            payload.setText(bytes);
        }
    }

    @Override
    public void showScanning(boolean active) {
        scanning = active;
        if (scanButton != null) {
            scanButton.setText(active ? "停止扫描" : "重新扫描");
        }
    }

    @Override
    public void allowRequest(boolean enabled) {
        if (requestButton != null) requestButton.setEnabled(enabled);
    }

    private String[] permissions(Role role) {
        if (Build.VERSION.SDK_INT >= 31) {
            return new String[] {
                Manifest.permission.BLUETOOTH_CONNECT,
                role == Role.CLIENT ? Manifest.permission.BLUETOOTH_SCAN
                        : Manifest.permission.BLUETOOTH_ADVERTISE
            };
        }
        return role == Role.CLIENT ? new String[] {Manifest.permission.ACCESS_FINE_LOCATION}
                : new String[0];
    }

    private void startRole(Role role) {
        stopSessions();
        if (role == Role.CLIENT) showDevices();
        pendingRole = role;
        String[] missing = Arrays.stream(permissions(role))
                .filter(p -> checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED)
                .toArray(String[]::new);
        if (missing.length > 0) {
            requestPermissions(missing, REQUEST_PERMISSION);
        } else {
            startPending(true);
        }
    }

    private void startPending(boolean promptToEnable) {
        Role role = pendingRole;
        if (role == null) return;
        for (String permission : permissions(role)) {
            if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
                pendingRole = null;
                showStatus("缺少权限，请在系统设置允许蓝牙扫描或连接。");
                return;
            }
        }
        BluetoothManager manager = getSystemService(BluetoothManager.class);
        BluetoothAdapter adapter = manager == null ? null : manager.getAdapter();
        try {
            if (adapter == null) {
                pendingRole = null;
                showStatus("本机没有可用的蓝牙适配器。");
            } else if (!adapter.isEnabled()) {
                if (promptToEnable) {
                    startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                            REQUEST_ENABLE);
                } else {
                    pendingRole = null;
                    showStatus("蓝牙尚未开启。");
                }
            } else {
                pendingRole = null;
                if (role == Role.CLIENT) {
                    client = new SensorClient(this, adapter, this, this::showStatus);
                    client.start();
                } else {
                    server = new SensorPeripheral(this, manager, adapter, this::showPeripheralStatus);
                    broadcastButton.setText("停止广播");
                    server.start();
                }
            }
        } catch (SecurityException | IllegalStateException failure) {
            pendingRole = null;
            stopSessions();
            if (role == Role.SERVER) broadcastButton.setText("启动广播");
            showStatus("启动失败，" + failure.getMessage());
        }
    }

    @Override
    public void onRequestPermissionsResult(int code, String[] permissions, int[] results) {
        super.onRequestPermissionsResult(code, permissions, results);
        if (code == REQUEST_PERMISSION) startPending(true);
    }

    @Override
    protected void onActivityResult(int code, int result, Intent data) {
        super.onActivityResult(code, result, data);
        if (code == REQUEST_ENABLE) startPending(false);
    }

    private void updateBackCallback() {
        if (Build.VERSION.SDK_INT < 33) return;
        OnBackInvokedDispatcher dispatcher = getOnBackInvokedDispatcher();
        if (page == Page.DEVICES && backCallback != null) {
            dispatcher.unregisterOnBackInvokedCallback(backCallback);
            backCallback = null;
        } else if (page != Page.DEVICES && backCallback == null) {
            backCallback = this::returnToDevices;
            dispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                    backCallback);
        }
    }

    @SuppressLint("GestureBackNavigation") // 旧版本的返回键走这里。
    @Override
    public void onBackPressed() {
        if (page == Page.DEVICES) super.onBackPressed();
        else returnToDevices();
    }

    private void returnToDevices() {
        pendingRole = null;
        stopSessions();
        showDevices();
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (client != null || server != null) {
            returnToDevices();
            showStatus("页面退到后台，蓝牙实战已停止。");
        }
    }

    private void stopSessions() {
        if (client != null) {
            client.close();
            client = null;
        }
        if (server != null) {
            server.close();
            server = null;
        }
    }

    private void showPeripheralStatus(String message) {
        if (server != null && server.isClosed()) {
            server = null;
            broadcastButton.setText("启动广播");
        }
        showStatus(message);
    }

    private void showStatus(String message) {
        status.setText(message);
        Log.i("GuideBthome", message);
    }
}
```

</details>

<a id="walkthrough"></a>

## 对着代码讲重点

点请求 → 手机 A 写 01 → 手机 B 应答 → 手机 A 发起读取 → 回调拿到字节 → 解析并更新页面。

## 点击按钮，手机 A 写入 01

```java
void requestSample() {
    if (stage != Stage.READY) return;
    byte[] command = {DemoProtocol.MEASURE};
    int type = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT;
    view.showSample("等待读数", "");
    enter(Stage.WRITE, "正在向教学特征写入 01", 10_000);
    try {
        if (Build.VERSION.SDK_INT >= 33) {
            int status = gatt.writeCharacteristic(sample, command, type);
            if (status != BluetoothStatusCodes.SUCCESS) fail("写请求没有受理，code=" + status);
        } else {
            sample.setWriteType(type);
            if (!sample.setValue(command) || !gatt.writeCharacteristic(sample)) {
                fail("写请求没有受理");
            }
        }
    } catch (SecurityException | IllegalStateException error) {
        fail("写请求无法发起，" + error.getMessage());
    }
}
```

第一行只允许在 READY 时发送。byte[] 是字节数组，command 只有一个元素，值来自 DemoProtocol.MEASURE，也就是 01。

WRITE_TYPE_DEFAULT 表示要求对方回应这次写入。API 33 对应 Android 13，新系统直接把数据数组传给 writeCharacteristic。旧系统先 setWriteType、setValue，再调用写入方法。

这两个分支用的是同一条命令。返回状态码或布尔值告诉你请求是否受理。按钮进入 WRITE 阶段后变灰，防止重复发送，10 秒没结果就结束等待。

## 手机 B 收到指令后准备数据

在上面的 SensorPeripheral 中找 onCharacteristicWriteRequest。value 是手机 A 发来的字节，id 是系统给这次请求的编号。writeStatus 检查来源、目标特征、偏移和指令值，respond 用同一个编号把成功或错误状态回复给手机 A。

成功时，temperature 从 2500 变为 2650。它是为了教学生成的模拟读数。手机 B 收到下一次请求又会切回 2500。实际传感器需要怎样启动测量、要等多久，由硬件协议决定。

## 手机 A 收到写成功，再请求读取

```java
public void onCharacteristicWrite(BluetoothGatt source, BluetoothGattCharacteristic item,
        int status) {
    handle(source, () -> {
        if (stage != Stage.WRITE || !DemoProtocol.SAMPLE.equals(item.getUuid())) return;
        if (status != BluetoothGatt.GATT_SUCCESS) {
            fail("写入失败，status=" + status);
            return;
        }
        enter(Stage.READ, "外设已确认写入，正在读取结果", 10_000);
        if (!source.readCharacteristic(sample)) fail("读请求没有受理");
    });
}
```

先确认正在等写结果且特征正确，再检查 status。成功后进入 READ，调用 readCharacteristic。这个方法只需要告诉系统要读哪个特征。

手机 B 的 onCharacteristicReadRequest 收到请求后生成结果数组，再用 sendResponse 返回字节。手机 A 随后的 onCharacteristicRead 回调拿到数据。Android 13 起直接用 value 参数，旧版本从特征对象取值，工程统一交给 received 处理。

## 把字节换成屏幕上的数字

先看本次会收到的数据。

```text
40 02 5A 0A 03 BF 13
```

40 是 BTHome v2 明文信息，02 表示接下来是两字节温度，03 表示接下来是两字节湿度。打开[完整解析器](#decoder)，温度的关键计算是下面一行。

```java
double temperature = (short) littleEndian16(data, offset) / 100.0;
```

littleEndian16 把低字节在前的数据组合起来。5A 0A 得到十六进制 0A5A，即十进制 2650。再除以 100.0 得到 26.50。short 按有符号的 16 位整数解释，负温度也能保留下来。

湿度 BF 13 组合成 5055，除以 100.0 得到 50.55。湿度使用无符号值。解析器每次读取前检查字节是否够用，遇到加密或不完整数据会给出说明。[BTHome 数据格式](https://bthome.io/format/)

## 显示结果，恢复按钮

received 先检查读取状态，再解析数据并确认温度和湿度齐全。成功时调用 view.showSample，把读数字符串和原始字节交给页面。

```java
public void showSample(String reading, String bytes) {
    if (sample != null) {
        sample.setText(reading);
        payload.setText(bytes);
    }
}
```

setText 更新屏幕上的两个文本区域。客户端随后回到 READY，按钮重新可点。这样一次点击有明确的开始和结束。

## 自己试一次

先在纸上把回包里的 5A 0A 算成温度。然后把手机 B 的 SensorPeripheral 中模拟温度分支的 2650 改为 2700，重新运行手机 B。再次请求时对照手机 A 显示的 27.00 °C 和原始字节。

**一句话记住**　先按约定发指令，再读返回值，最后把字节翻成数字。

**动手验证**　请求两次，对照原始字节，看到温度在 26.50 和 25.00 之间切换。

**面试题**　写成功就能把温度显示出来吗？仍要等读回调带回数据，并解析成功。

## 收到错误时，分清是哪一步

writeCharacteristic 的即时返回失败，说明系统没有受理这次写操作。onCharacteristicWrite 的 status 失败，说明已发起操作的写结果失败。读请求和读回调也各有一次检查。

读成功但提示无法解析时，把原始字节和 DemoProtocol.sample 对照。先检查字节数量、对象 ID，再检查小端顺序和倍率。未知对象、截断数组和加密消息都要按实际情况处理。

工程把失败转换成提示并关闭会话。需要重试时返回列表重新扫描连接。本例没有命令编号，连续操作靠 READY、WRITE、READ 三个阶段控制。

## 再想两道题

1. **湿度为什么不强转 short？** 本示例的湿度对象使用无符号 16 位整数，温度对象使用有符号整数。
2. **手机 B 为什么收到写请求就改变模拟温度？** 这是本示例定义的即时模拟测量。真实设备完成测量的时间要查设备协议。

继续读[双机验收篇](#android/bthome-mvp/two-device-check)。

回看[连接篇](#android/bthome-mvp/connection) · [返回工程入口](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/android/bthome-mvp)
