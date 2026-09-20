<script setup lang="ts">
import type { SalesInvoiceStockItem } from '../repositories/invoiceRepository';
import type { InvoiceLineDraftItem } from '../types/wholesaleInvoiceDraft';

const props = defineProps<{
  isSearchingStock: boolean;
  stockSearchResults: SalesInvoiceStockItem[];
  invoiceItems: InvoiceLineDraftItem[];
}>();

const stockSearchText = defineModel<string>('stockSearchText', { required: true });

const emit = defineEmits<{
  (e: 'search-input'): void;
  (e: 'search-focus'): void;
  (e: 'clear-search'): void;
  (e: 'add-stock', stock: SalesInvoiceStockItem): void;
}>();

const formatMoney = (amount: number) =>
  `৳${amount.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;

const formatDate = (dateStr: string) => (dateStr ? dateStr.slice(0, 10) : '');

const isItemAlreadyAdded = (stockId: number) =>
  props.invoiceItems.some((item) => item.global_stock_id === stockId);

const showResults = () =>
  stockSearchText.value.trim().length > 0 || props.stockSearchResults.length > 0;
</script>

<template>
  <div class="invoice-desk-card">
    <div class="invoice-desk-section-label">Add items</div>
    <q-input
      v-model="stockSearchText"
      outlined
      dense
      hide-bottom-space
      placeholder="Search stock by name, barcode, or product code..."
      @update:model-value="emit('search-input')"
      @focus="emit('search-focus')"
    >
      <template #prepend>
        <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-6" />
      </template>
      <template v-if="stockSearchText" #append>
        <q-icon
          name="ph ph-x-circle"
          size="16px"
          class="cursor-pointer text-grey-5"
          @click="emit('clear-search')"
        />
      </template>
    </q-input>

    <div v-if="showResults()" class="invoice-desk-search-results">
      <q-item v-if="isSearchingStock" class="q-py-md text-center">
        <q-item-section>
          <div class="row items-center justify-center q-gutter-sm text-grey-6 text-caption">
            <q-spinner color="primary" size="20px" />
            <span>Searching stock inventory...</span>
          </div>
        </q-item-section>
      </q-item>

      <q-item v-else-if="!stockSearchResults.length" class="q-py-md text-center">
        <q-item-section>
          <div class="text-caption text-grey-6">
            No available stock found
            <template v-if="stockSearchText">
              for <strong>"{{ stockSearchText }}"</strong>
            </template>
          </div>
        </q-item-section>
      </q-item>

      <q-item
        v-for="stock in stockSearchResults"
        :key="stock.global_stock_id"
        clickable
        class="invoice-desk-search-row q-py-sm"
        :class="{ 'invoice-desk-search-row--allocated': stock.is_allocated_to_tenant }"
        @click="emit('add-stock', stock)"
      >
        <q-item-section avatar min-width="40px">
          <q-avatar size="36px" rounded color="grey-2" class="overflow-hidden">
            <img v-if="stock.image_url" :src="stock.image_url" alt="" />
            <q-icon v-else name="ph ph-package" color="grey-6" size="20px" />
          </q-avatar>
        </q-item-section>

        <q-item-section>
          <div class="row items-center justify-between no-wrap">
            <q-item-label class="text-weight-bold text-body2 text-grey-9 ellipsis">
              {{ stock.name }}
            </q-item-label>
            <q-badge
              :color="stock.is_allocated_to_tenant ? 'positive' : 'grey-3'"
              :text-color="stock.is_allocated_to_tenant ? 'white' : 'grey-9'"
              class="text-weight-bold text-caption q-ml-xs"
            >
              {{
                stock.is_allocated_to_tenant
                  ? 'Your allocation'
                  : stock.holding_tenant_name || 'Parent pool'
              }}
            </q-badge>
          </div>
          <q-item-label caption class="text-grey-6 row items-center q-gutter-xs q-mt-xs">
            <span v-if="stock.barcode">Barcode: {{ stock.barcode }}</span>
            <span v-if="stock.barcode && stock.shipment_name">•</span>
            <span v-if="stock.shipment_name">Shipment: {{ stock.shipment_name }}</span>
            <span>•</span>
            <span>Received: {{ formatDate(stock.stock_created_at) }}</span>
          </q-item-label>
        </q-item-section>

        <q-item-section side class="items-end">
          <div class="row items-center q-gutter-sm">
            <div class="text-right">
              <div class="text-caption text-weight-bold text-primary">
                {{ stock.available_atp }} in stock
              </div>
              <div class="text-caption text-grey-6 invoice-desk-money">
                {{ formatMoney(stock.suggested_sell_price || stock.unit_cost_price || 0) }}
              </div>
            </div>
            <q-btn
              dense
              unelevated
              size="sm"
              :color="isItemAlreadyAdded(stock.global_stock_id) ? 'grey-3' : 'primary'"
              :text-color="isItemAlreadyAdded(stock.global_stock_id) ? 'grey-7' : 'white'"
              :icon="isItemAlreadyAdded(stock.global_stock_id) ? 'ph ph-check' : 'ph ph-plus'"
              :label="isItemAlreadyAdded(stock.global_stock_id) ? 'Added' : 'Add'"
              no-caps
              class="text-weight-bold q-px-sm"
              :disable="isItemAlreadyAdded(stock.global_stock_id)"
              @click.stop="emit('add-stock', stock)"
            />
          </div>
        </q-item-section>
      </q-item>
    </div>
  </div>
</template>

<style scoped lang="scss">
@import '../styles/invoice-desk.scss';
</style>
