<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import {
  useShopStaffProductSearchQuery,
  type ShopStaffProductSearchHit,
} from '../composables/useShopStaffProductSearchQuery';
import { roundUpToNearest5 } from '../utils/catalogPricingUtils';
import { showErrorNotification, showSuccessNotification, parseSupabaseError } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  orderId: number;
  shopId: number;
  customerGroupId?: number | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'added'): void;
}>();

interface PendingGiftLine {
  product_id: number | null;
  shop_customer_stock_id: number | null;
  product_name: string;
  image_url: string | null;
  unit_cost_amount: number;
  quantity: number;
  gift_source: 'stock' | 'customer_stock';
}

const giftSource = ref<'stock' | 'customer_stock'>('stock');
const pendingLines = ref<PendingGiftLine[]>([]);
const search = ref('');
const searchSubmitted = ref('');
const saving = ref(false);

const shopIdRef = computed(() => props.shopId);
const catalogSearchScope = computed(() => 'warehouse_stock' as const);
const catalogSearch = useShopStaffProductSearchQuery(searchSubmitted, {
  shopId: shopIdRef,
  scope: catalogSearchScope,
}, 20);

const customerStockQuery = useQuery({
  queryKey: computed(() =>
    shopOrderQueryKeys.shopCustomerStocks(props.shopId, props.customerGroupId),
  ),
  enabled: computed(() => props.modelValue && giftSource.value === 'customer_stock'),
  queryFn: () =>
    shopOrderRepository.listShopCustomerStocks(props.shopId, props.customerGroupId),
});

const customerStockRows = computed(() =>
  (customerStockQuery.data.value ?? []).filter((row) => row.quantity_on_hand > 0),
);

const customerStockFilter = ref('');
const filteredCustomerStockRows = computed(() => {
  const q = customerStockFilter.value.trim().toLowerCase();
  if (!q) return customerStockRows.value;
  return customerStockRows.value.filter((row) => row.product_name.toLowerCase().includes(q));
});

const resetForm = () => {
  giftSource.value = 'stock';
  pendingLines.value = [];
  search.value = '';
  searchSubmitted.value = '';
  customerStockFilter.value = '';
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) resetForm();
  },
);

watch(giftSource, () => {
  pendingLines.value = [];
});

const debouncedWarehouseSearch = (() => {
  let timer: ReturnType<typeof setTimeout> | undefined;
  return () => {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      searchSubmitted.value = search.value.trim();
    }, 300);
  };
})();

watch(search, () => {
  if (giftSource.value === 'stock') debouncedWarehouseSearch();
});

const runSearch = () => {
  searchSubmitted.value = search.value.trim();
};

const addPendingLine = (
  productId: number | null,
  productName: string,
  imageUrl: string | null = null,
  unitCostAmount = 0,
  shopCustomerStockId: number | null = null,
) => {
  const source = giftSource.value;
  const idx = pendingLines.value.findIndex(
    (line) =>
      line.gift_source === source
      && line.shop_customer_stock_id === shopCustomerStockId
      && line.product_id === productId,
  );
  if (idx >= 0) {
    const next = [...pendingLines.value];
    next[idx] = { ...next[idx], quantity: next[idx].quantity + 1 };
    pendingLines.value = next;
    return;
  }
  pendingLines.value = [
    ...pendingLines.value,
    {
      product_id: productId,
      shop_customer_stock_id: shopCustomerStockId,
      product_name: productName,
      image_url: imageUrl,
      unit_cost_amount: unitCostAmount,
      quantity: 1,
      gift_source: source,
    },
  ];
};

const addFromWarehouseHit = (hit: ShopStaffProductSearchHit) => {
  addPendingLine(
    hit.product_id,
    hit.product_name,
    hit.image_url ?? null,
    Number(hit.unit_cost_amount ?? 0),
  );
  search.value = '';
  searchSubmitted.value = '';
};

const addFromCustomerStockRow = (row: import('../types').ShopCustomerStockRow) => {
  addPendingLine(row.product_id, row.product_name, null, 0, row.id);
  customerStockFilter.value = '';
};

const removePendingLine = (index: number) => {
  pendingLines.value = pendingLines.value.filter((_, i) => i !== index);
};

const updatePendingQty = (index: number, qty: number | string | null) => {
  const parsed = Math.trunc(Number(qty));
  if (!Number.isFinite(parsed) || parsed < 1) return;
  const next = [...pendingLines.value];
  next[index] = { ...next[index], quantity: parsed };
  pendingLines.value = next;
};

const close = () => emit('update:modelValue', false);

const submitLabel = computed(() =>
  pendingLines.value.length > 1 ? `Add ${pendingLines.value.length} gifts` : 'Add gift',
);

const submit = async () => {
  if (!pendingLines.value.length) return;
  saving.value = true;
  try {
    for (const line of pendingLines.value) {
      const giftLineCost =
        line.gift_source === 'stock'
          ? roundUpToNearest5(line.unit_cost_amount * line.quantity)
          : 0;
      const costOn = giftLineCost > 0;
      const res = await shopOrderRepository.addDropshipOrderGiftItem({
        orderId: props.orderId,
        productId: line.product_id,
        quantity: line.quantity,
        giftSource: line.gift_source,
        giftCostAmount: giftLineCost,
        giftCostChargedTo: costOn ? 'reseller' : null,
        shopCustomerStockId: line.shop_customer_stock_id,
      });
      if (!res.success) throw new Error(res.error || 'Failed to add gift');
    }
    showSuccessNotification(
      pendingLines.value.length > 1 ? 'Gift items added.' : 'Gift item added.',
    );
    emit('added');
    close();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to add gift item'));
  } finally {
    saving.value = false;
  }
};

const showWarehouseSearchHint = computed(
  () => giftSource.value === 'stock' && searchSubmitted.value.length > 0 && searchSubmitted.value.length < catalogSearch.minSearchLength,
);

const warehouseSearchReady = computed(
  () => searchSubmitted.value.trim().length >= catalogSearch.minSearchLength,
);
</script>

<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="shop_order.dropship-add-gift-width"
    :default-width="440"
    :min-width="360"
    :max-width="640"
    aria-label="Add gift item"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div class="gift-side-panel column no-wrap full-height">
      <div class="gift-side-panel__header row items-center q-pa-md shrink-0">
        <div class="col min-width-0">
          <div class="text-overline text-primary">Gift</div>
          <div class="text-subtitle1 text-weight-bold text-grey-9">Add gift item</div>
          <p class="text-caption text-grey-7 q-mb-none q-mt-xs">Recipient does not pay for gifts.</p>
        </div>
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          color="grey-7"
          aria-label="Close"
          @click="close"
        />
      </div>

      <q-separator />

      <div class="gift-side-panel__body col scroll q-pa-md column q-gutter-y-md">
        <q-btn-toggle
          v-model="giftSource"
          spread
          no-caps
          toggle-color="primary"
          :options="[
            { label: 'Warehouse (cost)', value: 'stock' },
            { label: 'Customer stock', value: 'customer_stock' },
          ]"
        />

        <template v-if="giftSource === 'stock'">
          <q-input
            v-model="search"
            dense
            outlined
            clearable
            label="Search warehouse stock"
            @keyup.enter="runSearch"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>

          <div v-if="showWarehouseSearchHint" class="text-caption text-grey-6">
            Type at least {{ catalogSearch.minSearchLength }} characters to search.
          </div>
          <div v-else-if="catalogSearch.isFetching.value" class="text-caption text-grey-6">
            Searching…
          </div>
          <div
            v-else-if="warehouseSearchReady && !catalogSearch.results.value.length"
            class="text-caption text-grey-6"
          >
            No warehouse stock matches this search.
          </div>

          <q-list
            v-if="catalogSearch.results.value.length"
            bordered
            separator
            class="rounded-borders gift-search-results"
          >
            <q-item v-for="hit in catalogSearch.results.value" :key="hit.product_id">
              <q-item-section avatar>
                <q-avatar v-if="hit.image_url" rounded size="40px">
                  <img :src="hit.image_url" :alt="hit.product_name">
                </q-avatar>
                <q-avatar v-else rounded size="40px" color="grey-3" text-color="grey-7" icon="ph ph-package" />
              </q-item-section>
              <q-item-section>
                <q-item-label>{{ hit.product_name }}</q-item-label>
                <q-item-label caption>
                  <span v-if="hit.product_code">{{ hit.product_code }} · </span>
                  ATP {{ hit.available_atp ?? 0 }}
                </q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-plus"
                  color="primary"
                  aria-label="Add to list"
                  @click="addFromWarehouseHit(hit)"
                />
              </q-item-section>
            </q-item>
          </q-list>
        </template>

        <template v-else>
          <q-input
            v-model="customerStockFilter"
            dense
            outlined
            clearable
            label="Filter customer stock"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>

          <div v-if="customerStockQuery.isLoading.value" class="text-caption text-grey-6">
            Loading customer stock…
          </div>
          <div v-else-if="!filteredCustomerStockRows.length" class="text-caption text-grey-6">
            No customer stock on hand.
          </div>

          <q-list
            v-else
            bordered
            separator
            class="rounded-borders gift-search-results"
          >
            <q-item v-for="row in filteredCustomerStockRows" :key="row.product_id">
              <q-item-section>
                <q-item-label>{{ row.product_name }}</q-item-label>
                <q-item-label caption>{{ row.quantity_on_hand }} on hand</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-plus"
                  color="primary"
                  aria-label="Add to list"
                  @click="addFromCustomerStockRow(row)"
                />
              </q-item-section>
            </q-item>
          </q-list>
        </template>
      </div>

      <div class="gift-side-panel__pending q-px-md q-pb-md shrink-0">
        <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-sm">
          Gifts to add
          <span v-if="pendingLines.length" class="text-weight-regular text-grey-6">
            ({{ pendingLines.length }})
          </span>
        </div>
        <div
          v-if="!pendingLines.length"
          class="gift-pending-empty text-caption text-grey-6 q-pa-md text-center"
        >
          Search warehouse stock and tap + to add items here.
        </div>
        <div v-else class="gift-pending-list rounded-borders">
          <div
            v-for="(line, index) in pendingLines"
            :key="`${line.gift_source}-${line.product_id}-${index}`"
            class="gift-pending-row row items-center no-wrap q-gutter-sm"
          >
            <q-avatar v-if="line.image_url" rounded size="48px" class="gift-pending-row__thumb shrink-0">
              <img :src="line.image_url" :alt="line.product_name">
            </q-avatar>
            <q-avatar
              v-else
              rounded
              size="48px"
              color="grey-3"
              text-color="grey-7"
              icon="ph ph-package"
              class="gift-pending-row__thumb shrink-0"
            />
            <div class="col min-width-0 gift-pending-row__text">
              <div class="gift-pending-row__name text-body2 text-grey-9">
                {{ line.product_name }}
              </div>
              <div class="text-caption text-grey-6 text-capitalize">
                {{ line.gift_source.replace('_', ' ') }}
              </div>
            </div>
            <q-input
              :model-value="line.quantity"
              class="gift-pending-row__qty shrink-0"
              type="number"
              dense
              outlined
              label="Qty"
              min="1"
              @update:model-value="updatePendingQty(index, $event)"
            />
            <q-btn
              flat
              round
              dense
              icon="ph ph-trash"
              color="grey-7"
              class="shrink-0"
              aria-label="Remove"
              @click="removePendingLine(index)"
            />
          </div>
        </div>
      </div>

      <div class="gift-side-panel__footer row items-center justify-end q-gutter-sm q-pa-md shrink-0">
        <q-btn flat no-caps label="Cancel" color="grey-7" @click="close" />
        <q-btn
          color="primary"
          unelevated
          no-caps
          :label="submitLabel"
          icon="ph ph-gift"
          :loading="saving"
          :disable="!pendingLines.length"
          @click="submit"
        />
      </div>
    </div>
  </AppResizableOverlayPanel>
</template>

<style scoped>
.gift-side-panel {
  height: 100%;
  min-height: 0;
}

.gift-side-panel__pending {
  border-top: 1px solid var(--bw-theme-border, #e2e8f0);
  background: var(--bw-theme-surface-muted, #f8fafc);
  max-height: 280px;
  overflow-y: auto;
}

.gift-pending-empty {
  border: 1px dashed var(--bw-theme-border, #e2e8f0);
  border-radius: var(--bw-radius-md, 8px);
}

.gift-pending-list {
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  background: #fff;
  overflow: hidden;
}

.gift-pending-row {
  padding: 10px 12px;
  border-bottom: 1px solid var(--bw-theme-border, #e2e8f0);
}

.gift-pending-row:last-child {
  border-bottom: none;
}

.gift-pending-row__thumb {
  flex-shrink: 0;
}

.gift-pending-row__text {
  min-width: 0;
  flex: 1 1 auto;
}

.gift-pending-row__name {
  white-space: normal;
  overflow-wrap: anywhere;
  line-height: 1.35;
}

.gift-pending-row__qty {
  width: 72px;
  flex-shrink: 0;
}

.gift-pending-row__qty :deep(.q-field__bottom) {
  display: none;
}

.gift-side-panel__footer {
  border-top: 1px solid var(--bw-theme-border, #e2e8f0);
}

.gift-search-results {
  max-height: 220px;
  overflow-y: auto;
}
</style>
