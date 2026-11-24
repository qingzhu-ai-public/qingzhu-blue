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
