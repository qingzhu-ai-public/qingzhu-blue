// BTHome v2 协议层：纯 ArkTS，只碰 Uint8Array/DataView，不碰蓝牙 API。
// 可以离线跑 selfTest()（13 项），再上真机。规范：https://bthome.io/format/
// 教学 GATT 协议（DEMO_SERVICE/DEMO_CHAR）与 Android/iOS bthome-mvp 完全一致，可跨平台互连。

export const BTHOME_UUID: string = '0000fcd2-0000-1000-8000-00805f9b34fb';
export const BTHOME_UUID16: number = 0xFCD2;

export interface ObjSpec {
  id: number;
  label: string;
  len: number;
  signed: boolean;
  factor: number;
  unit: string;
  min: number;
  max: number;
}

// 对象 ID 表：解析器需要的全部信息。未登记的 ID 一律停止解析（规范强制）。
// 完整表见 bthome.io；本课实现常用 5 种，扩展只加表项。
export const OBJECTS: ObjSpec[] = [
  { id: 0x00, label: '序号', len: 1, signed: false, factor: 1, unit: '', min: 0, max: 255 },
  { id: 0x01, label: '电量', len: 1, signed: false, factor: 1, unit: '%', min: 0, max: 100 },
  { id: 0x02, label: '温度', len: 2, signed: true, factor: 0.01, unit: '°C', min: -40, max: 85 },
  { id: 0x03, label: '湿度', len: 2, signed: false, factor: 0.01, unit: '%', min: 0, max: 100 },
  { id: 0x0C, label: '电压', len: 2, signed: false, factor: 0.001, unit: 'V', min: 0, max: 65.535 }
];

export function findSpec(id: number): ObjSpec | undefined {
  return OBJECTS.find((item: ObjSpec) => item.id === id);
}

export interface Measurement {
  id: number;
  label: string;
  value: number;
  unit: string;
  inRange: boolean;
}

export interface BthomeReading {
  version: number;
  trigger: boolean;
  objects: Measurement[];
}

// 输入是服务数据里 UUID 之后的字节。坏帧抛带原因的错误，UI 显示故障而不是硬显示数字。
export function parseBthome(payload: Uint8Array): BthomeReading {
  if (payload.length < 2) { throw new Error('没有测量对象'); }
  const info = payload[0];
  const version = (info >> 5) & 7;
  if (version !== 2) { throw new Error('需要 BTHome v2'); }
  if ((info & 0x01) !== 0) { throw new Error('加密帧需要密钥，本示例只解析明文'); }
  const reading: BthomeReading = { version: version, trigger: (info & 0x04) !== 0, objects: [] };
  let i = 1;
  let last = -1;
  while (i < payload.length) {
    const id = payload[i];
    if (id < last) { throw new Error('对象 ID 未升序'); }
    const spec = findSpec(id);
    if (!spec) { throw new Error('未知对象 ID 0x' + id.toString(16).toUpperCase()); }
    if (i + 1 + spec.len > payload.length) {
      throw new Error('对象 0x' + id.toString(16).toUpperCase() + ' 数据不完整');
    }
    let raw = 0;
    for (let k = 0; k < spec.len; k++) { raw |= payload[i + 1 + k] << (8 * k); }
    if (spec.signed && spec.len === 2 && raw >= 0x8000) { raw -= 0x10000; }
    const value = raw * spec.factor;
    if (id === 0x03 && (value < 0 || value > 100)) {
      throw new Error('湿度 ' + value.toFixed(2) + '% 越界（0–100），帧可疑');
    }
    const m: Measurement = { id: id, label: spec.label, value: value, unit: spec.unit,
      inRange: value >= spec.min && value <= spec.max };
    reading.objects.push(m);
    last = id;
    i += 1 + spec.len;
  }
  if (reading.objects.length === 0) { throw new Error('没有测量对象'); }
  return reading;
}

export function displayReading(reading: BthomeReading): string {
  const parts: string[] = [];
  reading.objects.forEach((m: Measurement) => {
    if (m.id === 0x00) { return; } // 序号不是读数
    const spec = findSpec(m.id);
    const digits = spec && spec.factor === 1 ? 0 : (spec && spec.factor === 0.001 ? 3 : 2);
    parts.push(m.label + ' ' + m.value.toFixed(digits) + (m.unit ? ' ' + m.unit : '') +
      (m.inRange ? '' : '（越界）'));
  });
  return parts.length > 0 ? parts.join(' · ') : '无可显示的读数';
}

// 编码：v2 不加密定时（0x40）+ 对象 ID 升序 + 小端。packetId >= 0 时加序号对象 0x00。
export function encodeBthome(temperature: number, humidity: number, packetId: number = -1): Uint8Array {
  const out: number[] = [0x40];
  if (packetId >= 0) { out.push(0x00, packetId & 0xff); }
  const t = Math.round(temperature * 100);
  const tu = t < 0 ? t + 0x10000 : t;
  out.push(0x02, tu & 0xff, (tu >> 8) & 0xff);
  const h = Math.round(humidity * 100);
  out.push(0x03, h & 0xff, (h >> 8) & 0xff);
  return new Uint8Array(out);
}

// 版本兜底：API 10–21 没有 ScanResult.serviceDataMap（API 22 才有），手解原始 AD。
// AD 段循环：[len][type][value...]；type=0x16 且 UUID 小端匹配即命中。
export function extractServiceData(raw: ArrayBuffer, uuid16: number): Uint8Array | null {
  const bytes = new Uint8Array(raw);
  let i = 0;
  while (i < bytes.length) {
    const len = bytes[i];
    if (len === 0) { break; }
    if (i + len >= bytes.length) { break; } //  malformed：长度越界即停
    if (bytes[i + 1] === 0x16 && len >= 3 &&
      (bytes[i + 2] | (bytes[i + 3] << 8)) === uuid16) {
      return bytes.slice(i + 4, i + 1 + len);
    }
    i += len + 1;
  }
  return null;
}

export function hexBytes(bytes: Uint8Array): string {
  return Array.from(bytes).map((b: number) => b.toString(16).padStart(2, '0').toUpperCase()).join(' ');
}

export function bytesFromHex(hex: string): Uint8Array {
  const clean = hex.replace(/[^0-9a-fA-F]/g, '');
  const out: number[] = [];
  for (let i = 0; i + 1 < clean.length; i += 2) { out.push(parseInt(clean.substring(i, i + 2), 16)); }
  return new Uint8Array(out);
}

// ---- 教学 GATT 协议（非 BTHome 标准，只为练习连接/读写路线；三端一致） ----

export const DEMO_SERVICE: string = '476cdf45-6063-43a1-b8e2-8c1fbed00601';
export const DEMO_CHAR: string = '476cdf45-6063-43a1-b8e2-8c1fbed00602';

export function measureCommand(): ArrayBuffer {
  return new Uint8Array([0x01]).buffer;
}

// 与 Android DemoProtocol.sample / iOS DemoProtocol.sampleBytes 相同的帧：
// 温度 sint16 小端（单位 0.01°C）+ 固定湿度 50.55%。
export function demoFrame(temperature: number): ArrayBuffer {
  const tu = temperature < 0 ? temperature + 0x10000 : temperature;
  return new Uint8Array([0x40, 0x02, tu & 0xff, (tu >> 8) & 0xff, 0x03, 0xbf, 0x13]).buffer;
}

// ---- 13 项自检：不连真机也能验证协议层。App 自检面板一键跑。 ----

function throws(action: () => void): boolean {
  try { action(); return false; } catch (error) { return true; }
}

export function selfTest(): string[] {
  const report: string[] = [];
  const check = (name: string, ok: boolean): void => {
    report.push((ok ? 'PASS ' : 'FAIL ') + name);
  };
  const official = parseBthome(bytesFromHex('40 02 C4 09 03 BF 13'));
  check('官方样例 v2 明文', official.version === 2 && !official.trigger);
  check('温度 25.00', Math.abs(official.objects[0].value - 25.0) < 0.001);
  check('湿度 50.55', Math.abs(official.objects[1].value - 50.55) < 0.001);
  const negative = parseBthome(bytesFromHex('40 02 DA FD'));
  check('零下 −5.50', Math.abs(negative.objects[0].value + 5.5) < 0.001);
  const extras = parseBthome(bytesFromHex('40 00 05 01 64 0C EA 0B'));
  check('序号/电量/电压', extras.objects.length === 3 && extras.objects[0].value === 5 &&
    extras.objects[1].value === 100 && Math.abs(extras.objects[2].value - 3.05) < 0.0001);
  check('升序违规报错', throws(() => { parseBthome(bytesFromHex('40 03 BF 13 02 C4 09')); }));
  check('未知 ID 即停', throws(() => { parseBthome(bytesFromHex('40 02 C4 09 FF 01')); }));
  check('截断帧报错', throws(() => { parseBthome(bytesFromHex('40 02 C4')); }));
  check('加密帧拒绝', throws(() => { parseBthome(bytesFromHex('41 02 C4 09')); }));
  check('湿度越界报错', throws(() => { parseBthome(bytesFromHex('40 03 A2 28')); }));
  const encoded = encodeBthome(25.0, 50.55);
  const roundTrip = parseBthome(encodeBthome(-5.5, 50.55));
  check('编码→解码闭环', hexBytes(encoded) === '40 02 C4 09 03 BF 13' &&
    Math.abs(roundTrip.objects[0].value + 5.5) < 0.001);
  const adv = bytesFromHex('02 01 06 03 03 D2 FC 0A 16 D2 FC 40 02 C4 09 03 BF 13');
  const advBuf = adv.buffer as ArrayBuffer;
  const hit = extractServiceData(advBuf, BTHOME_UUID16);
  check('AD 提取命中', hit !== null ? hexBytes(hit) === '40 02 C4 09 03 BF 13' : false);
  check('AD 提取未命中', extractServiceData(advBuf, 0x180F) === null);
  return report;
}