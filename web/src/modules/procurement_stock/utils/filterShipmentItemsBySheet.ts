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

/** Same line list on every sheet; only rows in `sheetId` keep their quantities. */
export function mapShipmentItemsQuantitiesBySheet(
  items: GlobalShipmentItem[],
  sheetId: string,
  sections: Array<{ id: number }>,
): GlobalShipmentItem[] {
  if (sheetId === 'sheet_all') {
    return items;
  }

  const inSectionIds = new Set(
    filterShipmentItemsBySheet(items, sheetId, sections).map((item) => item.id),
  );

  return items.map((item) => {
    if (inSectionIds.has(item.id)) {
      return item;
    }
    return {
      ...item,
      ordered_quantity: 0,
      received_quantity: 0,
    };
  });
}
