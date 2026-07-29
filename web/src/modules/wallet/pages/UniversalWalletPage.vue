<template>
  <q-page class="wallet-page-container q-pa-md q-pa-md-lg">
    <div class="q-gutter-y-lg">
      <!-- Modern Header Banner -->
      <section class="wallet-header-card q-pa-md q-pa-md-lg surface-card shadow-soft">
        <div class="row items-center justify-between q-col-gutter-md">
          <div class="col-12 col-md-8">
            <div class="row items-center q-gutter-x-sm q-mb-xs">
              <q-badge color="primary" class="soft-badge text-weight-bolder text-uppercase q-px-sm q-py-xs">
                Ledger Hub
              </q-badge>
              <span class="text-caption text-muted">Multi-currency financial system</span>
            </div>
            <h1 class="text-h5 text-md-h4 text-weight-bolder q-my-none text-ink tracking-tight">
              Universal Wallet
            </h1>
            <p class="text-body2 text-muted q-mb-none q-mt-xs font-gentle">
              Manage accounts, financial balances, and transaction history across tenants, billing profiles (customers &amp; resellers), vendors, and courier partners.
            </p>
          </div>
          <div class="col-12 col-md-4 text-left text-md-right">
            <div class="inline-block soft-pill-container q-pa-xs">
              <span class="text-caption text-muted q-px-sm">Active Tenant:</span>
              <q-chip dense flat class="bg-primary-soft text-primary text-weight-bold">
                <q-icon name="ph ph-buildings" size="14px" class="q-mr-xs" />
                {{ authStore.selectedTenant?.name || 'Primary Platform' }}
              </q-chip>
            </div>
          </div>
        </div>
      </section>

      <!-- Soft Entity Type Selector Tabs -->
      <section class="tabs-container surface-card shadow-soft q-pa-xs">
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
      </section>

      <!-- Soft Selector Card for Non-Tenant Entities -->
      <transition name="fade-slide">
        <section v-if="activeTab !== 'tenant'" class="soft-selector-card surface-card shadow-soft q-pa-md">
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
        </section>
      </transition>

      <!-- Main Ledger View -->
      <section class="wallet-main-content">
        <UniversalWallet
          :key="`${activeTab}-${effectiveEntityId}`"
          :entity-type="activeTab"
          :entity-id="effectiveEntityId"
          :entity-name="selectedEntityNameOnly"
          :allow-adjustment="true"
        />
      </section>
    </div>
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

interface EntityOption {
  label: string;
  value: number;
  caption?: string | undefined;
  rawName?: string | undefined;
}

const authStore = useAuthStore();
const activeTab = ref<UniversalWalletEntityType>('tenant');
const selectedEntityId = ref<number>(1);
const isEntityLoading = ref<boolean>(false);
const filterText = ref<string>('');

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

// Data loaders for entities
async function loadBillingProfiles() {
  const tenantId = authStore.selectedTenant?.id;
  if (!tenantId) return;
  isEntityLoading.value = true;
  try {
    const { data } = await supabase
      .from('billing_profiles')
      .select('id, name, email, phone')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });

    if (data && data.length > 0) {
      billingProfileOptions.value = data.map((bp) => ({
        label: bp.name || `Profile #${bp.id}`,
        value: Number(bp.id),
        caption: [bp.phone, bp.email].filter(Boolean).join(' • '),
        rawName: bp.name || undefined,
      }));
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
    const couriers = await dropshipCourierRepository.listCouriers();
    // Query public.couriers table for true database numeric IDs
    const { data: dbCouriers } = await supabase
      .from('couriers')
      .select('id, name, code');

    const dbCourierMap = new Map<string, number>();
    if (dbCouriers) {
      for (const dbc of dbCouriers) {
        if (dbc.code) dbCourierMap.set(dbc.code.toLowerCase(), Number(dbc.id));
        if (dbc.name) dbCourierMap.set(dbc.name.toLowerCase(), Number(dbc.id));
      }
    }

    courierOptions.value = couriers.map((c, index) => {
      let numericId = dbCourierMap.get(c.code.toLowerCase()) || dbCourierMap.get(c.name.toLowerCase());
      if (!numericId) {
        // Fallback to numeric parsing or stable positive ID
        const parsed = parseInt(c.id.replace(/\D/g, '').substring(0, 8), 10);
        numericId = !isNaN(parsed) && parsed > 0 ? parsed : index + 1;
      }
      return {
        label: `${c.name}${c.code ? ` (${c.code.toUpperCase()})` : ''}`,
        value: numericId,
        caption: c.notes || undefined,
        rawName: c.name,
      };
    });
  } catch (err) {
    console.error('[UniversalWalletPage] Failed to load couriers:', err);
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
  await Promise.all([loadBillingProfiles(), loadVendors(), loadCouriers()]);
  selectDefaultEntityForTab();
});
</script>

<style scoped>
.wallet-page-container {
  max-width: 1400px;
  margin: 0 auto;
}

.text-ink {
  color: var(--bw-theme-ink, #1e293b);
}

.text-muted {
  color: var(--bw-theme-muted, #64748b);
}

.surface-card {
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  border-radius: 16px;
}

.shadow-soft {
  box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.04);
}

.soft-badge {
  border-radius: 8px;
  background: rgba(var(--q-primary-rgb, 59, 130, 246), 0.12) !important;
  color: var(--q-primary, #3b82f6) !important;
}

.soft-pill-container {
  background: rgba(241, 245, 249, 0.8);
  border-radius: 20px;
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.bg-primary-soft {
  background: rgba(var(--q-primary-rgb, 59, 130, 246), 0.08) !important;
}

/* Tabs Styling */
.tabs-container {
  overflow-x: auto;
}

.soft-tabs-bar {
  background: transparent;
}

.soft-tab-btn {
  border-radius: 12px;
  margin: 2px;
  transition: all 0.2s ease;
}

.soft-tab-btn:hover {
  background: rgba(241, 245, 249, 0.6);
}

.tab-icon-wrapper {
  width: 34px;
  height: 34px;
  border-radius: 10px;
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
  box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
}

.tab-title {
  font-size: 0.9rem;
  color: #334155;
  line-height: 1.2;
}

.tab-subtitle {
  font-size: 0.72rem;
  color: #94a3b8;
  line-height: 1.1;
}

/* Soft Selector Card */
.soft-selector-card {
  background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%);
}

.selected-entity-preview {
  background: rgba(241, 245, 249, 0.6);
  border: 1px dashed rgba(203, 213, 225, 0.8);
  border-radius: 12px;
}

.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}

.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>


