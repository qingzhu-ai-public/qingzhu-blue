---
title: 连接篇
slug: connection
order: 30
summary: 连接教学外设并找到可读写的特征。
---

# 连接篇　选中一台设备，请它建立连接

在手机 A 的列表里点「连接」，看详情页的「请求新读数」何时从灰色变为可点。

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

<a id="walkthrough"></a>

## 对着代码讲重点

点连接 → connectGatt → 连接回调 → discoverServices → 找到特征 → 点亮请求按钮。

## 点击连接时，程序记得你选了谁

扫描结果里的 getDevice 返回 BluetoothDevice，可以把它理解成「这台被发现的设备」。SensorActivity 的连接按钮执行之前保存的动作，将这个对象交给 connect。

```java
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
```

第一行检查当前还在扫描或等用户选择，防止重复连接。先停扫，再显示正在连接。

connectGatt 向手机蓝牙系统发起连接。参数依次是应用环境、是否等待自动连接、接收结果的回调、传输方式、初始物理层和回调执行的位置。本例用 false 直接尝试连接，用 TRANSPORT_LE 选择 BLE，使用 LE 1M 初始物理层。最后的 owner 让回调在主线程处理。

返回的 gatt 是后续读写要用的客户端对象。拿到它之后等系统通知连接结果。12 秒都没完成，本项目会显示超时并释放资源。

## 接到已连接消息，再请设备列出功能

```java
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
```

status 表示这次事件是否成功，newState 表示连接状态。先看 status，再看 newState。STATE_DISCONNECTED 是断开，STATE_CONNECTED 是连上。

连上以后调用 discoverServices，请设备提供服务信息。服务可以理解成一组功能，特征是组内具体可读写的数据项。例如温湿度计的服务里有一个读取温湿度的入口。

这里 source 就是回调对应的 GATT 对象。discoverServices 返回 true 表示受理请求，发现结果还要继续等。

## 按协议编号找到对应特征

```java
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
```

UUID 是双方约定的编号。SERVICE 用来找服务，SAMPLE 用来找服务里的特征。服务和特征编号可以在 DemoProtocol 完整源码中对照。

required 把 READ 和 WRITE 两种能力组合起来，后面的按位运算检查目标特征是不是两者都支持。找到并通过检查后才执行 ready，让「请求新读数」变成可点状态。

ready 进入 READY 阶段，enter 调用页面的 allowRequest，最终通过 requestButton.setEnabled(true) 点亮按钮。

## 看不懂 handle 时，先知道它的职责

上面两个回调都把后续操作交给 handle。它先把任务排到主线程，然后检查这个事件是否属于当前连接。已经关闭的会话、旧连接的消息会被忽略，权限异常会转为失败提示。上面的完整代码里可以看到这几项检查。

## 返回列表时清理连接

用户返回时，Activity 调用 stopSessions，再由客户端 close 先 disconnect，随后 close 释放 GATT。清理时还会取消超时、停止扫描和禁用请求按钮。退出前台同样结束本次练习。

## 自己试一次

趁详情页还显示正在连接时点「返回列表」。确认上一次连接的回调没有让已关闭的详情页重新出现。

**一句话记住**　先连上设备，再找到对的服务和特征，才知道往哪里发数据。

**动手验证**　点连接，观察提示从连接变成发现服务，再到可以请求。返回列表后重新扫描连接一次。

**面试题**　连接成功就能发送吗？还要发现服务并取得实际可写的特征。

## 失败时按最后成功的一步查

停在正在连接，先确认外设仍在工作。回调 status 失败时保留数值，超时则保留 CONNECT 阶段。自动重试策略可以在之后扩展，目前由用户返回列表重试。

已经连上却找不到特征时，对照两台手机 DemoProtocol 的 SERVICE 和 SAMPLE，并检查手机 B 注册的是哪个服务。广播中的服务编号只是发现线索，最终还要查实际 GATT 服务表。

连接中返回页面后，客户端关闭会话。handle 检查 source 是否为当前 gatt，并检查 CLOSED，阻止旧事件更新界面。

## 再想两道题

1. **discoverServices 返回 true 就能显示请求按钮吗？** 还要等发现回调成功，并确认特征具备读写能力。
2. **为什么保存 gatt 成员变量？** 后续发现、读写、断开和释放，都通过同一个客户端对象操作。

继续读[传输篇](#android/bthome-mvp/transfer)。

回看[扫描篇](#android/bthome-mvp/scanning) · [返回工程入口](https://github.com/qingzhu-ai-public/qingzhu-blue/tree/main/examples/android/bthome-mvp)
