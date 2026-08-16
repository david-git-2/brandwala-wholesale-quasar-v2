<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card style="min-width: 650px; max-width: 95vw; border-radius: 12px">
      <q-card-section class="row items-center justify-between q-py-md bg-primary text-white">
        <div class="text-h6 row items-center no-wrap">
          <q-icon name="ph ph-question" class="q-mr-sm" size="24px" />
          {{ $t('shop_admin.help_features_guide') }}
        </div>
        <q-btn icon="ph ph-x" flat round dense v-close-popup color="white" />
      </q-card-section>

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

      <q-tab-panels v-model="helpTab" animated class="q-pa-xs">
        <q-tab-panel name="types" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-book-open" color="blue-1" text-color="blue-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.create_type_catalog') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_vendor_catalog_desc') }}</div>
            </div>
          </div>
          <q-separator inset />
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-package" color="green-1" text-color="green-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.create_type_stock') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_fixed_price_desc') }}</div>
            </div>
          </div>
          <q-separator inset />
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-truck" color="orange-1" text-color="orange-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.create_type_dropship') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_dropship_desc') }}</div>
            </div>
          </div>
        </q-tab-panel>

        <q-tab-panel name="modes" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-clipboard-text" color="purple-1" text-color="purple-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.help_procurement_intent_title') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_procurement_intent_desc') }}</div>
            </div>
          </div>
          <q-separator inset />
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-shopping-cart" color="teal-1" text-color="teal-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.help_fixed_checkout_title') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_fixed_checkout_desc') }}</div>
            </div>
          </div>
          <q-separator inset />
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-briefcase" color="indigo-1" text-color="indigo-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.help_wholesale_checkout_title') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_wholesale_checkout_desc') }}</div>
            </div>
          </div>
        </q-tab-panel>

        <q-tab-panel name="settings" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-coin" color="yellow-2" text-color="yellow-9" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.help_currencies_title') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_currencies_desc') }}</div>
            </div>
          </div>
          <q-separator inset />
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-calculator" color="indigo-1" text-color="indigo-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.help_retail_pricing_title') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_retail_pricing_desc') }}</div>
            </div>
          </div>
          <q-separator inset />
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="ph ph-chart-bar" color="cyan-1" text-color="cyan-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-subtitle2">{{ $t('shop_admin.help_qty_display_title') }}</div>
              <div class="text-caption text-grey-7">{{ $t('shop_admin.help_qty_display_desc') }}</div>
            </div>
          </div>
        </q-tab-panel>

        <q-tab-panel name="scenarios">
          <ShopScenarioFinder
            :presets="SHOP_CONFIGURATION_PRESETS"
            show-all-cards
            apply-disabled
            :apply-disabled-tooltip="$t('shop_admin.shop_type_locked')"
          />
        </q-tab-panel>
      </q-tab-panels>

      <q-separator />
      <q-card-actions align="right" class="q-pr-md q-pb-md">
        <q-btn :label="$t('shop_admin.got_it')" color="primary" unelevated v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { SHOP_CONFIGURATION_PRESETS } from 'src/modules/shop_order/constants/shopConfigurationPresets';
import ShopScenarioFinder from 'src/modules/shop_order/components/ShopScenarioFinder.vue';

defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const helpTab = ref('types');
</script>
