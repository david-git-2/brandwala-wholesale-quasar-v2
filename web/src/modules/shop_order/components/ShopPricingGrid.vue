<template>
  <q-card flat bordered>
    <q-table
      flat
      row-key="id"
      selection="multiple"
      v-model:selected="selectedRows"
      :rows="listings"
      :columns="columns"
      :pagination="{ rowsPerPage: 50 }"
      :dense="$q.screen.lt.md"
    >
      <!-- Product Info -->
      <template #body-cell-product_name="props">
        <q-td :props="props">
          <div class="row items-center no-wrap">
            <q-avatar size="32px" rounded class="q-mr-sm bg-grey-3">
              <q-img v-if="props.row.product_image_url" :src="props.row.product_image_url" />
              <q-icon v-else name="ph ph-image" color="grey-6" />
            </q-avatar>
            <div class="ellipsis" style="max-width: 220px">
              <div class="text-weight-bold text-grey-9">{{ props.row.product_name }}</div>
              <div class="text-caption text-grey-6">
                {{ props.row.product_code || props.row.product_barcode || 'No Code' }}
              </div>
            </div>
          </div>
        </q-td>
      </template>

      <!-- Cost / Dropship Floor (Read only / inline info) -->
      <template #body-cell-min_sell_price="props">
        <q-td :props="props">
          <div v-if="shopType === 'dropship'" class="text-caption text-grey-8">
            {{ formatMoney(props.row.minimum_sell_price_amount, props.row.minimum_sell_price_currency_id) }}
          </div>
          <div v-else class="text-grey-4">—</div>
        </q-td>
      </template>

      <!-- Inline Sell Price Input -->
      <template #body-cell-sell_price="props">
        <q-td :props="props" style="min-width: 160px">
          <q-input
            :model-value="props.row.sell_price_amount"
            type="number"
            step="0.01"
            dense
            outlined
            class="bg-white"
            @change="(val: any) => onUpdateSellPrice(props.row, Number(val))"
          >
            <template #prepend>
              <q-btn
                flat
                round
                dense
                size="sm"
                :icon="props.row.is_price_locked ? 'ph ph-lock-key' : 'ph ph-lock-key-open'"
                :color="props.row.is_price_locked ? 'negative' : 'grey-5'"
                @click.stop="onTogglePriceLock(props.row)"
              >
                <q-tooltip>{{ props.row.is_price_locked ? 'Price Locked (Manual override active)' : 'Unlocked (Uses pricing rule)' }}</q-tooltip>
              </q-btn>
            </template>
            <template #append>
              <q-icon
                v-if="savingId === props.row.id"
                name="ph ph-circle-notch"
                class="fa-spin"
                size="16px"
                color="primary"
              />
            </template>
          </q-input>
        </q-td>
      </template>

      <!-- Inline Minimum Sell Price Input (Dropship) -->
      <template #body-cell-min_sell_price_input="props">
        <q-td :props="props" style="min-width: 140px">
          <q-input
            v-if="shopType === 'dropship'"
            :model-value="props.row.minimum_sell_price_amount"
            type="number"
            step="0.01"
            dense
            outlined
            class="bg-white"
            @change="(val: any) => onUpdateMinPrice(props.row, val === '' || val === null ? null : Number(val))"
          >
            <template #append>
              <q-icon
                v-if="savingId === props.row.id"
                name="ph ph-circle-notch"
                class="fa-spin"
                size="16px"
                color="primary"
              />
            </template>
          </q-input>
          <div v-else class="text-grey-4 text-center">—</div>
        </q-td>
      </template>

      <!-- Display Qty Override Inline -->
      <template #body-cell-display_quantity="props">
        <q-td :props="props" style="min-width: 170px">
          <div class="row items-center no-wrap q-gutter-x-xs">
            <q-btn
              flat
              round
              dense
              size="sm"
              :icon="props.row.is_quantity_locked ? 'ph ph-lock-key' : 'ph ph-lock-key-open'"
              :color="props.row.is_quantity_locked ? 'negative' : 'grey-5'"
              @click.stop="onToggleQuantityLock(props.row)"
            >
              <q-tooltip>{{ props.row.is_quantity_locked ? 'Quantity Locked' : 'Unlocked' }}</q-tooltip>
            </q-btn>
            <q-select
              :model-value="props.row.quantity_override_type || 'absolute'"
              dense
              outlined
              options-dense
              emit-value
              map-options
              style="width: 70px"
              class="bg-white"
              :options="[
                { label: 'Abs', value: 'absolute' },
                { label: 'Rel', value: 'relative' },
              ]"
              @update:model-value="(val: any) => onUpdateOverrideType(props.row, val)"
            />
            <q-input
              :model-value="props.row.display_quantity_override"
              type="number"
              dense
              outlined
              clearable
              class="bg-white col"
              :placeholder="String(props.row.available_to_sell)"
              @change="(val: any) => onUpdateDisplayQty(props.row, val === '' || val === null ? null : Number(val))"
            />
          </div>
        </q-td>
      </template>

      <!-- Actual Available Qty -->
      <template #body-cell-actual_quantity="props">
        <q-td :props="props" class="text-center">
          <div class="text-weight-medium text-grey-8">
            {{ props.row.available_to_sell }}
          </div>
        </q-td>
      </template>

      <!-- Status Toggle -->
      <template #body-cell-is_active="props">
        <q-td :props="props" class="text-center">
          <q-toggle
            :model-value="props.row.is_active"
            color="positive"
            dense
            @update:model-value="(val: boolean) => onUpdateActive(props.row, val)"
          />
        </q-td>
      </template>
    </q-table>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import type { ShopProductListing, UpsertListingPayload } from '../types';

const props = defineProps<{
  listings: ShopProductListing[];
  shopType: string;
  currencies: Array<{ id: number; code: string }>;
  isSaving: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:selected', selected: ShopProductListing[]): void;
  (e: 'save-listing', payload: UpsertListingPayload): void;
}>();

const { t } = useI18n();

const selectedRows = ref<ShopProductListing[]>([]);
const savingId = ref<number | null>(null);

watch(selectedRows, (newVal) => {
  emit('update:selected', newVal);
});

const columns = computed(() => [
  {
    name: 'product_name',
    label: t('shop_admin.col_product'),
    field: 'product_name',
    align: 'left' as const,
    sortable: true,
  },
  {
    name: 'min_sell_price',
    label: t('shop_admin.dropship_floor'),
    field: 'minimum_sell_price_amount',
    align: 'left' as const,
  },
  {
    name: 'sell_price',
    label: t('shop_admin.col_sell_price'),
    field: 'sell_price_amount',
    align: 'left' as const,
  },
  {
    name: 'min_sell_price_input',
    label: t('shop_admin.min_dropship_price'),
    field: 'minimum_sell_price_amount',
    align: 'left' as const,
  },
  {
    name: 'display_quantity',
    label: t('shop_admin.col_display_qty'),
    field: 'display_quantity_override',
    align: 'center' as const,
  },
  {
    name: 'actual_quantity',
    label: t('shop_admin.col_actual_qty'),
    field: 'available_to_sell',
    align: 'center' as const,
    sortable: true,
  },
  {
    name: 'is_active',
    label: t('shop_admin.col_listing_active'),
    field: 'is_active',
    align: 'center' as const,
  },
]);

const formatMoney = (amount: number | null, currencyId: number | null): string => {
  if (amount === null || currencyId === null) return '—';
  const curr = props.currencies.find((c) => c.id === currencyId);
  const code = curr ? curr.code : '';
  return `${Number(amount).toFixed(2)} ${code}`;
};

const createPayload = (listing: ShopProductListing): UpsertListingPayload => ({
  id: listing.id,
  tenant_id: listing.tenant_id,
  shop_id: listing.shop_id,
  global_stock_allocation_id: listing.global_stock_allocation_id,
  sell_price_amount: Number(listing.sell_price_amount),
  sell_price_currency_id: listing.sell_price_currency_id,
  minimum_sell_price_amount: listing.minimum_sell_price_amount
    ? Number(listing.minimum_sell_price_amount)
    : null,
  minimum_sell_price_currency_id: listing.minimum_sell_price_currency_id,
  show_quantity: listing.show_quantity,
  display_quantity_override: listing.display_quantity_override,
  is_active: listing.is_active,
  is_price_locked: listing.is_price_locked ?? false,
  is_quantity_locked: listing.is_quantity_locked ?? false,
  quantity_override_type: listing.quantity_override_type ?? 'absolute',
});

const onUpdateSellPrice = (listing: ShopProductListing, newPrice: number) => {
  if (isNaN(newPrice) || newPrice === listing.sell_price_amount) return;
  savingId.value = listing.id;
  const payload = createPayload(listing);
  payload.sell_price_amount = newPrice;
  payload.is_price_locked = true; // Auto lock price on manual edit
  emit('save-listing', payload);
};

const onTogglePriceLock = (listing: ShopProductListing) => {
  savingId.value = listing.id;
  const payload = createPayload(listing);
  payload.is_price_locked = !listing.is_price_locked;
  emit('save-listing', payload);
};

const onToggleQuantityLock = (listing: ShopProductListing) => {
  savingId.value = listing.id;
  const payload = createPayload(listing);
  payload.is_quantity_locked = !listing.is_quantity_locked;
  emit('save-listing', payload);
};

const onUpdateOverrideType = (listing: ShopProductListing, type: 'absolute' | 'relative') => {
  savingId.value = listing.id;
  const payload = createPayload(listing);
  payload.quantity_override_type = type;
  emit('save-listing', payload);
};

const onUpdateMinPrice = (listing: ShopProductListing, newMinPrice: number | null) => {
  savingId.value = listing.id;
  const payload = createPayload(listing);
  payload.minimum_sell_price_amount = newMinPrice;
  payload.is_price_locked = true; // Auto lock price on manual edit
  emit('save-listing', payload);
};

const onUpdateDisplayQty = (listing: ShopProductListing, newQty: number | null) => {
  savingId.value = listing.id;
  const payload = createPayload(listing);
  payload.display_quantity_override = newQty;
  payload.is_quantity_locked = true; // Auto lock quantity on manual edit
  emit('save-listing', payload);
};

const onUpdateActive = (listing: ShopProductListing, isActive: boolean) => {
  savingId.value = listing.id;
  const payload = createPayload(listing);
  payload.is_active = isActive;
  emit('save-listing', payload);
};
</script>
