export type DropshipManagementOrderStatus = 'pending' | 'processing' | 'shipped' | 'delivered';

export type DropshipManagementChargePayer = 'recipient' | 'merchant' | 'company';

export interface DropshipManagementChargeLine {
  amount: number;
  payer: DropshipManagementChargePayer;
}

export interface DropshipManagementSettlementForm {
  totalCollectedCod: number;
  delivery: DropshipManagementChargeLine;
  print: DropshipManagementChargeLine;
  packing: DropshipManagementChargeLine;
  returnCost: DropshipManagementChargeLine;
  returnReasonNote: string;
  discountCompanyPay: number;
  resellerPurchaseCost: number;
}

export interface DropshipManagementDummyOrder {
  id: string;
  name: string;
  merchant: string;
  recipient: string;
  recipientPhone: string;
  courierName: string;
  awb: string;
  orderDate: string;
  status: DropshipManagementOrderStatus;
  calculatedCod: number;
  settlement: DropshipManagementSettlementForm;
}

export const dropshipManagementChargePayerOptions: Array<{
  label: string;
  value: DropshipManagementChargePayer;
}> = [
  { label: 'Recipient pays', value: 'recipient' },
  { label: 'Merchant pays', value: 'merchant' },
  { label: 'Company pays', value: 'company' },
];

function settlement(
  partial: Partial<DropshipManagementSettlementForm> & Pick<DropshipManagementSettlementForm, 'totalCollectedCod' | 'resellerPurchaseCost'>,
): DropshipManagementSettlementForm {
  return {
    totalCollectedCod: partial.totalCollectedCod,
    resellerPurchaseCost: partial.resellerPurchaseCost,
    delivery: partial.delivery ?? { amount: 120, payer: 'recipient' },
    print: partial.print ?? { amount: 15, payer: 'merchant' },
    packing: partial.packing ?? { amount: 20, payer: 'merchant' },
    returnCost: partial.returnCost ?? { amount: 0, payer: 'company' },
    returnReasonNote: partial.returnReasonNote ?? '',
    discountCompanyPay: partial.discountCompanyPay ?? 0,
  };
}

export const dropshipManagementDummyOrders: DropshipManagementDummyOrder[] = [
  {
    id: '1',
    name: 'DS-1042',
    merchant: 'Fashion Hub BD',
    recipient: 'Rahim Uddin',
    recipientPhone: '01711-000042',
    courierName: 'Pathao Courier',
    awb: 'PAW-8821042',
    orderDate: '20 Aug 2026',
    status: 'delivered',
    calculatedCod: 2500,
    settlement: settlement({ totalCollectedCod: 2480, resellerPurchaseCost: 1800, discountCompanyPay: 50 }),
  },
  {
    id: '2',
    name: 'DS-1041',
    merchant: 'Style Mart',
    recipient: 'Fatima Begum',
    recipientPhone: '01822-000041',
    courierName: 'RedX',
    awb: 'RDX-4419021',
    orderDate: '19 Aug 2026',
    status: 'shipped',
    calculatedCod: 3200,
    settlement: settlement({
      totalCollectedCod: 3200,
      resellerPurchaseCost: 2400,
      delivery: { amount: 150, payer: 'recipient' },
    }),
  },
  {
    id: '3',
    name: 'DS-1039',
    merchant: 'Urban Closet',
    recipient: 'Karim Hassan',
    recipientPhone: '01933-000039',
    courierName: 'Steadfast',
    awb: 'SF-9931844',
    orderDate: '18 Aug 2026',
    status: 'processing',
    calculatedCod: 1800,
    settlement: settlement({
      totalCollectedCod: 1800,
      resellerPurchaseCost: 1350,
      delivery: { amount: 100, payer: 'recipient' },
      print: { amount: 10, payer: 'company' },
    }),
  },
  {
    id: '4',
    name: 'DS-1035',
    merchant: 'Fashion Hub BD',
    recipient: 'Nusrat Jahan',
    recipientPhone: '01644-000035',
    courierName: 'Pathao Courier',
    awb: 'PAW-8821035',
    orderDate: '16 Aug 2026',
    status: 'delivered',
    calculatedCod: 4100,
    settlement: settlement({
      totalCollectedCod: 4100,
      resellerPurchaseCost: 3100,
      returnCost: { amount: 80, payer: 'company' },
      returnReasonNote: 'Partial return — one size exchanged at hub.',
    }),
  },
  {
    id: '5',
    name: 'DS-1032',
    merchant: 'Trendy Wear',
    recipient: 'Sakib Ahmed',
    recipientPhone: '01555-000032',
    courierName: 'RedX',
    awb: 'RDX-4418732',
    orderDate: '15 Aug 2026',
    status: 'pending',
    calculatedCod: 2200,
    settlement: settlement({ totalCollectedCod: 2200, resellerPurchaseCost: 1650 }),
  },
  {
    id: '6',
    name: 'DS-1028',
    merchant: 'Style Mart',
    recipient: 'Mina Roy',
    recipientPhone: '01306-000028',
    courierName: 'Steadfast',
    awb: 'SF-9931728',
    orderDate: '14 Aug 2026',
    status: 'processing',
    calculatedCod: 2900,
    settlement: settlement({
      totalCollectedCod: 2900,
      resellerPurchaseCost: 2150,
      packing: { amount: 25, payer: 'merchant' },
    }),
  },
];

export function findDropshipManagementDummyOrder(id: string): DropshipManagementDummyOrder | undefined {
  return dropshipManagementDummyOrders.find((order) => order.id === id);
}
