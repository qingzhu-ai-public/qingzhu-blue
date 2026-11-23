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
