import type { ProductBasedCostingFileListInput } from '../../types';

export const productBasedCostingQueryKeys = {
  all: ['productBasedCosting'] as const,
  filesList: (params: ProductBasedCostingFileListInput) =>
    ['productBasedCosting', 'files', 'list', params] as const,
  fileDetail: (id: number) => ['productBasedCosting', 'files', 'detail', id] as const,
  itemsList: (fileId: number) => ['productBasedCosting', 'items', 'list', fileId] as const,
};
