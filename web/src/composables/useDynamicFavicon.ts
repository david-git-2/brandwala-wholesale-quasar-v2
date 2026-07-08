/**
 * useDynamicFavicon
 *
 * Watches the current route path and swaps the browser tab favicon to a
 * colour-matched version of the TradeFlowBD brand icon.
 *
 * Scope → colour mapping mirrors the login page canvas:
 *   platform  →  red    #ef4444
 *   app       →  green  #10b981
 *   shop      →  blue   #3b82f6
 *   (default) →  violet #7c3aed
 */

import { watch } from 'vue';
import { useRoute } from 'vue-router';

// ── Brand icon SVG builder ────────────────────────────────────────────────────
function buildIconSvg(color: string): string {
  // Same four-quadrant grid shape as the login page brand mark
  return `<svg width="32" height="32" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="28" height="28" rx="7" fill="${color}" fill-opacity="0.18"/>
  <path d="M7 9.5C7 8.12 8.12 7 9.5 7H14V14H7V9.5Z" fill="${color}"/>
  <path d="M14 7H18.5C19.88 7 21 8.12 21 9.5V14H14V7Z" fill="${color}" fill-opacity="0.7"/>
  <path d="M7 14H14V21H9.5C8.12 21 7 19.88 7 18.5V14Z" fill="${color}" fill-opacity="0.7"/>
  <path d="M14 14H21V18.5C21 19.88 19.88 21 18.5 21H14V14Z" fill="${color}" fill-opacity="0.45"/>
</svg>`;
}

function toDataUri(svg: string): string {
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}

type FaviconScope = 'platform' | 'app' | 'shop' | 'default';

// Pre-build all four variants once at module load
const FAVICON: Record<FaviconScope, string> = {
  platform: toDataUri(buildIconSvg('#ef4444')), // red
  app: toDataUri(buildIconSvg('#10b981')), // emerald
  shop: toDataUri(buildIconSvg('#3b82f6')), // blue
  default: toDataUri(buildIconSvg('#7c3aed')), // violet
};

// ── Scope detection from URL path ─────────────────────────────────────────────
function detectScope(path: string): FaviconScope {
  if (/^\/platform(\/|$)/.test(path)) return 'platform';
  if (/\/(shop)(\/|$)/.test(path)) return 'shop';
  if (/\/(app)(\/|$)/.test(path)) return 'app';
  return 'default';
}

// ── DOM helper ────────────────────────────────────────────────────────────────
function applyFavicon(href: string): void {
  // Target by stable id — avoids fighting Quasar or the browser's size-matching
  let link = document.getElementById('dynamic-favicon') as HTMLLinkElement | null;

  if (!link) {
    // Fallback: remove all existing icon links and inject a fresh one
    document.querySelectorAll('link[rel="icon"]').forEach((el) => el.remove());
    link = document.createElement('link');
    link.id = 'dynamic-favicon';
    link.rel = 'icon';
    document.head.appendChild(link);
  }

  link.type = 'image/svg+xml';
  link.href = href;
}

// ── Public composable ─────────────────────────────────────────────────────────
export function useDynamicFavicon(): void {
  const route = useRoute();

  watch(
    () => route.path,
    (path) => {
      const scope = detectScope(path);
      const faviconHref = FAVICON[scope];
      applyFavicon(faviconHref);
    },
    { immediate: true },
  );
}
