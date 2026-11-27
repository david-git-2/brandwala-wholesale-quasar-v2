export type PayTransferEntityType = 'tenant' | 'customer' | 'courier' | 'vendor' | 'cargo_company';

export type PayTransferParty = {
  key: string;
  entityType: PayTransferEntityType;
  entityId: number;
  name: string;
  availableBalance: number;
  dueTotal: number;
};

export const payTransferPartyKey = (entityType: string, entityId: number) =>
  `${entityType}:${entityId}`;
