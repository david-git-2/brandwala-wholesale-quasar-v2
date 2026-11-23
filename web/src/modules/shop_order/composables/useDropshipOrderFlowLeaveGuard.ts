import { onBeforeUnmount, type ComputedRef, type Ref } from 'vue';
import { onBeforeRouteLeave } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { requestConfirmation } from 'src/utils/appFeedback';
import { isDropshipOrderFlowRoute } from '../utils/dropshipOrderFlow';

export type DropshipOrderFlowLeaveGuardOptions = {
  hasActiveOrder: Ref<boolean> | ComputedRef<boolean>;
  skip?: Ref<boolean> | ComputedRef<boolean>;
  title?: string;
  message?: string;
  beforeUnload?: boolean;
};

export function useDropshipOrderFlowLeaveGuard(
  options: DropshipOrderFlowLeaveGuardOptions,
) {
  const { t } = useI18n();

  const confirmLeaveFlow = async (): Promise<boolean> => {
    if (options.skip?.value || !options.hasActiveOrder.value) return true;

    return requestConfirmation(
      options.message ?? t('shop.dropship_leave_flow_message'),
      options.title ?? t('shop.dropship_leave_flow_title'),
      t('shop.dropship_leave_flow_confirm'),
    );
  };

  onBeforeRouteLeave(async (to) => {
    if (options.skip?.value || !options.hasActiveOrder.value) return true;
    if (isDropshipOrderFlowRoute(to)) return true;
    return confirmLeaveFlow();
  });

  if (options.beforeUnload !== false) {
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      if (options.skip?.value || !options.hasActiveOrder.value) return;
      event.preventDefault();
    };

    if (typeof window !== 'undefined') {
      window.addEventListener('beforeunload', onBeforeUnload);
      onBeforeUnmount(() => {
        window.removeEventListener('beforeunload', onBeforeUnload);
      });
    }
  }

  return { confirmLeaveFlow };
}