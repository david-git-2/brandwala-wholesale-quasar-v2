import type { WholesaleMethodOption } from 'src/modules/bills_pays/composables/useWholesalePaymentMethodMeta';

const PROFILE_METHOD_ORDER = [
  'cash',
  'bank',
  'bank_transfer',
  'cheque',
  'mobile_banking',
  'mfs',
] as const;

const PROFILE_METHOD_ALIASES = new Set<string>([
  ...PROFILE_METHOD_ORDER,
  'mobile banking',
  'bank transfer',
]);

export function isProfileCashMovementMethod(option: WholesaleMethodOption): boolean {
  const v = option.value.toLowerCase();
  const code = option.code.toLowerCase();
  if (PROFILE_METHOD_ALIASES.has(v) || PROFILE_METHOD_ALIASES.has(code)) return true;
  if (v.includes('mobile') || code.includes('mobile')) return true;
  if (v.includes('mfs') || code.includes('mfs')) return true;
  return false;
}

export function sortProfileCashMovementMethods(
  options: WholesaleMethodOption[],
): WholesaleMethodOption[] {
  const rank = (opt: WholesaleMethodOption) => {
    const v = opt.value.toLowerCase();
    const idx = PROFILE_METHOD_ORDER.findIndex((k) => v === k || opt.code.toLowerCase() === k);
    return idx >= 0 ? idx : 99;
  };
  return [...options].sort((a, b) => rank(a) - rank(b) || a.label.localeCompare(b.label));
}

export const PROFILE_CASH_DEFAULT_METHOD = 'cash';
