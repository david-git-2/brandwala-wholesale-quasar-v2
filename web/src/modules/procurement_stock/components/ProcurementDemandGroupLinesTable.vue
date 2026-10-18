<template>
  <q-markup-table
    flat
    class="demand-table demand-group-lines-table shipment-items-markup-table shipment-details-table"
  >
    <thead>
      <tr>
        <th class="text-center demand-line-col">#</th>
        <th class="text-center demand-image-col">Image</th>
        <th class="text-left demand-product-col">Product</th>
        <th class="text-left demand-code-col">SKU / barcode</th>
        <th
          class="text-center demand-qty-col tf-ops-col-tint--qty"
          :class="{ 'tf-ops-col-tint--qty-readonly': isBuyMode }"
        >
          {{ isFulfillMode ? 'Packaged' : 'Customer need' }}
        </th>
        <th v-if="isBuyMode" class="text-center demand-place-col tf-ops-col-tint--qty">
          Placed qty
        </th>
        <th v-if="isBuyMode" class="text-left demand-vendor-col tf-ops-col-tint--vendor">
          Buy from
        </th>
        <th v-if="isFulfillMode" class="text-center demand-delivered-col">
          {{ allocatedColumnLabel }}
        </th>
      </tr>
    </thead>
    <tbody>
      <slot />
    </tbody>
  </q-markup-table>
</template>

<script setup lang="ts">
defineProps<{
  isBuyMode: boolean;
  isFulfillMode: boolean;
  allocatedColumnLabel: string;
}>();
</script>

<style scoped lang="scss">
.demand-group-lines-table.shipment-items-markup-table :deep(th),
.demand-group-lines-table.shipment-items-markup-table :deep(td) {
  padding: 0 !important;
  height: 44px;
  border: 1px solid #eef1f5;
  vertical-align: middle;
}

.demand-group-lines-table.shipment-items-markup-table :deep(thead th) {
  position: static;
  top: auto;
  font-weight: 700;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #0f172a;
  background: #f3f4f6;
  padding: 6px 8px !important;
  height: auto;
}

.demand-group-lines-table :deep(.demand-line-col) {
  width: 40px;
  min-width: 40px;
  max-width: 40px;
  background: #f9fafb;
}

.demand-group-lines-table :deep(.demand-line-num) {
  font-size: 12px;
}

.demand-group-lines-table :deep(th.tf-ops-col-tint--qty),
.demand-group-lines-table :deep(td.tf-ops-col-tint--qty) {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

.demand-group-lines-table :deep(th.tf-ops-col-tint--qty-readonly),
.demand-group-lines-table :deep(td.tf-ops-col-tint--qty-readonly) {
  background-color: #e8f0fe !important;
}

.demand-group-lines-table :deep(th.tf-ops-col-tint--vendor),
.demand-group-lines-table :deep(td.tf-ops-col-tint--vendor) {
  background-color: #e8f5e9 !important;
  box-shadow: inset 2px 0 0 #059669;
}

.demand-group-lines-table :deep(.demand-excel-readonly) {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;
  padding: 0 6px;
  font-variant-numeric: tabular-nums;
}

.demand-group-lines-table :deep(.demand-product-col) {
  padding: 6px 8px !important;
}

.demand-group-lines-table :deep(.demand-code-col) {
  min-width: 108px;
  max-width: 160px;
  padding: 6px 8px !important;
  font-size: 12px;
  line-height: 1.35;
  word-break: break-all;
}

.demand-group-lines-table :deep(.demand-product-code) {
  font-variant-numeric: tabular-nums;
}

.demand-group-lines-table :deep(.demand-product-barcode) {
  font-size: 11px;
}

.demand-group-lines-table :deep(.demand-code-line + .demand-code-line) {
  margin-top: 4px;
}

.demand-group-lines-table :deep(.demand-code-copy-btn) {
  flex-shrink: 0;
  opacity: 0.55;
}

.demand-group-lines-table :deep(.demand-code-line:hover .demand-code-copy-btn) {
  opacity: 1;
}

.demand-group-lines-table :deep(.demand-image-col) {
  padding: 4px !important;
}

.demand-group-lines-table :deep(tr:hover td) {
  filter: brightness(0.99);
}

.demand-group-lines-table :deep(input[type='number']::-webkit-outer-spin-button),
.demand-group-lines-table :deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none !important;
  margin: 0 !important;
}

.demand-group-lines-table :deep(input[type='number']) {
  -moz-appearance: textfield !important;
  appearance: textfield !important;
}

.demand-group-lines-table :deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
  min-height: 44px !important;
  transition: background-color 0.1s ease-in-out, box-shadow 0.1s ease-in-out;
}

.demand-group-lines-table :deep(.excel-cell-input .q-field__control:before),
.demand-group-lines-table :deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

.demand-group-lines-table :deep(.excel-cell-input:hover .q-field__control) {
  background-color: rgba(255, 255, 255, 0.45) !important;
}

.demand-group-lines-table :deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: #ffffff !important;
  border: 1.5px solid #059669 !important;
  box-shadow: 0 0 0 1px #059669 !important;
}

.demand-group-lines-table :deep(.excel-cell-input--qty .q-field__native),
.demand-group-lines-table :deep(.excel-cell-input--qty input) {
  text-align: center;
}

body.body--dark .demand-group-lines-table.shipment-items-markup-table :deep(thead th) {
  background: #2a2a2a;
  color: #e4e4e7;
  border-color: #3f3f46;
}

body.body--dark .demand-group-lines-table.shipment-items-markup-table :deep(td) {
  border-color: #3f3f46;
}
</style>
