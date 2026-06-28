export const DEFAULT_THRIFT_TYPE_ICON = 'style';

export interface ThriftTypeIconOption {
  value: string | null;
  label: string;
}

export const THRIFT_TYPE_ICON_OPTIONS: ThriftTypeIconOption[] = [
  { value: null, label: 'Default (style)' },
  { value: 'style', label: 'Style' },
  { value: 'checkroom', label: 'Checkroom' },
  { value: 'woman', label: 'Woman' },
  { value: 'straighten', label: 'Straighten' },
  { value: 'height', label: 'Height' },
  { value: 'nightlife', label: 'Nightlife' },
  { value: 'star', label: 'Star' },
  { value: 'dry_cleaning', label: 'Dry cleaning' },
  { value: 'category', label: 'Category' },
  { value: 'accessibility_new', label: 'Off shoulder' },
  { value: 'shopping_bag', label: 'Shopping bag' },
  { value: 'local_mall', label: 'Local mall' },
  { value: 'watch', label: 'Watch' },
  { value: 'diamond', label: 'Diamond' },
  { value: 'favorite', label: 'Favorite' },
  { value: 'celebration', label: 'Celebration' },
  { value: 'beach_access', label: 'Beach' },
  { value: 'ac_unit', label: 'Winter' },
  { value: 'child_care', label: 'Kids' },
];

export function resolveTypeIcon(icon?: string | null): string {
  return icon?.trim() || DEFAULT_THRIFT_TYPE_ICON;
}
