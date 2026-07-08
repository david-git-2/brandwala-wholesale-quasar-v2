<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center q-col-gutter-md">
        <div class="col-auto">
          <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
        </div>
        <div class="col">
          <div class="text-overline">Shops</div>
          <h1 class="text-h5 q-my-none">Shop Access Matrix: {{ shopName }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Grant shop access to customer groups and define granular overrides. Overrides set to
            "Inherit" fallback to the group's default profile.
          </p>
        </div>
      </section>

      <!-- Error banner -->
      <q-banner v-if="store.error" class="text-white bg-negative" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" label="Dismiss" @click="store.clearError()" />
        </template>
      </q-banner>

      <!-- Loading state -->
      <q-card
        v-if="store.loadingGroups || store.loadingAccess || store.loadingCurrencies"
        flat
        bordered
      >
        <q-card-section class="text-center q-pa-xl text-grey-7">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          Loading access settings…
        </q-card-section>
      </q-card>

      <!-- Matrix List -->
      <div v-else class="q-gutter-y-md">
        <q-card v-for="group in store.customerGroups" :key="group.id" flat bordered>
          <q-card-section class="row items-center justify-between q-py-sm bg-grey-1">
            <div class="col">
              <span class="text-subtitle1 text-weight-medium text-grey-9">{{ group.name }}</span>
              <span class="q-ml-md">
                <q-badge :color="getAccessRow(group.id)?.status ? 'positive' : 'grey-5'">
                  {{ getAccessRow(group.id)?.status ? 'Access Granted' : 'No Access' }}
                </q-badge>
              </span>
            </div>
            <div class="col-auto">
              <q-btn
                v-if="!activeGroupId || activeGroupId !== group.id"
                flat
                label="Configure Overrides"
                color="primary"
                icon="settings"
                @click="editGroup(group.id)"
              />
              <q-btn
                v-else
                flat
                label="Collapse"
                color="grey-7"
                icon="expand_less"
                @click="editGroup(null)"
              />
            </div>
          </q-card-section>

          <q-slide-transition>
            <div v-if="activeGroupId === group.id">
              <q-card-section class="q-gutter-y-md q-pt-md">
                <!-- Master Access Toggle -->
                <div class="row items-center q-col-gutter-md">
                  <div class="col-12 col-sm-6">
                    <q-toggle
                      v-model="editForm.status"
                      label="Grant Catalog Access"
                      caption="Master switch for this shop and group."
                      color="primary"
                    />
                  </div>
                </div>

                <div v-if="editForm.status" class="q-gutter-y-md q-mt-sm">
                  <div class="text-subtitle2 text-grey-8">Granular Overrides</div>

                  <div class="row q-col-gutter-md">
                    <!-- Browse Override -->
                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_browse"
                        label="Browse Shop Catalog"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="inheritOptions"
                      />
                    </div>

                    <!-- See Price Override -->
                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.see_price"
                        label="See Unit Prices"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="inheritOptions"
                      />
                    </div>

                    <!-- View Quantity Override -->
                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_view_quantity"
                        label="View Stock Quantities"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="inheritOptions"
                      />
                    </div>

                    <!-- Add to Cart Override -->
                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_add_to_cart"
                        label="Add to Cart"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="inheritOptions"
                      />
                    </div>

                    <!-- Place Order Override -->
                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_place_order"
                        label="Place / Submit Order"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="inheritOptions"
                      />
                    </div>

                    <!-- Negotiate Override -->
                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_negotiate"
                        label="Can Negotiate"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="inheritOptions"
                      />
                    </div>

                    <!-- Dropship Price Override -->
                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_set_dropship_price"
                        label="Set Dropship Price"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="inheritOptions"
                      />
                    </div>

                    <!-- Price Tier Code -->
                    <div class="col-12 col-sm-4">
                      <q-input
                        v-model="editForm.price_tier_code"
                        label="Price Tier Code"
                        outlined
                        dense
                        placeholder="e.g. tier1"
                      />
                    </div>
                  </div>

                  <div class="text-subtitle2 text-grey-8 q-mt-lg">Commercial Credit Limit</div>

                  <div class="row q-col-gutter-md">
                    <!-- Credit Limit Amount -->
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

                    <!-- Credit Limit Currency -->
                    <div class="col-12 col-sm-6">
                      <q-select
                        v-model="editForm.credit_limit_currency_id"
                        label="Credit Limit Currency"
                        outlined
                        dense
                        emit-value
                        map-options
                        option-value="id"
                        option-label="code"
                        :options="store.currencies"
                        :disable="!editForm.credit_limit_amount"
                        :rules="[
                          (val) =>
                            !editForm.credit_limit_amount ||
                            !!val ||
                            'Currency is required when amount is specified',
                        ]"
                      />
                    </div>
                  </div>
                </div>
              </q-card-section>

              <q-card-actions align="right" class="q-pa-md border-top bg-grey-1">
                <q-btn flat label="Cancel" color="grey-7" @click="editGroup(null)" />
                <q-btn
                  unelevated
                  label="Save Group Overrides"
                  color="primary"
                  :loading="store.saving"
                  @click="onSave"
                />
              </q-card-actions>
            </div>
          </q-slide-transition>
        </q-card>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopPermissionsStore } from '../stores/shopPermissionsStore';
import type { UpsertAccessPayload, ShopCustomerGroupAccess } from '../types';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const store = useShopPermissionsStore();

const tenantId = computed(() => authStore.tenantId as number);
const shopId = computed(() => Number(route.params.shopId));
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const shopName = ref<string>('');
const activeGroupId = ref<number | null>(null);

const editForm = ref<UpsertAccessPayload>({
  shop_id: 0,
  customer_group_id: 0,
  status: false,
  can_browse: null,
  see_price: null,
  can_add_to_cart: null,
  can_place_order: null,
  can_negotiate: null,
  can_view_quantity: null,
  can_set_dropship_price: null,
  price_tier_code: null,
  credit_limit_amount: null,
  credit_limit_currency_id: null,
});

const inheritOptions = [
  { label: 'Inherit Default Profile', value: null },
  { label: 'Allow Override', value: true },
  { label: 'Deny Override', value: false },
];

const getAccessRow = (groupId: number): ShopCustomerGroupAccess | undefined => {
  return store.accessOverrides.find((o) => o.customer_group_id === groupId);
};

const editGroup = (groupId: number | null) => {
  activeGroupId.value = groupId;
  if (!groupId) return;

  const row = getAccessRow(groupId);
  editForm.value = {
    shop_id: shopId.value,
    customer_group_id: groupId,
    status: row ? row.status : false,
    can_browse: row ? row.can_browse : null,
    see_price: row ? row.see_price : null,
    can_add_to_cart: row ? row.can_add_to_cart : null,
    can_place_order: row ? row.can_place_order : null,
    can_negotiate: row ? row.can_negotiate : null,
    can_view_quantity: row ? row.can_view_quantity : null,
    can_set_dropship_price: row ? row.can_set_dropship_price : null,
    price_tier_code: row ? row.price_tier_code : null,
    credit_limit_amount: row
      ? row.credit_limit_amount
        ? Number(row.credit_limit_amount)
        : null
      : null,
    credit_limit_currency_id: row ? row.credit_limit_currency_id : null,
  };
};

const load = async () => {
  if (!tenantId.value || !shopId.value) return;

  // Fetch shop details for header
  const { data: shopData } = await supabase
    .from('shops')
    .select('name')
    .eq('id', shopId.value)
    .single();
  if (shopData) {
    shopName.value = shopData.name;
  }

  void store.fetchCustomerGroups(tenantId.value);
  void store.fetchAccessOverrides(shopId.value);
  void store.fetchCurrencies();
};

const onSave = async () => {
  // Clear currency if amount is null to satisfy constraint
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
    editGroup(null);
  }
};

const goBack = () => {
  void router.push({
    name: 'app-shop-shops-page',
    params: { tenantSlug: tenantSlug.value },
  });
};

onMounted(load);
</script>
