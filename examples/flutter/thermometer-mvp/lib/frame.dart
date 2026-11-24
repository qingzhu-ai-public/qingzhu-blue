import 'dart:typed_data';

const serviceId = '476cdf45-6063-43a1-b8e2-8c1fbed00601';
const sampleId = '476cdf45-6063-43a1-b8e2-8c1fbed00602';
const measureCommand = [0x01];

String decodeFrame(List<int> data) {
  if (data.length != 7 ||
      data.any((byte) => byte < 0 || byte > 255) ||
      data[0] != 0x40 ||
      data[1] != 0x02 ||
      data[4] != 0x03) {
    throw const FormatException('回包格式不符');
  }
  final bytes = ByteData.sublistView(Uint8List.fromList(data));
  final temperature = bytes.getInt16(2, Endian.little) / 100;
  final humidity = bytes.getUint16(5, Endian.little) / 100;
  return '${temperature.toStringAsFixed(2)} °C · ${humidity.toStringAsFixed(2)}% RH';
}

String hexFrame(List<int> data) => data
    .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
