export type ApBillPaperLocalLine = {
  description: string;
  amount: number;
};

export type ApBillPaperVendor = {
  paper: 'vendor';
  foreign_amount: number;
  conversion_rate: number;
  bdt_amount: number;
};

export type ApBillPaperCargo = {
  paper: 'cargo';
  weight_kg: number;
  price: number;
  conversion_rate: number;
  bdt_amount: number;
};

export type ApBillPaperLocal = {
  paper: 'local';
  lines: ApBillPaperLocalLine[];
  bdt_amount: number;
};

export type ApBillPaperSnapshot = ApBillPaperVendor | ApBillPaperCargo | ApBillPaperLocal;
