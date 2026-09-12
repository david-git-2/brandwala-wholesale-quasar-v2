import type { BrandLogoScope } from 'src/constants/brandAssets';
import {
  SCOPE_THEME_CANVAS_DARK,
  SCOPE_THEME_CANVAS_LIGHT,
  SCOPE_THEME_PRIMARY_DARK,
  SCOPE_THEME_PRIMARY_LIGHT,
} from 'src/constants/brandAssets';

export function resolveScopeFromPath(path: string): BrandLogoScope | null {
  if (/^\/platform(\/|$)/.test(path)) return 'platform';
  if (/\/investor(\/|$)/.test(path)) return 'investor';
  if (/\/(shop)(\/|$)/.test(path)) return 'shop';
  if (/\/(app)(\/|$)/.test(path)) return 'app';
  return null;
}

export function resolveBrandScope(path: string, queryScope?: string | null): BrandLogoScope {
  if (
    queryScope === 'platform' ||
    queryScope === 'app' ||
    queryScope === 'shop' ||
    queryScope === 'investor'
  ) {
    return queryScope;
  }

  return resolveScopeFromPath(path) ?? 'app';
}

export function scopeThemePrimary(scope: BrandLogoScope, dark: boolean): string {
  return dark ? SCOPE_THEME_PRIMARY_DARK[scope] : SCOPE_THEME_PRIMARY_LIGHT[scope];
}

export function scopeThemeCanvas(dark: boolean): string {
  return dark ? SCOPE_THEME_CANVAS_DARK : SCOPE_THEME_CANVAS_LIGHT;
}
