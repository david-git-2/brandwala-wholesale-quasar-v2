export const globalReferenceQueryKeys = {
  markets: () => ['globalReference', 'markets'] as const,
  marketDetail: (id: number) => ['globalReference', 'market', { id }] as const,
  marketByCode: (code: string) => ['globalReference', 'marketByCode', { code }] as const,

  currencies: () => ['globalReference', 'currencies'] as const,
  currencyDetail: (id: number) => ['globalReference', 'currency', { id }] as const,
  currencyByCode: (code: string) => ['globalReference', 'currencyByCode', { code }] as const,

  paymentMethods: () => ['globalReference', 'paymentMethods'] as const,
  paymentMethodDetail: (id: number) => ['globalReference', 'paymentMethod', { id }] as const,

  unitsOfMeasure: () => ['globalReference', 'unitsOfMeasure'] as const,
  unitOfMeasureDetail: (id: number) => ['globalReference', 'unitOfMeasure', { id }] as const,
};
