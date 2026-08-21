<template>
  <div>
    <q-card flat bordered class="q-mb-md">
      <q-card-section>
        <div class="text-subtitle2 text-weight-medium">{{ $t('shop_admin.shop_details_section') }}</div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-md">
          {{ $t('shop_admin.shop_details_section_caption') }}
        </p>
        <div class="row q-col-gutter-md items-start">
          <div class="col-12 col-md-7">
            <q-input
              v-model="form.name"
              :label="$t('shop_admin.shop_name') + ' *'"
              outlined
              dense
              :error="!!errors.name"
              :error-message="errors.name"
            />
          </div>
          <div class="col-12 col-md-5">
            <q-input
              v-model="form.slug"
              :label="$t('shop_admin.slug') + ' *'"
              outlined
              dense
              :hint="$t('shop_admin.slug_hint')"
              :error="!!errors.slug"
              :error-message="errors.slug"
              @update:model-value="
                () => {
                  form.slug = form.slug.toLowerCase().replace(/[^a-z0-9-]/g, '-');
                }
              "
            />
          </div>
        </div>

        <q-input
          v-model="form.description"
          :label="$t('shop_admin.shop_description')"
          outlined
          dense
          type="textarea"
          rows="2"
          class="q-mt-md"
          :hint="$t('shop_admin.shop_description_hint')"
        />

        <q-select
          v-model="form.category_ids"
          :options="categoryOptions"
          option-value="id"
          option-label="name"
          emit-value
          map-options
          multiple
          use-chips
          outlined
          dense
          class="q-mt-md"
          :label="$t('shop_admin.shop_categories')"
          :loading="loadingCategories"
          :hint="$t('shop_admin.shop_categories_hint')"
          :no-option-label="$t('shop_admin.no_shop_categories_yet')"
        />
        <div class="row items-center justify-between q-mt-xs">
          <div
            v-if="!loadingCategories && categoryOptions.length === 0"
            class="text-caption text-grey-7"
          >
            {{ $t('shop_admin.no_shop_categories_yet') }}
          </div>
          <div class="col" />
          <router-link
            :to="categoriesPageTo"
            class="text-primary text-weight-medium text-caption"
            style="text-decoration: none"
          >
            <q-icon name="ph ph-plus-circle" size="14px" class="q-mr-xs" />
            {{ $t('shop_admin.manage_or_add_categories') }}
          </router-link>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat bordered class="q-mb-md">
      <q-card-section>
        <div class="text-subtitle2 text-weight-medium">{{ $t('shop_admin.shop_type') }}</div>
        <div class="text-body2 text-weight-medium q-mt-xs">{{ shopTypeLabel }}</div>
        <p class="text-caption text-grey-7 q-mb-none q-mt-xs">{{ shopTypeDescription }}</p>
        <div class="text-caption text-grey-6 q-mt-sm">{{ $t('shop_admin.shop_type_locked') }}</div>
      </q-card-section>
    </q-card>

    <q-card v-if="form.shop_type === 'vendor_catalog'" flat bordered class="q-mb-md">
      <q-card-section>
        <div class="text-subtitle2 text-weight-medium">{{ $t('shop_admin.vendor_brand_settings') }}</div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-md">
          {{ $t('shop_admin.vendor_brand_caption') }}
        </p>

        <q-select
          v-model="selectedVendorCodes"
          :options="vendorOptions"
          option-value="code"
          option-label="label"
          emit-value
          map-options
          multiple
          use-chips
          outlined
          dense
          :label="$t('shop_admin.vendor')"
          :hint="$t('shop_admin.vendor_hint')"
          :loading="loadingVendors"
          :no-option-label="$t('shop_admin.no_vendors')"
          data-test="shop-vendor-select"
        />
        <div v-if="errors.vendor_code" class="text-negative text-caption q-mt-xs">
          {{ errors.vendor_code }}
        </div>
        <div
          v-else-if="!loadingVendors && selectedVendorCodes.length === 0"
          class="text-caption text-grey-7 q-mt-xs"
        >
          {{ $t('shop_admin.add_vendor_prompt') }}
        </div>

        <div
          v-if="form.vendor_filters && form.vendor_filters.length > 0"
          class="q-gutter-y-sm q-mt-md"
        >
          <q-select
            v-for="vf in form.vendor_filters"
            :key="vf.vendor_code"
            v-model="vf.brands"
            multiple
            use-chips
            outlined
            dense
            :options="vendorBrandsMap[vf.vendor_code] || []"
            :loading="loadingBrandsMap[vf.vendor_code]"
            :label="`${$t('shop_admin.select_brands')} — ${getVendorLabel(vf.vendor_code)}`"
            @focus="loadBrandsForVendor(vf.vendor_code)"
          />
        </div>
      </q-card-section>
    </q-card>

    <q-card flat bordered class="q-mb-md">
      <q-card-section>
        <div class="text-subtitle2 text-weight-medium">{{ $t('shop_admin.shop_currencies') }}</div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-md">
          {{ $t('shop_admin.help_currencies_desc') }}
        </p>
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-6">
            <q-select
              v-model="form.buy_currency_id"
              :options="currencyOptions"
              emit-value
              map-options
              :loading="loadingCurrencies"
              :label="$t('shop_admin.cost_currency') + ' *'"
              :hint="$t('shop_admin.cost_currency_hint')"
              outlined
              dense
              :error="!!errors.buy_currency_id"
              :error-message="errors.buy_currency_id"
            />
          </div>
          <div class="col-12 col-sm-6">
            <q-select
              v-model="form.sell_currency_id"
              :options="currencyOptions"
              emit-value
              map-options
              :loading="loadingCurrencies"
              :label="$t('shop_admin.checkout_currency') + ' *'"
              :hint="$t('shop_admin.checkout_currency_hint')"
              outlined
              dense
              :error="!!errors.sell_currency_id"
              :error-message="errors.sell_currency_id"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card v-if="form.shop_type === 'fixed_price'" flat bordered class="q-mb-md">
      <q-card-section>
        <div class="text-subtitle2 text-weight-medium">{{ $t('shop_admin.retail_pricing_qty') }}</div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-md">
          {{ $t('shop_admin.retail_pricing_caption') }}
        </p>
        <q-select
          v-model="form.order_mode"
          :options="orderModeOptions"
          emit-value
          map-options
          :label="$t('shop_admin.order_mode') + ' *'"
          :hint="selectedOrderModeHint"
          outlined
          dense
          class="q-mb-md"
        >
          <template #option="scope">
            <q-item v-bind="scope.itemProps">
              <q-item-section>
                <q-item-label>{{ scope.opt.label }}</q-item-label>
                <q-item-label caption>{{ scope.opt.description }}</q-item-label>
              </q-item-section>
            </q-item>
          </template>
        </q-select>
        <div class="row q-col-gutter-md items-center">
          <div class="col-12 col-sm-6">
            <q-select
              v-model="form.pricing_method"
              :options="pricingMethodOptions"
              emit-value
              map-options
              :label="$t('shop_admin.pricing_method') + ' *'"
              :hint="selectedPricingHint"
              outlined
              dense
            >
              <template #option="scope">
                <q-item v-bind="scope.itemProps">
                  <q-item-section>
                    <q-item-label>{{ scope.opt.label }}</q-item-label>
                    <q-item-label caption>{{ scope.opt.description }}</q-item-label>
                  </q-item-section>
                </q-item>
              </template>
            </q-select>
          </div>
          <div class="col-12 col-sm-6" v-if="form.pricing_method === 'markup'">
            <q-input
              v-model.number="form.markup_percentage"
              type="number"
              :label="$t('shop_admin.markup_pct') + ' *'"
              suffix="%"
              outlined
              dense
              :error="!!errors.markup_percentage"
              :error-message="errors.markup_percentage"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card
      v-if="form.shop_type === 'fixed_price' || form.shop_type === 'dropship'"
      flat
      bordered
      class="q-mb-md"
    >
      <q-card-section>
        <div class="text-subtitle2 text-weight-medium">{{ $t('shop_admin.qty_display_mode') }}</div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-md">
          {{ $t('shop_admin.help_qty_display_desc') }}
        </p>
        <q-select
          v-model="form.quantity_display_mode"
          :options="qtyDisplayOptions"
          emit-value
          map-options
          :label="$t('shop_admin.qty_display_mode') + ' *'"
          outlined
          dense
        >
          <template #option="scope">
            <q-item v-bind="scope.itemProps">
              <q-item-section>
                <q-item-label>{{ scope.opt.label }}</q-item-label>
                <q-item-label caption>{{ scope.opt.description }}</q-item-label>
              </q-item-section>
            </q-item>
          </template>
        </q-select>
      </q-card-section>
    </q-card>

    <q-card v-if="form.shop_type === 'dropship'" flat bordered class="q-mb-md">
      <q-card-section>
        <div class="text-subtitle2 text-weight-medium">{{ $t('shop_admin.dropship_default_charges') }}</div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-md">
          {{ $t('shop_admin.dropship_charges_caption') }}
        </p>
        <div class="row q-col-gutter-md">
          <div class="col-6">
            <q-input
              v-model.number="form.default_print_charge_amount"
              type="number"
              :label="$t('shop_admin.default_print_charge')"
              outlined
              dense
            />
          </div>
          <div class="col-6">
            <q-input
              v-model.number="form.default_packing_charge_amount"
              type="number"
              :label="$t('shop_admin.default_packing_charge')"
              outlined
              dense
            />
          </div>
        </div>
        <div class="q-mt-md text-grey-8 text-weight-medium q-mb-xs">
          {{ $t('shop_admin.margin_deductions_title') }}
        </div>
        <div class="row q-col-gutter-md">
          <div class="col-6">
            <q-toggle
              v-model="form.deduct_print_from_margin"
              :label="$t('shop_admin.deduct_print_from_margin')"
              color="primary"
            />
          </div>
          <div class="col-6">
            <q-toggle
              v-model="form.deduct_packing_from_margin"
              :label="$t('shop_admin.deduct_packing_from_margin')"
              color="primary"
            />
          </div>
        </div>
        <div class="text-caption text-grey-6 q-mt-sm">
          {{ $t('shop_admin.courier_charges_note') }}
        </div>
      </q-card-section>
    </q-card>

    <q-card flat bordered>
      <q-card-section>
        <div class="text-subtitle2 text-weight-medium">{{ $t('shop_admin.shop_visibility_section') }}</div>
        <p class="text-caption text-grey-7 q-mt-xs q-mb-md">
          {{ $t('shop_admin.shop_visibility_caption') }}
        </p>
        <div class="q-gutter-y-md">
          <div>
            <q-toggle
              v-model="form.is_active"
              :label="$t('shop_admin.make_public')"
              color="positive"
              :disable="publicToggleDisabled"
            />
            <q-tooltip v-if="publicToggleDisabled">{{ publishBlockedReason }}</q-tooltip>
            <div class="text-caption text-grey-7 q-ml-lg">
              {{ publicToggleDisabled ? publishBlockedReason : $t('shop_admin.make_public_hint') }}
            </div>
          </div>
          <div>
            <q-toggle v-model="form.show_stock_quantity" :label="$t('shop_admin.show_stock_qty')" color="primary" />
            <div class="text-caption text-grey-7 q-ml-lg">{{ $t('shop_admin.help_show_stock_qty_desc') }}</div>
          </div>
          <div v-if="form.shop_type === 'fixed_price'">
            <q-toggle v-model="form.allow_delivery" :label="$t('shop_admin.allow_delivery')" color="primary" />
            <div class="text-caption text-grey-7 q-ml-lg">{{ $t('shop_admin.allow_delivery_hint') }}</div>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { Shop, ShopOrderMode, ShopType, UpdateShopPayload } from 'src/modules/shop_order/types';
import {
  derivedShopIsNegotiable,
  getAllowedOrderModes,
} from 'src/modules/shop_order/constants/shopConfigurationPresets';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import { productService } from 'src/modules/products/services/productService';
import type { Vendor } from 'src/modules/vendor/types';
import { useShopCategoryListQuery } from '../composables/useShopCategoryQuery';

type ShopForm = {
  id: number;
  tenant_id: number;
  name: string;
  slug: string;
  description?: string;
  category_ids?: number[];
  shop_type: ShopType;
  vendor_code: string;
  order_mode: ShopOrderMode;
  is_negotiable: boolean;
  show_stock_quantity: boolean;
  is_active: boolean;
  allow_delivery: boolean;
  buy_currency_id: number | null;
  sell_currency_id: number | null;
  pricing_method: 'direct_cost' | 'markup';
  markup_percentage: number;
  quantity_display_mode: 'original' | 'custom_override';
  default_print_charge_amount?: number;
  default_packing_charge_amount?: number;
  deduct_charges_from_margin: boolean;
  deduct_print_from_margin: boolean;
  deduct_packing_from_margin: boolean;
  vendor_filters?: Array<{ vendor_code: string; brands: string[] }> | null;
};

const props = defineProps<{
  shop: Shop;
}>();

const { t } = useI18n();
const authStore = useAuthStore();
const { data: currencies, isLoading: loadingCurrencies } = useGlobalCurrenciesQuery();

const categoriesPageTo = computed(() => ({
  name: 'app-shop-categories-page',
  params: { tenantSlug: authStore.selectedTenant?.slug ?? '' },
}));

const errors = reactive<{
  name?: string;
  slug?: string;
  vendor_code?: string;
  buy_currency_id?: string;
  sell_currency_id?: string;
  markup_percentage?: string;
}>({});

function shopToForm(shop: Shop): ShopForm {
  return {
    id: shop.id,
    tenant_id: shop.tenant_id,
    name: shop.name,
    slug: shop.slug,
    description: shop.description || '',
    category_ids: shop.category_ids || [],
    shop_type: shop.shop_type,
    vendor_code: shop.vendor_code ?? '',
    order_mode: shop.order_mode,
    is_negotiable: derivedShopIsNegotiable(shop.shop_type),
    show_stock_quantity: shop.show_stock_quantity,
    is_active: shop.is_active,
    allow_delivery: shop.allow_delivery || false,
    buy_currency_id: shop.buy_currency_id,
    sell_currency_id: shop.sell_currency_id,
    pricing_method: shop.pricing_method || 'direct_cost',
    markup_percentage: shop.markup_percentage || 0,
    quantity_display_mode: shop.quantity_display_mode || 'original',
    default_print_charge_amount: shop.default_print_charge_amount || 0,
    default_packing_charge_amount: shop.default_packing_charge_amount || 0,
    deduct_charges_from_margin: shop.deduct_charges_from_margin || false,
    deduct_print_from_margin: shop.deduct_print_from_margin || false,
    deduct_packing_from_margin: shop.deduct_packing_from_margin || false,
    vendor_filters: cloneVendorFilters(shop),
  };
}

const form = reactive<ShopForm>(shopToForm(props.shop));

watch(
  () => props.shop,
  (shop) => {
    Object.assign(form, shopToForm(shop));
    form.vendor_filters?.forEach((vf) => {
      void loadBrandsForVendor(vf.vendor_code);
    });
  },
);

function cloneVendorFilters(shop: Shop): Array<{ vendor_code: string; brands: string[] }> {
  if (shop.vendor_filters && shop.vendor_filters.length > 0) {
    return shop.vendor_filters.map((vf) => ({
      vendor_code: vf.vendor_code,
      brands: [...(vf.brands || [])],
    }));
  }
  if (shop.vendor_code) {
    return [{ vendor_code: shop.vendor_code, brands: [] }];
  }
  return [];
}

const vendorBrandsMap = reactive<Record<string, string[]>>({});
const loadingBrandsMap = reactive<Record<string, boolean>>({});
const vendors = ref<Vendor[]>([]);
const loadingVendors = ref(false);

const currencyOptions = computed(() =>
  (currencies.value ?? []).map((c) => ({ value: c.id, label: `${c.name} (${c.code})` })),
);

const categoryParams = computed(() => ({ tenantId: form.tenant_id }));
const { data: categoryData, isLoading: loadingCategories } = useShopCategoryListQuery(categoryParams);
const categoryOptions = computed(() => {
  const selected = new Set(form.category_ids || []);
  return (categoryData.value || [])
    .filter((c) => c.is_active || selected.has(c.id))
    .map((c) => ({ id: c.id, name: c.name }));
});

const vendorOptions = computed(() =>
  vendors.value.map((v: Vendor) => ({ code: v.code, label: `${v.name} (${v.code})` })),
);

const selectedVendorCodes = computed({
  get: (): string[] => form.vendor_filters?.map((v) => v.vendor_code) ?? [],
  set: (codes: string[] | string | null) => {
    const next = Array.isArray(codes) ? codes : codes ? [codes] : [];
    const prevBrands = new Map(
      (form.vendor_filters ?? []).map((v) => [v.vendor_code, v.brands ?? []]),
    );
    form.vendor_filters = next.map((code) => ({
      vendor_code: code,
      brands: prevBrands.get(code) ?? [],
    }));
    form.vendor_code = next[0] ?? '';
    next.forEach((code) => {
      void loadBrandsForVendor(code);
    });
  },
});

const shopTypeLabel = computed(() => {
  const map: Record<ShopType, string> = {
    vendor_catalog: t('shop_admin.create_type_catalog'),
    fixed_price: t('shop_admin.create_type_stock'),
    dropship: t('shop_admin.create_type_dropship'),
  };
  return map[form.shop_type] ?? form.shop_type;
});

const shopTypeDescription = computed(() => {
  const map: Record<ShopType, string> = {
    vendor_catalog: t('shop_admin.create_type_catalog_desc'),
    fixed_price: t('shop_admin.create_type_stock_desc'),
    dropship: t('shop_admin.create_type_dropship_desc'),
  };
  return map[form.shop_type] ?? '';
});

const orderModeOptions = computed(() => {
  const all = [
    {
      value: 'procurement_intent' as ShopOrderMode,
      label: t('shop_admin.order_mode_procurement_intent'),
      description: t('shop_admin.help_procurement_intent_desc'),
    },
    {
      value: 'checkout_fixed' as ShopOrderMode,
      label: t('shop_admin.order_mode_checkout_fixed'),
      description: t('shop_admin.help_fixed_checkout_desc'),
    },
    {
      value: 'checkout_wholesale' as ShopOrderMode,
      label: t('shop_admin.order_mode_checkout_wholesale'),
      description: t('shop_admin.help_wholesale_checkout_desc'),
    },
  ];
  const allowed = getAllowedOrderModes(form.shop_type);
  return all.filter((o) => allowed.includes(o.value));
});

const selectedOrderModeHint = computed(
  () => orderModeOptions.value.find((o) => o.value === form.order_mode)?.description ?? '',
);

const pricingMethodOptions = computed(() => [
  {
    value: 'direct_cost',
    label: t('shop_admin.pricing_direct_cost'),
    description: t('shop_admin.pricing_direct_cost_hint'),
  },
  {
    value: 'markup',
    label: t('shop_admin.pricing_markup'),
    description: t('shop_admin.pricing_markup_hint'),
  },
]);

const selectedPricingHint = computed(
  () => pricingMethodOptions.value.find((o) => o.value === form.pricing_method)?.description ?? '',
);

const qtyDisplayOptions = computed(() => [
  {
    value: 'original',
    label: t('shop_admin.qty_display_original'),
    description: t('shop_admin.qty_display_original_hint'),
  },
  {
    value: 'custom_override',
    label: t('shop_admin.qty_display_override'),
    description: t('shop_admin.qty_display_override_hint'),
  },
]);

const getVendorLabel = (code: string) => {
  const opt = vendorOptions.value.find((o) => o.code === code);
  return opt ? opt.label : code;
};

const loadBrandsForVendor = async (vendorCode: string) => {
  if (vendorBrandsMap[vendorCode]) return;
  loadingBrandsMap[vendorCode] = true;
  try {
    const res = await productService.listBrands({ vendorCode, tenantId: form.tenant_id });
    vendorBrandsMap[vendorCode] = res.success && res.data ? res.data : [];
  } catch {
    vendorBrandsMap[vendorCode] = [];
  } finally {
    loadingBrandsMap[vendorCode] = false;
  }
};

const loadVendors = async () => {
  loadingVendors.value = true;
  const { vendorService } = await import('src/modules/vendor/services/vendorService');
  const result = await vendorService.listVendors(form.tenant_id);
  vendors.value = result.success && result.data ? result.data : [];
  loadingVendors.value = false;
};

void loadVendors();
if (props.shop.vendor_filters) {
  props.shop.vendor_filters.forEach((vf) => {
    void loadBrandsForVendor(vf.vendor_code);
  });
}

watch(
  () => form.shop_type,
  (shopType) => {
    form.is_negotiable = derivedShopIsNegotiable(shopType);
    if (shopType === 'vendor_catalog') form.order_mode = 'procurement_intent';
    else if (shopType === 'dropship') form.order_mode = 'checkout_fixed';
  },
);

function hasVendor(): boolean {
  return Boolean(
    form.vendor_code.trim() ||
      (form.vendor_filters && form.vendor_filters.length > 0 && form.vendor_filters[0]?.vendor_code),
  );
}

const publishBlockers = computed(() => {
  const blockers: string[] = [];
  if (!form.name.trim()) blockers.push(t('shop_admin.name_required'));
  if (!form.slug.trim()) blockers.push(t('shop_admin.slug_required'));
  if (!form.buy_currency_id) blockers.push(t('shop_admin.cost_currency_required'));
  if (!form.sell_currency_id) blockers.push(t('shop_admin.checkout_currency_required'));
  if (form.shop_type === 'vendor_catalog' && !hasVendor()) {
    blockers.push(t('shop_admin.vendor_required_to_publish'));
  }
  if (
    form.shop_type === 'fixed_price' &&
    form.pricing_method === 'markup' &&
    (form.markup_percentage === null || form.markup_percentage === undefined || form.markup_percentage < 0)
  ) {
    blockers.push(t('shop_admin.markup_non_negative'));
  }
  return blockers;
});

const canPublish = computed(() => publishBlockers.value.length === 0);
const publicToggleDisabled = computed(() => !canPublish.value && !form.is_active);
const publishBlockedReason = computed(() => publishBlockers.value.join(' '));

function validate(): boolean {
  Object.keys(errors).forEach((k) => delete (errors as Record<string, string>)[k]);
  let ok = true;
  if (!form.name.trim()) {
    errors.name = t('shop_admin.name_required');
    ok = false;
  }
  if (!form.slug.trim()) {
    errors.slug = t('shop_admin.slug_required');
    ok = false;
  }

  if (!form.is_active) return ok;

  if (!form.buy_currency_id) {
    errors.buy_currency_id = t('shop_admin.cost_currency_required');
    ok = false;
  }
  if (!form.sell_currency_id) {
    errors.sell_currency_id = t('shop_admin.checkout_currency_required');
    ok = false;
  }
  if (form.shop_type === 'vendor_catalog' && !hasVendor()) {
    errors.vendor_code = t('shop_admin.vendor_required_to_publish');
    ok = false;
  }
  if (
    form.shop_type === 'fixed_price' &&
    form.pricing_method === 'markup' &&
    (form.markup_percentage === null || form.markup_percentage === undefined || form.markup_percentage < 0)
  ) {
    errors.markup_percentage = t('shop_admin.markup_non_negative');
    ok = false;
  }
  return ok;
}

function buildPayload(): UpdateShopPayload | null {
  form.is_negotiable = derivedShopIsNegotiable(form.shop_type);
  if (form.shop_type === 'vendor_catalog' && form.vendor_filters?.[0]) {
    form.vendor_code = form.vendor_filters[0].vendor_code;
  }
  if (!validate()) return null;
  return {
    id: form.id,
    tenant_id: form.tenant_id,
    name: form.name.trim(),
    slug: form.slug.trim(),
    description: form.description?.trim() || null,
    category_ids: form.category_ids || [],
    order_mode: form.order_mode,
    is_negotiable: form.is_negotiable,
    show_stock_quantity: form.show_stock_quantity,
    is_active: form.is_active,
    allow_delivery: form.allow_delivery,
    buy_currency_id: form.buy_currency_id,
    sell_currency_id: form.sell_currency_id,
    default_currency_id: form.sell_currency_id,
    pricing_method: form.pricing_method,
    markup_percentage: Number(form.markup_percentage || 0),
    quantity_display_mode: form.quantity_display_mode,
    default_print_charge_amount: Number(form.default_print_charge_amount || 0),
    default_packing_charge_amount: Number(form.default_packing_charge_amount || 0),
    deduct_charges_from_margin: form.deduct_charges_from_margin,
    deduct_print_from_margin: form.deduct_print_from_margin,
    deduct_packing_from_margin: form.deduct_packing_from_margin,
    vendor_code:
      form.shop_type === 'vendor_catalog' ? form.vendor_code.trim() || null : null,
    vendor_filters: form.shop_type === 'vendor_catalog' ? (form.vendor_filters ?? null) : null,
  };
}

defineExpose({ buildPayload });
</script>
