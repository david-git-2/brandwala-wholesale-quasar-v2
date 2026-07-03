import type { ThriftMarketingTagConfig } from '../types/marketingTag';

export const DEFAULT_MARKETING_TAG_CONFIG: ThriftMarketingTagConfig = {
  brand_name: '',
  show_logo: true,
  show_brand_name: true,
  show_listed_sell: true,
  show_core_sizes: true,
  show_additional_sizes: true,
  show_barcode_text: true,
};

export function resolveMarketingTagConfig(
  saved?: Partial<ThriftMarketingTagConfig> | null,
): ThriftMarketingTagConfig {
  if (!saved) return { ...DEFAULT_MARKETING_TAG_CONFIG };
  return {
    ...DEFAULT_MARKETING_TAG_CONFIG,
    ...saved,
  };
}
