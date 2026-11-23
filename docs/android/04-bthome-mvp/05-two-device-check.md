---
title: 双机验收篇
slug: two-device-check
order: 50
summary: 用一台手机模拟外设，另一台走完整个通信流程。
---

# 双机验收篇　先写出一个能被连接的模拟温湿度计

手机 B 模拟温湿度计，手机 A 负责扫描、连接和请求。下面先列出外设实现涉及的完整文件，再讲服务注册、广播和应答。

## 本篇完整代码

以下文件取自同一个 Android Studio 工程，包含各自的 import、成员变量和全部方法。按标出的路径对照项目，配套文件已在工程中提供。后面的讲解按本篇功能顺序展开。

先找到这些文件的位置。

- [SensorPeripheral.java](#peripheral)
- [SensorActivity.java](#activity)
- [DemoProtocol.java](#protocol)

<a id="manifest"></a>

### AndroidManifest.xml

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

<a id="peripheral"></a>

### SensorPeripheral.java

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

<a id="activity"></a>

### SensorActivity.java

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

<a id="protocol"></a>

### DemoProtocol.java

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

## 对着代码讲重点

现在沿着一次操作读下面的几个关键位置。需要查看上下文时，回到本篇前面的完整文件。

## 先向系统注册服务

在 [SensorPeripheral.java](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/android/bthome-mvp/app/src/main/java/guide/bluetooth/bthome/SensorPeripheral.java) 找到 `start`。


先通过适配器取得 advertiser。它为空时显示本机无法作为广播外设，可以交换两台手机的角色。openGattServer 把应用环境和外设回调交给系统，返回本机 GATT Server。

创建主服务并填入教学服务 UUID，然后添加 SAMPLE 特征。PROPERTY_READ 和 PROPERTY_WRITE 告诉客户端支持什么操作；PERMISSION_READ 和 PERMISSION_WRITE 是外设访问权限配置。两组常量分别控制特征声明和访问要求。

addService 的返回值说明系统是否受理注册。后面要继续等 onServiceAdded。这里预设 15 秒超时，避免页面一直停在注册状态。

## 等服务就绪再开始广播

在 [SensorPeripheral.java](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/android/bthome-mvp/app/src/main/java/guide/bluetooth/bthome/SensorPeripheral.java) 找到 `onServiceAdded`。


回调成功而且 UUID 符合预期，才调用 advertise。这样手机 A 扫到广播立即连接时，外设已经有对应服务可发现。advertisingRequested 防止重复启动。

## 把广播数据交给 Android

在 [SensorPeripheral.java](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/android/bthome-mvp/app/src/main/java/guide/bluetooth/bthome/SensorPeripheral.java) 找到 `advertise`。


connectable(true) 允许别人连接。广播里同时放教学服务 UUID 和 BTHome Service Data。前者让手机 A 识别本项目的可连接外设，后者用于显示广播温度。

传统广播有 31 字节预算。这里 Flags 约占 3 字节，128 位服务 UUID 项占 18 字节，BTHome 服务数据项占 8 字节，共 29 字节。因此没有再把设备名称放进去。广播内存放的温度固定为 25.00 °C。

startAdvertising 发起后要等 AdvertiseCallback。成功取消超时，失败显示系统错误码。若超过广播长度预算，就需要缩减数据或另行安排扫描响应数据。



## 记录是谁连上了外设

在 [SensorPeripheral.java](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/android/bthome-mvp/app/src/main/java/guide/bluetooth/bthome/SensorPeripheral.java) 找到 `onConnectionStateChange`。


peer 保存当前客户端。第二台客户端来连接时会被取消连接，这个示例一次服务一个客户端。断开时清空 peer，并把下一轮的模拟温度重置为 2500。传输篇里 writeStatus 用 peer 校验请求来源。

## 停止按钮怎样释放整个会话

在 [SensorPeripheral.java](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/android/bthome-mvp/app/src/main/java/guide/bluetooth/bthome/SensorPeripheral.java) 找到 `close`。


closed 防止重复关闭，也让排队的旧事件不再执行。先取消启动计时，再停止广播、取消当前连接并关闭 Server。这个 App 的「停止广播」按钮结束整个模拟会话。系统 stopAdvertising 本身只停止广播，连接还需要单独处理。

## 安装并操作

在工程目录运行构建脚本，把输出的 APK 安装到两台手机。首次换用 Gradle 调试签名时，如果手机里留着之前用临时实验签名的版本，先卸载旧实验 App。安装步骤见[工程入口](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/android/bthome-mvp)。

| 操作 | 手机 A 应看到 | 手机 B 应看到 |
| --- | --- | --- |
| B 启动广播，A 开始扫描 | 教学温湿度计和 25.00 °C | 正在广播 |
| A 点击连接 | 先连接，再发现服务，最后允许请求 | 客户端已连接 |
| A 请求一次 | 26.50 °C、50.55% RH 和原始字节 | 收到 01 并返回新读数 |
| A 再请求一次 | 温度回到 25.00 °C | 返回第二组读数 |
| B 停止会话 | 提示断开，请求按钮禁用 | 广播停止 |

## 用两端日志找到出错的位置

每台手机分别执行下面命令，把序列号替换成 adb devices 输出的值。

```powershell
adb -s <序列号> logcat -s GuideBthome
```

广播启动失败先查外设端权限和广播能力。手机 A 能看到温度却找不到特征时，查教学服务 UUID 和服务注册日志。写入成功却读不到时，依次看 B 是否收到 01、A 是否进入 READ、B 是否返回字节以及 A 是否解析失败。

再故意关闭手机 B 的蓝牙或退出页面，确认手机 A 能结束当前操作。没有错误回调的情况下，客户端的连接、发现、写、读各阶段计时也会结束等待。记录故障时写下两端手机、Android 版本、最后成功阶段和原始错误码。

**一句话记住**　先让模拟设备准备好柜台和告示，再从另一台手机检查一问一答的每一步。

## 面试题

1. **为什么注册服务成功后才广播？** 客户端发现外设就可能立即连接，服务要提前准备好。
2. **停止广播就会断开吗？** 系统停止广播和断开连接是不同操作。这个 App 的停止按钮同时执行了这些清理。
3. **为什么要记录两端日志？** 客户端等待超时时，外设日志可以帮助判断请求是否到达以及是否发送响应。

[Android GATT Server 参考](https://developer.android.com/reference/android/bluetooth/BluetoothGattServer)

回看[传输篇](#android/bthome-mvp/transfer) · [返回工程入口](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/android/bthome-mvp)
