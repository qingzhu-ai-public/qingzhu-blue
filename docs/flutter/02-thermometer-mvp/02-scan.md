---
title: 扫描篇　让设备出现一行
slug: scan
order: 20
---

# 扫描篇　让设备出现一行

B 启动模拟温湿度计。A 点「开始扫描」。看到一行设备名称和 RSSI 后，就可以点进去连接。

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

### 1. 点按钮后先申请权限

看 `_startScan()` 里的第一段。它先调用 `requestAndroidBlePermissions()`。这个函数通过 `DeviceInfoPlugin` 读取 Android API 级别。31 及以上申请附近设备所需的扫描和连接权限。低版本走位置权限。iOS 的授权由 Core Bluetooth 负责，入口篇已经把用途写进 Info.plist。

### 2. 等系统蓝牙可用

授权结果说明用户是否允许。还要从 `statusStream` 等到系统给出明确状态。只有 `BleStatus.ready` 才开始扫描。如果返回关闭或权限不足，界面提示原因，并结束这次操作。

### 3. 结果进 Map，停扫时取消订阅

`scanForDevices(withServices: [Uuid.parse(serviceId)])` 会筛选广播中的教学服务。每次进监听回调，把 `device.id` 作为键。旧行会被新广播覆盖。八秒后 `Timer` 调用 `_stopScan()`，由保存的订阅句柄取消扫描。

**动手试试**　把扫描窗口改成三秒。关掉外设后应看到空列表说明，再开启外设重试。

**一句话**　扫到的设备是一条条送来的，把每台设备的最新结果放回同一行。

**面试题**　那个扫描调用的返回值是不是设备列表？

返回的是流。订阅它才能收到实际设备。

[连接](#flutter/thermometer-mvp/connection) · [插件 API](https://pub.dev/documentation/flutter_reactive_ble/latest/flutter_reactive_ble/FlutterReactiveBle-class.html)
