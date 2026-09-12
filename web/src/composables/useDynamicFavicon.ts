/**
 * useDynamicFavicon
 *
 * Scope + appearance: tint the TradeFlow BD mark to each place primary.
 */

import { watch } from 'vue';
import { useRoute } from 'vue-router';
import { resolveBrandScope, scopeThemeCanvas } from 'src/utils/scopeTheme';
import { buildScopeFavicon } from 'src/utils/scopeFavicon';

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

export function syncFaviconWithAppearance(path?: string, queryScope?: string | null): void {
  const resolvedPath = path ?? (typeof window !== 'undefined' ? window.location.pathname : '/');
  const scope = resolveBrandScope(resolvedPath, queryScope);
  const light = isLightAppearance();

  applyThemeColor(scopeThemeCanvas(!light));

  void buildScopeFavicon(scope, !light)
    .then(applyFavicon)
    .catch(() => {
      // Keep the splash favicon if tinting fails.
    });
}

export function useDynamicFavicon(): void {
  const route = useRoute();

  watch(
    () => [route.path, route.query.scope] as const,
    ([path, queryScope]) => {
      const scope = typeof queryScope === 'string' ? queryScope : null;
      syncFaviconWithAppearance(path, scope);
    },
    { immediate: true },
  );
}
