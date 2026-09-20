<script setup lang="ts">
import type { InvoiceBrand } from '../repositories/invoiceRepository';
import type { BillingProfile } from '../repositories/billingProfileRepository';
import type { SalesInvoiceStockItem } from '../repositories/invoiceRepository';
import type { InvoiceLineDraftItem } from '../types/wholesaleInvoiceDraft';
import InvoicePartiesStrip from './InvoicePartiesStrip.vue';
import InvoiceStockSearchBar from './InvoiceStockSearchBar.vue';
import InvoiceLinesTable from './InvoiceLinesTable.vue';
import InvoiceTotalsPanel from './InvoiceTotalsPanel.vue';

type BillingProfileWithTenant = BillingProfile & {
  tenant?: { id: number; name: string; slug: string } | null;
};

defineProps<{
  invoiceItems: InvoiceLineDraftItem[];
  hasReturnedItems: boolean;
  isSearchingStock: boolean;
  stockSearchResults: SalesInvoiceStockItem[];
  totalQuantity: number;
  totalReturnQuantity: number;
  totalReturnCredit: number;
  subtotalAmount: number;
  totalDiscountAmount: number;
  grandTotalAmount: number;
  overallDiscountLocked: boolean;
  brandOptions: InvoiceBrand[];
  brandsLoading: boolean;
  billingProfileOptions: BillingProfileWithTenant[];
  billingProfilesLoading: boolean;
}>();

const selectedBrandId = defineModel<number | null>('selectedBrandId', { required: true });
const selectedBillingProfileId = defineModel<number | null>('selectedBillingProfileId', { required: true });
const overallDiscountInput = defineModel<number | null>('overallDiscountInput', { required: true });
const stockSearchText = defineModel<string>('stockSearchText', { required: true });

const emit = defineEmits<{
  (e: 'filter-billing-profiles', val: string, update: (fn: () => void) => void): void;
  (e: 'stock-search-input'): void;
  (e: 'search-focus'): void;
  (e: 'clear-stock-search'): void;
  (e: 'add-stock', stock: SalesInvoiceStockItem): void;
  (e: 'remove-item', index: number): void;
  (e: 'apply-overall-discount', val: string | number | null): void;
}>();
</script>

<template>
  <div class="invoice-desk-body">
    <div class="invoice-desk-body__main">
      <InvoicePartiesStrip
        v-model:selected-brand-id="selectedBrandId"
        v-model:selected-billing-profile-id="selectedBillingProfileId"
        mode="edit"
        :brand-options="brandOptions"
        :brands-loading="brandsLoading"
        :billing-profile-options="billingProfileOptions"
        :billing-profiles-loading="billingProfilesLoading"
        @filter-billing-profiles="(val, update) => emit('filter-billing-profiles', val, update)"
      />

      <InvoiceStockSearchBar
        v-model:stock-search-text="stockSearchText"
        :is-searching-stock="isSearchingStock"
        :stock-search-results="stockSearchResults"
        :invoice-items="invoiceItems"
        @search-input="emit('stock-search-input')"
        @search-focus="emit('search-focus')"
        @clear-search="emit('clear-stock-search')"
        @add-stock="(stock) => emit('add-stock', stock)"
      />

      <InvoiceLinesTable
        mode="composer"
        :composer-items="invoiceItems"
        :has-returned-items="hasReturnedItems"
        @remove-composer-item="(index) => emit('remove-item', index)"
      />
    </div>

    <aside v-if="invoiceItems.length" class="invoice-desk-body__aside">
      <InvoiceTotalsPanel
        v-model:overall-discount-input="overallDiscountInput"
        mode="composer"
        :item-count="invoiceItems.length"
        :total-quantity="totalQuantity"
        :total-return-quantity="totalReturnQuantity"
        :subtotal-amount="subtotalAmount"
        :total-discount-amount="totalDiscountAmount"
        :total-return-credit="totalReturnCredit"
        :grand-total-amount="grandTotalAmount"
        :overall-discount-locked="overallDiscountLocked"
        @apply-overall-discount="(val) => emit('apply-overall-discount', val)"
      />
    </aside>
  </div>
</template>

<style scoped lang="scss">
@import '../styles/invoice-desk.scss';
</style>
