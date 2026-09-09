import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';

export function filterShipmentItemsBySheet(
  items: GlobalShipmentItem[],
  sheetId: string,
  sections: Array<{ id: number }>,
): GlobalShipmentItem[] {
  if (sheetId === 'sheet_all') {
    return items;
  }

  const match = sheetId.match(/^section_(\d+)$/);
  if (!match) {
    return items;
  }

  const sectionDbId = Number(match[1]);
  const firstSectionDbId = sections[0]?.id ?? null;

  return items.filter(
    (item) =>
      item.section_id === sectionDbId ||
      (item.section_id == null && sectionDbId === firstSectionDbId),
  );
}
