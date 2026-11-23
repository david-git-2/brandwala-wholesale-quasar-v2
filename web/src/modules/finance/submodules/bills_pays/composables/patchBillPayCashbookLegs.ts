import type { BillPayCashbookLeg, BillPayCashbookLegs } from '../types/billPayCashbookLegs';
import type { ApplyDepositCacheInput } from '../types/applyDepositCacheInput';

function emptyLegForProfile(profileId: number, input: ApplyDepositCacheInput): BillPayCashbookLeg {
  const pointId = input.legLocationPointId;
  return {
    profile_id: profileId,
    cashbook_account_id: 0,
    default_pot_id: input.deposit.pot_id,
    points:
      pointId != null
        ? [
            {
              id: pointId,
              code: input.locationCode?.trim() || 'main',
              name: '',
              is_active: true,
            },
          ]
        : [],
    pots: [],
  };
}

export function patchLegPots(leg: BillPayCashbookLeg, input: ApplyDepositCacheInput): BillPayCashbookLeg {
  const potId = input.deposit.pot_id;
  const pointName =
    input.legLocationPointId != null
      ? leg.points.find((p) => p.id === input.legLocationPointId)?.name?.trim() || null
      : null;
  const idx = leg.pots.findIndex((p) => p.id === potId);
  if (idx >= 0) {
    const pots = [...leg.pots];
    const booksRate =
      input.legBooksRate != null && input.legBooksRate > 0
        ? input.legBooksRate
        : pots[idx].books_rate;
    pots[idx] = {
      ...pots[idx],
      amount: input.deposit.balance_after,
      books_rate: booksRate,
    };
    return { ...leg, pots };
  }
  const booksRate =
    input.legBooksRate != null && input.legBooksRate > 0 ? input.legBooksRate : null;
  return {
    ...leg,
    pots: [
      ...leg.pots,
      {
        id: potId,
        cashbook_point_id: input.legLocationPointId ?? 0,
        currency_code: input.deposit.currency_code,
        amount: input.deposit.balance_after,
        books_rate: booksRate,
        drawer_group: null,
        point_code: input.locationCode?.trim() || null,
        point_name: pointName,
      },
    ],
  };
}

function patchLegForProfile(
  leg: BillPayCashbookLeg | null,
  profileId: number,
  input: ApplyDepositCacheInput,
): BillPayCashbookLeg | null {
  if (!leg || leg.profile_id !== profileId) return leg;
  return patchLegPots(leg, input);
}

/** Patch from/to legs after deposit; seeds a payer/receive leg when bundle data was empty. */
export function patchBillPayCashbookLegs(
  legs: BillPayCashbookLegs | null,
  input: ApplyDepositCacheInput,
): BillPayCashbookLegs {
  const currency_code =
    legs?.currency_code?.trim().toUpperCase()
    || input.deposit.currency_code.trim().toUpperCase()
    || 'BDT';

  const from = legs?.from_leg ?? null;
  const to = legs?.to_leg ?? null;
  const { profileId } = input;

  const createOnSide = (): BillPayCashbookLeg =>
    patchLegPots(emptyLegForProfile(profileId, input), input);

  let from_leg = from;
  let to_leg = to;

  if (from?.profile_id === profileId) {
    from_leg = patchLegPots(from, input);
  } else if (to?.profile_id === profileId) {
    to_leg = patchLegPots(to, input);
  } else if (from == null && to == null) {
    from_leg = createOnSide();
  } else if (from == null && (to == null || to.profile_id !== profileId)) {
    from_leg = createOnSide();
  } else if (to == null && from != null && from.profile_id !== profileId) {
    to_leg = createOnSide();
  } else {
    from_leg = patchLegForProfile(from, profileId, input);
    to_leg = patchLegForProfile(to, profileId, input);
  }

  return { currency_code, from_leg, to_leg };
}