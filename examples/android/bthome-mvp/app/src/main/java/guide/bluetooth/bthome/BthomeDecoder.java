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
