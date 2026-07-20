<template>
  <div class="shop-preset-picker q-mb-md">
    <div class="text-subtitle2 text-weight-medium q-mb-xs">
      Start from a preset / প্রিসেট থেকে শুরু করুন
    </div>
    <div class="row q-gutter-sm">
      <q-chip
        v-for="preset in presets"
        :key="preset.id"
        clickable
        dense
        :outline="modelValue !== preset.id"
        :color="modelValue === preset.id ? 'primary' : 'grey-7'"
        :text-color="modelValue === preset.id ? 'white' : undefined"
        @click="emit('update:modelValue', preset.id)"
      >
        <span class="text-weight-medium">{{ preset.id }} — {{ shortLabel(preset.id) }}</span>
        <span v-if="shortLabelBn(preset.id)" class="q-ml-xs text-caption opacity-80">
          {{ shortLabelBn(preset.id) }}
        </span>
      </q-chip>
      <q-chip
        clickable
        dense
        :outline="modelValue !== 'custom'"
        :color="modelValue === 'custom' ? 'primary' : 'grey-7'"
        :text-color="modelValue === 'custom' ? 'white' : undefined"
        @click="emit('update:modelValue', 'custom')"
      >
        <span class="text-weight-medium">Custom</span>
        <span class="q-ml-xs text-caption opacity-80">ম্যানুয়ালি কনফিগার</span>
      </q-chip>
    </div>
    <q-banner
      v-if="bannerText"
      dense
      rounded
      class="bg-blue-1 text-primary q-mt-sm"
      style="border-radius: 8px"
    >
      <template #avatar>
        <q-icon name="check_circle" color="primary" />
      </template>
      {{ bannerText }}
    </q-banner>
  </div>
</template>

<script setup lang="ts">
import type {
  ShopConfigurationPreset,
  ShopConfigurationPresetId,
} from 'src/modules/shop_order/constants/shopConfigurationPresets';

defineProps<{
  modelValue: ShopConfigurationPresetId | 'custom' | null;
  presets: ShopConfigurationPreset[];
  bannerText?: string | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: ShopConfigurationPresetId | 'custom'): void;
}>();

const SHORT_LABELS: Record<ShopConfigurationPresetId, string> = {
  A: 'Procurement',
  B: 'Catalog',
  C: 'Retail markup',
  D: 'Direct cost',
  E: 'Wholesale',
  F: 'Dropship',
};

const SHORT_LABELS_BN: Record<ShopConfigurationPresetId, string> = {
  A: 'ক্রয়',
  B: 'ক্যাটালগ',
  C: 'মার্কআপ',
  D: 'সরাসরি খরচ',
  E: 'পাইকারি',
  F: 'ড্রপশিপ',
};

function shortLabel(id: ShopConfigurationPresetId): string {
  return SHORT_LABELS[id];
}

function shortLabelBn(id: ShopConfigurationPresetId): string {
  return SHORT_LABELS_BN[id];
}
</script>
