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
