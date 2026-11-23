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
