import type { ThriftStock } from '../../stock/types';

export function formatCoreSizes(stock: ThriftStock): string | null {
  const m = stock.measurements;
  if (!m) return null;
  const parts: string[] = [];
  const list = [
    { label: 'B', val: m.bust_in },
    { label: 'W', val: m.waist_in },
    { label: 'H', val: m.hips_in },
    { label: 'L', val: m.length_in },
  ];
  for (const item of list) {
    if (item.val !== null && item.val !== undefined && Number(item.val) > 0) {
      parts.push(`${item.label}${item.val}`);
    }
  }
  return parts.length > 0 ? parts.join(' · ') : null;
}

export function formatAdditionalSizes(stock: ThriftStock): string | null {
  const m = stock.measurements;
  if (!m) return null;
  const parts: string[] = [];
  const list = [
    { label: 'Sh', val: m.shoulder_width_in },
    { label: 'Sl', val: m.sleeve_length_in },
    { label: 'Arm', val: m.arm_circumference_in },
    { label: 'Hem', val: m.hem_width_in },
    { label: 'Neck', val: m.neck_opening_in },
  ];
  for (const item of list) {
    if (item.val !== null && item.val !== undefined && Number(item.val) > 0) {
      parts.push(`${item.label}${item.val}`);
    }
  }
  if (m.fabric_stretch && m.fabric_stretch !== 'none') {
    parts.push(`Str:${m.fabric_stretch}`);
  }
  return parts.length > 0 ? parts.join(' · ') : null;
}
