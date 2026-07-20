import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import type { ShopConfigurationPreset } from '../constants/shopConfigurationPresets';

export function useShopLocale() {
  const { locale } = useI18n();
  const isBn = computed(() => locale.value === 'bn');

  const presetName = (preset: ShopConfigurationPreset) =>
    isBn.value ? preset.nameBn : preset.name;

  const presetDescription = (preset: ShopConfigurationPreset) =>
    isBn.value ? preset.descriptionBn : preset.description;

  return { isBn, presetName, presetDescription };
}
