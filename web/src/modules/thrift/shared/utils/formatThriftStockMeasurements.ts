import type { ThriftStock } from '../../stock/types';

export function formatThriftStockMeasurements(stock: ThriftStock): string {
  const parts: string[] = [];

  if (stock.size) {
    parts.push(`Size: ${stock.size}`);
  }

  const m = stock.measurements;
  if (m) {
    const list = [
      { label: 'Bust', val: m.bust_in },
      { label: 'Waist', val: m.waist_in },
      { label: 'Hips', val: m.hips_in },
      { label: 'Length', val: m.length_in },
      { label: 'Shoulder', val: m.shoulder_width_in },
      { label: 'Sleeve', val: m.sleeve_length_in },
      { label: 'Arm', val: m.arm_circumference_in },
      { label: 'Hem', val: m.hem_width_in },
      { label: 'Neck', val: m.neck_opening_in },
    ];

    for (const item of list) {
      if (item.val !== null && item.val !== undefined && Number(item.val) > 0) {
        parts.push(`${item.label}: ${item.val}"`);
      }
    }
    
    if (m.fabric_stretch && m.fabric_stretch !== 'none') {
      parts.push(`Stretch: ${m.fabric_stretch}`);
    }
    if (m.lining !== null && m.lining !== undefined) {
      parts.push(m.lining ? 'Lined' : 'No lining');
    }
  }

  return parts.length > 0 ? parts.join(' · ') : '—';
}
