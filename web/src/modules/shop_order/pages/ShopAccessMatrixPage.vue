<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center q-col-gutter-md">
        <div class="col-auto">
          <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
        </div>
        <div class="col">
          <div class="text-overline">{{ $t('navigation.shops') }}</div>
          <h1 class="text-h5 q-my-none">
            {{ $t('shop_admin.access_matrix_title', { name: shopName }) }}
          </h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ $t('shop_admin.access_matrix_subtitle') }}
          </p>
        </div>
      </section>

      <!-- Error banner -->
      <q-banner v-if="store.error" class="text-white bg-negative" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" :label="$t('shop_admin.dismiss')" @click="store.clearError()" />
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
          {{ $t('shop_admin.loading_access') }}
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
                  {{
                    getAccessRow(group.id)?.status
                      ? $t('shop_admin.access_granted')
                      : $t('shop_admin.no_access')
                  }}
                </q-badge>
              </span>
            </div>
            <div class="col-auto">
              <q-btn
                v-if="!activeGroupId || activeGroupId !== group.id"
                flat
                :label="$t('shop_admin.configure')"
                color="primary"
                icon="settings"
                @click="editGroup(group.id)"
              />
              <q-btn
                v-else
                flat
                :label="$t('shop_admin.collapse')"
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
                      :label="$t('shop_admin.grant_catalog_access')"
                      :caption="$t('shop_admin.grant_catalog_caption')"
                      color="primary"
                      @update:model-value="onStatusToggle"
                    />
                  </div>
                </div>

                <div v-if="editForm.status" class="q-gutter-y-md q-mt-sm">
                  <div class="text-subtitle2 text-grey-8">{{ $t('shop_admin.capabilities') }}</div>

                  <div class="row q-col-gutter-md items-center">
                    <div class="col-12 col-sm-4" v-if="shopType !== 'dropship'">
                      <q-toggle
                        v-model="editForm.can_browse"
                        :label="$t('shop_admin.browse_catalog')"
                        color="primary"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-toggle
                        v-model="editForm.see_price"
                        :label="$t('shop_admin.see_prices')"
                        color="primary"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-toggle
                        v-model="editForm.can_view_quantity"
                        :label="$t('shop_admin.view_stock_qty')"
                        color="primary"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-toggle
                        v-model="editForm.can_add_to_cart"
                        :label="$t('shop_admin.add_to_cart')"
                        color="primary"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-toggle
                        v-model="editForm.can_place_order"
                        :label="$t('shop_admin.place_order')"
                        color="primary"
                      />
                    </div>

                    <div class="col-12 col-sm-4" v-if="shopType !== 'dropship'">
                      <q-toggle
                        v-model="editForm.can_negotiate"
                        :label="$t('shop_admin.negotiate')"
                        color="primary"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-toggle
                        v-model="editForm.can_set_dropship_price"
                        :label="$t('shop_admin.set_dropship_price')"
                        color="primary"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-input
                        v-model="editForm.price_tier_code"
                        :label="$t('shop_admin.price_tier_code')"
                        outlined
                        dense
                        :placeholder="$t('shop_admin.price_tier_placeholder')"
                      />
                    </div>
                  </div>

                  <div class="text-subtitle2 text-grey-8 q-mt-lg">
                    {{ $t('shop_admin.commercial_credit_limit') }}
                  </div>
                  <p class="text-caption text-grey-7 q-mb-none">
                    {{ $t('shop_admin.credit_limit_hint') }}
                  </p>

                  <div class="row q-col-gutter-md">
                    <div class="col-12 col-sm-6">
                      <q-input
                        v-model.number="editForm.credit_limit_amount"
                        type="number"
                        step="0.01"
                        :label="$t('shop_admin.credit_amount')"
                        outlined
                        dense
                        clearable
                        :placeholder="$t('shop_admin.unlimited')"
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
                        :rules="[
                          (val) =>
                            !editForm.credit_limit_amount ||
                            !!val ||
                            $t('shop_admin.currency_required'),
                        ]"
                      />
                    </div>
                  </div>
                </div>
              </q-card-section>

              <q-card-actions align="right" class="q-pa-md border-top bg-grey-1">
                <q-btn
                  flat
                  :label="$t('shop_admin.cancel')"
                  color="grey-7"
                  @click="editGroup(null)"
                />
                <q-btn
                  unelevated
                  :label="$t('shop_admin.save')"
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
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopPermissionsStore } from '../stores/shopPermissionsStore';
import type { UpsertAccessPayload, ShopCustomerGroupAccess } from '../types';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const store = useShopPermissionsStore();
const { t } = useI18n();

const tenantId = computed(() => authStore.tenantId as number);
const shopId = computed(() => Number(route.params.shopId));
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const shopName = ref<string>('');
const shopType = ref<string>('');
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

const coerceBool = (value: boolean | null | undefined, fallback = false) =>
  value === true ? true : value === false ? false : fallback;

const applyAccessDefaults = () => {
  editForm.value.can_browse = coerceBool(editForm.value.can_browse, true);
  editForm.value.can_add_to_cart = coerceBool(editForm.value.can_add_to_cart, true);
  editForm.value.can_place_order = coerceBool(editForm.value.can_place_order, true);
  editForm.value.see_price = coerceBool(editForm.value.see_price, false);
  editForm.value.can_view_quantity = coerceBool(editForm.value.can_view_quantity, true);
  editForm.value.can_negotiate = coerceBool(editForm.value.can_negotiate, false);
  editForm.value.can_set_dropship_price = coerceBool(editForm.value.can_set_dropship_price, false);
};

const onStatusToggle = (granted: boolean) => {
  if (granted) {
    applyAccessDefaults();
  }
};

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
    can_browse: coerceBool(row?.can_browse, true),
    see_price: coerceBool(row?.see_price, false),
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

const onSave = async () => {
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

watch(tenantId, (v) => {
  if (v) load();
});

onMounted(load);
</script>
