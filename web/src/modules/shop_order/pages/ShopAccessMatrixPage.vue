<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Page Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col-12 col-md-auto row items-center no-wrap">
          <q-btn flat round icon="ph ph-arrow-left" color="grey-7" class="q-mr-sm" @click="goBack" />
          <div>
            <div class="text-overline text-primary font-weight-bold">
              {{ $t('navigation.shops') }}
            </div>
            <h1 class="text-h5 text-weight-bold q-my-none">
              {{ $t('shop_admin.access_matrix_title', { name: shopName }) }}
            </h1>
            <p class="text-caption text-grey-7 q-mb-none">
              {{ $t('shop_admin.access_matrix_subtitle') }}
            </p>
          </div>
        </div>

        <!-- Header Actions / Quick Refresh -->
        <div class="col-12 col-md-auto row items-center q-gutter-sm">
          <q-btn
            flat
            dense
            icon="ph ph-arrows-clockwise"
            label="Refresh"
            color="grey-8"
            :loading="isLoading"
            @click="load"
          />
        </div>
      </section>

      <!-- Error banner -->
      <q-banner v-if="store.error" class="text-white bg-negative" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" :label="$t('shop_admin.dismiss')" @click="store.clearError()" />
        </template>
      </q-banner>

      <!-- Summary Stats Banner -->
      <div v-if="!isLoading" class="row q-col-gutter-md">
        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="stat-card">
            <q-card-section class="q-pa-sm row items-center no-wrap">
              <q-avatar icon="ph ph-users-three" color="primary-soft" text-color="primary" size="42px" class="q-mr-md" />
              <div>
                <div class="text-caption text-grey-7">Total Customer Groups</div>
                <div class="text-h6 text-weight-bold">{{ store.customerGroups.length }}</div>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="stat-card">
            <q-card-section class="q-pa-sm row items-center no-wrap">
              <q-avatar icon="ph ph-check-circle" color="positive-soft" text-color="positive" size="42px" class="q-mr-md" />
              <div>
                <div class="text-caption text-grey-7">Access Granted</div>
                <div class="text-h6 text-weight-bold text-positive">{{ grantedCount }}</div>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="stat-card">
            <q-card-section class="q-pa-sm row items-center no-wrap">
              <q-avatar icon="ph ph-x-circle" color="grey-3" text-color="grey-7" size="42px" class="q-mr-md" />
              <div>
                <div class="text-caption text-grey-7">Access Denied</div>
                <div class="text-h6 text-weight-bold text-grey-7">{{ store.customerGroups.length - grantedCount }}</div>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="stat-card">
            <q-card-section class="q-pa-sm row items-center no-wrap">
              <q-avatar icon="ph ph-credit-card" color="warning-soft" text-color="warning" size="42px" class="q-mr-md" />
              <div>
                <div class="text-caption text-grey-7">Credit Limits Active</div>
                <div class="text-h6 text-weight-bold text-warning">{{ creditLimitCount }}</div>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <!-- Loading State -->
      <q-card v-if="isLoading" flat bordered>
        <q-card-section class="text-center q-pa-xl text-grey-7">
          <q-spinner size="36px" color="primary" class="q-mr-sm" />
          <div>{{ $t('shop_admin.loading_access') }}</div>
        </q-card-section>
      </q-card>

      <!-- Clean Access Matrix Table -->
      <q-card v-else flat bordered class="overflow-hidden">
        <!-- Controls Toolbar -->
        <q-card-section class="row items-center justify-between q-col-gutter-md border-bottom bg-grey-1">
          <!-- Left: Search & Filter -->
          <div class="col-12 col-sm-auto row items-center q-gutter-sm">
            <q-input
              v-model="searchQuery"
              outlined
              dense
              placeholder="Search group name..."
              class="bg-white"
              style="min-width: 220px;"
              clearable
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="18px" />
              </template>
            </q-input>

            <q-select
              v-model="statusFilter"
              outlined
              dense
              emit-value
              map-options
              :options="[
                { label: 'All Statuses', value: 'all' },
                { label: 'Granted Only', value: 'granted' },
                { label: 'Denied Only', value: 'denied' },
              ]"
              class="bg-white"
              style="min-width: 150px;"
            />
          </div>

          <!-- Right: Legend -->
          <div class="col-12 col-sm-auto row items-center q-gutter-x-sm text-caption text-grey-7">
            <span class="row items-center"><q-badge rounded color="positive" class="q-mr-xs" /> Access Granted</span>
            <span class="row items-center"><q-badge rounded color="grey-5" class="q-mr-xs" /> Access Revoked</span>
          </div>
        </q-card-section>

        <!-- Minimalist Matrix Table View -->
        <div class="treasury-table-wrap">
          <q-table
            flat
            :bordered="false"
            square
            dense
            :rows="filteredGroups"
            :columns="matrixColumns"
            row-key="id"
            :pagination="{ rowsPerPage: 0 }"
            hide-pagination
            class="matrix-table"
          >
            <!-- Group Name Column -->
            <template #body-cell-group="props">
              <q-td :props="props">
                <div class="row items-center no-wrap">
                  <div class="text-weight-bold text-body2 text-grey-9 q-mr-sm">
                    {{ props.row.name }}
                  </div>
                  <q-badge
                    :color="getAccessRow(props.row.id)?.status ? 'positive' : 'grey-5'"
                    class="q-px-xs text-caption"
                  >
                    {{
                      getAccessRow(props.row.id)?.status
                        ? $t('shop_admin.access_granted')
                        : $t('shop_admin.no_access')
                    }}
                  </q-badge>
                </div>
              </q-td>
            </template>

            <!-- Active Capabilities Summary Badges Column -->
            <template #body-cell-capabilities="props">
              <q-td :props="props">
                <div v-if="getAccessRow(props.row.id)?.status" class="row items-center q-gutter-xs">
                  <q-badge
                    v-for="badge in getCapabilityBadges(getAccessRow(props.row.id))"
                    :key="badge.label"
                    outline
                    :color="badge.color"
                    class="q-px-xs text-caption text-weight-medium"
                  >
                    {{ badge.label }}
                  </q-badge>
                </div>
                <span v-else class="text-caption text-grey-5">Access Disabled</span>
              </q-td>
            </template>

            <!-- Actions Column -->
            <template #body-cell-actions="props">
              <q-td :props="props" class="text-right">
                <div class="row items-center justify-end q-gutter-x-xs">
                  <!-- Quick Presets Dropdown -->
                  <q-btn-dropdown
                    flat
                    dense
                    size="sm"
                    color="grey-8"
                    icon="ph ph-lightning"
                    label="Preset"
                  >
                    <q-list style="min-width: 180px;">
                      <q-item-label header class="text-caption text-weight-bold">
                        Apply Quick Preset
                      </q-item-label>
                      <q-item clickable v-close-popup @click="applyPresetToGroup(props.row.id, 'full')">
                        <q-item-section avatar>
                          <q-icon name="ph ph-check-circle" color="positive" />
                        </q-item-section>
                        <q-item-section>
                          <q-item-label class="text-weight-medium">Full Access</q-item-label>
                          <q-item-label caption>Enable all capabilities</q-item-label>
                        </q-item-section>
                      </q-item>

                      <q-item clickable v-close-popup @click="applyPresetToGroup(props.row.id, 'standard')">
                        <q-item-section avatar>
                          <q-icon name="ph ph-shopping-bag" color="primary" />
                        </q-item-section>
                        <q-item-section>
                          <q-item-label class="text-weight-medium">Standard Buyer</q-item-label>
                          <q-item-label caption>Browse, Price, Cart, Order</q-item-label>
                        </q-item-section>
                      </q-item>

                      <q-item clickable v-close-popup @click="applyPresetToGroup(props.row.id, 'view_only')">
                        <q-item-section avatar>
                          <q-icon name="ph ph-eye" color="info" />
                        </q-item-section>
                        <q-item-section>
                          <q-item-label class="text-weight-medium">View & Price Only</q-item-label>
                          <q-item-label caption>Browse catalog; ordering disabled</q-item-label>
                        </q-item-section>
                      </q-item>

                      <q-separator />

                      <q-item clickable v-close-popup @click="applyPresetToGroup(props.row.id, 'revoke')">
                        <q-item-section avatar>
                          <q-icon name="ph ph-prohibit" color="negative" />
                        </q-item-section>
                        <q-item-section>
                          <q-item-label class="text-weight-medium text-negative">Revoke Access</q-item-label>
                          <q-item-label caption>Block all shop access</q-item-label>
                        </q-item-section>
                      </q-item>
                    </q-list>
                  </q-btn-dropdown>

                  <!-- Primary Configure Access Button -->
                  <q-btn
                    unelevated
                    dense
                    size="sm"
                    color="primary"
                    icon="ph ph-gear-six"
                    label="Configure Access"
                    class="q-px-sm"
                    @click="openEditDrawer(props.row.id)"
                  />
                </div>
              </q-td>
            </template>
          </q-table>
        </div>
      </q-card>

      <!-- Slide-Over Drawer: Configure Group Access -->
      <q-dialog v-model="drawerOpen" position="right" maximized transition-show="slide-left" transition-hide="slide-right">
        <q-card class="column no-wrap" style="width: 500px; max-width: 100vw;">
          <!-- Drawer Header -->
          <q-card-section class="row items-center justify-between bg-primary text-white q-py-md">
            <div>
              <div class="text-overline opacity-80">Configure Group Access</div>
              <div class="text-h6 text-weight-bold">{{ activeGroupName }}</div>
            </div>
            <q-btn flat round icon="ph ph-x" color="white" v-close-popup />
          </q-card-section>

          <!-- Drawer Content with All Capability Toggles, Master Access, Price Tier & Credit Limit -->
          <q-card-section class="col scroll q-gutter-y-lg q-pa-md">
            <!-- Master Status Section -->
            <q-card flat bordered class="bg-grey-1">
              <q-card-section class="row items-center justify-between">
                <div>
                  <div class="text-subtitle2 text-weight-bold">Grant Shop Access</div>
                  <div class="text-caption text-grey-7">Master switch for this customer group</div>
                </div>
                <q-toggle
                  v-model="editForm.status"
                  color="positive"
                  @update:model-value="onDrawerStatusToggle"
                />
              </q-card-section>
            </q-card>

            <template v-if="editForm.status">
              <!-- Domain 1: Catalog & Stock Visibility -->
              <div>
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm row items-center">
                  <q-icon name="ph ph-eye" size="18px" color="primary" class="q-mr-xs" />
                  1. Catalog & Stock Visibility
                </div>
                <q-card flat bordered class="q-pa-sm">
                  <div class="q-gutter-y-xs">
                    <q-toggle
                      v-if="shopType !== 'dropship'"
                      v-model="editForm.can_browse"
                      label="Browse Catalog"
                      caption="Allow searching & viewing product catalog"
                      color="primary"
                    />
                    <q-toggle
                      v-model="editForm.can_view_quantity"
                      label="View Stock Quantity"
                      caption="Show available inventory counts to buyers"
                      color="primary"
                    />
                  </div>
                </q-card>
              </div>

              <!-- Domain 2: Wholesale Pricing & Tiers -->
              <div>
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm row items-center">
                  <q-icon name="ph ph-tag" size="18px" color="primary" class="q-mr-xs" />
                  2. Wholesale Pricing & Tiers
                </div>
                <q-card flat bordered class="q-pa-md q-gutter-y-sm">
                  <q-toggle
                    v-model="editForm.see_price"
                    label="See Unit Prices"
                    caption="Display pricing on catalog & detail pages"
                    color="primary"
                  />
                  <q-toggle
                    v-model="editForm.can_set_dropship_price"
                    label="Set Custom Dropship Selling Price"
                    caption="Allow resellers to set customer dropship price"
                    color="primary"
                  />

                  <div class="q-pt-xs">
                    <q-input
                      v-model="editForm.price_tier_code"
                      label="Price Tier Code"
                      outlined
                      dense
                      placeholder="e.g. VIP_GOLD, BULK_TIER_A"
                      hint="Optional tier override code for special pricing"
                    />
                  </div>
                </q-card>
              </div>

              <!-- Domain 3: Purchasing Capabilities -->
              <div>
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm row items-center">
                  <q-icon name="ph ph-shopping-cart" size="18px" color="primary" class="q-mr-xs" />
                  3. Ordering & Cart Capabilities
                </div>
                <q-card flat bordered class="q-pa-sm">
                  <div class="q-gutter-y-xs">
                    <q-toggle
                      v-model="editForm.can_add_to_cart"
                      label="Add to Cart"
                      caption="Enable adding items to shopping cart"
                      color="primary"
                    />
                    <q-toggle
                      v-model="editForm.can_place_order"
                      label="Place Order / Checkout"
                      caption="Enable submitting wholesale orders"
                      color="primary"
                    />
                    <q-toggle
                      v-if="shopType !== 'dropship'"
                      v-model="editForm.can_negotiate"
                      label="Price Negotiation"
                      caption="Allow requesting custom price negotiations"
                      color="primary"
                    />
                  </div>
                </q-card>
              </div>

              <!-- Domain 4: Commercial Credit Limit -->
              <div>
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm row items-center">
                  <q-icon name="ph ph-bank" size="18px" color="primary" class="q-mr-xs" />
                  4. Commercial Credit Limit
                </div>
                <q-card flat bordered class="q-pa-md q-gutter-y-sm">
                  <div class="text-caption text-grey-7">
                    Define maximum unpaid credit order limit for this group. Leave empty for unlimited credit.
                  </div>
                  <div class="row q-col-gutter-sm">
                    <div class="col-12 col-sm-6">
                      <q-input
                        v-model.number="editForm.credit_limit_amount"
                        type="number"
                        step="0.01"
                        label="Credit Limit Amount"
                        outlined
                        dense
                        clearable
                        placeholder="Unlimited"
                      />
                    </div>
                    <div class="col-12 col-sm-6">
                      <q-select
                        v-model="editForm.credit_limit_currency_id"
                        label="Credit Currency"
                        outlined
                        dense
                        emit-value
                        map-options
                        option-value="id"
                        option-label="code"
                        :options="store.currencies"
                        :disable="!editForm.credit_limit_amount"
                      />
                    </div>
                  </div>
                </q-card>
              </div>
            </template>
          </q-card-section>

          <!-- Drawer Footer Actions -->
          <q-card-actions align="right" class="q-pa-md border-top bg-grey-1">
            <q-btn flat label="Cancel" color="grey-7" v-close-popup />
            <q-btn
              unelevated
              label="Save Access Settings"
              color="primary"
              icon="ph ph-floppy-disk"
              :loading="store.saving"
              @click="onDrawerSave"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopPermissionsStore } from '../stores/shopPermissionsStore';
import type { UpsertAccessPayload, ShopCustomerGroupAccess } from '../types';
import { showSuccessNotification } from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const store = useShopPermissionsStore();

const tenantId = computed(() => authStore.tenantId as number);
const shopId = computed(() => Number(route.params.shopId));
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const shopName = ref<string>('');
const shopType = ref<string>('');
const searchQuery = ref<string>('');
const statusFilter = ref<'all' | 'granted' | 'denied'>('all');

const drawerOpen = ref<boolean>(false);
const activeGroupId = ref<number | null>(null);

const editForm = ref<UpsertAccessPayload>({
  shop_id: 0,
  customer_group_id: 0,
  status: false,
  can_browse: false,
  see_price: false,
  can_add_to_cart: false,
  can_place_order: false,
  can_negotiate: false,
  can_view_quantity: false,
  can_set_dropship_price: false,
  price_tier_code: null,
  credit_limit_amount: null,
  credit_limit_currency_id: null,
});

const isLoading = computed(
  () => store.loadingGroups || store.loadingAccess || store.loadingCurrencies,
);

const grantedCount = computed(() => {
  return store.accessOverrides.filter((o) => o.status).length;
});

const creditLimitCount = computed(() => {
  return store.accessOverrides.filter((o) => o.status && !!o.credit_limit_amount).length;
});

const filteredGroups = computed(() => {
  return store.customerGroups.filter((g) => {
    if (searchQuery.value && !g.name.toLowerCase().includes(searchQuery.value.toLowerCase())) {
      return false;
    }
    const row = getAccessRow(g.id);
    const isGranted = !!row?.status;
    if (statusFilter.value === 'granted' && !isGranted) return false;
    if (statusFilter.value === 'denied' && isGranted) return false;

    return true;
  });
});

const activeGroupName = computed(() => {
  if (!activeGroupId.value) return '';
  return store.customerGroups.find((g) => g.id === activeGroupId.value)?.name ?? '';
});

const matrixColumns = [
  { name: 'group', label: 'Customer Group', align: 'left' as const, field: 'name' },
  { name: 'capabilities', label: 'Enabled Capabilities & Rules', align: 'left' as const, field: 'id' },
  { name: 'actions', label: 'Actions', align: 'right' as const, field: 'id' },
];

const coerceBool = (value: boolean | null | undefined, fallback = false) =>
  value === true ? true : value === false ? false : fallback;

const getAccessRow = (groupId: number): ShopCustomerGroupAccess | undefined => {
  return store.accessOverrides.find((o) => o.customer_group_id === groupId);
};

const formatCreditLimit = (row?: ShopCustomerGroupAccess): string => {
  if (!row || !row.credit_limit_amount) return 'Unlimited';
  const curr = store.currencies.find((c) => c.id === row.credit_limit_currency_id)?.code ?? '';
  return `${Number(row.credit_limit_amount).toLocaleString()} ${curr}`;
};

const getCapabilityBadges = (row?: ShopCustomerGroupAccess) => {
  if (!row || !row.status) return [];
  const badges: Array<{ label: string; color: string }> = [];

  if (row.can_browse !== false) badges.push({ label: 'Browse', color: 'blue-7' });
  if (row.see_price !== false) badges.push({ label: 'See Price', color: 'cyan-8' });
  if (row.can_view_quantity !== false) badges.push({ label: 'Stock Qty', color: 'indigo-6' });

  if (row.can_add_to_cart !== false && row.can_place_order !== false) {
    badges.push({ label: 'Cart & Order', color: 'positive' });
  } else {
    if (row.can_add_to_cart !== false) badges.push({ label: 'Cart Only', color: 'teal-7' });
    if (row.can_place_order !== false) badges.push({ label: 'Order Only', color: 'positive' });
  }

  if (row.can_negotiate) badges.push({ label: 'Negotiate', color: 'deep-purple-6' });
  if (row.can_set_dropship_price) badges.push({ label: 'Dropship Price', color: 'secondary' });

  if (row.price_tier_code) {
    badges.push({ label: `Tier: ${row.price_tier_code}`, color: 'primary' });
  }

  if (row.credit_limit_amount) {
    badges.push({ label: `Credit: ${formatCreditLimit(row)}`, color: 'amber-9' });
  }

  return badges;
};

const applyAccessDefaults = () => {
  editForm.value.can_browse = coerceBool(editForm.value.can_browse, true);
  editForm.value.can_add_to_cart = coerceBool(editForm.value.can_add_to_cart, true);
  editForm.value.can_place_order = coerceBool(editForm.value.can_place_order, true);
  editForm.value.see_price = coerceBool(editForm.value.see_price, true);
  editForm.value.can_view_quantity = coerceBool(editForm.value.can_view_quantity, true);
  editForm.value.can_negotiate = coerceBool(editForm.value.can_negotiate, false);
  editForm.value.can_set_dropship_price = coerceBool(editForm.value.can_set_dropship_price, false);
};

// Quick Preset applier
const applyPresetToGroup = async (
  groupId: number,
  preset: 'full' | 'standard' | 'view_only' | 'revoke',
) => {
  const row = getAccessRow(groupId);
  let payload: UpsertAccessPayload;

  if (preset === 'revoke') {
    payload = {
      shop_id: shopId.value,
      customer_group_id: groupId,
      status: false,
      can_browse: false,
      see_price: false,
      can_add_to_cart: false,
      can_place_order: false,
      can_negotiate: false,
      can_view_quantity: false,
      can_set_dropship_price: false,
      price_tier_code: row?.price_tier_code ?? null,
      credit_limit_amount: row?.credit_limit_amount ? Number(row.credit_limit_amount) : null,
      credit_limit_currency_id: row?.credit_limit_currency_id ?? null,
    };
  } else if (preset === 'view_only') {
    payload = {
      shop_id: shopId.value,
      customer_group_id: groupId,
      status: true,
      can_browse: true,
      see_price: true,
      can_view_quantity: true,
      can_add_to_cart: false,
      can_place_order: false,
      can_negotiate: false,
      can_set_dropship_price: false,
      price_tier_code: row?.price_tier_code ?? null,
      credit_limit_amount: row?.credit_limit_amount ? Number(row.credit_limit_amount) : null,
      credit_limit_currency_id: row?.credit_limit_currency_id ?? null,
    };
  } else if (preset === 'standard') {
    payload = {
      shop_id: shopId.value,
      customer_group_id: groupId,
      status: true,
      can_browse: true,
      see_price: true,
      can_view_quantity: true,
      can_add_to_cart: true,
      can_place_order: true,
      can_negotiate: false,
      can_set_dropship_price: false,
      price_tier_code: row?.price_tier_code ?? null,
      credit_limit_amount: row?.credit_limit_amount ? Number(row.credit_limit_amount) : null,
      credit_limit_currency_id: row?.credit_limit_currency_id ?? null,
    };
  } else {
    // Full
    payload = {
      shop_id: shopId.value,
      customer_group_id: groupId,
      status: true,
      can_browse: true,
      see_price: true,
      can_view_quantity: true,
      can_add_to_cart: true,
      can_place_order: true,
      can_negotiate: shopType.value !== 'dropship',
      can_set_dropship_price: true,
      price_tier_code: row?.price_tier_code ?? null,
      credit_limit_amount: row?.credit_limit_amount ? Number(row.credit_limit_amount) : null,
      credit_limit_currency_id: row?.credit_limit_currency_id ?? null,
    };
  }

  const res = await store.saveAccessOverride(payload);
  if (res.success) {
    showSuccessNotification(`Applied ${preset.replace('_', ' ')} preset to group.`);
  }
};

// Drawer editing logic
const openEditDrawer = (groupId: number) => {
  activeGroupId.value = groupId;
  const row = getAccessRow(groupId);

  editForm.value = {
    shop_id: shopId.value,
    customer_group_id: groupId,
    status: row ? row.status : false,
    can_browse: coerceBool(row?.can_browse, true),
    see_price: coerceBool(row?.see_price, true),
    can_add_to_cart: coerceBool(row?.can_add_to_cart, true),
    can_place_order: coerceBool(row?.can_place_order, true),
    can_negotiate: coerceBool(row?.can_negotiate, false),
    can_view_quantity: coerceBool(row?.can_view_quantity, true),
    can_set_dropship_price: coerceBool(row?.can_set_dropship_price, false),
    price_tier_code: row ? row.price_tier_code : null,
    credit_limit_amount: row
      ? row.credit_limit_amount
        ? Number(row.credit_limit_amount)
        : null
      : null,
    credit_limit_currency_id: row ? row.credit_limit_currency_id : null,
  };

  if (editForm.value.status) {
    applyAccessDefaults();
  }

  drawerOpen.value = true;
};

const onDrawerStatusToggle = (granted: boolean) => {
  if (granted) {
    applyAccessDefaults();
  }
};

const onDrawerSave = async () => {
  if (
    editForm.value.credit_limit_amount === null ||
    editForm.value.credit_limit_amount === undefined ||
    String(editForm.value.credit_limit_amount) === ''
  ) {
    editForm.value.credit_limit_amount = null;
    editForm.value.credit_limit_currency_id = null;
  }

  const res = await store.saveAccessOverride(editForm.value);
  if (res.success) {
    drawerOpen.value = false;
  }
};

const load = async () => {
  if (!tenantId.value || !shopId.value) return;

  const { data: shopData } = await supabase
    .from('shops')
    .select('name, shop_type')
    .eq('id', shopId.value)
    .single();
  if (shopData) {
    shopName.value = shopData.name;
    shopType.value = shopData.shop_type;
  }

  void store.fetchCustomerGroups(tenantId.value);
  void store.fetchAccessOverrides(shopId.value);
  void store.fetchCurrencies();
};

const goBack = () => {
  void router.push({
    name: 'app-shop-shops-page',
    params: { tenantSlug: tenantSlug.value },
  });
};

watch(tenantId, (v) => {
  if (v) void load();
});

onMounted(load);
</script>

<style scoped lang="scss">
.stat-card {
  border-radius: 10px;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
  }
}

.matrix-table {
  :deep(.q-table th) {
    font-weight: 700;
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 0.5px;
    color: var(--bw-theme-muted, #666);
    background-color: #f9fafb;
    padding: 12px 16px;
  }

  :deep(.q-table td) {
    padding: 12px 16px;
  }
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.opacity-80 {
  opacity: 0.8;
}
</style>
