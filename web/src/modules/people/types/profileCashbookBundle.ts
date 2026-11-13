export type ProfileCashbookBundleRow = {
  bundleId: number;
  cashLocationId: number;
  locationCode: string;
  locationName: string;
  deskPointId: number | null;
  currencyCode: string;
  amount: number;
  booksRate: number;
};
