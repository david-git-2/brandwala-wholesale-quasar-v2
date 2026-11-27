export type BillPayCashbookPointRow = {
  id: number;
  code: string;
  name: string;
  is_active: boolean;
};

export type BillPayCashbookPotRow = {
  id: number;
  cashbook_point_id: number;
  currency_code: string;
  amount: number;
  books_rate: number | null;
  drawer_group: string | null;
  point_code: string | null;
  point_name: string | null;
};

export type BillPayCashbookLeg = {
  profile_id: number;
  cashbook_account_id: number;
  default_pot_id: number | null;
  points: BillPayCashbookPointRow[];
  pots: BillPayCashbookPotRow[];
};

export type BillPayCashbookLegs = {
  currency_code: string;
  from_leg: BillPayCashbookLeg | null;
  to_leg: BillPayCashbookLeg | null;
};

function parseLeg(raw: unknown): BillPayCashbookLeg | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, unknown>;
  const profileId = Number(r.profile_id);
  const accountId = Number(r.cashbook_account_id ?? r.cashbook_id);
  if (!Number.isFinite(profileId) || !Number.isFinite(accountId)) return null;

  const pointsRaw = r.points;
  const points = Array.isArray(pointsRaw)
    ? pointsRaw.map((row) => {
        const p = row as Record<string, unknown>;
        return {
          id: Number(p.id),
          code: String(p.code ?? ''),
          name: String(p.name ?? ''),
          is_active: p.is_active !== false,
        };
      })
    : [];

  const potsRaw = r.pots;
  const pots = Array.isArray(potsRaw)
    ? potsRaw.map((row) => {
        const p = row as Record<string, unknown>;
        return {
          id: Number(p.id),
          cashbook_point_id: Number(p.cashbook_point_id ?? p.cash_location_id),
          currency_code: String(p.currency_code ?? 'BDT').trim().toUpperCase(),
          amount: Number(p.amount ?? 0),
          books_rate:
            p.books_rate != null && Number.isFinite(Number(p.books_rate))
              ? Number(p.books_rate)
              : null,
          drawer_group: p.drawer_group != null ? String(p.drawer_group).trim() || null : null,
          point_code: p.point_code != null ? String(p.point_code) : null,
          point_name: p.point_name != null ? String(p.point_name) : null,
        };
      })
    : [];

  return {
    profile_id: profileId,
    cashbook_account_id: accountId,
    default_pot_id:
      r.default_pot_id != null && Number.isFinite(Number(r.default_pot_id))
        ? Number(r.default_pot_id)
        : null,
    points,
    pots,
  };
}

export function parseBillPayCashbookLegsFromRpc(raw: unknown): BillPayCashbookLegs | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, unknown>;
  const currency = String(r.currency_code ?? 'BDT').trim().toUpperCase() || 'BDT';
  return {
    currency_code: currency,
    from_leg: parseLeg(r.from_leg),
    to_leg: parseLeg(r.to_leg),
  };
}
