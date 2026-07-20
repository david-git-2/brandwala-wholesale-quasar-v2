<template>
  <div>
    <!-- Interactive Finder -->
    <div
      class="q-pa-md bg-grey-1 rounded-borders q-mb-lg"
      style="border: 1px solid #e0e0e0; border-radius: 8px"
    >
      <div class="text-subtitle1 text-weight-bold text-primary q-mb-md row items-center justify-between">
        <span class="row items-center">
          <q-icon name="explore" class="q-mr-xs" />
          Interactive Scenario Finder / সিনারিও ফাইন্ডার
        </span>
        <q-btn
          flat
          dense
          color="grey-7"
          icon="restart_alt"
          label="Reset / রিসেট"
          size="sm"
          @click="resetFinder"
        />
      </div>

      <!-- Question 1: Shop Type -->
      <div class="q-mb-md">
        <div class="text-subtitle2 text-grey-8 q-mb-xs">
          1. What is the shop type? (দোকানের ধরন কী?)
        </div>
        <div class="row q-col-gutter-sm">
          <div class="col-4">
            <q-btn
              :outline="finderShopType !== 'vendor_catalog'"
              color="primary"
              class="full-width"
              label="Vendor Catalog"
              no-caps
              @click="selectShopType('vendor_catalog')"
            />
          </div>
          <div class="col-4">
            <q-btn
              :outline="finderShopType !== 'fixed_price'"
              color="primary"
              class="full-width"
              label="Fixed Price"
              no-caps
              @click="selectShopType('fixed_price')"
            />
          </div>
          <div class="col-4">
            <q-btn
              :outline="finderShopType !== 'dropship'"
              color="primary"
              class="full-width"
              label="Dropship"
              no-caps
              @click="selectShopType('dropship')"
            />
          </div>
        </div>
      </div>

      <!-- Question 2a: Negotiable (for vendor_catalog) -->
      <div v-if="finderShopType === 'vendor_catalog'" class="q-mb-md">
        <div class="text-subtitle2 text-grey-8 q-mb-xs">
          2. Is it negotiable? (দরকষাকষি করা যাবে?)
        </div>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-btn
              :outline="finderNegotiable !== true"
              color="primary"
              class="full-width"
              label="Yes (হ্যাঁ)"
              no-caps
              @click="finderNegotiable = true"
            />
          </div>
          <div class="col-6">
            <q-btn
              :outline="finderNegotiable !== false"
              color="primary"
              class="full-width"
              label="No (না)"
              no-caps
              @click="finderNegotiable = false"
            />
          </div>
        </div>
      </div>

      <!-- Question 2b: Order Mode (for fixed_price) -->
      <div v-if="finderShopType === 'fixed_price'" class="q-mb-md">
        <div class="text-subtitle2 text-grey-8 q-mb-xs">
          2. What is the order mode? (অর্ডার মোড কী?)
        </div>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-btn
              :outline="finderOrderMode !== 'checkout_fixed'"
              color="primary"
              class="full-width"
              label="Fixed Checkout (খুচরা)"
              no-caps
              @click="selectOrderMode('checkout_fixed')"
            />
          </div>
          <div class="col-6">
            <q-btn
              :outline="finderOrderMode !== 'checkout_wholesale'"
              color="primary"
              class="full-width"
              label="Wholesale Checkout (পাইকারি)"
              no-caps
              @click="selectOrderMode('checkout_wholesale')"
            />
          </div>
        </div>
      </div>

      <!-- Question 3b: Pricing Method (for fixed_price + checkout_fixed) -->
      <div
        v-if="finderShopType === 'fixed_price' && finderOrderMode === 'checkout_fixed'"
        class="q-mb-md"
      >
        <div class="text-subtitle2 text-grey-8 q-mb-xs">
          3. What is the pricing method? (মূল্য নির্ধারণ পদ্ধতি?)
        </div>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-btn
              :outline="finderPricingMethod !== 'markup'"
              color="primary"
              class="full-width"
              label="Markup % (মার্কআপ)"
              no-caps
              @click="finderPricingMethod = 'markup'"
            />
          </div>
          <div class="col-6">
            <q-btn
              :outline="finderPricingMethod !== 'direct_cost'"
              color="primary"
              class="full-width"
              label="Direct Cost (সরাসরি খরচ)"
              no-caps
              @click="finderPricingMethod = 'direct_cost'"
            />
          </div>
        </div>
      </div>

      <!-- Result Banner -->
      <div
        v-if="finderResultPreset"
        class="q-pa-md bg-primary text-white rounded-borders q-mt-md"
        style="border-radius: 8px"
      >
        <div class="text-subtitle2 text-weight-bold">
          Recommended Scenario / প্রস্তাবিত সিনারিও:
        </div>
        <div class="text-h6 text-weight-medium q-mb-sm">{{ finderResultPreset.name }}</div>
        <div class="text-body2">{{ finderResultPreset.description }}</div>
        <div class="text-body2 q-mt-xs text-italic">
          বাংলা: {{ finderResultPreset.descriptionBn }}
        </div>
        <div class="q-mt-md">
          <q-btn
            unelevated
            color="white"
            text-color="primary"
            label="Use this preset / এই প্রিসেট ব্যবহার করুন"
            no-caps
            :disable="applyDisabled"
            @click="emitSelect(finderResultPreset.id)"
          >
            <q-tooltip v-if="applyDisabled && applyDisabledTooltip">
              {{ applyDisabledTooltip }}
            </q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <template v-if="showAllCards">
      <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md">
        All Shop Configuration Scenarios / সকল কনফিগারেশন সিনারিও
      </div>

      <div class="q-gutter-y-md">
        <q-card
          v-for="sc in presets"
          :key="sc.id"
          flat
          bordered
          :class="isHighlighted(sc.id) ? 'bg-blue-50 border-blue-300' : 'bg-white'"
          style="border-radius: 8px"
        >
          <q-card-section class="q-pb-xs">
            <div class="text-subtitle2 text-weight-bold text-primary">
              {{ sc.name }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              <strong>Downstream Path:</strong> {{ sc.downstream }}
            </div>
          </q-card-section>

          <q-card-section class="q-pt-xs q-pb-md">
            <div class="text-body2 text-grey-8">{{ sc.description }}</div>
            <div class="text-body2 text-grey-7 q-mt-xs text-italic">
              বাংলা: {{ sc.descriptionBn }}
            </div>

            <div class="q-mt-sm bg-grey-1 q-pa-sm rounded-borders">
              <div class="row q-col-gutter-sm text-caption text-grey-8">
                <div class="col-4">
                  <strong>Shop Type:</strong> {{ sc.fields.shop_type }}
                </div>
                <div class="col-4">
                  <strong>Order Mode:</strong> {{ sc.fields.order_mode }}
                </div>
                <div class="col-4">
                  <strong>Negotiable:</strong>
                  {{ sc.fields.is_negotiable ? 'Yes' : 'No' }}
                </div>
                <div v-if="sc.fields.shop_type === 'fixed_price'" class="col-4">
                  <strong>Pricing Method:</strong> {{ sc.fields.pricing_method }}
                </div>
                <div v-if="sc.fields.shop_type === 'fixed_price'" class="col-4">
                  <strong>Qty Display:</strong> {{ sc.fields.quantity_display_mode }}
                </div>
                <div class="col-4">
                  <strong>Show Stock Qty:</strong>
                  {{ sc.fields.show_stock_quantity ? 'Yes' : 'No' }}
                </div>
              </div>
            </div>

            <div class="q-mt-sm">
              <q-btn
                outline
                color="primary"
                size="sm"
                label="Use this preset / এই প্রিসেট ব্যবহার করুন"
                no-caps
                :disable="applyDisabled"
                @click="emitSelect(sc.id)"
              >
                <q-tooltip v-if="applyDisabled && applyDisabledTooltip">
                  {{ applyDisabledTooltip }}
                </q-tooltip>
              </q-btn>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import type {
  ShopConfigurationPreset,
  ShopConfigurationPresetId,
} from 'src/modules/shop_order/constants/shopConfigurationPresets';
import type { ShopOrderMode, ShopType } from 'src/modules/shop_order/types';

const props = withDefaults(
  defineProps<{
    presets: ShopConfigurationPreset[];
    showAllCards?: boolean;
    highlightId?: ShopConfigurationPresetId | null;
    applyDisabled?: boolean;
    applyDisabledTooltip?: string;
  }>(),
  {
    showAllCards: true,
    highlightId: null,
    applyDisabled: false,
    applyDisabledTooltip: '',
  },
);

const emit = defineEmits<{
  select: [id: ShopConfigurationPresetId];
}>();

const finderShopType = ref<ShopType | null>(null);
const finderNegotiable = ref<boolean | null>(null);
const finderOrderMode = ref<ShopOrderMode | null>(null);
const finderPricingMethod = ref<'direct_cost' | 'markup' | null>(null);

const resetFinder = () => {
  finderShopType.value = null;
  finderNegotiable.value = null;
  finderOrderMode.value = null;
  finderPricingMethod.value = null;
};

const selectShopType = (type: ShopType) => {
  finderShopType.value = type;
  finderNegotiable.value = null;
  finderOrderMode.value = null;
  finderPricingMethod.value = null;
};

const selectOrderMode = (mode: ShopOrderMode) => {
  finderOrderMode.value = mode;
  finderPricingMethod.value = null;
};

const finderResult = computed((): ShopConfigurationPresetId | null => {
  if (!finderShopType.value) return null;

  if (finderShopType.value === 'vendor_catalog') {
    if (finderNegotiable.value === true) return 'A';
    if (finderNegotiable.value === false) return 'B';
  }

  if (finderShopType.value === 'fixed_price') {
    if (finderOrderMode.value === 'checkout_wholesale') return 'E';
    if (finderOrderMode.value === 'checkout_fixed') {
      if (finderPricingMethod.value === 'markup') return 'C';
      if (finderPricingMethod.value === 'direct_cost') return 'D';
    }
  }

  if (finderShopType.value === 'dropship') {
    return 'F';
  }

  return null;
});

const finderResultPreset = computed(() => {
  if (!finderResult.value) return null;
  return props.presets.find((sc) => sc.id === finderResult.value) ?? null;
});

const isHighlighted = (id: ShopConfigurationPresetId) => {
  if (props.highlightId) return props.highlightId === id;
  return finderResult.value === id;
};

const emitSelect = (id: ShopConfigurationPresetId) => {
  if (props.applyDisabled) return;
  emit('select', id);
};
</script>
