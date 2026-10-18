/** Shared Vue Query `staleTime` values. Pick by data type, do not invent new numbers per page. */
export const STALE_LIVE = 15_000; // orders, stock, demand that change during the day
export const STALE_STANDARD = 30_000; // default lists and details
export const STALE_MEDIUM = 2 * 60_000; // costing files, products
export const STALE_REFERENCE = 10 * 60_000; // tags, vendors, currencies, types, modules
