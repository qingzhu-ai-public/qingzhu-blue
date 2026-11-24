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
<summary>App.tsx</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/react-native/thermometer-mvp/App.tsx)

```tsx
import { useEffect, useRef, useState } from 'react';
import { Button, ScrollView, StyleSheet, Text, View } from 'react-native';
import BleManager, { BleState, type Peripheral } from 'react-native-ble-manager';
import { decodeFrame, hexFrame, MEASURE, SAMPLE, SERVICE } from './frame';
import { requestAndroidBlePermissions } from './permissions';

class OperationTimeout extends Error {}

function withTimeout<T>(operation: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new OperationTimeout('操作超时')), ms);
  });
  return Promise.race([operation, deadline]).finally(() => clearTimeout(timer));
}

export default function App() {
  const [devices, setDevices] = useState<Peripheral[]>([]);
  const [scanning, setScanning] = useState(false);
  const [busy, setBusy] = useState(false);
  const [ready, setReady] = useState(false);
  const [message, setMessage] = useState('用另一台手机启动教学外设。');
  const [reading, setReading] = useState('等待测量');
  const [hex, setHex] = useState('');
  const active = useRef(false);
  const scanningNow = useRef(false);
  const locked = useRef(false);
  const session = useRef(0);
  const current = useRef<string | null>(null);
  const started = useRef<Promise<void> | null>(null);

  useEffect(() => {
    active.current = true;
    const found = BleManager.onDiscoverPeripheral(device => {
      if (!scanningNow.current) return;
      setDevices(list => [...list.filter(item => item.id !== device.id), device]);
    });
    const stopped = BleManager.onStopScan(() => {
      if (!scanningNow.current) return;
      scanningNow.current = false;
      setScanning(false);
      setMessage('扫描结束。列表为空时，请确认外设仍在广播。');
    });
    const disconnected = BleManager.onDisconnectPeripheral(event => {
      if (event.peripheral !== current.current) return;
      ++session.current;
      current.current = null;
      locked.current = false;
      setBusy(false);
      setReady(false);
      setMessage('已断开，可重新扫描。');
    });
    return () => {
      active.current = false;
      ++session.current;
      found.remove();
      stopped.remove();
      disconnected.remove();
      if (scanningNow.current) void BleManager.stopScan().catch(() => {});
      scanningNow.current = false;
      const id = current.current;
      current.current = null;
      if (id) void BleManager.disconnect(id).catch(() => {});
    };
  }, []);

  async function startScan() {
    if (locked.current || scanningNow.current || current.current) return;
    locked.current = true;
    setBusy(true);
    try {
      if (!await requestAndroidBlePermissions()) {
        if (active.current) setMessage('请在系统设置中允许蓝牙扫描所需的权限。');
        return;
      }
      if (!active.current) return;
      started.current ??= BleManager.start({ showAlert: false }).catch(error => {
        started.current = null;
        throw error;
      });
      await started.current;
      const state = await BleManager.checkState();
      if (!active.current) return;
      if (state !== BleState.On) {
        setMessage('蓝牙暂不可用：' + state + '。请检查开关和权限后重试。');
        return;
      }
      setDevices([]);
      scanningNow.current = true;
      setScanning(true);
      setMessage('正在查找教学外设…');
      await BleManager.scan({ serviceUUIDs: [SERVICE], seconds: 8, allowDuplicates: false });
      if (!active.current) await BleManager.stopScan();
    } catch (error) {
      scanningNow.current = false;
      if (active.current) {
        setScanning(false);
        setMessage('扫描失败：' + String(error));
      }
    } finally {
      locked.current = false;
      if (active.current) setBusy(false);
    }
  }

  async function connect(device: Peripheral) {
    if (locked.current || current.current) return;
    locked.current = true;
    setBusy(true);
    setReading('等待测量');
    setHex('');
    const attempt = ++session.current;
    try {
      if (scanningNow.current) {
        scanningNow.current = false;
        setScanning(false);
        await BleManager.stopScan();
      }
      if (!active.current || attempt !== session.current) return;
      current.current = device.id;
      setMessage('正在连接…');
      await withTimeout(BleManager.connect(device.id), 10000);
      if (attempt !== session.current) return;
      setMessage('正在查找读写特征…');
      const info = await withTimeout(BleManager.retrieveServices(device.id), 8000);
      if (attempt !== session.current) return;
      const sample = info.characteristics?.find(item =>
        item.service.toLowerCase() === SERVICE && item.characteristic.toLowerCase() === SAMPLE);
      if (!sample?.properties?.Read || !sample.properties.Write) {
        throw new Error('教学特征需要同时支持 Read 和 Write');
      }
      setReady(true);
      setMessage('可以请求读数。');
    } catch (error) {
      if (attempt === session.current) await disconnect('连接或服务发现失败：' + String(error));
    } finally {
      if (attempt === session.current) {
        locked.current = false;
        if (active.current) setBusy(false);
      }
    }
  }

  async function measure() {
    const id = current.current;
    if (!id || !ready || locked.current) return;
    const attempt = session.current;
    locked.current = true;
    setBusy(true);
    setMessage('正在请求新读数…');
    setReading('等待测量');
    setHex('');
    try {
      await withTimeout(BleManager.write(id, SERVICE, SAMPLE, MEASURE), 6000);
      if (attempt !== session.current) return;
      const data = await withTimeout(BleManager.read(id, SERVICE, SAMPLE), 6000);
      if (attempt !== session.current) return;
      setHex(hexFrame(data));
      setReading(decodeFrame(data));
      setMessage('读数已更新。');
    } catch (error) {
      if (attempt !== session.current) return;
      if (error instanceof OperationTimeout) {
        await disconnect('读写超时，请重新连接。');
      } else {
        setMessage('读写失败：' + String(error));
      }
    } finally {
      if (attempt === session.current) {
        locked.current = false;
        if (active.current) setBusy(false);
      }
    }
  }

  async function disconnect(reason: string) {
    const attempt = ++session.current;
    const id = current.current;
    current.current = null;
    locked.current = true;
    setBusy(true);
    setReady(false);
    setMessage(reason);
    try {
      if (id) await withTimeout(BleManager.disconnect(id), 6000);
    } catch (error) {
      if (active.current && attempt === session.current) {
        setMessage('结束连接失败：' + String(error));
      }
    } finally {
      if (attempt === session.current) {
        locked.current = false;
        if (active.current) setBusy(false);
      }
    }
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.page}>
      <Text style={styles.title}>蓝牙温湿度计</Text>
      <Text>{message}</Text>
      <Button title="开始扫描" disabled={busy || scanning || ready} onPress={startScan} />
      {devices.map(device => (
        <View key={device.id}>
          <Button title={(device.name || '教学温湿度计') + ' · ' + device.rssi + ' dBm'}
            disabled={busy || ready} onPress={() => connect(device)} />
        </View>
      ))}
      <Button title="请求新读数" disabled={!ready || busy} onPress={measure} />
      <Button title="断开连接" disabled={!ready || busy} onPress={() => disconnect('已断开。')} />
      <Text style={styles.title}>{reading}</Text>
      <Text selectable>{hex}</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  page: { padding: 24, paddingTop: 56, gap: 14 },
  title: { fontSize: 24, fontWeight: '600' },
});
```

</details>

<details>
<summary>permissions.ts</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/react-native/thermometer-mvp/permissions.ts)

```typescript
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
```

</details>

<details>
<summary>frame.ts</summary>

[打开工程源码](https://github.com/qingzhu-ai-public/qingzhu-blue/blob/main/examples/react-native/thermometer-mvp/frame.ts)

```typescript
export const SERVICE = '476cdf45-6063-43a1-b8e2-8c1fbed00601';
export const SAMPLE = '476cdf45-6063-43a1-b8e2-8c1fbed00602';
export const MEASURE = [0x01];

export function decodeFrame(data: number[]): string {
  if (data.length !== 7 || data.some(byte => !Number.isInteger(byte) || byte < 0 || byte > 255) ||
      data[0] !== 0x40 || data[1] !== 0x02 || data[4] !== 0x03) {
    throw new Error('回包格式不符');
  }
  const view = new DataView(Uint8Array.from(data).buffer);
  const temperature = view.getInt16(2, true) / 100;
  const humidity = view.getUint16(5, true) / 100;
  return temperature.toFixed(2) + ' °C · ' + humidity.toFixed(2) + '% RH';
}

export function hexFrame(data: number[]): string {
  return data.map(byte => byte.toString(16).padStart(2, '0').toUpperCase()).join(' ');
}
```

</details>

<a id="walkthrough"></a>

## 跟着操作看代码

### 1. 系统清单声明用途，运行时才找用户授权

入口篇里的 Expo 插件处理清单。点按钮后，`requestAndroidBlePermissions()` 会按 `Platform.Version` 选择系统权限，再逐项检查 `requestMultiple` 的结果。拒绝时直接返回。iOS 由原生模块初始化触发系统流程。

### 2. 先等模块初始化，再扫服务 UUID

`BleManager.start()` 是初始化。这个 Promise 缓存下来，避免每次点击重复初始化。接着 `checkState()` 检查系统状态。状态是 `BleState.On` 才调用 `scan({ serviceUUIDs: [SERVICE], seconds: 8 })`。

### 3. 设备由事件送来

`useEffect` 里先注册 `onDiscoverPeripheral`。回调拿到设备时先查扫描标记，再按 `device.id` 替换列表条目。系统发出 `onStopScan` 后撤掉扫描标记并恢复界面。离开页面时用 `remove()` 撤掉监听。

**动手试试**　先拒绝授权并观察提示。恢复权限后扫描两轮，看同一设备是否始终只有一行。

**一句话**　扫到的设备是一条条送来的，把每台设备的最新结果放回同一行。

**面试题**　那个扫描调用的返回值是不是设备列表？

返回的是启动操作的 Promise。设备列表由发现事件一条条组成。

[连接](#react-native/thermometer-mvp/connection) · [插件 API](https://innoveit.github.io/react-native-ble-manager/methods/)
