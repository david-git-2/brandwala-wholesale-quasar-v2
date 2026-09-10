<template>
  <component :is="embedded ? 'div' : 'q-page'" :class="embedded ? 'access-embedded' : 'bw-page'">
    <section :class="embedded ? 'access-section column no-wrap full-height' : 'bw-page__stack'">
      <section v-if="!embedded" class="row items-center q-col-gutter-md q-mb-md">
        <div class="col-12 row items-center no-wrap">
          <q-btn
            flat
            round
            icon="ph ph-arrow-left"
            color="grey-7"
            class="q-mr-sm"
            :aria-label="$t('shop_admin.cancel')"
            @click="goBack"
          />
          <div>
            <div class="text-overline text-primary">{{ $t('navigation.shops') }}</div>
            <h1 class="text-h5 text-weight-bold q-my-none">
              {{ $t('shop_admin.access_matrix_title', { name: shopName }) }}
            </h1>
            <p class="text-caption text-grey-7 q-mb-none">
              {{ $t('shop_admin.access_matrix_subtitle') }}
            </p>
          </div>
        </div>
      </section>

      <q-banner v-if="store.error" class="text-white bg-negative q-mb-md" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" :label="$t('shop_admin.dismiss')" @click="store.clearError()" />
        </template>
      </q-banner>

      <div :class="embedded ? 'access-container column no-wrap col' : 'column no-wrap'">
        <div class="access-toolbar row items-center no-wrap q-gutter-sm q-mb-md">
          <q-input
            v-model="searchInput"
            outlined
            dense
            :placeholder="$t('shop_admin.access_search_placeholder')"
            class="search-box col"
            data-test="access-search"
            @keyup.enter.prevent="applySearch"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-5" />
            </template>
            <template v-if="searchInput || appliedSearch" #append>
              <q-icon
                name="ph ph-x"
                size="16px"
                class="cursor-pointer text-grey-5"
                @click="clearSearch"
              />
            </template>
          </q-input>
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-clockwise"
            color="grey-7"
            class="col-auto"
            :loading="isLoading"
            @click="reload"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
          <q-btn
            v-if="canAdministerCustomerGroup"
            flat
            no-caps
            dense
            icon="ph ph-plus"
            color="grey-8"
            :label="$t('shop_admin.access_create_group')"
            class="col-auto"
            data-test="access-create-group-btn"
            @click="openCreateDialog"
          />
          <q-btn
            unelevated
            color="primary"
            no-caps
            icon="ph ph-user-plus"
            :label="$t('shop_admin.access_add_group')"
            :disable="availableGroups.length === 0"
            class="action-btn text-weight-medium col-auto"
            data-test="access-add-btn"
            @click="openAddDialog"
          >
            <q-tooltip v-if="availableGroups.length === 0">
              {{ $t('shop_admin.access_no_groups_to_add') }}
            </q-tooltip>
          </q-btn>
        </div>

        <div
          v-if="grantedGroups.length === 0 && !isLoading"
          class="column items-center justify-center q-pa-xl text-center col"
        >
          <q-avatar size="56px" color="grey-3" text-color="grey-9" class="q-mb-md">
            <q-icon name="ph ph-users-three" size="28px" />
          </q-avatar>
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">
            {{
              appliedSearch
                ? $t('shop_admin.access_no_search_results')
                : $t('shop_admin.access_no_granted')
            }}
          </div>
          <p
            v-if="!appliedSearch && canAdministerCustomerGroup"
            class="text-caption text-grey-6 q-mb-md"
            style="max-width: 380px"
          >
            {{ $t('shop_admin.access_no_granted_hint') }}
          </p>
          <p
            v-else-if="!appliedSearch"
            class="text-caption text-grey-6 q-mb-md"
            style="max-width: 380px"
          >
            Customer groups are created on the parent tenant. Once they exist, add them to this shop here.
          </p>
          <div v-if="!appliedSearch" class="row items-center justify-center q-gutter-sm">
            <q-btn
              v-if="availableGroups.length > 0"
              unelevated
              color="primary"
              no-caps
              icon="ph ph-user-plus"
              :label="$t('shop_admin.access_add_group')"
              class="action-btn text-weight-bold"
              data-test="access-add-btn"
              @click="openAddDialog"
            />
            <q-btn
              v-if="canAdministerCustomerGroup"
              :flat="availableGroups.length > 0"
              :unelevated="availableGroups.length === 0"
              :color="availableGroups.length === 0 ? 'primary' : 'grey-8'"
              no-caps
              icon="ph ph-plus"
              :label="
                availableGroups.length === 0
                  ? $t('shop_admin.access_create_group_first')
                  : $t('shop_admin.access_create_group')
              "
              class="action-btn text-weight-bold"
              data-test="access-create-group-btn"
              @click="openCreateDialog"
            />
          </div>
        </div>

        <div v-else class="treasury-table-wrap col">
          <q-table
            flat
            :bordered="false"
            square
            dense
            :rows="grantedGroups"
            :columns="matrixColumns"
            row-key="id"
            :pagination="{ rowsPerPage: 0 }"
            hide-pagination
            :loading="isLoading"
            class="access-table col"
          >
            <template #body-cell-group="props">
              <q-td :props="props">
                <div class="row items-center no-wrap">
                  <q-avatar
                    size="32px"
                    class="q-mr-sm group-avatar flex-shrink-0"
                    :style="{
                      backgroundColor: props.row.accent_color || '#e2e8f0',
                      color: props.row.accent_color ? '#fff' : '#475569',
                    }"
                  >
                    {{ getInitials(props.row.name) }}
                  </q-avatar>
                  <div class="two-line ellipsis">
                    <div class="text-weight-medium text-grey-9 ellipsis">{{ props.row.name }}</div>
                  </div>
                </div>
              </q-td>
            </template>

            <template #body-cell-status="props">
              <q-td :props="props">
                <span
                  class="status-chip"
                  :class="props.row.is_active !== false ? 'status-chip--active' : 'status-chip--inactive'"
                >
                  {{
                    props.row.is_active !== false
                      ? $t('shop_admin.active')
                      : $t('shop_admin.inactive')
                  }}
                </span>
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props" class="text-right">
                <div class="row items-center justify-end no-wrap q-gutter-x-xs">
                  <q-btn
                    flat
                    dense
                    no-caps
                    size="sm"
                    color="primary"
                    icon="ph ph-users"
                    :label="$t('shop_admin.members')"
                    data-test="access-members-btn"
                    @click="openGroupDetails(props.row)"
                  />
                  <q-btn
                    flat
                    dense
                    no-caps
                    size="sm"
                    color="grey-8"
                    icon="ph ph-gear"
                    :label="$t('shop_admin.configure')"
                    data-test="access-configure-btn"
                    @click="openEditDrawer(props.row.id)"
                  />
                  <q-btn
                    flat
                    dense
                    round
                    size="sm"
                    color="negative"
                    icon="ph ph-trash"
                    :loading="deletingGroupId === props.row.id"
                    :aria-label="$t('shop_admin.access_delete_group')"
                    data-test="access-delete-group-btn"
                    @click="deleteGroup(props.row)"
                  />
                </div>
              </q-td>
            </template>
          </q-table>
        </div>
      </div>

      <q-dialog v-model="addDialogOpen" persistent>
        <q-card style="min-width: 360px; max-width: 480px">
          <q-card-section class="row items-center q-pb-none">
            <div class="text-h6">{{ $t('shop_admin.access_add_dialog_title') }}</div>
            <q-space />
            <q-btn icon="ph ph-x" flat round dense v-close-popup />
          </q-card-section>
          <q-card-section class="q-gutter-md">
            <q-select
              v-model="selectedGroupId"
              outlined
              dense
              emit-value
              map-options
              :options="availableGroupOptions"
              :label="$t('shop_admin.access_pick_group')"
              :hint="$t('shop_admin.access_pick_group_hint')"
              :disable="availableGroups.length === 0"
              data-test="access-group-select"
            />
            <div v-if="availableGroups.length === 0" class="text-caption text-grey-7">
              {{ $t('shop_admin.access_no_groups_to_add') }}
            </div>
          </q-card-section>
          <q-card-actions align="right" class="q-pa-md">
            <q-btn
              v-if="canAdministerCustomerGroup"
              flat
              no-caps
              :label="$t('shop_admin.access_create_group_first')"
              @click="switchAddToCreate"
            />
            <q-space />
            <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
            <q-btn
              color="primary"
              unelevated
              no-caps
              :label="$t('shop_admin.access_add_group')"
              :loading="store.saving"
              :disable="!selectedGroupId"
              data-test="access-add-save"
              @click="addSelectedGroup"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <q-dialog v-model="createDialogOpen" persistent>
        <q-card style="min-width: 400px; max-width: 520px">
          <q-card-section class="row items-center q-pb-none">
            <div class="text-h6">{{ $t('shop_admin.access_create_dialog_title') }}</div>
            <q-space />
            <q-btn icon="ph ph-x" flat round dense v-close-popup />
          </q-card-section>
          <q-form @submit.prevent="createThenGrant">
            <q-card-section class="q-gutter-md">
              <p class="text-caption text-grey-7 q-mb-none">
                {{ $t('shop_admin.access_create_then_add_hint') }}
              </p>
              <q-input
                v-model="createForm.name"
                :label="$t('shop_admin.group_name') + ' *'"
                outlined
                dense
                :rules="[(val) => !!val?.trim() || $t('shop_admin.access_group_name_required')]"
                data-test="access-create-name"
              />
              <div>
                <div class="text-caption text-grey-7 q-mb-xs">{{ $t('shop_admin.accent_color') }}</div>
                <div class="row items-center q-gutter-xs">
                  <div
                    v-for="color in presetColors"
                    :key="color"
                    class="cursor-pointer preset-swatch"
                    :class="{ 'preset-swatch--active': createForm.accentColor === color }"
                    :style="{ backgroundColor: color }"
                    @click="createForm.accentColor = color"
                  />
                </div>
              </div>
              <q-input
                v-model="createForm.adminName"
                :label="$t('shop_admin.access_admin_name') + ' *'"
                outlined
                dense
                :rules="[(val) => !!val?.trim() || $t('shop_admin.access_admin_name_required')]"
              />
              <q-input
                v-model="createForm.adminEmail"
                :label="$t('shop_admin.access_admin_email') + ' *'"
                type="email"
                outlined
                dense
                :rules="[
                  (val) => !!val?.trim() || $t('shop_admin.access_admin_email_required'),
                  (val) => isEmailValid(val) || $t('shop_admin.access_admin_email_invalid'),
                ]"
              />
            </q-card-section>
            <q-card-actions align="right" class="q-pa-md">
              <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
              <q-btn
                color="primary"
                unelevated
                no-caps
                type="submit"
                :label="$t('shop_admin.access_create_and_add')"
                :loading="isCreating"
                :disable="!isCreateFormValid"
                data-test="access-create-save"
              />
            </q-card-actions>
          </q-form>
        </q-card>
      </q-dialog>

      <q-dialog
        v-model="drawerOpen"
        position="right"
        maximized
        transition-show="slide-left"
        transition-hide="slide-right"
      >
        <q-card class="column no-wrap" style="width: 500px; max-width: 100vw">
          <q-card-section class="row items-center justify-between bg-primary text-white q-py-md">
            <div>
              <div class="text-overline opacity-80">{{ $t('shop_admin.configure') }}</div>
              <div class="text-h6 text-weight-bold">{{ activeGroupName }}</div>
            </div>
            <q-btn flat round icon="ph ph-x" color="white" v-close-popup />
          </q-card-section>

          <q-card-section class="col scroll q-gutter-y-lg q-pa-md">
            <div>
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm row items-center">
                <q-icon name="ph ph-eye" size="18px" color="primary" class="q-mr-xs" />
                {{ $t('shop_admin.access_domain_catalog') }}
              </div>
              <q-card flat bordered class="q-pa-sm">
                <div class="q-gutter-y-xs">
                  <q-toggle
                    v-if="shopType !== 'dropship'"
                    v-model="editForm.can_browse"
                    :label="$t('shop_admin.browse_catalog')"
                    color="primary"
                  />
                  <q-toggle
                    v-if="shopType !== 'vendor_catalog'"
                    v-model="editForm.can_view_quantity"
                    :label="$t('shop_admin.view_stock_qty')"
                    color="primary"
                  />
                </div>
              </q-card>
            </div>

            <div>
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm row items-center">
                <q-icon name="ph ph-tag" size="18px" color="primary" class="q-mr-xs" />
                {{ $t('shop_admin.access_domain_pricing') }}
              </div>
              <q-card flat bordered class="q-pa-md q-gutter-y-sm">
                <q-toggle
                  v-if="showPurchasePriceToggle"
                  v-model="editForm.can_see_buy_price"
                  :label="
                    shopType === 'vendor_catalog'
                      ? $t('shop_admin.can_see_catalog_price')
                      : $t('shop_admin.can_see_buy_price')
                  "
                  color="primary"
                />
                <q-toggle
                  v-if="showSellPriceToggle"
                  v-model="editForm.can_see_sell_price"
                  :label="$t('shop_admin.can_see_sell_price')"
                  color="primary"
                />
                <q-toggle
                  v-if="showResellMinimumToggle"
                  v-model="editForm.can_see_resell_minimum_price"
                  :label="$t('shop_admin.can_see_resell_minimum_price')"
                  color="primary"
                />
                <q-toggle
                  v-if="shopType === 'dropship'"
                  v-model="editForm.can_set_dropship_price"
                  :label="$t('shop_admin.set_dropship_price')"
                  color="primary"
                />
                <q-input
                  v-if="shopType !== 'vendor_catalog'"
                  v-model="editForm.price_tier_code"
                  :label="$t('shop_admin.price_tier_code')"
                  outlined
                  dense
                  :placeholder="$t('shop_admin.price_tier_placeholder')"
                />
              </q-card>
            </div>

            <div>
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm row items-center">
                <q-icon name="ph ph-shopping-cart" size="18px" color="primary" class="q-mr-xs" />
                {{ $t('shop_admin.access_domain_ordering') }}
              </div>
              <q-card flat bordered class="q-pa-sm">
                <div class="q-gutter-y-xs">
                  <q-toggle
                    v-model="editForm.can_add_to_cart"
                    :label="$t('shop_admin.add_to_cart')"
                    color="primary"
                  />
                  <q-toggle
                    v-model="editForm.can_place_order"
                    :label="$t('shop_admin.place_order')"
                    color="primary"
                  />
                  <q-toggle
                    v-if="shopType !== 'dropship'"
                    v-model="editForm.can_negotiate"
                    :label="$t('shop_admin.negotiate')"
                    color="primary"
                  />
                </div>
              </q-card>
            </div>

            <div>
              <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm row items-center">
                <q-icon name="ph ph-bank" size="18px" color="primary" class="q-mr-xs" />
                {{ $t('shop_admin.commercial_credit_limit') }}
              </div>
              <q-card flat bordered class="q-pa-md q-gutter-y-sm">
                <div class="text-caption text-grey-7">
                  {{ $t('shop_admin.credit_limit_hint') }}
                </div>
                <div class="row q-col-gutter-sm">
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="editForm.credit_limit_amount"
                      type="number"
                      step="0.01"
                      :label="$t('shop_admin.credit_amount')"
                      outlined
                      dense
                      clearable
                    />
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="editForm.credit_limit_currency_id"
                      :label="$t('shop_admin.credit_currency')"
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
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md border-top">
            <q-btn flat :label="$t('shop_admin.cancel')" color="grey-7" v-close-popup />
            <q-btn
              unelevated
              :label="$t('shop_admin.save')"
              color="primary"
              icon="ph ph-floppy-disk"
              :loading="store.saving"
              @click="onDrawerSave"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <CustomerGroupDetailsDrawer
        v-model="groupDetailsOpen"
        :group="selectedDetailsGroup"
      />
    </section>
  </component>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerGroupMutations } from 'src/modules/tenant/composables/useCustomerGroupMutations';
import type { CustomerGroupCreateInput } from 'src/modules/tenant/types';
import { useShopPermissionsStore } from '../stores/shopPermissionsStore';
import type { UpsertAccessPayload, ShopCustomerGroupAccess, Shop } from '../types';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import CustomerGroupDetailsDrawer from '../components/CustomerGroupDetailsDrawer.vue';
import { useCanAdministerCustomerGroup } from 'src/modules/customer/composables/useCanAdministerCustomerGroup';

const props = withDefaults(defineProps<{ embedded?: boolean; shop?: Shop | null }>(), {
  embedded: false,
  shop: null,
});

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const authStore = useAuthStore();
const canAdministerCustomerGroup = useCanAdministerCustomerGroup();
const store = useShopPermissionsStore();
const { createGroupMutation, deleteGroupMutation } = useCustomerGroupMutations();

const tenantId = computed(() => authStore.tenantId as number);
const shopId = computed(() => Number(route.params.shopId));
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const shopName = ref('');
const shopType = ref<Shop['shop_type'] | ''>('');
const searchInput = ref('');
const appliedSearch = ref('');
const deletingGroupId = ref<number | null>(null);

const showPurchasePriceToggle = computed(
  () => shopType.value === 'vendor_catalog' || shopType.value === 'dropship',
);
const showSellPriceToggle = computed(
  () => shopType.value === 'fixed_price' || shopType.value === 'dropship',
);
const showResellMinimumToggle = computed(() => shopType.value === 'dropship');

const addDialogOpen = ref(false);
const createDialogOpen = ref(false);
const selectedGroupId = ref<number | null>(null);
const drawerOpen = ref(false);
const activeGroupId = ref<number | null>(null);
const groupDetailsOpen = ref(false);
const selectedDetailsGroup = ref<{
  id: number;
  name: string;
  accent_color: string | null;
} | null>(null);

const createForm = reactive({
  name: '',
  accentColor: '#B45F34',
  adminName: '',
  adminEmail: '',
});

const presetColors = [
  '#B45F34',
  '#2563EB',
  '#059669',
  '#D97706',
  '#7C3AED',
  '#DB2777',
  '#4B5563',
  '#000000',
];

const editForm = ref<UpsertAccessPayload>({
  shop_id: 0,
  customer_group_id: 0,
  status: true,
  can_browse: true,
  can_see_buy_price: true,
  can_see_sell_price: true,
  can_see_resell_minimum_price: true,
  can_add_to_cart: true,
  can_place_order: true,
  can_negotiate: false,
  can_view_quantity: true,
  can_set_dropship_price: false,
  price_tier_code: null,
  credit_limit_amount: null,
  credit_limit_currency_id: null,
});

const isLoading = computed(
  () => store.loadingGroups || store.loadingAccess || store.loadingCurrencies,
);

const isCreating = computed(() => createGroupMutation.isPending.value || store.saving);

const isEmailValid = (email: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((email ?? '').trim());

const isCreateFormValid = computed(
  () =>
    !!createForm.name.trim() &&
    !!createForm.adminName.trim() &&
    !!createForm.adminEmail.trim() &&
    isEmailValid(createForm.adminEmail),
);

const getAccessRow = (groupId: number): ShopCustomerGroupAccess | undefined =>
  store.accessOverrides.find((o) => o.customer_group_id === groupId);

const grantedGroups = computed(() =>
  store.customerGroups.filter((g) => {
    if (!getAccessRow(g.id)?.status) return false;
    if (appliedSearch.value && !g.name.toLowerCase().includes(appliedSearch.value.toLowerCase())) {
      return false;
    }
    return true;
  }),
);

const availableGroups = computed(() =>
  store.customerGroups.filter((g) => g.is_active !== false && !getAccessRow(g.id)?.status),
);

const availableGroupOptions = computed(() =>
  availableGroups.value.map((g) => ({ label: g.name, value: g.id })),
);

const activeGroupName = computed(() => {
  if (!activeGroupId.value) return '';
  return store.customerGroups.find((g) => g.id === activeGroupId.value)?.name ?? '';
});

const matrixColumns = computed(() => [
  { name: 'group', label: t('shop_admin.access_col_group'), align: 'left' as const, field: 'name' },
  { name: 'status', label: t('shop_admin.status'), align: 'left' as const, field: 'is_active' },
  { name: 'actions', label: t('shop_admin.actions'), align: 'right' as const, field: 'id' },
]);

const applySearch = () => {
  appliedSearch.value = searchInput.value.trim();
};

const clearSearch = () => {
  searchInput.value = '';
  appliedSearch.value = '';
};

const reload = () => {
  void load();
};

const getInitials = (name?: string | null) => {
  if (!name) return 'G';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'G';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'G';
};

const coerceBool = (value: boolean | null | undefined, fallback = false) =>
  value === true ? true : value === false ? false : fallback;

const standardGrantPayload = (groupId: number): UpsertAccessPayload => {
  const row = getAccessRow(groupId);
  const isCatalog = shopType.value === 'vendor_catalog';
  const isFixed = shopType.value === 'fixed_price';
  const isDropship = shopType.value === 'dropship';
  return {
    shop_id: shopId.value,
    customer_group_id: groupId,
    status: true,
    can_browse: true,
    can_see_buy_price: isCatalog || isDropship,
    can_see_sell_price: isCatalog || isFixed || isDropship,
    can_see_resell_minimum_price: isDropship,
    can_view_quantity: true,
    can_add_to_cart: true,
    can_place_order: true,
    can_negotiate: false,
    can_set_dropship_price: false,
    price_tier_code: row?.price_tier_code ?? null,
    credit_limit_amount: row?.credit_limit_amount ? Number(row.credit_limit_amount) : null,
    credit_limit_currency_id: row?.credit_limit_currency_id ?? null,
  };
};

const normalizePricePermissionsForShopType = (form: UpsertAccessPayload) => {
  if (shopType.value === 'vendor_catalog') {
    form.can_see_resell_minimum_price = false;
  }
  if (shopType.value === 'fixed_price') {
    form.can_see_buy_price = false;
    form.can_see_resell_minimum_price = false;
  }
  if (shopType.value !== 'dropship') {
    form.can_see_resell_minimum_price = false;
    form.can_set_dropship_price = false;
  }
};

const openAddDialog = () => {
  selectedGroupId.value = availableGroups.value[0]?.id ?? null;
  addDialogOpen.value = true;
};

const openCreateDialog = () => {
  createForm.name = '';
  createForm.accentColor = '#B45F34';
  createForm.adminName = '';
  createForm.adminEmail = '';
  createDialogOpen.value = true;
};

const switchAddToCreate = () => {
  addDialogOpen.value = false;
  openCreateDialog();
};

const addSelectedGroup = async () => {
  if (!selectedGroupId.value) return;
  const res = await store.saveAccessOverride(standardGrantPayload(selectedGroupId.value));
  if (res.success) {
    addDialogOpen.value = false;
    selectedGroupId.value = null;
  }
};

const createThenGrant = async () => {
  if (!tenantId.value || !isCreateFormValid.value) return;
  try {
    const group = await createGroupMutation.mutateAsync({
      tenant_id: tenantId.value,
      name: createForm.name.trim(),
      accent_color: createForm.accentColor || null,
      is_active: true,
      admin_name: createForm.adminName.trim(),
      admin_email: createForm.adminEmail.trim().toLowerCase(),
    } as CustomerGroupCreateInput & { admin_name: string; admin_email: string });

    await store.fetchCustomerGroups(tenantId.value);
    const res = await store.saveAccessOverride(standardGrantPayload(group.id));
    if (res.success) {
      createDialogOpen.value = false;
    }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : t('shop_admin.access_create_failed');
    showErrorNotification(message);
  }
};

const deleteGroup = async (group: { id: number; name: string }) => {
  const confirmed = await requestConfirmation(
    t('shop_admin.access_delete_group_confirm', { name: group.name }),
    t('shop_admin.access_delete_group'),
    t('shop_admin.delete'),
  );
  if (!confirmed || !tenantId.value) return;

  deletingGroupId.value = group.id;
  try {
    await deleteGroupMutation.mutateAsync({ id: group.id, tenant_id: tenantId.value });
    if (selectedDetailsGroup.value?.id === group.id) {
      groupDetailsOpen.value = false;
      selectedDetailsGroup.value = null;
    }
    await store.fetchCustomerGroups(tenantId.value);
    showSuccessNotification(t('shop_admin.access_delete_group_success'));
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : t('shop_admin.access_delete_group_failed');
    showErrorNotification(message);
  } finally {
    deletingGroupId.value = null;
  }
};

const openGroupDetails = (group: { id: number; name: string; accent_color: string | null }) => {
  selectedDetailsGroup.value = group;
  groupDetailsOpen.value = true;
};

const openEditDrawer = (groupId: number) => {
  activeGroupId.value = groupId;
  const row = getAccessRow(groupId);

  editForm.value = {
    shop_id: shopId.value,
    customer_group_id: groupId,
    status: true,
    can_browse: coerceBool(row?.can_browse, true),
    can_see_buy_price: coerceBool(row?.can_see_buy_price, true),
    can_see_sell_price: coerceBool(row?.can_see_sell_price, true),
    can_see_resell_minimum_price: coerceBool(row?.can_see_resell_minimum_price, true),
    can_add_to_cart: coerceBool(row?.can_add_to_cart, true),
    can_place_order: coerceBool(row?.can_place_order, true),
    can_negotiate: coerceBool(row?.can_negotiate, false),
    can_view_quantity: coerceBool(row?.can_view_quantity, true),
    can_set_dropship_price: coerceBool(row?.can_set_dropship_price, false),
    price_tier_code: row ? row.price_tier_code : null,
    credit_limit_amount: row?.credit_limit_amount ? Number(row.credit_limit_amount) : null,
    credit_limit_currency_id: row ? row.credit_limit_currency_id : null,
  };

  drawerOpen.value = true;
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

  editForm.value.status = true;
  normalizePricePermissionsForShopType(editForm.value);
  if (shopType.value === 'vendor_catalog') {
    editForm.value.price_tier_code = null;
  }
  const res = await store.saveAccessOverride(editForm.value);
  if (res.success) {
    drawerOpen.value = false;
  }
};

const load = async () => {
  if (!tenantId.value || !shopId.value) return;

  if (props.shop?.name) {
    shopName.value = props.shop.name;
    shopType.value = props.shop.shop_type;
  } else {
    const { data: shopData } = await supabase
      .from('shops')
      .select('name, shop_type')
      .eq('id', shopId.value)
      .single();
    if (shopData) {
      shopName.value = shopData.name;
      shopType.value = shopData.shop_type;
    }
  }

  void store.fetchCustomerGroups(tenantId.value);
  void store.fetchAccessOverrides(shopId.value);
  void store.fetchCurrencies();
};

const goBack = () => {
  void router.push({
    name: 'app-shop-shops-list-page',
    params: { tenantSlug: tenantSlug.value },
  });
};

watch(tenantId, (v) => {
  if (v) void load();
});

onMounted(load);
</script>

<style scoped lang="scss">
.access-embedded {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.access-section,
.access-container {
  height: 100%;
  min-height: 0;
}

.access-toolbar {
  background: transparent;
  flex-shrink: 0;
}

.action-btn {
  border-radius: 8px !important;
}

.search-box {
  min-width: 0;
}

.search-box :deep(.q-field__control) {
  border-radius: 8px;
}

.search-box :deep(.q-field--outlined .q-field__control:before) {
  border: 1px solid #e2e8f0;
}

.search-box :deep(.q-field--outlined .q-field__control:hover:before) {
  border-color: #cbd5e1;
}

.treasury-table-wrap {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.access-table {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: transparent;
}

.access-table :deep(.q-table__container) {
  flex: 1 1 0%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  box-shadow: none;
  background: transparent;
}

.access-table :deep(.q-table__middle) {
  flex: 1 1 0%;
  min-height: 0;
  overflow-y: auto;
}

.access-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #f8fafc;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.05em;
  color: #64748b;
  border-bottom: 1px solid #e2e8f0;
}

.access-table :deep(tbody tr td) {
  padding: 12px 16px;
  vertical-align: middle;
  border-bottom: 1px solid #f1f5f9;
}

.access-table :deep(tbody tr) {
  transition: background-color 0.15s ease-in-out;
}

.access-table :deep(tbody tr:hover) {
  background-color: rgba(241, 245, 249, 0.6);
}

.two-line {
  min-height: 36px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.group-avatar {
  font-size: 12px;
  font-weight: 600;
}

.status-chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 500;
  line-height: 18px;
}

.status-chip--active {
  background: #e6f4ea;
  color: #137333;
}

.status-chip--inactive {
  background: #f1f3f4;
  color: #5f6368;
}

body.body--dark .search-box :deep(.q-field--outlined .q-field__control:before) {
  border-color: #334155;
}

body.body--dark .status-chip--inactive {
  background: #2a2a2a;
  color: #94a3b8;
}

body.body--dark .access-table :deep(thead tr th) {
  background: #242424;
  color: #94a3b8;
  border-color: #2e2e2e;
}

body.body--dark .access-table :deep(tbody tr:hover) {
  background-color: rgba(255, 255, 255, 0.04);
}

.border-top {
  border-top: 1px solid var(--bw-theme-border);
}

.opacity-80 {
  opacity: 0.8;
}

.preset-swatch {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: 2px solid transparent;
}

.preset-swatch--active {
  border-color: var(--q-primary);
}
</style>
