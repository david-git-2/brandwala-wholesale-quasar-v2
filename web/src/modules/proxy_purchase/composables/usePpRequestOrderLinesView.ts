import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { resolvePpRequestOrderLinesView } from '../utils/resolvePpRequestOrderLinesView';
import type { PpPurchaseRequestStatus } from '../types/ppPurchaseRequest';

export function usePpRequestOrderLinesView(
  requestStatus: Ref<PpPurchaseRequestStatus | null | undefined>,
) {
  const authStore = useAuthStore();

  const viewKey = computed(() =>
    resolvePpRequestOrderLinesView(authStore.matchedRole, requestStatus.value),
  );

  return { viewKey };
}