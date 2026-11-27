import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import type { MoneyPayKind } from 'src/modules/finance/submodules/bills_pays/types/moneyPayDialog';
import { useCashbookPartyQuery } from 'src/modules/finance/submodules/bills_pays/composables/useCashbookPartyQuery';
import { resolveCashbookRouteProfileId } from '../utils/profileMoneyProfileId';
import { useProfileCashMovementReturn } from './useProfileCashMovementReturn';
import { useProfileCashMovementSubmit } from './useProfileCashMovementSubmit';

const ROUTE_ENTITY_TYPES = new Set(['tenant', 'customer', 'courier', 'vendor', 'investor']);

export function useProfileCashMovementPage(pageKind: Extract<MoneyPayKind, 'deposit' | 'withdrawal'>) {
  const authStore = useAuthStore();
  const route = useRoute();
  const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();

  const profileId = ref<number | null>(null);
  const profileLoading = ref(true);
  const profileLoadError = ref<string | null>(null);

  const operatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);
  const booksTenantId = computed(() => authStore.selectedTenant?.id ?? 0);

  const routeEntityType = computed(() => {
    const raw = route.params.entityType;
    const t = typeof raw === 'string' ? raw : '';
    return ROUTE_ENTITY_TYPES.has(t) ? t : 'customer';
  });

  const entityId = computed(() => {
    const raw = route.params.entityId;
    const id = Number(typeof raw === 'string' ? raw : '');
    return Number.isFinite(id) && id > 0 ? id : 0;
  });

  const kindRef = ref<MoneyPayKind>(pageKind);

  const { returnPath, goBack, partyNameFromQuery } = useProfileCashMovementReturn({
    entityType: () => routeEntityType.value,
    entityId: () => entityId.value,
  });

  const partyParams = computed(() => ({
    tenantId: operatingTenantId.value,
    entityType: routeEntityType.value,
    entityId: entityId.value,
    search: undefined,
    ledgerOffset: 0,
    ledgerLimit: 1,
  }));

  const { detailQuery } = useCashbookPartyQuery(partyParams);

  const partyName = computed(() => {
    const fromQuery = partyNameFromQuery.value;
    if (fromQuery) return fromQuery;
    return detailQuery.data.value?.name?.trim() || 'Party';
  });

  const loadProfileId = async () => {
    profileLoading.value = true;
    profileLoadError.value = null;
    profileId.value = null;
    if (entityId.value <= 0 || operatingTenantId.value <= 0) {
      profileLoadError.value = 'Invalid party.';
      profileLoading.value = false;
      return;
    }
    try {
      profileId.value = await resolveCashbookRouteProfileId(
        operatingTenantId.value,
        booksTenantId.value,
        routeEntityType.value,
        entityId.value,
      );
    } catch (error: unknown) {
      profileLoadError.value =
        error instanceof Error ? error.message : 'Could not resolve cash profile.';
    } finally {
      profileLoading.value = false;
    }
  };

  const { movementMutation, submitMovement } = useProfileCashMovementSubmit({
    kind: kindRef,
    profileId,
    tenantId: operatingTenantId,
    booksTenantId,
    entityType: routeEntityType,
    entityId,
    onMovementSuccess: () => {
      goBack();
    },
  });

  const pageReady = computed(
    () => !profileLoading.value && profileId.value != null && !profileLoadError.value,
  );

  watch(
    () => [entityId.value, routeEntityType.value, operatingTenantId.value],
    () => {
      void loadProfileId();
    },
  );

  onMounted(() => {
    void loadProfileId();
    setCustomBreadcrumbs([
      {
        label: 'Cashbook',
        to: route.params.tenantSlug
          ? `/${String(route.params.tenantSlug)}/app/cashbook`
          : '/app/cashbook',
      },
      {
        label: partyName.value,
        to: returnPath.value,
      },
      {
        label: pageKind === 'deposit' ? 'Deposit' : 'Withdraw',
      },
    ]);
  });

  onUnmounted(() => {
    clearCustomBreadcrumbs();
  });

  watch(partyName, (name) => {
    setCustomBreadcrumbs([
      {
        label: 'Cashbook',
        to: route.params.tenantSlug
          ? `/${String(route.params.tenantSlug)}/app/cashbook`
          : '/app/cashbook',
      },
      {
        label: name,
        to: returnPath.value,
      },
      {
        label: pageKind === 'deposit' ? 'Deposit' : 'Withdraw',
      },
    ]);
  });

  return {
    operatingTenantId,
    booksTenantId,
    routeEntityType,
    entityId,
    profileId,
    profileLoading,
    profileLoadError,
    partyName,
    pageReady,
    returnPath,
    goBack,
    movementMutation,
    submitMovement,
  };
}