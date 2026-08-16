<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 480px; max-width: 96vw; border-radius: 12px">
      <q-card-section class="row items-center justify-between q-px-lg q-py-md">
        <div>
          <div class="text-h6 text-weight-medium">{{ $t('shop_admin.create_shop') }}</div>
          <div class="text-caption text-grey-6 q-mt-xs">
            {{ $t('shop_admin.create_shop_caption') }}
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" color="grey-7" v-close-popup />
      </q-card-section>

      <q-card-section class="q-px-lg q-pt-none q-pb-md">
        <q-input
          v-model="name"
          :label="$t('shop_admin.shop_name') + ' *'"
          outlined
          dense
          class="q-mb-md"
          :error="!!errors.name"
          :error-message="errors.name"
        />

        <div class="text-subtitle2 text-weight-medium q-mb-sm">
          {{ $t('shop_admin.create_pick_type') }}
        </div>
        <div class="q-gutter-y-sm">
          <q-card
            v-for="opt in typeOptions"
            :key="opt.value"
            flat
            bordered
            class="cursor-pointer shop-type-card"
            :class="{ 'shop-type-card--selected': shopType === opt.value }"
            @click="shopType = opt.value"
          >
            <q-card-section class="row items-start no-wrap q-py-sm q-px-md">
              <q-icon :name="opt.icon" size="22px" :color="opt.color" class="q-mt-xs q-mr-md" />
              <div>
                <div class="text-weight-medium">{{ opt.label }}</div>
                <div class="text-caption text-grey-7">{{ opt.description }}</div>
              </div>
            </q-card-section>
          </q-card>
        </div>
        <div v-if="errors.shop_type" class="text-negative text-caption q-mt-xs">
          {{ errors.shop_type }}
        </div>

        <q-banner v-if="saveError" class="text-white bg-negative q-mt-md" rounded dense>
          {{ saveError }}
        </q-banner>
      </q-card-section>

      <q-card-actions align="right" class="q-px-lg q-pb-md q-pt-none">
        <q-btn flat :label="$t('shop_admin.cancel')" :disable="saving" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          no-caps
          :label="$t('shop_admin.create_and_continue')"
          :loading="saving || loadingCurrencies"
          :disable="saving"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import type { CreateShopPayload, ShopType } from 'src/modules/shop_order/types';
import {
  createDefaultsForShopType,
  pickShopCurrencyDefaults,
  slugFromShopName,
} from 'src/modules/shop_order/constants/shopConfigurationPresets';
import { useGlobalCurrenciesQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';

const props = defineProps<{
  modelValue: boolean;
  tenantId: number;
  saving?: boolean;
  saveError?: string | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save', value: CreateShopPayload): void;
}>();

const { t } = useI18n();
const { data: currencies, isLoading: loadingCurrencies } = useGlobalCurrenciesQuery();

const localModelValue = computed({
  get: () => props.modelValue,
  set: (v: boolean) => emit('update:modelValue', v),
});

const name = ref('');
const shopType = ref<ShopType | null>(null);
const errors = reactive<{ name?: string; shop_type?: string }>({});

const typeOptions = computed(() => [
  {
    value: 'vendor_catalog' as const,
    label: t('shop_admin.create_type_catalog'),
    description: t('shop_admin.create_type_catalog_desc'),
    icon: 'ph ph-book-open',
    color: 'indigo',
  },
  {
    value: 'fixed_price' as const,
    label: t('shop_admin.create_type_stock'),
    description: t('shop_admin.create_type_stock_desc'),
    icon: 'ph ph-package',
    color: 'teal',
  },
  {
    value: 'dropship' as const,
    label: t('shop_admin.create_type_dropship'),
    description: t('shop_admin.create_type_dropship_desc'),
    icon: 'ph ph-truck',
    color: 'deep-orange',
  },
]);

watch(
  () => props.modelValue,
  (opened) => {
    if (!opened) return;
    name.value = '';
    shopType.value = null;
    Object.keys(errors).forEach((k) => delete (errors as Record<string, string>)[k]);
  },
);

const onSave = () => {
  Object.keys(errors).forEach((k) => delete (errors as Record<string, string>)[k]);

  if (!name.value.trim()) {
    errors.name = t('shop_admin.name_required');
    return;
  }
  if (!shopType.value) {
    errors.shop_type = t('shop_admin.shop_type_required');
    return;
  }

  const slug = slugFromShopName(name.value);
  if (!slug) {
    errors.name = t('shop_admin.slug_required');
    return;
  }

  const currencyIds = pickShopCurrencyDefaults(currencies.value ?? []);
  if (!currencyIds) {
    errors.shop_type = t('shop_admin.checkout_currency_required');
    return;
  }

  const defaults = createDefaultsForShopType(shopType.value);

  emit('save', {
    tenant_id: props.tenantId,
    name: name.value.trim(),
    slug,
    ...defaults,
    ...currencyIds,
    default_currency_id: currencyIds.sell_currency_id,
    vendor_code: null,
    description: null,
    category_ids: [],
  });
};
</script>

<style scoped>
.shop-type-card {
  border-radius: 8px;
}
.shop-type-card--selected {
  border-color: var(--q-primary);
  box-shadow: inset 3px 0 0 var(--q-primary);
}
</style>
