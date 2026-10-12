export type ApBillPaperLine = {
  description: string;
  amount: number;
  currency_code?: string;
  currency_symbol?: string;
};

export type ApBillPaperCurrencyGroup = {
  currency_code: string;
  currency_symbol?: string;
  foreign_total: number;
  lines: ApBillPaperLine[];
};

/** @deprecated Legacy snapshot — summed foreign total with FX on paper */
export type ApBillPaperForeignTotal = {
  paper: 'vendor' | 'material';
  foreign_amount: number;
  conversion_rate: number;
  bdt_amount: number;
};

/** @deprecated Legacy snapshot — freight total with FX on paper */
export type ApBillPaperFreight = {
  paper: 'cargo' | 'freight';
  weight_kg: number;
  price: number;
  conversion_rate: number;
  bdt_amount: number;
};

export type ApBillPaperBucketLines = {
  paper: string;
  lines: ApBillPaperLine[];
  currency_groups?: ApBillPaperCurrencyGroup[];
  mixed_currencies?: boolean;
  foreign_total?: number | null;
  currency_code?: string;
  currency_symbol?: string;
  bdt_amount: number;
  conversion_rate?: number | null;
  weight_kg?: number;
};

export type ApBillPaperLines = {
  paper: 'local' | 'customs' | 'handling' | 'finance' | 'other';
  lines: ApBillPaperLine[];
  bdt_amount: number;
};

export type ApBillPaperSnapshot =
  | ApBillPaperForeignTotal
  | ApBillPaperFreight
  | ApBillPaperLines
  | ApBillPaperBucketLines;
