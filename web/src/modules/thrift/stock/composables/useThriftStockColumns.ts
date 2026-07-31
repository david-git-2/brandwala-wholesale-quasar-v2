import { ref, computed } from 'vue';
import type { QTableColumn } from 'quasar';

export const statusOptions = [
  { label: 'Available', value: 'AVAILABLE' },
  { label: 'Out of stock', value: 'OUT_OF_STOCK' },
  { label: 'Damaged', value: 'DAMAGED' },
  { label: 'Stolen', value: 'STOLEN' },
];

export const conditionOptions = [
  { label: 'New with tags', value: 'NEW_WITH_TAGS' },
  { label: 'Excellent', value: 'EXCELLENT' },
  { label: 'Good', value: 'GOOD' },
  { label: 'Fair', value: 'FAIR' },
];

export const conditionSelectOptions = [
  { label: 'New with tags', value: 'NEW_WITH_TAGS' },
  { label: 'Excellent', value: 'EXCELLENT' },
  { label: 'Good', value: 'GOOD' },
  { label: 'Fair', value: 'FAIR' },
];

export const sectionSelectOptions = [
  { label: 'Male', value: 'MALE' },
  { label: 'Female', value: 'FEMALE' },
  { label: 'Unisex', value: 'UNISEX' },
  { label: 'Kids', value: 'KIDS' },
  { label: 'Home', value: 'HOME' },
];

const DEFAULT_VISIBLE_COLUMNS = [
  'select',
  'sl',
  'image',
  'barcode',
  'name',
  'brand_name',
  'section',
  'size',
  'box',
  'product_weight',
  'extra_weight',
  'condition',
  'quantity',
  'origin_unit_price',
  'extra_origin_unit_price',
  'product_unit_cost',
  'cargo_share_per_unit',
  'ops_share_per_unit',
  'additional_charges_cost',
  'landed_unit_cost',
  'suggested_sell_unit_price',
  'item_markup_pct',
  'effective_markup_pct',
  'listed_unit_price',
  'status',
  'actions',
];

export function useThriftStockColumns() {
  const columns: QTableColumn[] = [
    { name: 'select', align: 'center', label: '', field: 'id' },
    { name: 'sl', align: 'center', label: 'SL', field: 'id' },
    { name: 'image', align: 'center', label: 'Image', field: 'image_url' },
    { name: 'barcode', align: 'left', label: 'Barcode', field: 'barcode', sortable: true },
    { name: 'name', align: 'left', label: 'Item Name', field: 'name', sortable: true },
    { name: 'brand_name', align: 'left', label: 'Brand', field: 'brand_name', sortable: true },
    { name: 'section', align: 'left', label: 'Section', field: 'section', sortable: true },
    { name: 'size', align: 'left', label: 'Size', field: 'size', sortable: true, classes: 'measurements-col', headerClasses: 'measurements-col' },
    { name: 'box', align: 'left', label: 'Box', field: 'box_id', sortable: true },
    { name: 'product_weight', align: 'right', label: 'Product Wt', field: 'product_weight', sortable: true },
    { name: 'extra_weight', align: 'right', label: 'Extra Wt', field: 'extra_weight', sortable: true },
    { name: 'condition', align: 'left', label: 'Condition', field: 'condition', sortable: true },
    { name: 'quantity', align: 'right', label: 'Qty', field: 'quantity', sortable: true },
    { name: 'origin_unit_price', align: 'right', label: 'Origin Price', field: 'origin_unit_price', sortable: true },
    { name: 'extra_origin_unit_price', align: 'right', label: 'Extra Origin Price', field: 'extra_origin_unit_price', sortable: true },
    { name: 'product_unit_cost', align: 'right', label: 'Product Unit Cost', field: 'id' },
    { name: 'cargo_share_per_unit', align: 'right', label: 'Cargo / Unit', field: 'id' },
    { name: 'ops_share_per_unit', align: 'right', label: 'Ops / Unit', field: 'id' },
    { name: 'additional_charges_cost', align: 'right', label: 'Add. Charges', field: 'additional_charges_cost', sortable: true },
    { name: 'landed_unit_cost', align: 'right', label: 'Landed Unit Cost', field: 'id' },
    { name: 'suggested_sell_unit_price', align: 'right', label: 'Suggested Sell', field: 'id' },
    { name: 'item_markup_pct', align: 'right', label: 'Item Markup', field: 'id' },
    { name: 'effective_markup_pct', align: 'right', label: 'Effective Margin', field: 'id' },
    { name: 'listed_unit_price', align: 'right', label: 'Listed Sell Price', field: 'id' },
    { name: 'status', align: 'center', label: 'Status', field: 'status', sortable: true },
    { name: 'actions', align: 'center', label: 'Actions', field: 'id' },
  ];

  const columnSelectorOptions = columns
    .filter((col) => !['select', 'sl', 'image', 'actions'].includes(col.name))
    .map((col) => ({ label: col.label, value: col.name }));

  const selectedColumnNames = ref<string[]>(DEFAULT_VISIBLE_COLUMNS);

  const visibleColumns = computed(() => {
    const alwaysVisible = ['select', 'sl', 'image', 'actions'];
    return [...alwaysVisible, ...selectedColumnNames.value];
  });

  const allSelectableColumnsSelected = computed({
    get() {
      return columnSelectorOptions.every((opt) => selectedColumnNames.value.includes(opt.value));
    },
    set(val: boolean) {
      if (val) {
        selectedColumnNames.value = columnSelectorOptions.map((opt) => opt.value);
      } else {
        selectedColumnNames.value = [];
      }
    },
  });

  const tableCellClass = (colName: string) => {
    const editableCols = [
      'barcode',
      'name',
      'brand_name',
      'section',
      'box',
      'product_weight',
      'extra_weight',
      'condition',
      'quantity',
      'origin_unit_price',
      'extra_origin_unit_price',
      'additional_charges_cost',
      'item_markup_pct',
      'listed_unit_price',
      'status',
    ];
    return editableCols.includes(colName) ? 'editable-cell' : '';
  };

  const stickyCellClass = (colName: string) => {
    if (colName === 'select') return 'col-sticky-select';
    if (colName === 'sl') return 'col-sticky-sl';
    if (colName === 'image') return 'col-sticky-image';
    return '';
  };

  return {
    columns,
    columnSelectorOptions,
    selectedColumnNames,
    visibleColumns,
    allSelectableColumnsSelected,
    tableCellClass,
    stickyCellClass,
  };
}
