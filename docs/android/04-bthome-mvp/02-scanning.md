---
title: 扫描篇
slug: scanning
order: 20
summary: 申请权限、扫描设备并显示广播温度。
---

# 扫描篇　点一下按钮，让附近设备出现在列表

点「开始扫描」，允许权限后，在列表看到广播温度。下面先列出本篇使用的完整文件，再从按钮点击开始讲解。

## 本篇完整代码

以下文件取自同一个 Android Studio 工程，包含各自的 import、成员变量和全部方法。按标出的路径对照项目，配套文件已在工程中提供。后面的讲解按本篇功能顺序展开。

先找到这些文件的位置。

- [SensorActivity.java](#activity)
- [SensorClient.java](#client)
- [DemoProtocol.java](#protocol)
- [BthomeDecoder.java](#decoder)

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

<a id="client"></a>

### SensorClient.java

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

<a id="decoder"></a>

### BthomeDecoder.java

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

## 对着代码讲重点

现在沿着一次操作读下面的几个关键位置。需要查看上下文时，回到本篇前面的完整文件。

## 先知道这几个写法

`client.start()` 表示让 client 这个对象执行 start 方法。对象可以先理解成一个负责某件事的工具，方法就是它能做的动作。`if` 表示满足条件才执行，`return` 表示到这里结束本次方法。

代码里经常出现「回调」。例如你请蓝牙系统查找设备，它需要一些时间。你先把一个接收结果的方法交给系统，系统找到设备后调用它，把结果送回来。这就是后面要读的 onScanResult。

## 按钮先调用 startRole

在 SensorActivity 的 showDevices 里，按钮第一次被点击会执行 `startRole(Role.CLIENT)`。这里 CLIENT 表示本机当查找设备的一方。

蓝牙扫描需要用户许可，所以这个方法先检查权限。清单声明放在[AndroidManifest.xml 的完整代码](#manifest)，运行时的申请发生在下面。

## 手机版本不同，需要的权限也不同

```java
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
```

`String[]` 是一组文字，这里装着权限名称。`SDK_INT >= 31` 表示 Android 12 或更新版本。扫描端申请 SCAN 和 CONNECT，分别用于查找与连接。外设端用 CONNECT 和 ADVERTISE，后者允许广播。

如果手机版本较旧，扫描端申请 ACCESS_FINE_LOCATION。两套权限都已在清单声明，旧版权限用 maxSdkVersion=30 限定适用系统。清单里的 neverForLocation 表示本 App 不通过扫描推断位置，系统可能据此过滤部分信标。[Android 权限说明](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)

## 找到还没允许的权限，再弹窗

```java
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
```

先停掉上一次会话，再把用户选的角色记到 pendingRole。弹窗要等用户操作，返回后靠这个变量接着做。

中间三行 stream 写法可以逐句读成「遍历所需权限，留下未允许的，把它们放进 missing 数组」。实际检查用的是 `checkSelfPermission`，它返回 PERMISSION_GRANTED 才算允许。

missing.length 大于零时，`requestPermissions` 把待申请权限交给 Android。REQUEST_PERMISSION 是项目定义的请求编号，回调时用它识别这是哪一次请求。全都已允许时，进入 startPending。

## 用户点完弹窗，从哪里继续

```java
public void onRequestPermissionsResult(int code, String[] permissions, int[] results) {
    super.onRequestPermissionsResult(code, permissions, results);
    if (code == REQUEST_PERMISSION) startPending(true);
}
```

这就是系统回调。请求编号相符时，再进 startPending，重新检查每项权限。用户拒绝时显示缺少权限，流程就停下。已经拒绝并不再询问的权限，可能要到手机设置里允许。

接着在上面的 startPending 里找到这两行。

```java
BluetoothManager manager = getSystemService(BluetoothManager.class);
BluetoothAdapter adapter = manager == null ? null : manager.getAdapter();
```

第一行向 Android 取得蓝牙管理服务，第二行取得本机适配器。`null` 表示没有拿到对象。`? :` 是条件选择写法，管理服务为空就让 adapter 也为空，否则调用 getAdapter。

有适配器后用 isEnabled 检查蓝牙是否开启。关闭时，ACTION_REQUEST_ENABLE 会请系统弹出开启提示。onActivityResult 收到结果后再检查一次。用户允许权限、开启蓝牙后，才创建 SensorClient 并执行 start。

## 现在真正开始扫描

```java
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
```

先取 BluetoothLeScanner。为空就显示不可用。enter 记录「正在扫描」，并设置 12 秒计时。ScanSettings.Builder 用来准备扫描设置，LOW_LATENCY 表示积极扫描，适合当前前台查找。

核心是 `scanner.startScan(null, settings, scanCallback)`。三个位置依次放过滤条件、扫描设置、接收结果的回调。本例第一个参数为空，先接收广播，再在回调里筛选 BTHome 数据。

try/catch 是处理失败的写法。权限失效时系统可能抛出 SecurityException，catch 把它转成页面提示。

## 找到设备，系统会调用这个方法

```java
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
```

先抓住这条主线。result 是刚收到的扫描结果，getScanRecord 取广播，getServiceData 按 FCD2 取 BTHome 数据，decode 把字节换成温度，showDevice 把结果交给页面。

`if (record == null) return` 表示没有广播内容就跳过。下一行 data 为空也跳过。这样只展示包含 BTHome 服务数据的设备。

getRssi 是这次信号强度。demo 判断它是否可连接并且广播了教学服务，是页面决定显示连接按钮的依据。owner.post 把处理安排到主线程，确保后面可以安全更新界面。

最后看 Activity 的 showDevice。它通过地址在 rows 中找卡片，第一次创建，随后更新。reading.setText 将温度文字显示到卡片。一次扫描会多次收到同一设备，因此要更新原行。

## 扫描结束后，为什么列表还在

finishScan 调用 stopScan，并把阶段改成 PICK，表示等用户选设备。stopScan 内部调用 `scanner.stopScan(scanCallback)`，传入开始时同一个回调对象。计时到期也走这条路径。退出页面则通过 close 清理会话。

## 动手验证

先拒绝权限，看提示是否停在缺少权限。允许权限后重新扫描，确认列表显示温度。停止扫描后，已发现的设备应保留。Android 11 及以下还要手动检查系统位置开关。

**一句话记住**　先问用户能不能找，再请系统开始找，找到一台就往列表放一台。

**面试题**　startScan 调用结束，设备是不是都找到了？扫描要持续一段时间，结果从回调陆续抵达。

## 找不到设备，沿这三处查

先看页面有没有缺少权限提示。回到系统设置核对 App 权限，旧系统还要核对位置开关。

然后看手机 B 是否显示广播已启动。广播注册或启动失败时，手机 A 的扫描逻辑即使正确也收不到它。

如果触发 onScanFailed，保留 errorCode。它表示系统扫描失败。扫描窗口结束且列表为空，表示这段时间没有收到本示例接受的数据。当前回调会跳过缺少 FCD2 服务数据的设备。

## 再想两道题

1. **为什么重复收到同一设备的广播，列表没有不断增加？** showDevice 按本轮的地址找已有卡片，找到了就更新读数。
2. **12 秒结束扫描是系统要求吗？** 这是项目选择的等待时间。enter 安排计时，onTimeout 再调用 finishScan。

继续读[连接篇](#android/bthome-mvp/connection)。

回看[原型与工程入口](#android/bthome-mvp/prototype) · [返回工程入口](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/android/bthome-mvp)
