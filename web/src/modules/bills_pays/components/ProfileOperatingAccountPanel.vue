<template>
  <div class="column no-wrap q-gutter-y-sm profile-operating-panel full-height">
    <div v-if="initialLoading" class="row justify-center q-py-lg">
      <q-spinner color="primary" size="2em" />
    </div>

    <div v-else-if="showLoadError" class="text-center text-negative q-pa-md">
      {{ errorMessage }}
    </div>

    <template v-else>
      <div class="profile-operating-panel__header q-pa-md">
        <div class="text-subtitle1 text-weight-bold">{{ partyName }}</div>
        <div class="row q-gutter-md q-mt-xs text-body2">
          <span v-if="entityType !== 'tenant'">
            Has with us <strong>{{ formatAmountBdt(available) }}</strong>
          </span>
          <span v-else>
            Cash <strong>{{ formatAmountBdt(available) }}</strong>
          </span>
          <span v-if="entityType !== 'tenant' && dueTotal > 0">
            Open due <strong>{{ formatAmountBdt(dueTotal) }}</strong>
          </span>
        </div>
        <div
          v-if="!cashbookEnabled && entityType !== 'tenant'"
          class="text-caption text-grey-7 q-mt-xs"
        >
          Payment history only — no cashbook wallet on this party.
        </div>
        <ProfileCashbookActionBar
          v-if="showActions && cashbookEnabled"
          class="q-mt-sm"
          @deposit="openDeposit"
          @withdraw="openWithdraw"
          @locations="openLocations"
        />
      </div>

      <div class="col overflow-auto profile-operating-panel__transactions column no-wrap">
        <div
          v-if="displayPays.length"
          class="row items-center justify-end q-px-sm q-py-xs profile-operating-panel__amount-toggle"
        >
          <q-btn-toggle
            v-model="amountViewMode"
            dense
            no-caps
            unelevated
            toggle-color="primary"
            class="profile-operating-panel__amount-toggle-inner"
            :options="amountViewOptions"
          />
        </div>
        <ProfilePayTransactionRow
          v-for="row in displayPays"
          :key="`pay-${row.id}`"
          :row="row"
          :viewed-profile-id="viewedProfileId"
          :viewed-profile-display-name="partyName"
          :amount-mode="amountViewMode"
          :currency-symbols="currencySymbolMap"
          :can-revert="canRevertRow(row)"
          :revert-loading="revertPendingId === row.id && revertMutation.isPending.value"
          @revert="openRevertDialog"
        />
        <div v-if="!displayPays.length && !activityQuery.isPending.value" class="text-caption text-grey-6 text-center q-py-lg">
          No transactions yet.
        </div>
        <div v-if="hasMorePays" class="row justify-center q-py-sm profile-operating-panel__load-more">
          <q-btn
            flat
            dense
            no-caps
            class="q-px-md"
            :loading="activityQuery.isFetchingNextPage.value"
            label="Load more"
            icon="ph ph-arrow-down"
            @click="loadMorePays"
          />
        </div>
      </div>
    </template>

    <ProfileCashLocationsPanel
      v-if="showActions && cashbookEnabled"
      v-model="locationsPanelOpen"
      :books-tenant-id="booksTenantId"
      :operating-tenant-id="tenantId"
      :profile-id="resolvedProfileId"
      :party-name="partyName"
    />

    <ProfilePayRevertDialog
      v-model="revertDialogOpen"
      :loading="revertMutation.isPending.value"
      @confirm="confirmRevert"
    />

    <MoneyPayDialog
      v-if="showActions && cashbookEnabled"
      v-model="dialogOpen"
      leg-layout="profile_cash"
      :kind="dialogKind"
      :title="dialogKind === 'deposit' ? 'Deposit' : 'Withdraw'"
      :from-party-name="partyName"
      :to-party-name="partyName"
      :loading="movementMutation.isPending.value"
      :field-flags="movementFieldFlags"
      :books-tenant-id="booksTenantId"
      :operating-tenant-id="tenantId"
      :profile-id="resolvedProfileId"
      books-currency-code="BDT"
      :default-method-code="PROFILE_CASH_DEFAULT_METHOD"
      @submit="onMoneyPaySubmit"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import ProfilePayTransactionRow from './ProfilePayTransactionRow.vue';
import ProfilePayRevertDialog from './ProfilePayRevertDialog.vue';
import MoneyPayDialog from './MoneyPayDialog.vue';
import { usePaymentsVoidAccess } from '../composables/usePaymentsVoidAccess';
import { useProfilePayRevertMutation } from '../composables/useProfilePayRevertMutation';
import { payProfileKernelCanRevert } from '../utils/payListDisplay';
import ProfileCashbookActionBar from 'src/modules/people/components/ProfileCashbookActionBar.vue';
import ProfileCashLocationsPanel from 'src/modules/people/components/ProfileCashLocationsPanel.vue';
import { useProfileCashMovementDialog } from 'src/modules/people/composables/useProfileCashMovementDialog';
import { PROFILE_CASH_DEFAULT_METHOD } from 'src/modules/people/constants/profileCashMovementMethods';
import { usePaymentProfileQuery } from '../composables/usePaymentProfileQuery';
import { useProfileActivityQuery } from '../composables/useProfileActivityQuery';
import { useCurrencySymbolMap } from '../composables/useCurrencySymbolMap';
import type { PayAmountDisplayMode } from '../utils/payListDisplay';
import type { PayListRow as PayRow } from '../repositories/paysRepository';
import type { PayTransferEntityType } from '../types/payTransferParty';

const PROFILE_PAY_PAGE_SIZE = 25;

const props = withDefaults(
  defineProps<{
    tenantId: number;
    booksTenantId: number;
    entityType: PayTransferEntityType | 'investor' | 'cargo_company';
    entityId: number;
    partyName?: string;
    tenantName?: string;
    active?: boolean;
    showActions?: boolean;
    tenantSlug?: string;
  }>(),
  {
    partyName: '—',
    tenantName: 'Company',
    active: true,
    showActions: true,
    tenantSlug: undefined,
  },
);

const paymentsVoidAccess = usePaymentsVoidAccess();
const revertMutation = useProfilePayRevertMutation();
const revertDialogOpen = ref(false);
const revertTargetId = ref<number | null>(null);
const revertPendingId = ref<number | null>(null);

const movementEntityId = computed(() => props.entityId);
const movementPartyName = computed(() => props.partyName);
const movementTenantSlug = computed(() => props.tenantSlug);
const movementActive = computed(() => props.active);

const {
  cashbookEnabled,
  dialogOpen,
  dialogKind,
  openDeposit,
  openWithdraw,
  openLocations,
  locationsPanelOpen,
  resolvedProfileId,
  onMoneyPaySubmit,
  movementMutation,
} = useProfileCashMovementDialog({
  tenantId: computed(() => props.tenantId),
  booksTenantId: computed(() => props.booksTenantId),
  entityType: computed(() => props.entityType),
  entityId: movementEntityId,
  partyName: movementPartyName,
  tenantSlug: movementTenantSlug,
  active: movementActive,
});

const movementFieldFlags = computed(() => ({
  showAllocations: false,
  showFromLeg: false,
  showToLeg: false,
  showInstrument: true,
  showDate: true,
  showReferenceNote: true,
}));

const profileParams = computed(() => ({
  tenantId: props.tenantId,
  entityType: props.entityType,
  entityId: props.entityId,
  ledgerLimit: 50,
  paysLimit: PROFILE_PAY_PAGE_SIZE,
}));

const profileQuery = usePaymentProfileQuery(profileParams);

const activityParams = computed(() => ({
  tenantId: props.tenantId,
  entityType: props.entityType,
  entityId: props.entityId,
  kind: 'payments' as const,
  limit: PROFILE_PAY_PAGE_SIZE,
}));

const activityEnabled = computed(() => !!props.active && props.entityId > 0);
const activityQuery = useProfileActivityQuery(activityParams, activityEnabled);

const amountViewMode = ref<PayAmountDisplayMode>('bdt');
const amountViewOptions = [
  { label: 'BDT equivalent', value: 'bdt' as const },
  { label: 'Original currency', value: 'original' as const },
];

const { currencySymbolMap } = useCurrencySymbolMap();

const payListPerspective = computed((): 'tenant' | 'party' =>
  props.entityType === 'tenant' ? 'tenant' : 'party',
);

const viewedProfileId = computed(() => resolvedProfileId.value ?? null);

const bundle = computed(() => profileQuery.data.value ?? null);
const available = computed(() => bundle.value?.detail.available_balance ?? 0);
const dueTotal = computed(() => bundle.value?.dueTotal ?? 0);

const initialLoading = computed(
  () =>
    profileQuery.isPending.value
    && !profileQuery.data.value
    && activityQuery.isPending.value
    && !activityQuery.data.value,
);

function mapPayActivityRow(row: Record<string, unknown>): PayRow {
  return {
    id: Number(row.id),
    payment_date: String(row.payment_date ?? ''),
    amount: Number(row.amount ?? 0),
    unallocated_amount: Number(row.unallocated_amount ?? 0),
    source: String(row.source ?? ''),
    direction: row.direction === 'out' ? 'out' : row.direction === 'in' ? 'in' : undefined,
    method: (row.method as string | null) ?? null,
    reference: (row.reference as string | null) ?? null,
    note: (row.note as string | null) ?? null,
    voided_at: (row.voided_at as string | null) ?? null,
    profile_id: row.profile_id == null ? null : Number(row.profile_id),
    profile_name: (row.profile_name as string | null) ?? null,
    shop_order_id: row.shop_order_id == null ? null : Number(row.shop_order_id),
    settlement_currency_code: String(row.settlement_currency_code ?? 'BDT'),
    foreign_amount: row.foreign_amount == null ? null : Number(row.foreign_amount),
    exchange_rate: Number(row.exchange_rate ?? 1),
    counterparty_name: (row.counterparty_name as string | null) ?? null,
    cashbook_point_name: (row.cashbook_point_name as string | null) ?? null,
    related_invoice_no: (row.related_invoice_no as string | null) ?? null,
    from_profile_id: row.from_profile_id == null ? null : Number(row.from_profile_id),
    to_profile_id: row.to_profile_id == null ? null : Number(row.to_profile_id),
    from_profile_name: (row.from_profile_name as string | null) ?? null,
    to_profile_name: (row.to_profile_name as string | null) ?? null,
    description: (row.description as string | null) ?? null,
    perspective: (row.perspective as 'tenant' | 'party' | undefined) ?? payListPerspective.value,
    spine: row.spine === 'kernel' ? 'kernel' : undefined,
    kernel_kind: (row.kernel_kind as string | null) ?? null,
    reverted_at: (row.reverted_at as string | null) ?? null,
    revert_reason: (row.revert_reason as string | null) ?? null,
    is_reversal: row.is_reversal === true,
    reverses_pays_id:
      row.reverses_pays_id == null ? null : Number(row.reverses_pays_id),
  };
}

function canRevertRow(row: PayRow): boolean {
  return paymentsVoidAccess.value && payProfileKernelCanRevert(row);
}

const openRevertDialog = (row: PayRow) => {
  revertTargetId.value = row.id;
  revertDialogOpen.value = true;
};

const confirmRevert = async (reason: string) => {
  const paysId = revertTargetId.value;
  if (paysId == null) return;
  revertPendingId.value = paysId;
  try {
    await revertMutation.mutateAsync({
      booksTenantId: props.booksTenantId,
      paysId,
      reason,
    });
    revertDialogOpen.value = false;
    revertTargetId.value = null;
  } finally {
    revertPendingId.value = null;
  }
};

const displayPays = computed((): PayRow[] => {
  const pages = activityQuery.data.value?.pages ?? [];
  const fromActivity = pages.flatMap((p) =>
    (p.items as Record<string, unknown>[]).map((row) => mapPayActivityRow(row)),
  );
  if (fromActivity.length) return fromActivity;
  return bundle.value?.pays ?? [];
});

const showLoadError = computed(
  () =>
    (profileQuery.isError.value || activityQuery.isError.value)
    && !displayPays.value.length
    && !activityQuery.isPending.value
    && !activityQuery.isFetching.value,
);

const errorMessage = computed(() => {
  const err = profileQuery.error.value ?? activityQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load payment history.';
});

const hasMorePays = computed(() => activityQuery.hasNextPage.value);

const loadMorePays = () => {
  if (!hasMorePays.value || activityQuery.isFetchingNextPage.value) return;
  void activityQuery.fetchNextPage();
};

</script>

<style scoped lang="scss">
.profile-operating-panel__header {
  background: var(--tf-neutral-canvas, #f7f4ef);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
}

.profile-operating-panel__transactions {
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
  background: #fff;
}

.profile-operating-panel__load-more {
  position: sticky;
  bottom: 0;
  background: #fff;
  border-top: 1px solid var(--tf-neutral-border, #e7e1d8);
}
</style>
