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
