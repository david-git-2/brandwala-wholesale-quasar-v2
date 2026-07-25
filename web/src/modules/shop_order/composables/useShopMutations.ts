import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import type { CreateShopPayload, UpdateShopPayload, Shop } from '../types';

export function useSaveShopMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: CreateShopPayload | UpdateShopPayload): Promise<Shop> => {
      const isEdit = 'id' in payload && typeof payload.id === 'number';
      const savedShop = await shopOrderRepository.upsertShop(payload);

      if (savedShop && savedShop.id) {
        await shopOrderRepository.updateShopExtraAttributes(
          savedShop.id,
          payload.tenant_id,
          payload.description || null,
          payload.category_ids || [],
        );
      }
      return savedShop;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['shopOrder', 'shops'] });
    },
  });
}
