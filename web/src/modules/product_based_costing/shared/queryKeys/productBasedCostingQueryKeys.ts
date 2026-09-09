import type { ProductBasedCostingFileListInput } from '../../types';

export const PBC_ITEMS_PAGE_SIZE = 25;

export const productBasedCostingQueryKeys = {
  all: ['productBasedCosting'] as const,
  filesList: (params: ProductBasedCostingFileListInput) =>
    ['productBasedCosting', 'files', 'list', params] as const,
  fileDetail: (id: number) => ['productBasedCosting', 'files', 'detail', id] as const,
  itemsRoot: (fileId: number) => ['productBasedCosting', 'items', fileId] as const,
  itemsList: (fileId: number) =>
    [...productBasedCostingQueryKeys.itemsRoot(fileId), 'list'] as const,
  itemsInfinite: (fileId: number, pageSize = PBC_ITEMS_PAGE_SIZE) =>
    [...productBasedCostingQueryKeys.itemsRoot(fileId), 'infinite', pageSize] as const,
};
