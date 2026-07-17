<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center q-col-gutter-md">
        <div class="col-auto">
          <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
        </div>
        <div class="col">
          <div class="text-overline">Shops / শপ</div>
          <h1 class="text-h5 q-my-none">Shop Access Matrix: {{ shopName }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Turn on access for each customer group on this shop. Use Allow or Deny for each
            capability — this screen is the source of truth.
          </p>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            এই শপে প্রতিটি কাস্টমার গ্রুপকে অ্যাক্সেস দিন। প্রতিটি সুবিধার জন্য Allow (অনুমতি) বা
            Deny (নিষেধ) বেছে নিন — কনফিগারেশন এখানেই করা হবে।
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
                  {{
                    getAccessRow(group.id)?.status
                      ? 'Access Granted / অ্যাক্সেস আছে'
                      : 'No Access / অ্যাক্সেস নেই'
                  }}
                </q-badge>
              </span>
            </div>
            <div class="col-auto">
              <q-btn
                v-if="!activeGroupId || activeGroupId !== group.id"
                flat
                label="Configure / কনফিগার"
                color="primary"
                icon="settings"
                @click="editGroup(group.id)"
              />
              <q-btn
                v-else
                flat
                label="Collapse / বন্ধ"
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
                      label="Grant Catalog Access / ক্যাটালগ অ্যাক্সেস দিন"
                      caption="Master switch for this shop + group. / এই শপ ও গ্রুপের মূল সুইচ।"
                      color="primary"
                      @update:model-value="onStatusToggle"
                    />
                  </div>
                </div>

                <div v-if="editForm.status" class="q-gutter-y-md q-mt-sm">
                  <div class="text-subtitle2 text-grey-8">Capabilities / সুবিধাসমূহ</div>

                  <div class="row q-col-gutter-md">
                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_browse"
                        label="Browse Catalog / ক্যাটালগ দেখা"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="allowDenyOptions"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.see_price"
                        label="See Prices / দাম দেখা"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="allowDenyOptions"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_view_quantity"
                        label="View Stock Qty / স্টক পরিমাণ দেখা"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="allowDenyOptions"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_add_to_cart"
                        label="Add to Cart / কার্টে যোগ"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="allowDenyOptions"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_place_order"
                        label="Place Order / অর্ডার দেওয়া"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="allowDenyOptions"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_negotiate"
                        label="Negotiate / দরকষাকষি"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="allowDenyOptions"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-select
                        v-model="editForm.can_set_dropship_price"
                        label="Set Dropship Price / ড্রপশিপ দাম সেট"
                        outlined
                        dense
                        emit-value
                        map-options
                        :options="allowDenyOptions"
                      />
                    </div>

                    <div class="col-12 col-sm-4">
                      <q-input
                        v-model="editForm.price_tier_code"
                        label="Price Tier Code / প্রাইস টিয়ার"
                        outlined
                        dense
                        placeholder="e.g. tier1"
                      />
                    </div>
                  </div>

                  <div class="text-subtitle2 text-grey-8 q-mt-lg">
                    Commercial Credit Limit / বাণিজ্যিক ক্রেডিট সীমা
                  </div>
                  <p class="text-caption text-grey-7 q-mb-none">
                    Max unpaid balance this group may hold on this shop. Leave empty for unlimited.
                    এই গ্রুপ এই শপে কত টাকা পর্যন্ত বাকি/ক্রেডিটে রাখতে পারবে। খালি = সীমা নেই।
                  </p>

                  <div class="row q-col-gutter-md">
                    <div class="col-12 col-sm-6">
                      <q-input
                        v-model.number="editForm.credit_limit_amount"
                        type="number"
                        step="0.01"
                        label="Credit Amount / ক্রেডিট পরিমাণ"
                        outlined
                        dense
                        clearable
                        placeholder="Unlimited / সীমা নেই"
                      />
                    </div>

                    <div class="col-12 col-sm-6">
                      <q-select
                        v-model="editForm.credit_limit_currency_id"
                        label="Credit Currency / ক্রেডিট মুদ্রা"
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
                            'Currency required / মুদ্রা লাগবে',
                        ]"
                      />
                    </div>
                  </div>
                </div>
              </q-card-section>

              <q-card-actions align="right" class="q-pa-md border-top bg-grey-1">
                <q-btn flat label="Cancel / বাতিল" color="grey-7" @click="editGroup(null)" />
                <q-btn
                  unelevated
                  label="Save / সেভ"
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

const allowDenyOptions = [
  { label: 'Allow / অনুমতি', value: true },
  { label: 'Deny / নিষেধ', value: false },
];

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
