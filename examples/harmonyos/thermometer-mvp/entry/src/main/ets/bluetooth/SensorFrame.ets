export const SERVICE: string = '476cdf45-6063-43a1-b8e2-8c1fbed00601';
export const SAMPLE: string = '476cdf45-6063-43a1-b8e2-8c1fbed00602';

export function measureCommand(): ArrayBuffer {
  return new Uint8Array([0x01]).buffer;
}

export function sampleFrame(temperature: number): ArrayBuffer {
  return new Uint8Array([0x40, 0x02, temperature & 0xff, (temperature >> 8) & 0xff,
    0x03, 0xbf, 0x13]).buffer;
}

export function decodeFrame(value: ArrayBuffer): string {
  const data = new Uint8Array(value);
  if (data.length !== 7 || data[0] !== 0x40 || data[1] !== 0x02 || data[4] !== 0x03) {
    throw new Error('回包格式不符');
  }
  const view = new DataView(value);
  const temperature = view.getInt16(2, true) / 100;
  const humidity = view.getUint16(5, true) / 100;
  return temperature.toFixed(2) + ' °C · ' + humidity.toFixed(2) + '% RH';
}

export function hexFrame(value: ArrayBuffer): string {
  return Array.from(new Uint8Array(value)).map((b: number) =>
    b.toString(16).padStart(2, '0').toUpperCase()).join(' ');
}
