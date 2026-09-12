import { BRAND_LOGO_MARK_LIGHT_SRC } from 'src/constants/brandAssets';
import type { BrandLogoScope } from 'src/constants/brandAssets';
import { scopeThemePrimary } from 'src/utils/scopeTheme';

const faviconCache = new Map<string, string>();
let maskImage: HTMLImageElement | null = null;
let maskLoadPromise: Promise<HTMLImageElement> | null = null;

function loadMaskImage(): Promise<HTMLImageElement> {
  if (maskImage) {
    return Promise.resolve(maskImage);
  }

  if (!maskLoadPromise) {
    maskLoadPromise = new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => {
        maskImage = image;
        resolve(image);
      };
      image.onerror = () => reject(new Error('Failed to load brand mark mask'));
      image.src = BRAND_LOGO_MARK_LIGHT_SRC;
    });
  }

  return maskLoadPromise;
}

export async function buildScopeFavicon(scope: BrandLogoScope, dark: boolean): Promise<string> {
  const cacheKey = `${scope}:${dark ? 'dark' : 'light'}`;
  const cached = faviconCache.get(cacheKey);
  if (cached) {
    return cached;
  }

  const image = await loadMaskImage();
  const size = 64;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;

  const context = canvas.getContext('2d');
  if (!context) {
    return BRAND_LOGO_MARK_LIGHT_SRC;
  }

  context.clearRect(0, 0, size, size);
  context.drawImage(image, 0, 0, size, size);
  context.globalCompositeOperation = 'source-in';
  context.fillStyle = scopeThemePrimary(scope, dark);
  context.fillRect(0, 0, size, size);

  const dataUrl = canvas.toDataURL('image/png');
  faviconCache.set(cacheKey, dataUrl);
  return dataUrl;
}
