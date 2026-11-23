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
