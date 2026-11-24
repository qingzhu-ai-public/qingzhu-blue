---
title: 传输篇　把七个字节变成温湿度
slug: transfer
order: 40
---

# 传输篇　把七个字节变成温湿度

点「请求新读数」。页面先发 `01`，收到写确认后发起读请求。读到 `40 02 5A 0A 03 BF 13` 时，应显示 `26.50 °C · 50.55% RH`。

## 本篇完整代码

按文件名展开。 [跳到讲解](#walkthrough)

<details>
<summary>lib/main.dart</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/flutter/thermometer-mvp/lib/main.dart)

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'frame.dart';
import 'permissions.dart';

void main() => runApp(const MaterialApp(home: ThermometerPage()));

class ThermometerPage extends StatefulWidget {
  const ThermometerPage({super.key});

  @override
  State<ThermometerPage> createState() => _ThermometerPageState();
}

class _ThermometerPageState extends State<ThermometerPage> {
  final _ble = FlutterReactiveBle();
  final _devices = <String, DiscoveredDevice>{};
  StreamSubscription<DiscoveredDevice>? _scan;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  Timer? _scanTimer;
  QualifiedCharacteristic? _sample;
  int _session = 0;
  bool _busy = false;
  String _message = '用另一台手机启动教学外设。';
  String _reading = '等待测量';
  String _hex = '';

  void _show(String message) {
    if (mounted) setState(() => _message = message);
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    final scan = _scan;
    _scan = null;
    await scan?.cancel();
    if (mounted) setState(() {});
  }

  Future<void> _startScan() async {
    if (_busy || _connection != null || _scan != null) return;
    setState(() => _busy = true);
    try {
      if (!await requestAndroidBlePermissions()) {
        _show('请在系统设置中允许蓝牙扫描所需的权限。');
        return;
      }
      if (!mounted) return;
      final status = await _ble.statusStream
          .where((value) => value != BleStatus.unknown)
          .timeout(const Duration(seconds: 10))
          .first;
      if (!mounted) return;
      if (status != BleStatus.ready) {
        _show('蓝牙暂不可用：${status.name}。请检查开关和系统权限。');
        return;
      }
      setState(() => _devices.clear());
      _scan = _ble
          .scanForDevices(withServices: [Uuid.parse(serviceId)])
          .listen(
            (device) {
              if (mounted) setState(() => _devices[device.id] = device);
            },
            onError: (Object error) async {
              await _stopScan();
              _show('扫描失败：$error');
            },
          );
      _show('正在查找教学外设…');
      _scanTimer = Timer(const Duration(seconds: 8), () async {
        await _stopScan();
        _show(_devices.isEmpty ? '没扫到设备，请检查教学外设是否在广播。' : '请选择设备。');
      });
    } catch (error) {
      _show('无法扫描：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(DiscoveredDevice device) async {
    if (_busy || _connection != null) return;
    setState(() {
      _busy = true;
      _reading = '等待测量';
      _hex = '';
    });
    final session = ++_session;
    try {
      await _stopScan();
      if (!mounted || session != _session) return;
      _show('正在连接…');
      _connection = _ble
          .connectToDevice(
            id: device.id,
            connectionTimeout: const Duration(seconds: 10),
          )
          .listen(
            (update) async {
              if (!mounted || session != _session) return;
              if (update.connectionState == DeviceConnectionState.connected) {
                await _discover(device.id, session);
              } else if (update.connectionState ==
                  DeviceConnectionState.disconnected) {
                await _disconnect('已断开，可重新扫描。');
              }
            },
            onError: (Object error) async {
              if (session == _session) await _disconnect('连接失败：$error');
            },
          );
    } catch (error) {
      if (session == _session) await _disconnect('连接失败：$error');
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Future<void> _discover(String deviceId, int session) async {
    final sample = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: Uuid.parse(serviceId),
      characteristicId: Uuid.parse(sampleId),
    );
    try {
      _show('正在查找读写特征…');
      final entry = await _ble
          .resolveSingle(sample)
          .timeout(const Duration(seconds: 8));
      if (!entry.isReadable || !entry.isWritableWithResponse) {
        throw StateError('教学特征需要同时支持 Read 和 Write');
      }
      if (!mounted || session != _session) return;
      setState(() => _sample = sample);
      _show('可以请求读数。');
    } catch (error) {
      if (session == _session) await _disconnect('找不到可用特征：$error');
    }
  }

  Future<void> _measure() async {
    final sample = _sample;
    if (sample == null || _busy) return;
    final session = _session;
    setState(() {
      _busy = true;
      _message = '正在请求新读数…';
      _reading = '等待测量';
      _hex = '';
    });
    try {
      await _ble
          .writeCharacteristicWithResponse(sample, value: measureCommand)
          .timeout(const Duration(seconds: 6));
      if (session != _session) return;
      final data = await _ble
          .readCharacteristic(sample)
          .timeout(const Duration(seconds: 6));
      if (!mounted || session != _session) return;
      setState(() => _hex = hexFrame(data));
      final reading = decodeFrame(data);
      setState(() => _reading = reading);
      _show('读数已更新。');
    } on TimeoutException {
      if (session == _session) await _disconnect('读写超时，请重新连接。');
    } catch (error) {
      if (session == _session) _show('读写失败：$error');
    } finally {
      if (mounted && session == _session) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect(String message) async {
    ++_session;
    final connection = _connection;
    _connection = null;
    _sample = null;
    _busy = true;
    _show(message);
    try {
      await connection?.cancel();
    } catch (error) {
      _show('结束连接失败：$error');
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    ++_session;
    _scanTimer?.cancel();
    unawaited(_scan?.cancel().catchError((Object _) {}));
    unawaited(_connection?.cancel().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('蓝牙温湿度计')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_message),
          FilledButton(
            onPressed: _busy || _connection != null || _scan != null
                ? null
                : _startScan,
            child: const Text('开始扫描'),
          ),
          for (final device in _devices.values)
            ListTile(
              title: Text(device.name.isEmpty ? '教学温湿度计' : device.name),
              subtitle: Text('${device.rssi} dBm'),
              enabled: !_busy && _connection == null,
              onTap: () => _connect(device),
            ),
          FilledButton(
            onPressed: _sample != null && !_busy ? _measure : null,
            child: const Text('请求新读数'),
          ),
          OutlinedButton(
            onPressed: _connection == null ? null : () => _disconnect('已断开。'),
            child: const Text('断开连接'),
          ),
          Text(_reading),
          SelectableText(_hex),
        ],
      ),
    );
  }
}
```

</details>

<details>
<summary>lib/permissions.dart</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/flutter/thermometer-mvp/lib/permissions.dart)

```dart
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
```

</details>

<details>
<summary>lib/frame.dart</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/flutter/thermometer-mvp/lib/frame.dart)

```dart
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
```

</details>

<a id="walkthrough"></a>

## 跟着操作看代码

### 1. 先写一个字节，等写确认

`_measure()` 用 `writeCharacteristicWithResponse(sample, value: measureCommand)` 向已验证特征写入 `[0x01]`。 如果命令没写成功，流程进错误处理。写确认表示外设接下了这次写操作，真正的温湿度由后续读请求拿到。

### 2. 读回字节，先留原样

`readCharacteristic(sample)` 返回 `List<int>`。 先把数组转成十六进制显示，再交给 `decodeFrame`。遇到新协议或截断包，页面还能显示实际读到的东西。

### 3. 按字段的位置拆包

`40` 是示例校验的头，`02` 标记温度，后面的低字节 `5A` 和高字节 `0A` 合成 `0A5A`，十进制 2650，除以 100 就得到 26.50。湿度字段 `03 BF 13` 同理，按无符号小端值解析。Dart 用 `ByteData.getInt16(2, Endian.little)`。 温度带符号才能表示负数。

**动手试试**　输入 `40 02 0C FE 03 BF 13`，预期 `-5.00 °C · 50.55% RH`。删掉一个字节，预期出现格式错误。

**一句话**　写是下单，读是取货，字节要按设备给的规格拆。

**面试题**　为什么写成功后还需要读？

写成功对应 GATT 写确认。这个教学协议把业务数据放在随后读取的特征值里。

[双端验收](#flutter/thermometer-mvp/two-device-check) · [插件 API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html)
