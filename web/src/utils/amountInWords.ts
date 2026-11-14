const ONES = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
] as const;

const TENS = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'] as const;

const capitalize = (phrase: string): string =>
  phrase
    .split(/(\s+|-)/)
    .map((part) => {
      if (!part || part === ' ' || part === '-') return part;
      return part.charAt(0).toUpperCase() + part.slice(1);
    })
    .join('');

function twoDigits(n: number): string {
  if (n < 20) return ONES[n] ?? '';
  const t = Math.floor(n / 10);
  const o = n % 10;
  return o ? `${TENS[t]}-${ONES[o]}` : TENS[t] ?? '';
}

function upTo999(n: number): string {
  if (n === 0) return '';
  if (n < 100) return twoDigits(n);
  const h = Math.floor(n / 100);
  const r = n % 100;
  const head = `${ONES[h]} hundred`;
  if (!r) return head;
  return `${head} ${twoDigits(r)}`;
}

function indianIntegerWords(n: number): string {
  if (n === 0) return 'zero';
  const parts: string[] = [];
  let rest = n;

  const crore = Math.floor(rest / 10_000_000);
  rest %= 10_000_000;
  if (crore) parts.push(`${upTo999(crore)} crore`);

  const lakh = Math.floor(rest / 100_000);
  rest %= 100_000;
  if (lakh) parts.push(`${upTo999(lakh)} lakh`);

  const thousand = Math.floor(rest / 1000);
  rest %= 1000;
  if (thousand) parts.push(`${upTo999(thousand)} thousand`);

  if (rest) parts.push(upTo999(rest));

  return parts.join(' ');
}

function westernIntegerWords(n: number): string {
  if (n === 0) return 'zero';
  const parts: string[] = [];
  let rest = n;

  const billion = Math.floor(rest / 1_000_000_000);
  rest %= 1_000_000_000;
  if (billion) parts.push(`${upTo999(billion)} billion`);

  const million = Math.floor(rest / 1_000_000);
  rest %= 1_000_000;
  if (million) parts.push(`${upTo999(million)} million`);

  const thousand = Math.floor(rest / 1000);
  rest %= 1000;
  if (thousand) parts.push(`${upTo999(thousand)} thousand`);

  if (rest) parts.push(upTo999(rest));

  return parts.join(' ');
}

/**
 * Amount in words for payment forms (Indian numbering for BDT).
 */
export function formatAmountInWords(
  amount: number | null | undefined,
  currencyCode = 'BDT',
): string | null {
  if (amount == null || !Number.isFinite(amount) || amount < 0) return null;

  const code = currencyCode.trim().toUpperCase() || 'BDT';
  const rounded = Math.round(amount * 100) / 100;
  const intPart = Math.floor(rounded);
  const frac = Math.round((rounded - intPart) * 100);

  if (intPart === 0 && frac === 0) return null;

  const useIndian = code === 'BDT';
  const core =
    intPart === 0
      ? ''
      : capitalize(useIndian ? indianIntegerWords(intPart) : westernIntegerWords(intPart));

  const fracWords = frac > 0 ? capitalize(useIndian ? indianIntegerWords(frac) : westernIntegerWords(frac)) : '';

  if (code === 'BDT') {
    if (!core && fracWords) return `${fracWords} Paisa only`;
    if (core && fracWords) return `${core} Taka and ${fracWords} Paisa only`;
    return `${core} Taka only`;
  }

  if (!core && fracWords) return `${fracWords} cents`;
  if (core && fracWords) return `${core} and ${fracWords} cents`;
  return core || null;
}