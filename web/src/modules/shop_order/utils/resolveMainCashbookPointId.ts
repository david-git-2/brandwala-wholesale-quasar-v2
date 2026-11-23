import { cashbookRepository } from 'src/modules/bills_pays/repositories/cashbookRepository';

/** Books-tenant **main** cash point for tenant treasury deposits. */
export async function resolveMainCashbookPointId(booksTenantId: number): Promise<number> {
  const accountId = await cashbookRepository.findCashbookAccountId({
    booksTenantId,
    entityType: 'tenant',
    entityId: booksTenantId,
  });
  if (!accountId) {
    throw new Error('Cashbook account not found for this tenant.');
  }
  const points = await cashbookRepository.listCashbookPoints(accountId);
  const main =
    points.find((p) => p.code?.trim().toLowerCase() === 'main' && p.is_active) ??
    points.find((p) => p.is_active);
  if (!main?.id) {
    throw new Error('No active cashbook location found (expected code main).');
  }
  return main.id;
}