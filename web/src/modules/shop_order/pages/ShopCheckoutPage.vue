<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">Checkout</div>
              <h1 class="text-h5 text-weight-bold q-my-none">Complete Wholesale Order</h1>
            </div>
          </div>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Submit Order"
            :loading="orderStore.saving"
            @click="submitOrder"
          />
        </div>
      </section>

      <div class="row q-col-gutter-lg">
        <!-- Delivery and Billing details (8 cols) -->
        <div class="col-xs-12 col-md-8">
          <div class="column q-gutter-md">
            <!-- Shipping Information -->
            <q-card
              v-if="shopType === 'dropship' || (shopType === 'fixed_price' && allowDelivery)"
              flat
              bordered
              class="form-card"
            >
              <q-card-section
                class="q-px-md q-py-sm border-bottom row items-center justify-between"
              >
                <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                  <q-icon name="local_shipping" size="18px" class="q-mr-xs text-primary" />
                  {{ $t('shop.shipping_info') }}
                </div>
                <!-- Toggle checkbox only for fixed_price -->
                <q-checkbox
                  v-if="shopType === 'fixed_price'"
                  v-model="requestDelivery"
                  :label="$t('shop.request_delivery')"
                  dense
                />
              </q-card-section>

              <q-card-section v-if="requestDelivery">
                <div class="row q-col-gutter-md">
                  <!-- Recipient Name -->
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model="recipientName"
                      outlined
                      dense
                      :label="$t('shop.recipient_name') + ' *'"
                    />
                  </div>

                  <!-- Recipient Phone -->
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model="recipientPhone"
                      outlined
                      dense
                      :label="$t('shop.recipient_phone') + ' *'"
                      @blur="onRecipientPhoneBlur"
                    />
                  </div>

                  <!-- Secondary Phone (Dropship) -->
                  <div v-if="shopType === 'dropship'" class="col-12 col-sm-6">
                    <q-input
                      v-model="secondaryPhone"
                      outlined
                      dense
                      label="Secondary Phone (Optional)"
                    />
                  </div>

                  <!-- District (Searchable Dropdown) -->
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="district"
                      outlined
                      dense
                      use-input
                      fill-input
                      hide-selected
                      input-debounce="0"
                      label="District *"
                      :options="districtOptions"
                      option-label="name"
                      option-value="name"
                      emit-value
                      map-options
                      @filter="filterDistrict"
                      @update:model-value="onDistrictChange"
                    >
                      <template #no-option>
                        <q-item>
                          <q-item-section class="text-grey">No matching district</q-item-section>
                        </q-item>
                      </template>
                      <template #option="scope">
                        <q-item v-bind="scope.itemProps">
                          <q-item-section>
                            <q-item-label>{{ scope.opt.name }}</q-item-label>
                            <q-item-label v-if="scope.opt.bnName" caption>{{ scope.opt.bnName }}</q-item-label>
                          </q-item-section>
                        </q-item>
                      </template>
                    </q-select>
                  </div>

                  <!-- Thana / Upazila (Searchable Dropdown) -->
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="thana"
                      outlined
                      dense
                      use-input
                      fill-input
                      hide-selected
                      input-debounce="0"
                      label="Thana / Upazila *"
                      :options="thanaOptions"
                      option-label="name"
                      option-value="name"
                      emit-value
                      map-options
                      @filter="filterThana"
                      @update:model-value="onThanaChange"
                    >
                      <template #no-option>
                        <q-item>
                          <q-item-section class="text-grey">No matching thana/upazila</q-item-section>
                        </q-item>
                      </template>
                      <template #option="scope">
                        <q-item v-bind="scope.itemProps">
                          <q-item-section>
                            <q-item-label>{{ scope.opt.name }}</q-item-label>
                            <q-item-label v-if="scope.opt.bnName" caption>{{ scope.opt.bnName }}</q-item-label>
                          </q-item-section>
                        </q-item>
                      </template>
                    </q-select>
                  </div>

                  <!-- Post Code / Post Office (Searchable Select or Manual Input) -->
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="postCode"
                      outlined
                      dense
                      use-input
                      fill-input
                      hide-selected
                      input-debounce="0"
                      label="Post Code / Post Office"
                      :options="postcodeOptions"
                      option-label="displayLabel"
                      option-value="postCode"
                      emit-value
                      map-options
                      @filter="filterPostcode"
                      @new-value="createPostcode"
                    >
                      <template #no-option>
                        <q-item>
                          <q-item-section class="text-grey">Type custom post code or office</q-item-section>
                        </q-item>
                      </template>
                      <template #option="scope">
                        <q-item v-bind="scope.itemProps">
                          <q-item-section>
                            <q-item-label>{{ scope.opt.postOffice }} - {{ scope.opt.postCode }}</q-item-label>
                          </q-item-section>
                        </q-item>
                      </template>
                    </q-select>
                  </div>

                  <!-- Detailed Address -->
                  <div class="col-12">
                    <q-input
                      v-model="shippingAddress"
                      outlined
                      dense
                      type="textarea"
                      :label="$t('shop.shipping_address') + ' *'"
                      rows="3"
                    />
                  </div>
                </div>

                <div v-if="shopType === 'dropship'" class="text-caption text-grey-7 q-mt-sm">
                  <q-icon name="info" size="14px" class="q-mr-xs text-primary" />
                  Inside Dhaka standard delivery: 60-70 BDT | Outside Dhaka: 120-130 BDT
                </div>

                <!-- Payment Mode and Delivery Instructions for Dropship -->
                <template v-if="shopType === 'dropship'">
                  <q-input
                    v-model="deliveryInstructions"
                    outlined
                    dense
                    type="textarea"
                    :label="$t('shop.delivery_instructions')"
                    rows="2"
                    class="q-mt-md"
                  />
                </template>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Checkout Summary (4 cols) -->
        <div class="col-xs-12 col-md-4">
          <q-card flat bordered class="summary-card sticky-card">
            <q-card-section class="q-px-md q-py-sm border-bottom">
              <div class="text-subtitle2 text-weight-bold text-grey-9">
                {{ $t('shop.items_summary') }}
              </div>
            </q-card-section>

            <q-list class="item-list-compact" separator>
              <q-item v-for="item in cartStore.items" :key="item.id" class="q-py-sm">
                <q-item-section avatar>
                  <q-avatar size="36px" rounded class="bg-grey-2">
                    <q-img v-if="item.image_url" :src="item.image_url" />
                    <q-icon v-else name="image" size="18px" color="grey-4" />
                  </q-avatar>
                </q-item-section>
                <q-item-section>
                  <div class="text-caption text-weight-bold text-grey-9 item-name">
                    {{ item.name }}
                  </div>
                  <div class="text-caption text-grey-6">
                    {{ $t('shop.qty') }}: {{ item.quantity }}
                  </div>
                </q-item-section>
                <q-item-section side v-if="cartStore.cart?.see_price_snapshot || cartStore.cart?.shop_type === 'dropship'">
                  <template v-if="cartStore.cart?.shop_type === 'dropship'">
                    <div class="text-caption text-grey-6 text-right" style="font-size: 10px;">
                      {{ $t('shop.cost_label') }} {{ formatBuyerItemTotal(item) }}
                    </div>
                    <div class="text-caption text-weight-bold text-primary text-right">
                      {{ $t('shop.pay_label') }} {{ formatItemTotal(item) }}
                    </div>
                  </template>
                  <template v-else>
                    <div class="text-caption text-weight-bold text-grey-9">
                      {{ formatItemTotal(item) }}
                    </div>
                  </template>
                </q-item-section>
              </q-item>
            </q-list>

            <q-separator />

            <q-card-section class="q-py-md">
              <template v-if="cartStore.cart?.shop_type === 'dropship'">
                <!-- Items Subtotal -->
                <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                  <span>{{ $t('shop.items_subtotal') }}</span>
                  <span class="text-weight-medium text-grey-9">
                    {{ formatAmount(cartStore.cartTotal) }}
                  </span>
                </div>

                <!-- Charges Section -->
                <div class="column q-mt-sm q-mb-sm bg-grey-1 q-pa-sm rounded-borders" style="border: 1px solid rgba(0,0,0,0.05); border-radius: 8px;">
                  <div class="text-caption text-weight-bold text-grey-7 q-mb-xs">
                    {{ $t('shop.dropship_charges') }}
                  </div>
                  
                  <div class="row justify-between text-caption text-grey-7 q-mb-xs">
                    <span>{{ $t('shop.delivery_charge') }}</span>
                    <span>{{ formatAmount(0) }}</span>
                  </div>
                  
                  <div v-if="!isPrepaid" class="row justify-between text-caption text-grey-7 q-mb-xs">
                    <span>{{ $t('shop.cod_fee') }}</span>
                    <span>{{ formatAmount(0) }}</span>
                  </div>
                  
                  <div class="row justify-between text-caption text-grey-7 q-mb-xs">
                    <span>
                      {{ $t('shop.print_charge') }}
                      <span class="text-grey-5">({{ deductPrintFromMargin ? 'deducted' : 'customer pays' }})</span>
                    </span>
                    <span>{{ formatAmount(printCharge) }}</span>
                  </div>
                  
                  <div class="row justify-between text-caption text-grey-7">
                    <span>
                      {{ $t('shop.packing_charge') }}
                      <span class="text-grey-5">({{ deductPackingFromMargin ? 'deducted' : 'customer pays' }})</span>
                    </span>
                    <span>{{ formatAmount(packingCharge) }}</span>
                  </div>

                  <div class="text-caption text-grey-6 q-mt-sm">
                    {{ $t('shop.courier_charges_may_vary') }}
                    <div>{{ $t('shop.courier_delivery_estimate', { min: formatAmount(courierEstimate.deliveryMin), max: formatAmount(courierEstimate.deliveryMax) }) }}</div>
                    <div v-if="!isPrepaid && codEstimateSummary">{{ $t('shop.courier_cod_estimate', { summary: codEstimateSummary }) }}</div>
                  </div>
                </div>

                <!-- Buyer Cost -->
                <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                  <span>{{ $t('shop.your_cost_buyer') }}</span>
                  <span class="text-weight-medium text-grey-9">
                    {{ formatAmount(cartStore.buyerCartTotal + printCharge + packingCharge) }}
                  </span>
                </div>

                <!-- Profit -->
                <div class="row justify-between q-mb-sm text-body2 text-grey-7">
                  <span>{{ $t('shop.estimated_profit') }}</span>
                  <span class="text-weight-bold text-positive">
                    {{ formatAmount(estimatedProfit) }}
                  </span>
                </div>
                
                <q-separator class="q-my-sm" />
              </template>

              <div class="row justify-between items-baseline q-mb-lg">
                <span class="text-subtitle1 text-weight-bold text-grey-9">{{
                  cartStore.cart?.shop_type === 'dropship' ? $t('shop.recipient_pay_total') : $t('shop.estimated_total')
                }}</span>
                <span
                  v-if="cartStore.cart?.see_price_snapshot || cartStore.cart?.shop_type === 'dropship'"
                  class="text-h6 text-weight-bold text-primary"
                >
                  {{ cartStore.cart?.shop_type === 'dropship' ? formatAmount(recipientGrandTotal) : formatCartTotal() }}
                </span>
                <span v-else class="text-subtitle1 text-grey-5 italic">
                  {{ $t('shop.prices_hidden') }}
                </span>
              </div>

              <!-- PLACE ORDER -->
              <q-btn
                color="primary"
                unelevated
                no-caps
                :label="$t('shop.place_order')"
                class="full-width pill-btn text-weight-bold q-py-sm"
                :loading="orderStore.saving"
                :disabled="
                  requestDelivery &&
                  (!recipientName.trim() || !recipientPhone.trim() || !shippingAddress.trim())
                "
                @click="submitOrder"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useShopCartStore } from '../stores/shopCartStore';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';

import { showErrorNotification } from 'src/utils/appFeedback';
import { fetchCourierChargeEstimate } from '../services/courierChargeEstimate';
import { useRecipientProfileStore } from 'src/modules/sales_invoice/stores/recipientProfileStore';
import {
  getBDDistricts,
  getBDUpazilas,
  getBDPostcodes,
  type BDLocationOption,
  type BDPostcodeOption,
} from 'src/utils/bdAddressService';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const cartStore = useShopCartStore();
const orderStore = useShopOrderStore();
const storefrontStore = useShopStorefrontStore();
const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value || []);
const recipientProfileStore = useRecipientProfileStore();
const lastLookupPhone = ref('');

const recipientName = ref('');
const recipientPhone = ref('');
const secondaryPhone = ref('');
const district = ref('Dhaka');
const thana = ref('Uttara');
const postCode = ref('');
const shippingAddress = ref('');
const requestDelivery = ref(false);

const isPrepaid = ref(false);
const deliveryInstructions = ref('');

// District & Thana/Upazila Options for Dropdown
const rawDistricts = ref<BDLocationOption[]>([]);
const rawThanas = ref<BDLocationOption[]>([]);
const rawPostcodes = ref<(BDPostcodeOption & { displayLabel: string })[]>([]);
const districtOptions = ref<BDLocationOption[]>([]);
const thanaOptions = ref<BDLocationOption[]>([]);
const postcodeOptions = ref<(BDPostcodeOption & { displayLabel: string })[]>([]);

const shopType = computed(() => cartStore.cart?.shop_type);
const allowDelivery = computed(() => cartStore.cart?.allow_delivery);

const shopId = computed(() => {
  return route.query.shopId ? Number(route.query.shopId) : null;
});

// Load BD Districts and Upazilas
const loadLocationData = async () => {
  rawDistricts.value = await getBDDistricts();
  districtOptions.value = rawDistricts.value;
  await updateThanaList(district.value);
};

const updateThanaList = async (distName: string) => {
  if (!distName) {
    rawThanas.value = await getBDUpazilas();
  } else {
    rawThanas.value = await getBDUpazilas(distName);
  }
  thanaOptions.value = rawThanas.value;
  await updatePostcodeList(distName, thana.value);
};

const updatePostcodeList = async (distName: string, thanaName: string) => {
  if (!distName) {
    rawPostcodes.value = [];
    postcodeOptions.value = [];
    return;
  }
  const fetched = await getBDPostcodes(distName, thanaName);
  const mapped = fetched.map((p) => ({
    ...p,
    displayLabel: `${p.postOffice} - ${p.postCode}`,
  }));
  rawPostcodes.value = mapped;
  postcodeOptions.value = mapped;
};

const filterDistrict = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    if (!needle) {
      districtOptions.value = rawDistricts.value;
    } else {
      districtOptions.value = rawDistricts.value.filter(
        (d) =>
          d.name.toLowerCase().includes(needle) ||
          d.bnName.toLowerCase().includes(needle)
      );
    }
  });
};

const filterThana = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    if (!needle) {
      thanaOptions.value = rawThanas.value;
    } else {
      thanaOptions.value = rawThanas.value.filter(
        (t) =>
          t.name.toLowerCase().includes(needle) ||
          t.bnName.toLowerCase().includes(needle)
      );
    }
  });
};

const filterPostcode = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    if (!needle) {
      postcodeOptions.value = rawPostcodes.value;
    } else {
      postcodeOptions.value = rawPostcodes.value.filter(
        (p) =>
          p.postCode.toLowerCase().includes(needle) ||
          p.postOffice.toLowerCase().includes(needle)
      );
    }
  });
};

const createPostcode = (val: string, done: (item: any) => void) => {
  const custom = {
    id: 0,
    districtId: 0,
    postOffice: val,
    postCode: val,
    displayLabel: val,
  };
  done(custom);
};

const onDistrictChange = async (newDistName: string) => {
  thana.value = '';
  postCode.value = '';
  await updateThanaList(newDistName);
};

const onThanaChange = async (newThanaName: string) => {
  postCode.value = '';
  await updatePostcodeList(district.value, newThanaName);
};

// Print/packing from shop; COD/delivery confirmed later by courier
const defaultPrintCharge = computed(() => Number(cartStore.cart?.default_print_charge_amount || 0));
const defaultPackingCharge = computed(() => Number(cartStore.cart?.default_packing_charge_amount || 0));

const deliveryCharge = computed(() => 0);
const printCharge = computed(() => (shopType.value === 'dropship' ? defaultPrintCharge.value : 0));
const packingCharge = computed(() => (shopType.value === 'dropship' ? defaultPackingCharge.value : 0));
const codCharge = computed(() => 0);

const deductPrintFromMargin = computed(() => !!cartStore.cart?.deduct_print_from_margin);
const deductPackingFromMargin = computed(() => !!cartStore.cart?.deduct_packing_from_margin);

const recipientGrandTotal = computed(() => {
  return cartStore.cartTotal
    + (deductPrintFromMargin.value ? 0 : printCharge.value)
    + (deductPackingFromMargin.value ? 0 : packingCharge.value);
});

const estimatedProfit = computed(() => {
  const buyerCost = cartStore.buyerCartTotal
    + printCharge.value
    + packingCharge.value;
  return recipientGrandTotal.value - buyerCost;
});

const courierEstimate = ref({
  deliveryMin: 60,
  deliveryMax: 130,
  codPercentMin: 1 as number | null,
  codPercentMax: 1 as number | null,
  codFlatMin: null as number | null,
  codFlatMax: null as number | null,
});

const codEstimateSummary = computed(() => {
  const e = courierEstimate.value;
  const parts: string[] = [];
  if (e.codPercentMin != null && e.codPercentMax != null) {
    parts.push(
      e.codPercentMin === e.codPercentMax
        ? `~${e.codPercentMin}%`
        : `~${e.codPercentMin}–${e.codPercentMax}%`
    );
  }
  if (e.codFlatMin != null && e.codFlatMax != null) {
    parts.push(
      e.codFlatMin === e.codFlatMax
        ? formatAmount(e.codFlatMin)
        : `${formatAmount(e.codFlatMin)}–${formatAmount(e.codFlatMax)}`
    );
  }
  return parts.join(' / ') || '~1%';
});

watch(shopType, async (type) => {
  if (type === 'dropship') {
    courierEstimate.value = await fetchCourierChargeEstimate();
  }
}, { immediate: true });

const currencySymbol = computed(() => {
  const shop = storefrontStore.shopDetails;
  if (shop?.sell_currency_id) {
    const curr = currencies.value.find((c) => c.id === shop.sell_currency_id);
    if (curr?.symbol) return curr.symbol;
  }
  return '£';
});

// Watch for cart changes to initialize requestDelivery
watch(
  () => cartStore.cart,
  (cart) => {
    if (cart) {
      if (cart.shop_type === 'dropship') {
        requestDelivery.value = true;
      } else {
        requestDelivery.value = false;
      }
    }
  },
  { immediate: true },
);

onMounted(async () => {
  await loadLocationData();
  if (!cartStore.cart && shopId.value) {
    await cartStore.fetchCart(shopId.value);
  }
  if (!storefrontStore.shopDetails) {
    const lastSlug = localStorage.getItem('last_visited_shop_slug');
    if (lastSlug) {
      await storefrontStore.fetchCatalog(lastSlug, { limit: 1, offset: 0 });
    }
  }
});

const goBack = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/cart`);
};

const onRecipientPhoneBlur = async () => {
  const phone = recipientPhone.value.replace(/\D/g, '');
  const tenantId = cartStore.cart?.tenant_id;
  if (!tenantId || !/^01\d{9}$/.test(phone)) return;
  if (phone === lastLookupPhone.value) return;
  lastLookupPhone.value = phone;

  const profile = await recipientProfileStore.getByPhone(tenantId, phone);
  if (!profile) return;

  if (!recipientName.value.trim()) recipientName.value = profile.name || '';
  if (!secondaryPhone.value.trim() && profile.secondary_phone) {
    secondaryPhone.value = profile.secondary_phone;
  }
  if (!shippingAddress.value.trim() && profile.address) {
    shippingAddress.value = profile.address;
  }
  if (profile.district) {
    district.value = profile.district;
    await updateThanaList(profile.district);
  }
  if (profile.thana) {
    thana.value = profile.thana;
    await updatePostcodeList(district.value, profile.thana);
  }
};

const submitOrder = async () => {
  if (!cartStore.cart?.id) return;

  if (shopType.value === 'dropship') {
    for (const item of cartStore.items) {
      const minPrice = item.unit_minimum_sell_price_amount || 0;
      const sellPrice = item.customer_sell_price_amount ?? 0;
      if (sellPrice < minPrice) {
        showErrorNotification(
          t('shop.price_below_min', {
            name: item.name,
            amount: `${currencySymbol.value}${minPrice.toFixed(2)}`,
          }),
        );
        return;
      }
    }
  }

  const name = requestDelivery.value ? recipientName.value.trim() : '';
  const phone = requestDelivery.value ? recipientPhone.value.trim() : '';
  
  // Format full combined shipping address if district/thana/postcode are specified
  let formattedAddress = requestDelivery.value ? shippingAddress.value.trim() : '';
  if (requestDelivery.value && (district.value || thana.value || postCode.value)) {
    const parts = [
      thana.value ? `Thana: ${thana.value}` : '',
      district.value ? `District: ${district.value}` : '',
      postCode.value ? `Post Code: ${postCode.value}` : '',
    ].filter(Boolean);
    const locationPart = parts.join(', ');

    if (formattedAddress && !formattedAddress.toLowerCase().includes(district.value.toLowerCase())) {
      formattedAddress = `${formattedAddress}\n${locationPart}`;
    } else if (!formattedAddress) {
      formattedAddress = locationPart;
    }
  }

  const res = await orderStore.submitOrder(
    cartStore.cart.id,
    name,
    phone,
    formattedAddress,
    null,
    isPrepaid.value,
    deliveryInstructions.value,
    codCharge.value,
    deliveryCharge.value,
    printCharge.value,
    packingCharge.value,
    0,
    requestDelivery.value ? secondaryPhone.value.trim() || null : null,
    requestDelivery.value ? district.value || null : null,
    requestDelivery.value ? thana.value || null : null,
  );
  if (res.success && res.data) {
    cartStore.clearCart();
    const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
    void router.push(`${tenantSlug}/shop/orders/${res.data.order_id}`);
  }
};

// Formatting helpers
const formatAmount = (val: number) => {
  return `${currencySymbol.value}${val.toFixed(2)}`;
};

const formatItemTotal = (item: any) => {
  const price =
    item.customer_sell_price_amount ??
    item.unit_sell_price_amount ??
    item.unit_list_price_amount ??
    0;
  const total = price * item.quantity;
  return `${currencySymbol.value}${total.toFixed(2)}`;
};

const formatBuyerItemTotal = (item: any) => {
  const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
  const total = price * item.quantity;
  return `${currencySymbol.value}${total.toFixed(2)}`;
};

const formatCartTotal = () => {
  return `${currencySymbol.value}${cartStore.cartTotal.toFixed(2)}`;
};
</script>

<script lang="ts">
export default {
  name: 'ShopCheckoutPage',
};
</script>

<style scoped>
.form-card,
.summary-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.item-list-compact {
  max-height: 250px;
  overflow-y: auto;
}

.item-name {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.sticky-card {
  position: sticky;
  top: 24px;
}

.font-semibold {
  font-weight: 500;
}

.italic {
  font-style: italic;
}
</style>
