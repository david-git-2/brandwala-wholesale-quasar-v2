<template>
  <div class="column no-wrap col overflow-hidden min-height-0">
    <q-input
      v-model="search"
      dense
      outlined
      clearable
      hide-bottom-space
      :placeholder="`Search ${entityLabel}…`"
      class="q-mb-sm"
    >
      <template #prepend>
        <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-5" />
      </template>
    </q-input>

    <TfEntityListShell v-if="loading && !rows.length" root-class="col">
      <TfEntityListRow v-for="n in 6" :key="n" skeleton />
    </TfEntityListShell>

    <div
      v-else-if="!rows.length"
      class="tf-entity-list-card col column items-center justify-center text-center q-pa-xl"
    >
      <q-icon name="ph ph-tray" size="36px" class="text-grey-5 q-mb-sm" />
      <div class="text-subtitle2 text-weight-medium text-grey-8">No {{ entityLabel }} found</div>
    </div>

    <TfEntityListShell v-else root-class="col">
      <TfEntityListRow
        v-for="row in rows"
        :key="row.id"
        :show-chevron="false"
        @click="openRow(row)"
      >
        <template #avatar>{{ getInitials(row.name) }}</template>
        <template #title>
          <span class="tf-entity-list-item__name">{{ row.name }}</span>
        </template>
        <template v-if="row.meta" #meta>{{ row.meta }}</template>
        <template #aside>
          <span v-if="row.balance != null" class="tf-num text-weight-medium q-mr-xs">
            {{ formatAmountBdt(row.balance) }}
          </span>
          <div @click.stop>
            <ProfileCashbookActionBar
              v-if="showCashActions"
              @deposit="onRowDeposit(row)"
              @withdraw="onRowWithdraw(row)"
              @locations="onRowLocations(row)"
            />
          </div>
        </template>
      </TfEntityListRow>
    </TfEntityListShell>

    <AppResizableOverlayPanel
      v-model="drawerOpen"
      storage-key="people.party-detail-drawer-width"
      :default-width="520"
      :min-width="400"
      :max-width="720"
      aria-label="Party payment account"
    >
      <div class="people-party-drawer column no-wrap full-height">
        <div class="people-party-drawer__header row items-center no-wrap q-pa-md shrink-0">
          <div class="col min-width-0">
            <div class="text-overline text-primary">Payments</div>
            <div v-if="selected" class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
              {{ selected.name }}
            </div>
          </div>
          <q-btn
            flat
            round
            dense
            icon="ph ph-x"
            color="grey-7"
            aria-label="Close"
            class="shrink-0"
            :ripple="false"
            @click="drawerOpen = false"
          />
        </div>
        <q-separator />
        <div class="people-party-drawer__body col scroll q-pa-md">
          <ProfileOperatingAccountPanel
            v-if="selected"
            :tenant-id="tenantId"
            :books-tenant-id="booksTenantId"
            :entity-type="entityType"
            :entity-id="selected.id"
            :party-name="selected.name"
            :tenant-name="tenantName"
            :tenant-slug="tenantSlug"
            :active="drawerOpen"
          />
        </div>
      </div>
    </AppResizableOverlayPanel>

    <ProfileCashLocationsPanel
      v-if="showCashActions"
      v-model="locationsPanelOpen"
      :books-tenant-id="booksTenantId"
      :operating-tenant-id="tenantId"
      :profile-id="resolvedProfileId"
      :party-name="selected?.name"
    />

    <MoneyPayDialog
      v-if="showCashActions"
      v-model="dialogOpen"
      leg-layout="profile_cash"
      :kind="dialogKind"
      :title="dialogKind === 'deposit' ? 'Deposit' : 'Withdraw'"
      :from-party-name="selected?.name ?? 'Party'"
      :to-party-name="selected?.name ?? 'Party'"
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
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { cashbookRepository } from 'src/modules/bills_pays/repositories/cashbookRepository';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import ProfileOperatingAccountPanel from 'src/modules/bills_pays/components/ProfileOperatingAccountPanel.vue';
import MoneyPayDialog from 'src/modules/bills_pays/components/MoneyPayDialog.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import ProfileCashbookActionBar from './ProfileCashbookActionBar.vue';
import ProfileCashLocationsPanel from './ProfileCashLocationsPanel.vue';
import { useProfileCashMovementDialog } from '../composables/useProfileCashMovementDialog';
import { PROFILE_CASH_DEFAULT_METHOD } from '../constants/profileCashMovementMethods';
import { isProfileCashbookEnabled } from '../utils/profileCashbookEnabled';
import { formatAmountBdt } from 'src/utils/currency';
import { getInitials } from 'src/modules/sales_invoice/utils/invoiceListDisplay';
import type { PayTransferEntityType } from 'src/modules/bills_pays/types/payTransferParty';

type PartyRow = {
  id: number;
  name: string;
  meta?: string;
  balance?: number;
};

const props = defineProps<{
  entityType: PayTransferEntityType | 'investor' | 'cargo_company';
  entityLabel: string;
}>();

const authStore = useAuthStore();
const route = useRoute();
const search = ref('');
const rows = ref<PartyRow[]>([]);
const loading = ref(false);
const drawerOpen = ref(false);
const selected = ref<{ id: number; name: string } | null>(null);
const movementPartyId = ref(0);

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});
const tenantName = computed(() => authStore.selectedTenant?.name ?? 'Company');
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined,
);

const showCashActions = computed(() => isProfileCashbookEnabled(props.entityType));

const movementFieldFlags = computed(() => ({
  showAllocations: false,
  showFromLeg: false,
  showToLeg: false,
  showInstrument: true,
  showDate: true,
  showReferenceNote: true,
}));

const movementPartyName = computed(() => selected.value?.name ?? 'Party');

const {
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
  tenantId,
  booksTenantId,
  entityType: computed(() => props.entityType),
  entityId: computed(() => movementPartyId.value),
  partyName: movementPartyName,
  tenantSlug,
  active: drawerOpen,
});

const partyMeta = (caption: string | null, code: string | null) => {
  const parts = [caption?.trim(), code?.trim()].filter(Boolean) as string[];
  return parts.length ? parts.join(' · ') : undefined;
};

const load = async () => {
  if (!tenantId.value) return;
  loading.value = true;
  try {
    const list = await cashbookRepository.listEntities({
      tenantId: tenantId.value,
      entityType: props.entityType,
      search: search.value || undefined,
      limit: 100,
    });
    rows.value = list.map((r) => ({
      id: r.entity_id,
      name: r.name,
      meta: partyMeta(r.caption, r.code),
      balance: r.available_balance,
    }));
  } finally {
    loading.value = false;
  }
};

watch([() => props.entityType, search, tenantId], () => void load(), { immediate: true });

const openRow = (row: { id: number; name: string }) => {
  selected.value = row;
  movementPartyId.value = row.id;
  drawerOpen.value = true;
};

const bindMovementParty = (row: { id: number; name: string }) => {
  selected.value = row;
  movementPartyId.value = row.id;
};

const onRowDeposit = (row: { id: number; name: string }) => {
  bindMovementParty(row);
  void openDeposit();
};

const onRowWithdraw = (row: { id: number; name: string }) => {
  bindMovementParty(row);
  void openWithdraw();
};

const onRowLocations = (row: { id: number; name: string }) => {
  bindMovementParty(row);
  void openLocations();
};
</script>

<style scoped lang="scss">
@import 'src/css/tf-entity-list.scss';

.people-party-drawer {
  background: var(--tf-neutral-surface);
  min-height: 0;
}

.people-party-drawer__header {
  border-bottom: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.08));
}

.min-width-0 {
  min-width: 0;
}
</style>