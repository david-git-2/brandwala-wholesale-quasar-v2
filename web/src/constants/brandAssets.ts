/** Canonical brand raster assets (`web/public/brand/`). */
export const BRAND_LOGO_LIGHT_SRC = '/brand/logo-light.png';
export const BRAND_LOGO_MARK_LIGHT_SRC = '/brand/logo-mark-light.png';
export const BRAND_FAVICON_LIGHT_SRC = '/brand/favicon-light.png';

export const BRAND_LOGO_DARK_SRC = '/brand/logo-dark.png';
export const BRAND_LOGO_MARK_DARK_SRC = '/brand/logo-mark-dark.png';
export const BRAND_FAVICON_DARK_SRC = '/brand/favicon-dark.png';

export const BRAND_LOGO_MARK_PLATFORM_SRC = '/brand/logo-mark-platform.png';
export const BRAND_LOGO_MARK_APP_SRC = '/brand/logo-mark-app.png';
export const BRAND_LOGO_MARK_SHOP_SRC = '/brand/logo-mark-shop.png';

export type BrandLogoScope = 'platform' | 'app' | 'shop' | 'investor';

/** Scope primaries — keep in sync with `.theme-*` in `web/src/css/app.scss`. */
export const SCOPE_THEME_PRIMARY_LIGHT: Record<BrandLogoScope, string> = {
  platform: '#464b71',
  app: '#488b8f',
  shop: '#3368a0',
  investor: '#413333',
};

export const SCOPE_THEME_PRIMARY_DARK: Record<BrandLogoScope, string> = {
  platform: '#118ab2',
  app: '#5ea3a3',
  shop: '#66a3bf',
  investor: '#f2765e',
};

export const SCOPE_THEME_CANVAS_LIGHT = '#fbfaf7';
export const SCOPE_THEME_CANVAS_DARK = '#141210';

export const BRAND_LOGO_MARK_BY_SCOPE: Record<BrandLogoScope, string> = {
  platform: BRAND_LOGO_MARK_PLATFORM_SRC,
  app: BRAND_LOGO_MARK_APP_SRC,
  shop: BRAND_LOGO_MARK_SHOP_SRC,
  investor: BRAND_LOGO_MARK_APP_SRC,
};
