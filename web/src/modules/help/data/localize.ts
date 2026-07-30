import type { LocalizedText } from '../types';

export const isBnLocale = (locale: string): boolean =>
  locale === 'bn' || locale.startsWith('bn');

export const lt = (text: LocalizedText, locale: string): string =>
  isBnLocale(locale) ? text.bn : text.en;

/** Flatten both locales for search indexing. */
export const localizedSearchBlob = (text: LocalizedText): string =>
  `${text.en} ${text.bn}`;
