import type { ApBillPaperSnapshot } from '../types/apBillPaper';

export function parseApBillPaper(
  channelMeta: Record<string, unknown> | null | undefined,
  apKind: string | null | undefined,
): ApBillPaperSnapshot | null {
  const raw = channelMeta?.ap_paper;
  if (raw && typeof raw === 'object' && raw !== null && 'paper' in raw) {
    return raw as ApBillPaperSnapshot;
  }
  return null;
}

export function apKindTitle(apKind: string | null | undefined): string {
  if (apKind === 'vendor') return 'Vendor AP';
  if (apKind === 'cargo') return 'Cargo AP';
  if (apKind === 'local') return 'Local AP';
  return 'AP bill';
}
