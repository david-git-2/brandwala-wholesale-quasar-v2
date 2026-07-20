<template>
  <div class="shop-preset-picker q-mb-md">
    <div class="text-subtitle2 text-weight-medium q-mb-xs">
      {{ $t('shop_admin.start_from_preset') }}
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
      </q-chip>
      <q-chip
        clickable
        dense
        :outline="modelValue !== 'custom'"
        :color="modelValue === 'custom' ? 'primary' : 'grey-7'"
        :text-color="modelValue === 'custom' ? 'white' : undefined"
        @click="emit('update:modelValue', 'custom')"
      >
        <span class="text-weight-medium">{{ $t('shop_admin.custom') }}</span>
        <span class="q-ml-xs text-caption opacity-80">{{ $t('shop_admin.configure_manually') }}</span>
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
import { useI18n } from 'vue-i18n';
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

const { t } = useI18n();

const SHORT_LABEL_KEYS: Record<ShopConfigurationPresetId, string> = {
  A: 'shop_admin.preset_short_a',
  B: 'shop_admin.preset_short_b',
  C: 'shop_admin.preset_short_c',
  D: 'shop_admin.preset_short_d',
  E: 'shop_admin.preset_short_e',
  F: 'shop_admin.preset_short_f',
};

function shortLabel(id: ShopConfigurationPresetId): string {
  return t(SHORT_LABEL_KEYS[id]);
}
</script>
