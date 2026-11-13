<template>
  <div class="column no-wrap col overflow-hidden">
    <q-input
      v-model="search"
      dense
      outlined
      clearable
      :placeholder="`Search ${entityLabel}…`"
      class="q-mb-sm"
    />
    <q-list v-if="rows.length" bordered separator class="col overflow-auto">
      <q-item
        v-for="row in rows"
        :key="row.id"
        clickable
        v-ripple
        @click="openRow(row)"
      >
        <q-item-section>
          <q-item-label>{{ row.name }}</q-item-label>
          <q-item-label v-if="row.subtitle" caption>{{ row.subtitle }}</q-item-label>
        </q-item-section>
        <q-item-section side class="row items-center q-gutter-xs no-wrap">
          <q-item-label v-if="row.balance != null" class="tf-num q-mr-sm">
            {{ formatAmountBdt(row.balance) }}
          </q-item-label>
          <ProfileCashbookActionBar
            v-if="showCashActions"
            @click.stop
            @deposit="onRowDeposit(row)"
            @withdraw="onRowWithdraw(row)"
            @locations="onRowLocations(row)"
          />
        </q-item-section>
      </q-item>
    </q-list>
    <div v-else-if="!loading" class="text-caption text-grey-6 text-center q-pa-lg">
      No {{ entityLabel }} found.
    </div>
    <div v-else class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="2em" />
    </div>

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
import ProfileCashbookActionBar from './ProfileCashbookActionBar.vue';
import ProfileCashLocationsPanel from './ProfileCashLocationsPanel.vue';
import { useProfileCashMovementDialog } from '../composables/useProfileCashMovementDialog';
import { PROFILE_CASH_DEFAULT_METHOD } from '../constants/profileCashMovementMethods';
import { isProfileCashbookEnabled } from '../utils/profileCashbookEnabled';
import { formatAmountBdt } from 'src/utils/currency';
import type { PayTransferEntityType } from 'src/modules/bills_pays/types/payTransferParty';

const props = defineProps<{
  entityType: PayTransferEntityType | 'investor' | 'cargo_company';
  entityLabel: string;
}>();

const authStore = useAuthStore();
const route = useRoute();
const search = ref('');
const rows = ref<Array<{ id: number; name: string; subtitle?: string; balance?: number }>>([]);
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
      subtitle: r.entity_type,
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

<style scoped>
.people-party-drawer {
  background: #fff;
  min-height: 0;
}

.people-party-drawer__header {
  border-bottom: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.08));
}

.min-width-0 {
  min-width: 0;
}
</style>
