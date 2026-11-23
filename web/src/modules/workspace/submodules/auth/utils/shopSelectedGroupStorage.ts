const STORAGE_KEY = 'brandwala.shop.selected-group.v1';

type SelectedGroupMap = Record<string, number>;

const storageKey = (email: string, tenantId: number) =>
  `${email.trim().toLowerCase()}:${tenantId}`;

const readMap = (): SelectedGroupMap => {
  if (typeof window === 'undefined') {
    return {};
  }

  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return {};
    }
    const parsed = JSON.parse(raw) as SelectedGroupMap;
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
};

export const readLastShopCustomerGroupId = (email: string, tenantId: number): number | null => {
  const value = readMap()[storageKey(email, tenantId)];
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
};

export const writeLastShopCustomerGroupId = (
  email: string,
  tenantId: number,
  groupId: number,
): void => {
  if (typeof window === 'undefined') {
    return;
  }

  const next = readMap();
  next[storageKey(email, tenantId)] = groupId;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
};
