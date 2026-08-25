import { computed } from 'vue';
import { useAppearance } from 'src/composables/useAppearance';
import {
  BRAND_FAVICON_DARK_SRC,
  BRAND_FAVICON_LIGHT_SRC,
  BRAND_LOGO_DARK_SRC,
  BRAND_LOGO_LIGHT_SRC,
  BRAND_LOGO_MARK_DARK_SRC,
  BRAND_LOGO_MARK_LIGHT_SRC,
} from 'src/constants/brandAssets';

export function useBrandAssets() {
  const { darkMode } = useAppearance();

  const brandLogoSrc = computed(() =>
    darkMode.value ? BRAND_LOGO_DARK_SRC : BRAND_LOGO_LIGHT_SRC,
  );

  const brandLogoMarkSrc = computed(() =>
    darkMode.value ? BRAND_LOGO_MARK_DARK_SRC : BRAND_LOGO_MARK_LIGHT_SRC,
  );

  const brandFaviconSrc = computed(() =>
    darkMode.value ? BRAND_FAVICON_DARK_SRC : BRAND_FAVICON_LIGHT_SRC,
  );

  return {
    darkMode,
    brandLogoSrc,
    brandLogoMarkSrc,
    brandFaviconSrc,
  };
}
