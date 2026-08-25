/**
 * useDynamicFavicon
 *
 * Light / dark theme: TradeFlow BD emblem PNG per appearance.
 */

import { watch } from 'vue';
import { useRoute } from 'vue-router';
import {
  BRAND_FAVICON_DARK_SRC,
  BRAND_FAVICON_LIGHT_SRC,
} from 'src/constants/brandAssets';

function isLightAppearance(): boolean {
  if (document.body.classList.contains('body--dark')) {
    return false;
  }

  try {
    const localDark = window.localStorage.getItem('brandwala.appearance.darkMode');
    if (localDark === 'true') {
      return false;
    }
  } catch {
    // ignore
  }

  return true;
}

function applyFavicon(href: string): void {
  let link = document.getElementById('dynamic-favicon') as HTMLLinkElement | null;

  if (!link) {
    document.querySelectorAll('link[rel="icon"]').forEach((el) => el.remove());
    link = document.createElement('link');
    link.id = 'dynamic-favicon';
    link.rel = 'icon';
    document.head.appendChild(link);
  }

  link.type = 'image/png';
  link.href = href;
}

function applyThemeColor(color: string): void {
  let meta = document.querySelector('meta[name="theme-color"]') as HTMLMetaElement | null;
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'theme-color';
    document.head.appendChild(meta);
  }
  meta.content = color;
}

export function syncFaviconWithAppearance(): void {
  if (isLightAppearance()) {
    applyFavicon(BRAND_FAVICON_LIGHT_SRC);
    applyThemeColor('#FBFAF7');
    return;
  }

  applyFavicon(BRAND_FAVICON_DARK_SRC);
  applyThemeColor('#171412');
}

export function useDynamicFavicon(): void {
  const route = useRoute();

  watch(
    () => route.path,
    () => {
      syncFaviconWithAppearance();
    },
    { immediate: true },
  );
}
