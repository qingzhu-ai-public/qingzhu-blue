import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestAndroidBlePermissions() async {
  if (!Platform.isAndroid) return true;
  final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  final permissions = sdk >= 31
      ? [Permission.bluetoothScan, Permission.bluetoothConnect]
      : [Permission.locationWhenInUse];
  final statuses = await permissions.request();
  return permissions.every(
    (permission) => statuses[permission]?.isGranted ?? false,
  );
}
