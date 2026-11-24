import { PermissionsAndroid, Platform } from 'react-native';

export async function requestAndroidBlePermissions(): Promise<boolean> {
  if (Platform.OS !== 'android') return true;
  const { BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION } = PermissionsAndroid.PERMISSIONS;
  const permissions = Number(Platform.Version) >= 31
    ? [BLUETOOTH_SCAN, BLUETOOTH_CONNECT]
    : [ACCESS_FINE_LOCATION];
  const statuses = await PermissionsAndroid.requestMultiple(permissions);
  return permissions.every(permission => statuses[permission] === PermissionsAndroid.RESULTS.GRANTED);
}
