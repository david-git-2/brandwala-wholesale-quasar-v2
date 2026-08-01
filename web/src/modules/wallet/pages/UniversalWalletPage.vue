<template>
  <q-page class="wallet-page-container q-pa-md">
    <UniversalWalletPageSkeleton v-if="isInitialLoading" />

    <div v-else class="q-gutter-y-md">
      <!-- Standard Page Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Ledger &amp; Financial Kernel</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Universal Wallet &amp; Accounting</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            3-bucket financial accounting (`available`, `pending`, `locked`), audit statements, and inflows across tenants, customers, vendors, and couriers.
          </p>
        </div>
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn
            unelevated
            color="primary"
            icon="ph ph-arrows-left-right"
            label="Transfer Buckets"
            no-caps
            class="text-weight-bold q-px-md rounded-borders"
            @click="isTransferModalOpen = true"
          />
          <q-chip dense flat class="bg-primary-soft text-primary text-weight-bold">
            <q-icon name="ph ph-buildings" size="14px" class="q-mr-xs" />
            {{ authStore.selectedTenant?.name || 'Primary Platform' }}
          </q-chip>
        </div>
      </section>

      <!-- Soft Entity Type Selector Tabs Card -->
      <q-card flat bordered class="tabs-card q-pa-xs">
        <q-tabs
          v-model="activeTab"
          dense
          no-caps
          active-color="primary"
          indicator-color="transparent"
          align="left"
          class="soft-tabs-bar"
          @update:model-value="onTabChange"
        >
          <!-- 1. Tenant -->
          <q-tab name="tenant" class="soft-tab-btn q-px-md q-py-sm">
            <div class="row items-center q-gutter-x-sm">
              <div class="tab-icon-wrapper" :class="{ active: activeTab === 'tenant' }">
                <q-icon name="ph ph-buildings" size="18px" />
              </div>
              <div class="column text-left">
                <span class="tab-title" :class="{ 'text-weight-bold text-primary': activeTab === 'tenant' }">
                  Tenant
                </span>
                <span class="tab-subtitle">Organization Ledger</span>
              </div>
            </div>
          </q-tab>

          <!-- 2. Billing Profile (Customer / Account) -->
          <q-tab name="customer" class="soft-tab-btn q-px-md q-py-sm">
            <div class="row items-center q-gutter-x-sm">
              <div class="tab-icon-wrapper" :class="{ active: activeTab === 'customer' }">
                <q-icon name="ph ph-receipt" size="18px" />
              </div>
              <div class="column text-left">
                <span class="tab-title" :class="{ 'text-weight-bold text-primary': activeTab === 'customer' }">
                  Billing Profile
                </span>
                <span class="tab-subtitle">Customer Accounts</span>
              </div>
            </div>
          </q-tab>

          <!-- 3. Vendor -->
          <q-tab name="vendor" class="soft-tab-btn q-px-md q-py-sm">
            <div class="row items-center q-gutter-x-sm">
              <div class="tab-icon-wrapper" :class="{ active: activeTab === 'vendor' }">
                <q-icon name="ph ph-storefront" size="18px" />
              </div>
              <div class="column text-left">
                <span class="tab-title" :class="{ 'text-weight-bold text-primary': activeTab === 'vendor' }">
                  Vendor
                </span>
                <span class="tab-subtitle">Supplier Wallets</span>
              </div>
            </div>
          </q-tab>

          <!-- 4. Courier -->
          <q-tab name="courier" class="soft-tab-btn q-px-md q-py-sm">
            <div class="row items-center q-gutter-x-sm">
              <div class="tab-icon-wrapper" :class="{ active: activeTab === 'courier' }">
                <q-icon name="ph ph-truck" size="18px" />
              </div>
              <div class="column text-left">
                <span class="tab-title" :class="{ 'text-weight-bold text-primary': activeTab === 'courier' }">
                  Courier
                </span>
                <span class="tab-subtitle">Delivery Remittance</span>
              </div>
            </div>
          </q-tab>
        </q-tabs>
      </q-card>

      <!-- Soft Selector Card for Non-Tenant Entities -->
      <transition name="fade-slide">
        <q-card v-if="activeTab !== 'tenant'" flat bordered class="q-pa-md">
          <div class="row items-center justify-between q-col-gutter-md">
            <div class="col-xs-12 col-sm-6 col-md-5">
              <label class="text-caption text-weight-bold text-muted q-mb-xs block">
                Target Entity Selection
              </label>
              <q-select
                v-model="selectedEntityId"
                outlined
                dense
                emit-value
                map-options
                use-input
                input-debounce="150"
                class="gentle-select"
                :options="filteredEntityOptions"
                :placeholder="entitySelectLabel"
                :loading="isEntityLoading"
                @filter="filterEntities"
              >
                <template #prepend>
                  <q-avatar size="24px" class="bg-primary-soft text-primary">
                    <q-icon :name="entitySelectIcon" size="14px" />
                  </q-avatar>
                </template>

                <template #no-option>
                  <q-item class="q-py-md text-center">
                    <q-item-section class="text-caption text-grey-6">
                      No matching {{ activeTabDisplay }} records found
                    </q-item-section>
                  </q-item>
                </template>

                <template #option="scope">
                  <q-item v-bind="scope.itemProps" class="soft-option-item q-py-sm">
                    <q-item-section avatar>
                      <q-avatar size="32px" class="bg-primary-soft text-primary text-weight-bold font-mono">
                        {{ scope.opt.label.charAt(0).toUpperCase() }}
                      </q-avatar>
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-weight-bold text-ink">{{ scope.opt.label }}</q-item-label>
                      <q-item-label v-if="scope.opt.caption" caption class="text-muted">
                        {{ scope.opt.caption }}
                      </q-item-label>
                    </q-item-section>
                    <q-item-section side>
                      <q-chip dense flat class="bg-grey-2 text-grey-8 text-weight-medium font-mono text-caption">
                        #{{ scope.opt.value }}
                      </q-chip>
                    </q-item-section>
                  </q-item>
                </template>
              </q-select>
            </div>

            <div class="col-xs-12 col-sm-6 col-md-7">
              <div class="selected-entity-preview row items-center q-pa-sm q-px-md rounded-borders">
                <div class="row items-center q-gutter-x-sm">
                  <q-icon name="ph ph-check-circle" color="positive" size="20px" />
                  <div>
                    <div class="text-caption text-muted">Active Wallet Focus</div>
                    <div class="text-subtitle2 text-weight-bolder text-primary">
                      {{ selectedEntityLabel }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </q-card>
      </transition>

      <!-- Navigation Sub-Tabs (Overview & Ledger vs Statement vs Platform Reports) -->
      <div class="sub-nav-bar row items-center justify-between">
        <q-btn-toggle
          v-model="activeSubView"
          dense
          unelevated
          toggle-color="primary"
          toggle-text-color="white"
          text-color="grey-8"
          class="bg-grey-2 q-pa-xs rounded-borders"
          no-caps
          :options="[
            { label: 'Overview & Ledger', value: 'overview', icon: 'ph ph-chart-pie-slice' },
            { label: 'Account Statement', value: 'statement', icon: 'ph ph-receipt' },
            { label: 'Platform Reports', value: 'reports', icon: 'ph ph-trend-up' },
          ]"
        />
      </div>

      <!-- View 1: Overview & Ledger -->
      <section v-if="activeSubView === 'overview'" class="q-gutter-y-md">
        <!-- 3-Bucket Account Card -->
        <WalletAccountCard
          :key="`acc-${activeTab}-${effectiveEntityId}`"
          :account="account"
          :entity-type="activeTab"
          :entity-name="selectedEntityNameOnly"
          @open-transfer="isTransferModalOpen = true"
        />

        <!-- Main Immutable Ledger View -->
        <UniversalWallet
          :key="`${activeTab}-${effectiveEntityId}`"
          :entity-type="activeTab"
          :entity-id="effectiveEntityId"
          :entity-name="selectedEntityNameOnly"
          :allow-adjustment="true"
        />
      </section>

      <!-- View 2: Account Statement -->
      <section v-else-if="activeSubView === 'statement'">
        <WalletStatementView
          :key="`stmt-${activeTab}-${effectiveEntityId}`"
          :entity-type="activeTab"
          :entity-id="effectiveEntityId"
          :entity-name="selectedEntityNameOnly"
        />
      </section>

      <!-- View 3: Platform Reports -->
      <section v-else-if="activeSubView === 'reports'">
        <WalletReportsView />
      </section>
    </div>

    <!-- Bucket Transfer Modal -->
    <WalletTransferModal
      v-model="isTransferModalOpen"
      :entity-type="activeTab"
      :entity-id="effectiveEntityId"
      :entity-name="selectedEntityNameOnly"
      @transferred="onTransferCompleted"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { vendorService } from 'src/modules/vendor/services/vendorService';
import { dropshipCourierRepository } from 'src/modules/shop_order/repositories/dropshipCourierRepository';
import type { UniversalWalletEntityType } from '../types';
import UniversalWallet from '../components/UniversalWallet.vue';
import UniversalWalletPageSkeleton from '../components/UniversalWalletPageSkeleton.vue';
import WalletAccountCard from '../components/WalletAccountCard.vue';
import WalletTransferModal from '../components/WalletTransferModal.vue';
import WalletStatementView from '../components/WalletStatementView.vue';
import WalletReportsView from '../components/WalletReportsView.vue';
import { useWalletAccounts } from '../composables/useWalletAccounts';

interface EntityOption {
  label: string;
  value: number;
  caption?: string | undefined;
  rawName?: string | undefined;
}

const authStore = useAuthStore();
const activeTab = ref<UniversalWalletEntityType>('tenant');
const activeSubView = ref<'overview' | 'statement' | 'reports'>('overview');
const selectedEntityId = ref<number>(1);
const isInitialLoading = ref<boolean>(true);
const isEntityLoading = ref<boolean>(false);
const filterText = ref<string>('');
const isTransferModalOpen = ref<boolean>(false);

// Cached option lists for each entity type
const billingProfileOptions = ref<EntityOption[]>([]);
const vendorOptions = ref<EntityOption[]>([]);
const courierOptions = ref<EntityOption[]>([]);

const effectiveEntityId = computed(() => {
  if (activeTab.value === 'tenant') {
    return authStore.selectedTenant?.id ?? 1;
  }
  return selectedEntityId.value || 1;
});

const { account, refetchAccount } = useWalletAccounts(
  () => activeTab.value,
  () => effectiveEntityId.value,
);

const currentEntityOptions = computed<EntityOption[]>(() => {
  switch (activeTab.value) {
    case 'customer': return billingProfileOptions.value;
    case 'vendor':   return vendorOptions.value;
    case 'courier':  return courierOptions.value;
    default:         return [];
  }
});

const filteredEntityOptions = computed<EntityOption[]>(() => {
  if (!filterText.value) return currentEntityOptions.value;
  const query = filterText.value.toLowerCase();
  return currentEntityOptions.value.filter(
    (opt) =>
      opt.label.toLowerCase().includes(query) ||
      (opt.caption && opt.caption.toLowerCase().includes(query)),
  );
});

const activeTabDisplay = computed(() => {
  switch (activeTab.value) {
    case 'tenant':   return 'Tenant';
    case 'customer': return 'Billing Profile';
    case 'vendor':   return 'Vendor';
    case 'courier':  return 'Courier';
    default:         return 'Entity';
  }
});

const entitySelectLabel = computed(() => {
  switch (activeTab.value) {
    case 'customer': return 'Search Billing Profile / Customer...';
    case 'vendor':   return 'Search Vendor / Supplier...';
    case 'courier':  return 'Search Courier Partner...';
    default:         return 'Select Entity...';
  }
});

const entitySelectIcon = computed(() => {
  switch (activeTab.value) {
    case 'customer': return 'ph ph-receipt';
    case 'vendor':   return 'ph ph-storefront';
    case 'courier':  return 'ph ph-truck';
    default:         return 'ph ph-buildings';
  }
});

const selectedEntityLabel = computed(() => {
  if (activeTab.value === 'tenant') {
    return authStore.selectedTenant?.name || 'Organization Ledger';
  }
  const matched = currentEntityOptions.value.find((opt) => opt.value === selectedEntityId.value);
  if (matched) return `${matched.label} (#${matched.value})`;
  return `ID #${selectedEntityId.value}`;
});

const selectedEntityNameOnly = computed(() => {
  if (activeTab.value === 'tenant') {
    return authStore.selectedTenant?.name || 'Tenant';
  }
  const matched = currentEntityOptions.value.find((opt) => opt.value === selectedEntityId.value);
  return matched?.rawName || matched?.label || '';
});

function filterEntities(val: string, update: (callback: () => void) => void) {
  update(() => {
    filterText.value = val;
  });
}

function onTransferCompleted() {
  void refetchAccount();
}

// Data loaders for entities
async function loadBillingProfiles() {
  const tenantId = authStore.selectedTenant?.id;
  if (!tenantId) return;
  isEntityLoading.value = true;
  try {
    const { data } = await supabase
      .from('billing_profiles')
      .select('id, name, email, phone, customer_groups(name)')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });

    if (data && data.length > 0) {
      billingProfileOptions.value = data.map((bp) => {
        const groupName = (bp as { customer_groups?: { name?: string } | null }).customer_groups?.name;
        const baseName = bp.name || `Profile #${bp.id}`;
        return {
          label: groupName ? `${groupName} · ${baseName}` : baseName,
          value: Number(bp.id),
          caption: [bp.phone, bp.email].filter(Boolean).join(' • ') || undefined,
          rawName: baseName,
        };
      });
    } else {
      billingProfileOptions.value = [];
    }
  } catch (err) {
    console.error('[UniversalWalletPage] Failed to load billing profiles:', err);
  } finally {
    isEntityLoading.value = false;
  }
}

async function loadVendors() {
  const tenantId = authStore.selectedTenant?.id;
  isEntityLoading.value = true;
  try {
    const res = await vendorService.listVendors(tenantId);
    if (res.success && res.data) {
      vendorOptions.value = res.data.map((v) => ({
        label: `${v.name}${v.code ? ` (${v.code})` : ''}`,
        value: Number(v.id),
        caption: v.phone || v.email || undefined,
        rawName: v.name,
      }));
    } else {
      vendorOptions.value = [];
    }
  } catch (err) {
    console.error('[UniversalWalletPage] Failed to load vendors:', err);
  } finally {
    isEntityLoading.value = false;
  }
}

async function loadCouriers() {
  isEntityLoading.value = true;
  try {
    const { data: services, error } = await supabase
      .from('courier_services')
      .select('id, name, code, wallet_entity_id, notes, is_active')
      .eq('is_active', true)
      .order('name', { ascending: true });

    if (error) throw error;

    courierOptions.value = (services || [])
      .filter((c) => c.wallet_entity_id != null)
      .map((c) => ({
        label: `${c.name}${c.code ? ` (${String(c.code).toUpperCase()})` : ''}`,
        value: Number(c.wallet_entity_id),
        caption: c.notes || `Service ${c.code || c.id}`,
        rawName: c.name,
      }));
  } catch (err) {
    console.error('[UniversalWalletPage] Failed to load couriers:', err);
    try {
      const couriers = await dropshipCourierRepository.listCouriers();
      courierOptions.value = couriers.map((c, index) => ({
        label: `${c.name}${c.code ? ` (${c.code.toUpperCase()})` : ''}`,
        value: index + 1,
        caption: c.notes || undefined,
        rawName: c.name,
      }));
    } catch {
      courierOptions.value = [];
    }
  } finally {
    isEntityLoading.value = false;
  }
}

function selectDefaultEntityForTab() {
  const opts = currentEntityOptions.value;
  if (opts.length > 0 && opts[0]) {
    selectedEntityId.value = opts[0].value;
  } else {
    selectedEntityId.value = 1;
  }
}

function onTabChange() {
  filterText.value = '';
  selectDefaultEntityForTab();
}

watch(
  () => authStore.selectedTenant?.id,
  () => {
    void loadBillingProfiles();
    void loadVendors();
    void loadCouriers();
  },
);

onMounted(async () => {
  isInitialLoading.value = true;
  try {
    await Promise.all([loadBillingProfiles(), loadVendors(), loadCouriers()]);
    selectDefaultEntityForTab();
  } finally {
    isInitialLoading.value = false;
  }
});
</script>

<style scoped>
.wallet-page-container {
  max-width: 1200px;
  margin: 0 auto;
}

.text-ink {
  color: var(--bw-theme-ink, #1e293b);
}

.text-muted {
  color: var(--bw-theme-muted, #64748b);
}

.bg-primary-soft {
  background: rgba(var(--q-primary-rgb, 59, 130, 246), 0.08) !important;
}

/* Tabs Styling */
.tabs-card {
  overflow-x: auto;
}

.soft-tabs-bar {
  background: transparent;
}

.soft-tab-btn {
  border-radius: 8px;
  margin: 2px;
  transition: all 0.2s ease;
}

.soft-tab-btn:hover {
  background: rgba(241, 245, 249, 0.6);
}

.tab-icon-wrapper {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(241, 245, 249, 1);
  color: #64748b;
  transition: all 0.2s ease;
}

.tab-icon-wrapper.active {
  background: var(--q-primary, #3b82f6);
  color: #ffffff;
}

.tab-title {
  font-size: 0.875rem;
  color: #334155;
  line-height: 1.2;
}

.tab-subtitle {
  font-size: 0.72rem;
  color: #94a3b8;
  line-height: 1.1;
}

.selected-entity-preview {
  background: rgba(241, 245, 249, 0.6);
  border: 1px dashed rgba(203, 213, 225, 0.8);
  border-radius: 8px;
}

.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all 0.2s ease;
}

.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>
