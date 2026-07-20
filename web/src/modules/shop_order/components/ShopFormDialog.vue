<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 560px; max-width: 96vw; border-radius: 12px">
      <!-- Header -->
      <q-card-section class="row items-center justify-between q-px-lg q-py-md">
        <div>
          <div class="text-h6 text-weight-medium">
            {{ isEdit ? $t('shop_admin.edit_shop') : $t('shop_admin.create_shop') }}
          </div>
          <div v-if="isEdit" class="q-mt-xs">
            <div class="text-caption text-grey-6 q-mb-xs">
              {{ $t('shop_admin.shop_type_locked') }}
            </div>
            <q-chip
              clickable
              dense
              :color="detectedPresetId ? 'blue-1' : 'grey-2'"
              :text-color="detectedPresetId ? 'primary' : 'grey-8'"
              icon="category"
              size="sm"
              @click="openScenariosHelp"
            >
              {{ detectedPresetBadgeLabel }}
              <q-tooltip>{{ $t('shop_admin.view_scenario_guide') }}</q-tooltip>
            </q-chip>
          </div>
        </div>
        <q-btn flat round dense icon="info" color="primary" @click="showHelpDialog = true">
          <q-tooltip>{{ $t('shop_admin.shop_functionality_guide') }}</q-tooltip>
        </q-btn>
      </q-card-section>

      <!-- Form Body -->
      <q-card-section class="q-px-lg q-pt-none q-pb-md">
        <ShopPresetPicker
          v-if="!isEdit"
          :model-value="selectedPresetId"
          :presets="SHOP_CONFIGURATION_PRESETS"
          :banner-text="appliedPresetBanner"
          @update:model-value="onPresetSelect"
        />

        <!-- Name + Slug -->
        <div class="row q-col-gutter-md items-start q-mb-md">
          <div class="col-7">
            <q-input
              v-model="form.name"
              :label="$t('shop_admin.shop_name') + ' *'"
              outlined
              dense
              :error="!!errors.name"
              :error-message="errors.name"
              @update:model-value="(val) => syncSlug(String(val ?? ''))"
            />
          </div>
          <div class="col-5">
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

        <!-- Shop type (create-only) -->
        <q-select
          v-if="!isEdit"
          v-model="form.shop_type"
          :options="shopTypeOptions"
          emit-value
          map-options
          :label="$t('shop_admin.shop_type') + ' *'"
          outlined
          dense
          class="q-mb-md"
          :error="!!errors.shop_type"
          :error-message="errors.shop_type"
        />

        <!-- vendor_code — only for vendor_catalog, create-only -->
        <q-select
          v-if="!isEdit && form.shop_type === 'vendor_catalog'"
          v-model="form.vendor_code"
          :options="vendorOptions"
          option-value="code"
          option-label="label"
          emit-value
          map-options
          :loading="loadingVendors"
          :label="$t('shop_admin.vendor') + ' *'"
          outlined
          dense
          class="q-mb-md"
          :hint="$t('shop_admin.vendor_hint')"
          :error="!!errors.vendor_code"
          :error-message="errors.vendor_code"
        >
          <template #no-option>
            <q-item>
              <q-item-section class="text-grey-6">
                {{ loadingVendors ? $t('shop_admin.loading_vendors') : $t('shop_admin.no_vendors') }}
              </q-item-section>
            </q-item>
          </template>
        </q-select>

        <!-- Shop type locked label when editing -->
        <div v-if="isEdit && shopTypeLabel" class="q-mb-md q-pa-sm bg-grey-2 rounded-borders">
          <div class="text-caption text-grey-6">{{ $t('shop_admin.shop_type') }}</div>
          <div class="text-body2 text-weight-medium text-grey-8">{{ shopTypeLabel }}</div>
        </div>

        <!-- Order mode -->
        <q-select
          v-model="form.order_mode"
          :options="orderModeOptions"
          emit-value
          map-options
          :label="$t('shop_admin.order_mode') + ' *'"
          outlined
          dense
          class="q-mb-md"
        />

        <!-- Currencies Selection -->
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-6">
            <q-select
              v-model="form.buy_currency_id"
              :options="currencyOptions"
              emit-value
              map-options
              :loading="loadingCurrencies"
              :label="$t('shop_admin.buy_currency') + ' *'"
              outlined
              dense
              :error="!!errors.buy_currency_id"
              :error-message="errors.buy_currency_id"
              :rules="[(val) => !!val || $t('shop_admin.buy_currency_required')]"
            />
          </div>
          <div class="col-6">
            <q-select
              v-model="form.sell_currency_id"
              :options="currencyOptions"
              emit-value
              map-options
              :loading="loadingCurrencies"
              :label="$t('shop_admin.sell_currency') + ' *'"
              outlined
              dense
              :error="!!errors.sell_currency_id"
              :error-message="errors.sell_currency_id"
              :rules="[(val) => !!val || $t('shop_admin.sell_currency_required')]"
            />
          </div>
        </div>

        <!-- Retail & Dropship Specific Configurations -->
        <div
          v-if="
            form.shop_type === 'fixed_price' ||
            form.shop_type === 'dropship' ||
            (isEdit && (shopTypeSnapshot === 'fixed_price' || shopTypeSnapshot === 'dropship'))
          "
          class="q-pa-md bg-blue-50 rounded-borders q-mb-md border-blue-100"
          style="background-color: #f0f7ff; border: 1px solid #d0e7ff; border-radius: 8px"
        >
          <div class="text-subtitle2 text-blue-9 text-weight-medium q-mb-sm">
            {{
              form.shop_type === 'dropship'
                ? $t('shop_admin.dropship_qty_settings')
                : $t('shop_admin.retail_pricing_qty')
            }}
          </div>

          <div
            v-if="form.shop_type === 'fixed_price' || (isEdit && shopTypeSnapshot === 'fixed_price')"
            class="row q-col-gutter-md items-center q-mb-sm"
          >
            <div class="col-6">
              <q-select
                v-model="form.pricing_method"
                :options="pricingMethodOptions"
                emit-value
                map-options
                :label="$t('shop_admin.pricing_method') + ' *'"
                outlined
                dense
              />
            </div>
            <div class="col-6" v-if="form.pricing_method === 'markup'">
              <q-input
                v-model.number="form.markup_percentage"
                type="number"
                :label="$t('shop_admin.markup_pct') + ' *'"
                suffix="%"
                outlined
                dense
                :error="!!errors.markup_percentage"
                :error-message="errors.markup_percentage"
                :rules="[
                  (val) => (val !== null && val !== undefined) || $t('shop_admin.markup_required'),
                  (val) => val >= 0 || $t('shop_admin.markup_non_negative'),
                ]"
              />
            </div>
          </div>

          <div class="row q-mb-sm">
            <div class="col-12">
              <q-select
                v-model="form.quantity_display_mode"
                :options="qtyDisplayOptions"
                emit-value
                map-options
                :label="$t('shop_admin.qty_display_mode') + ' *'"
                outlined
                dense
              />
            </div>
          </div>
        </div>

        <!-- Dropship specific charge defaults configuration -->
        <div
          v-if="form.shop_type === 'dropship' || (isEdit && shopTypeSnapshot === 'dropship')"
          class="q-pa-md bg-orange-50 rounded-borders q-mb-md border-orange-100"
          style="background-color: #fffaf0; border: 1px solid #ffe0b2; border-radius: 8px"
        >
          <div class="text-subtitle2 text-orange-9 text-weight-medium q-mb-sm">
            {{ $t('shop_admin.dropship_default_charges') }}
          </div>
          <div class="row q-col-gutter-md q-mb-sm">
            <div class="col-6">
              <q-input
                v-model.number="form.default_cod_charge_pct"
                type="number"
                :label="$t('shop_admin.default_cod_charge_pct')"
                suffix="%"
                outlined
                dense
              />
            </div>
            <div class="col-6">
              <q-input
                v-model.number="form.default_delivery_charge_amount"
                type="number"
                :label="$t('shop_admin.default_delivery_charge')"
                outlined
                dense
              />
            </div>
          </div>
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
        </div>

        <!-- Flags row -->
        <div class="row q-col-gutter-md items-center q-mb-md">
          <div class="col-auto">
            <q-toggle
              v-model="form.is_negotiable"
              :disable="
                form.shop_type === 'dropship' || (isEdit && shopTypeSnapshot === 'dropship')
              "
              :label="$t('shop_admin.negotiable')"
              color="primary"
            />
          </div>
          <div class="col-auto">
            <q-toggle v-model="form.show_stock_quantity" :label="$t('shop_admin.show_stock_qty')" color="primary" />
          </div>
          <div class="col-auto">
            <q-toggle v-model="form.is_active" :label="$t('shop_admin.active')" color="positive" />
          </div>
          <div
            v-if="
              form.shop_type === 'fixed_price' || (isEdit && shopTypeSnapshot === 'fixed_price')
            "
            class="col-auto"
          >
            <q-toggle v-model="form.allow_delivery" :label="$t('shop_admin.allow_delivery')" color="primary" />
          </div>
        </div>

        <!-- Error banner -->
        <q-banner v-if="saveError" class="text-white bg-negative q-mt-md" rounded dense>
          {{ saveError }}
        </q-banner>
      </q-card-section>

      <!-- Actions -->
      <q-card-actions align="right" class="q-px-lg q-pb-md q-pt-none">
        <q-btn flat :label="$t('shop_admin.cancel')" :disable="saving" @click="localModelValue = false" />
        <q-btn
          color="primary"
          unelevated
          :label="isEdit ? $t('shop_admin.update') : $t('shop_admin.create_shop')"
          :loading="saving"
          :disable="saving"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>

  <!-- Help Dialog explaining functionalities -->
  <q-dialog v-model="showHelpDialog">
    <q-card style="min-width: 650px; max-width: 95vw; border-radius: 12px">
      <!-- Header -->
      <q-card-section class="row items-center justify-between q-py-md bg-primary text-white">
        <div class="text-h6 row items-center no-wrap">
          <q-icon name="help_outline" class="q-mr-sm" size="24px" />
          {{ $t('shop_admin.help_features_guide') }}
        </div>
        <q-btn icon="close" flat round dense v-close-popup color="white" />
      </q-card-section>

      <!-- Tabs Navigation -->
      <q-tabs
        v-model="helpTab"
        dense
        class="text-grey-7"
        active-color="primary"
        indicator-color="primary"
        align="justify"
        narrow-indicator
      >
        <q-tab name="types" :label="$t('shop_admin.help_tab_types')" />
        <q-tab name="modes" :label="$t('shop_admin.help_tab_modes')" />
        <q-tab name="settings" :label="$t('shop_admin.help_tab_settings')" />
        <q-tab name="scenarios" :label="$t('shop_admin.help_tab_scenarios')" />
      </q-tabs>

      <q-separator />

      <!-- Tab Panels Content -->
      <q-tab-panels v-model="helpTab" animated class="q-pa-xs">
        <!-- Shop Types -->
        <q-tab-panel name="types" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="storefront"
              color="blue-1"
              text-color="blue-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_vendor_catalog_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_vendor_catalog_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="local_offer"
              color="green-1"
              text-color="green-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_fixed_price_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_fixed_price_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="local_shipping"
              color="orange-1"
              text-color="orange-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_dropship_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_dropship_desc') }}
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- Order Modes -->
        <q-tab-panel name="modes" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="assignment"
              color="purple-1"
              text-color="purple-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_procurement_intent_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_procurement_intent_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="shopping_cart"
              color="teal-1"
              text-color="teal-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_fixed_checkout_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_fixed_checkout_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="business"
              color="indigo-1"
              text-color="indigo-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_wholesale_checkout_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_wholesale_checkout_desc') }}
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- Settings -->
        <q-tab-panel name="settings" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="forum" color="pink-1" text-color="pink-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_negotiable_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_negotiable_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="visibility"
              color="cyan-1"
              text-color="cyan-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_show_stock_qty_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_show_stock_qty_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="monetization_on"
              color="yellow-2"
              text-color="yellow-9"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_currencies_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_currencies_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="calculate"
              color="indigo-1"
              text-color="indigo-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_retail_pricing_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_retail_pricing_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar
              icon="bar_chart"
              color="cyan-1"
              text-color="cyan-8"
              size="md"
              class="q-mr-md"
            />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_qty_display_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_qty_display_desc') }}
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="check_circle" color="positive" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">
                {{ $t('shop_admin.help_active_title') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.help_active_desc') }}
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- Scenarios -->
        <q-tab-panel name="scenarios" class="q-gutter-y-sm">
          <ShopScenarioFinder
            :presets="SHOP_CONFIGURATION_PRESETS"
            show-all-cards
            :highlight-id="scenarioHighlightId"
            :apply-disabled="isEdit"
            :apply-disabled-tooltip="$t('shop_admin.shop_type_locked')"
            @select="onHelpScenarioSelect"
          />
        </q-tab-panel>
      </q-tab-panels>

      <q-separator />

      <!-- Footer Actions -->
      <q-card-actions align="right" class="q-pr-md q-pb-md">
        <q-btn :label="$t('shop_admin.got_it')" color="primary" unelevated v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import type { Shop, ShopType, ShopOrderMode } from 'src/modules/shop_order/types';
import {
  SHOP_CONFIGURATION_PRESETS,
  applyPresetToForm,
  detectPresetFromShop,
  formMatchesPreset,
  getAllowedOrderModes,
  getPresetById,
  type ShopConfigurationPresetId,
} from 'src/modules/shop_order/constants/shopConfigurationPresets';
import { showErrorNotification } from 'src/utils/appFeedback';
import { useShopLocale } from '../composables/useShopLocale';
import ShopScenarioFinder from 'src/modules/shop_order/components/ShopScenarioFinder.vue';
import ShopPresetPicker from 'src/modules/shop_order/components/ShopPresetPicker.vue';
import { vendorService } from 'src/modules/vendor/services/vendorService';
import type { Vendor } from 'src/modules/vendor/types';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import type { GlobalCurrency } from 'src/modules/global_reference/types';

// ---- types ---------------------------------------------------------

type ShopForm = {
  id?: number;
  tenant_id: number;
  name: string;
  slug: string;
  shop_type: ShopType | null;
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
  default_cod_charge_pct?: number;
  default_delivery_charge_amount?: number;
  default_print_charge_amount?: number;
  default_packing_charge_amount?: number;
};

type FormErrors = {
  name?: string;
  slug?: string;
  shop_type?: string;
  vendor_code?: string;
  buy_currency_id?: string;
  sell_currency_id?: string;
  markup_percentage?: string;
};

// ---- props / emits -------------------------------------------------

const props = defineProps<{
  modelValue: boolean;
  initialData?: Shop | null;
  tenantId: number;
  saving?: boolean;
  saveError?: string | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save', value: any): void;
}>();

const { t } = useI18n();
const { presetName } = useShopLocale();

// ---- local state ---------------------------------------------------

const localModelValue = computed({
  get: () => props.modelValue,
  set: (v: boolean) => emit('update:modelValue', v),
});

const showHelpDialog = ref(false);
const helpTab = ref('types');

const errors = reactive<FormErrors>({});
const shopTypeSnapshot = ref<ShopType | null>(null);

const defaultForm = (): ShopForm => ({
  tenant_id: props.tenantId,
  name: '',
  slug: '',
  shop_type: null,
  vendor_code: '',
  order_mode: 'procurement_intent',
  is_negotiable: false,
  show_stock_quantity: true,
  is_active: true,
  allow_delivery: false,
  buy_currency_id: null,
  sell_currency_id: null,
  pricing_method: 'direct_cost',
  markup_percentage: 0,
  quantity_display_mode: 'original',
  default_cod_charge_pct: 0,
  default_delivery_charge_amount: 0,
  default_print_charge_amount: 0,
  default_packing_charge_amount: 0,
});

const form = reactive<ShopForm>(defaultForm());
const isEdit = computed(() => typeof form.id === 'number');

const detectedPresetId = computed(() => {
  if (!isEdit.value || !props.initialData) return null;
  return detectPresetFromShop(props.initialData);
});

const detectedPresetBadgeLabel = computed(() => {
  const id = detectedPresetId.value;
  if (!id) return t('shop_admin.custom_configuration');
  const preset = getPresetById(id);
  return preset ? t('shop_admin.matches_preset', { name: presetName(preset) }) : t('shop_admin.custom_configuration');
});

const scenarioHighlightId = computed((): ShopConfigurationPresetId | null => {
  if (isEdit.value) return detectedPresetId.value;
  const id = selectedPresetId.value;
  if (!id || id === 'custom') return null;
  return id;
});

const openScenariosHelp = () => {
  helpTab.value = 'scenarios';
  showHelpDialog.value = true;
};

const selectedPresetId = ref<ShopConfigurationPresetId | 'custom' | null>(null);

const appliedPresetBanner = computed(() => {
  if (!selectedPresetId.value || selectedPresetId.value === 'custom') return null;
  const preset = getPresetById(selectedPresetId.value);
  if (!preset) return null;
  const markupHint =
    preset.fields.pricing_method === 'markup' ? t('shop_admin.preset_markup_hint') : '';
  return t('shop_admin.preset_applied', { id: preset.id, markup: markupHint });
});

function onPresetSelect(value: ShopConfigurationPresetId | 'custom') {
  selectedPresetId.value = value;
  if (value === 'custom') return;
  applyPresetToForm(form, value);
}

const onHelpScenarioSelect = (id: ShopConfigurationPresetId) => {
  if (isEdit.value) {
    showErrorNotification(t('shop_admin.preset_locked_edit'));
    return;
  }
  applyPresetToForm(form, id);
  selectedPresetId.value = id;
  showHelpDialog.value = false;
};

const vendors = ref<Vendor[]>([]);
const loadingVendors = ref(false);

const vendorOptions = computed(() =>
  vendors.value.map((v) => ({ code: v.code, label: `${v.name} (${v.code})` })),
);

const loadVendors = async () => {
  loadingVendors.value = true;
  const result = await vendorService.listVendors(props.tenantId);
  vendors.value = result.success && result.data ? result.data : [];
  loadingVendors.value = false;
};

const currencies = ref<GlobalCurrency[]>([]);
const loadingCurrencies = ref(false);

const currencyOptions = computed(() =>
  currencies.value.map((c) => ({ value: c.id, label: `${c.name} (${c.code})` })),
);

const loadCurrencies = async () => {
  loadingCurrencies.value = true;
  try {
    currencies.value = await globalReferenceRepository.listCurrencies();
  } catch (e) {
    console.error('Failed to load currencies', e);
  } finally {
    loadingCurrencies.value = false;
  }
};

// ---- label helpers -------------------------------------------------

const shopTypeOptions = computed(() => [
  { value: 'vendor_catalog', label: t('shop_admin.shop_type_vendor_catalog') },
  { value: 'fixed_price', label: t('shop_admin.shop_type_fixed_price') },
  { value: 'dropship', label: t('shop_admin.shop_type_dropship') },
]);

const allOrderModeOptions = computed(() => [
  { value: 'procurement_intent' as ShopOrderMode, label: t('shop_admin.order_mode_procurement_intent') },
  { value: 'checkout_fixed' as ShopOrderMode, label: t('shop_admin.order_mode_checkout_fixed') },
  { value: 'checkout_wholesale' as ShopOrderMode, label: t('shop_admin.order_mode_checkout_wholesale') },
]);

const pricingMethodOptions = computed(() => [
  { value: 'direct_cost', label: t('shop_admin.pricing_direct_cost') },
  { value: 'markup', label: t('shop_admin.pricing_markup') },
]);

const qtyDisplayOptions = computed(() => [
  { value: 'original', label: t('shop_admin.qty_display_original') },
  { value: 'custom_override', label: t('shop_admin.qty_display_override') },
]);

const orderModeOptions = computed(() => {
  if (!form.shop_type) return allOrderModeOptions.value;
  const allowed = getAllowedOrderModes(form.shop_type);
  return allOrderModeOptions.value.filter((o) => allowed.includes(o.value));
});

const shopTypeLabel = computed(() => {
  const found = shopTypeOptions.value.find((o) => o.value === shopTypeSnapshot.value);
  return found?.label ?? shopTypeSnapshot.value ?? '';
});

// ---- slug auto-fill ------------------------------------------------

const syncSlug = (val: string) => {
  if (isEdit.value) return;
  form.slug = val
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');
};

// ---- watch open ----------------------------------------------------

watch(
  [() => props.modelValue, () => props.initialData, () => props.tenantId],
  ([opened, initialData, tenantId]) => {
    if (!opened) return;

    Object.keys(errors).forEach((k) => delete (errors as any)[k]);

    void loadVendors();
    void loadCurrencies();

    if (initialData) {
      shopTypeSnapshot.value = initialData.shop_type;
      Object.assign(form, {
        id: initialData.id,
        tenant_id: initialData.tenant_id,
        name: initialData.name,
        slug: initialData.slug,
        shop_type: initialData.shop_type,
        vendor_code: initialData.vendor_code ?? '',
        order_mode: initialData.order_mode,
        is_negotiable: initialData.is_negotiable,
        show_stock_quantity: initialData.show_stock_quantity,
        is_active: initialData.is_active,
        allow_delivery: initialData.allow_delivery || false,
        buy_currency_id: initialData.buy_currency_id,
        sell_currency_id: initialData.sell_currency_id,
        pricing_method: initialData.pricing_method || 'direct_cost',
        markup_percentage: initialData.markup_percentage || 0,
        quantity_display_mode: initialData.quantity_display_mode || 'original',
        default_cod_charge_pct: initialData.default_cod_charge_pct || 0,
        default_delivery_charge_amount: initialData.default_delivery_charge_amount || 0,
        default_print_charge_amount: initialData.default_print_charge_amount || 0,
        default_packing_charge_amount: initialData.default_packing_charge_amount || 0,
      });
    } else {
      shopTypeSnapshot.value = null;
      selectedPresetId.value = null;
      Object.assign(form, { ...defaultForm(), tenant_id: tenantId });
    }
  },
  { immediate: true },
);

watch(
  () => form.shop_type,
  (shopType) => {
    if (!shopType) return;

    if (shopType === 'vendor_catalog') {
      form.order_mode = 'procurement_intent';
    } else if (shopType === 'dropship') {
      form.order_mode = 'checkout_fixed';
      form.is_negotiable = false;
    } else if (shopType === 'fixed_price') {
      const allowed = getAllowedOrderModes('fixed_price');
      if (!allowed.includes(form.order_mode)) {
        form.order_mode = 'checkout_fixed';
      }
    }
  },
);

watch(
  () => [
    form.shop_type,
    form.order_mode,
    form.is_negotiable,
    form.pricing_method,
    form.markup_percentage,
    form.quantity_display_mode,
    form.show_stock_quantity,
  ],
  () => {
    const id = selectedPresetId.value;
    if (!id || id === 'custom') return;
    if (!formMatchesPreset(form, id)) {
      selectedPresetId.value = 'custom';
    }
  },
);

// ---- validation + save ---------------------------------------------

const validate = (): boolean => {
  Object.keys(errors).forEach((k) => delete (errors as any)[k]);
  let ok = true;

  if (!form.name.trim()) {
    errors.name = t('shop_admin.name_required');
    ok = false;
  }
  if (!form.slug.trim()) {
    errors.slug = t('shop_admin.slug_required');
    ok = false;
  }
  if (!isEdit.value && !form.shop_type) {
    errors.shop_type = t('shop_admin.shop_type_required');
    ok = false;
  }
  if (!isEdit.value && form.shop_type === 'vendor_catalog' && !form.vendor_code.trim()) {
    errors.vendor_code = t('shop_admin.vendor_required');
    ok = false;
  }
  if (!form.buy_currency_id) {
    errors.buy_currency_id = t('shop_admin.buy_currency_required');
    ok = false;
  }
  if (!form.sell_currency_id) {
    errors.sell_currency_id = t('shop_admin.sell_currency_required');
    ok = false;
  }
  const isFixedPrice =
    form.shop_type === 'fixed_price' || shopTypeSnapshot.value === 'fixed_price';
  if (
    isFixedPrice &&
    form.pricing_method === 'markup' &&
    (form.markup_percentage === null ||
      form.markup_percentage === undefined ||
      form.markup_percentage < 0)
  ) {
    errors.markup_percentage = t('shop_admin.markup_non_negative');
    ok = false;
  }

  return ok;
};

const onSave = () => {
  if (form.shop_type === 'dropship' || shopTypeSnapshot.value === 'dropship') {
    form.is_negotiable = false;
  }

  if (!validate()) return;

  if (isEdit.value) {
    emit('save', {
      id: form.id,
      tenant_id: form.tenant_id,
      name: form.name.trim(),
      slug: form.slug.trim(),
      order_mode: form.order_mode,
      is_negotiable: form.is_negotiable,
      show_stock_quantity: form.show_stock_quantity,
      is_active: form.is_active,
      allow_delivery: form.allow_delivery,
      buy_currency_id: form.buy_currency_id,
      sell_currency_id: form.sell_currency_id,
      pricing_method: form.pricing_method,
      markup_percentage: Number(form.markup_percentage || 0),
      quantity_display_mode: form.quantity_display_mode,
      default_cod_charge_pct: Number(form.default_cod_charge_pct || 0),
      default_delivery_charge_amount: Number(form.default_delivery_charge_amount || 0),
      default_print_charge_amount: Number(form.default_print_charge_amount || 0),
      default_packing_charge_amount: Number(form.default_packing_charge_amount || 0),
    });
  } else {
    emit('save', {
      tenant_id: form.tenant_id,
      name: form.name.trim(),
      slug: form.slug.trim(),
      shop_type: form.shop_type,
      vendor_code: form.shop_type === 'vendor_catalog' ? form.vendor_code.trim() : null,
      order_mode: form.order_mode,
      is_negotiable: form.is_negotiable,
      show_stock_quantity: form.show_stock_quantity,
      is_active: form.is_active,
      allow_delivery: form.allow_delivery,
      buy_currency_id: form.buy_currency_id,
      sell_currency_id: form.sell_currency_id,
      pricing_method: form.pricing_method,
      markup_percentage: Number(form.markup_percentage || 0),
      quantity_display_mode: form.quantity_display_mode,
      default_cod_charge_pct: Number(form.default_cod_charge_pct || 0),
      default_delivery_charge_amount: Number(form.default_delivery_charge_amount || 0),
      default_print_charge_amount: Number(form.default_print_charge_amount || 0),
      default_packing_charge_amount: Number(form.default_packing_charge_amount || 0),
    });
  }
};
</script>
