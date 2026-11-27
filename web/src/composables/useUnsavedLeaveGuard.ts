import { onBeforeUnmount, type ComputedRef, type Ref } from 'vue';
import { onBeforeRouteLeave } from 'vue-router';
import { requestUnsavedLeaveChoice, showErrorNotification } from 'src/utils/appFeedback';

export type UnsavedLeaveGuardOptions = {
  isDirty: Ref<boolean> | ComputedRef<boolean>;
  onSave: () => Promise<boolean>;
  onDiscard?: () => void;
  message?: string;
  title?: string;
  skip?: Ref<boolean>;
  beforeUnload?: boolean;
};

export function useUnsavedLeaveGuard(options: UnsavedLeaveGuardOptions) {
  const confirmLeave = async (): Promise<boolean> => {
    if (options.skip?.value || !options.isDirty.value) return true;

    const choice = await requestUnsavedLeaveChoice(options.message, options.title);
    if (choice === 'stay') return false;
    if (choice === 'discard') {
      options.onDiscard?.();
      return true;
    }

    try {
      const saved = await options.onSave();
      if (!saved) return false;
      return !options.isDirty.value;
    } catch (err) {
      showErrorNotification(
        err instanceof Error ? err.message : 'Failed to save changes',
      );
      return false;
    }
  };

  onBeforeRouteLeave(async () => confirmLeave());

  if (options.beforeUnload !== false) {
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      if (options.skip?.value || !options.isDirty.value) return;
      event.preventDefault();
    };

    if (typeof window !== 'undefined') {
      window.addEventListener('beforeunload', onBeforeUnload);
      onBeforeUnmount(() => {
        window.removeEventListener('beforeunload', onBeforeUnload);
      });
    }
  }

  return { confirmLeave };
}