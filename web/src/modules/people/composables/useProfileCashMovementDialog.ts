import { computed, ref, type ComputedRef, type Ref } from 'vue';
import { showErrorNotification } from 'src/utils/appFeedback';
import { isProfileCashbookEnabled } from '../utils/profileCashbookEnabled';
import { resolveMoneyProfileId } from '../utils/profileMoneyProfileId';

export function useProfileCashMovementDialog(options: {
  tenantId: ComputedRef<number>;
  booksTenantId: ComputedRef<number>;
  entityType: ComputedRef<string>;
  entityId: ComputedRef<number>;
  partyName: ComputedRef<string>;
  tenantSlug: ComputedRef<string | undefined>;
  active: Ref<boolean>;
}) {
  const locationsPanelOpen = ref(false);
  const profileId = ref<number | null>(null);

  const cashbookEnabled = computed(() =>
    isProfileCashbookEnabled(options.entityType.value),
  );

  const ensureProfileId = async () => {
    if (!cashbookEnabled.value || options.entityId.value <= 0) {
      profileId.value = null;
      return;
    }
    try {
      profileId.value = await resolveMoneyProfileId(
        options.booksTenantId.value,
        options.entityType.value,
        options.entityId.value,
      );
    } catch (error: unknown) {
      profileId.value = null;
      showErrorNotification(error instanceof Error ? error.message : 'Could not resolve cash profile.');
    }
  };

  const openLocations = async () => {
    await ensureProfileId();
    if (profileId.value == null) return;
    locationsPanelOpen.value = true;
  };

  const resolvedProfileId = computed(() => profileId.value);

  return {
    cashbookEnabled,
    locationsPanelOpen,
    resolvedProfileId,
    ensureProfileId,
    openLocations,
    partyName: options.partyName,
    operatingTenantId: options.tenantId,
    booksTenantId: options.booksTenantId,
  };
}