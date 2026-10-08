<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { useShopStaffProductSearchQuery } from '../composables/useShopStaffProductSearchQuery';
import { shopPermissionsService } from '../services/shopPermissionsService';
import type { Shop, ShopAutoGiftItemRow } from '../types';
import { showErrorNotification, showSuccessNotification, parseSupabaseError } from 'src/utils/appFeedback';

const props = defineProps<{ shop: Shop }>();

const queryClient = useQueryClient();
const customerSearch = ref('');
const customersLoading = ref(false);
const accessRows = ref<Array<{ customer_group_id: number }>>([]);
const groupNameById = ref<Record<number, string>>({});

const panelOpen = ref(false);
const selectedCustomerGroupId = ref<number | null>(null);
const receiveItemName = ref('');
const receiveQty = ref(1);
const savingReceive = ref(false);

const autoGiftsQuery = useQuery({
  queryKey: computed(() => shopOrderQueryKeys.shopAutoGifts(props.shop.id)),
  queryFn: () => shopOrderRepository.listShopAutoGiftItems(props.shop.id),
});

const customerStocksQuery = useQuery({
  queryKey: computed(() =>
    shopOrderQueryKeys.shopCustomerStocks(props.shop.id, selectedCustomerGroupId.value),
  ),
  enabled: computed(() => panelOpen.value && selectedCustomerGroupId.value != null),
  queryFn: () =>
    shopOrderRepository.listShopCustomerStocks(props.shop.id, selectedCustomerGroupId.value),
});

const customerRows = computed(() => {
  const ids = new Set(accessRows.value.map((r) => r.customer_group_id));
  const rows = [...ids].map((id) => ({
    customer_group_id: id,
    name: groupNameById.value[id] ?? `Group #${id}`,
  }));
  const q = customerSearch.value.trim().toLowerCase();
  const filtered = q
    ? rows.filter((r) => r.name.toLowerCase().includes(q))
    : rows;
  return filtered.sort((a, b) => a.name.localeCompare(b.name));
});

const selectedCustomerName = computed(() => {
  const id = selectedCustomerGroupId.value;
  if (id == null) return '';
  return groupNameById.value[id] ?? `Group #${id}`;
});

const loadCustomers = async () => {
  customersLoading.value = true;
  try {
    const [accessRes, groupsRes] = await Promise.all([
      shopPermissionsService.listAccessOverrides(props.shop.id),
      shopPermissionsService.listCustomerGroups(props.shop.tenant_id),
    ]);
    if (!accessRes.success) throw new Error(accessRes.error || 'Failed to load customers');
    if (!groupsRes.success) throw new Error(groupsRes.error || 'Failed to load groups');
    accessRows.value = accessRes.data ?? [];
    const names: Record<number, string> = {};
    for (const g of groupsRes.data ?? []) {
      names[g.id] = g.name;
    }
    groupNameById.value = names;
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to load customers'));
  } finally {
    customersLoading.value = false;
  }
};

onMounted(() => {
  void loadCustomers();
});

const invalidateStocks = () => {
  void queryClient.invalidateQueries({
    queryKey: shopOrderQueryKeys.shopCustomerStocks(props.shop.id, selectedCustomerGroupId.value),
  });
  void queryClient.invalidateQueries({
    queryKey: shopOrderQueryKeys.shopCustomerStocks(props.shop.id),
  });
};

const invalidateAutoGifts = () => {
  void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.shopAutoGifts(props.shop.id) });
};

const openCustomerPanel = (customerGroupId: number) => {
  selectedCustomerGroupId.value = customerGroupId;
  panelOpen.value = true;
  receiveItemName.value = '';
  receiveQty.value = 1;
};

const closePanel = () => {
  panelOpen.value = false;
};

const receiveStock = async () => {
  const groupId = selectedCustomerGroupId.value;
  const name = receiveItemName.value.trim();
  if (groupId == null || !name || receiveQty.value <= 0) return;
  savingReceive.value = true;
  try {
    const res = await shopOrderRepository.receiveShopCustomerStock({
      shopId: props.shop.id,
      customerGroupId: groupId,
      quantity: receiveQty.value,
      itemLabel: name,
    });
    if (!res.success) throw new Error(res.error || 'Receive failed');
    showSuccessNotification('Customer stock updated.');
    receiveItemName.value = '';
    receiveQty.value = 1;
    invalidateStocks();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to receive stock'));
  } finally {
    savingReceive.value = false;
  }
};

const shopIdRef = computed(() => props.shop.id);
const giftForm = ref({
  product_id: null as number | null,
  quantity: 1,
  gift_source: 'customer_stock' as 'stock' | 'customer_stock',
  gift_cost_amount: 0,
  gift_cost_charged_to: 'reseller' as 'reseller' | 'tenant',
  is_active: true,
});
const giftSearch = ref('');
const giftSearchSubmitted = ref('');
const giftSearchScope = computed(() =>
  giftForm.value.gift_source === 'stock' ? 'warehouse_stock' : 'shop_listings',
);
const giftCatalogSearch = useShopStaffProductSearchQuery(giftSearchSubmitted, {
  shopId: shopIdRef,
  scope: giftSearchScope,
}, 20);
const savingGift = ref(false);

const runGiftSearch = () => {
  giftSearchSubmitted.value = giftSearch.value.trim();
};

const saveAutoGift = async () => {
  if (!giftForm.value.product_id) return;
  savingGift.value = true;
  try {
    const costOn = giftForm.value.gift_source === 'stock' && giftForm.value.gift_cost_amount > 0;
    const res = await shopOrderRepository.upsertShopAutoGiftItem(props.shop.id, {
      product_id: giftForm.value.product_id,
      quantity: giftForm.value.quantity,
      gift_source: giftForm.value.gift_source,
      gift_cost_amount: giftForm.value.gift_source === 'stock' ? giftForm.value.gift_cost_amount : 0,
      gift_cost_charged_to: costOn ? giftForm.value.gift_cost_charged_to : null,
      is_active: giftForm.value.is_active,
    });
    if (!res.success) throw new Error(res.error || 'Save failed');
    showSuccessNotification('Auto gift saved.');
    giftForm.value.product_id = null;
    invalidateAutoGifts();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to save auto gift'));
  } finally {
    savingGift.value = false;
  }
};

const toggleAutoGift = async (row: ShopAutoGiftItemRow) => {
  try {
    const res = await shopOrderRepository.upsertShopAutoGiftItem(props.shop.id, {
      id: row.id,
      is_active: !row.is_active,
    });
    if (!res.success) throw new Error(res.error || 'Update failed');
    invalidateAutoGifts();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to update'));
  }
};

const deleteAutoGift = async (id: number) => {
  try {
    const res = await shopOrderRepository.deleteShopAutoGiftItem(id);
    if (!res.success) throw new Error(res.error || 'Delete failed');
    invalidateAutoGifts();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to delete'));
  }
};

watch(panelOpen, (open) => {
  if (!open) selectedCustomerGroupId.value = null;
});
</script>

<template>
  <div class="q-gutter-y-md">
    <q-card flat bordered>
      <q-card-section>
        <div class="text-subtitle2 text-weight-bold">Customers</div>
        <p class="text-caption text-grey-7 q-mb-md">
          Resellers who can use this shop. Open a customer to see gift stock they left with you.
        </p>
        <q-input
          v-model="customerSearch"
          dense
          outlined
          clearable
          label="Search customers"
          class="q-mb-sm"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>
        <q-list bordered separator class="rounded-borders">
          <q-item
            v-for="row in customerRows"
            :key="row.customer_group_id"
            v-ripple
            clickable
            @click="openCustomerPanel(row.customer_group_id)"
          >
            <q-item-section avatar>
              <q-icon name="ph ph-user" color="primary" />
            </q-item-section>
            <q-item-section>
              <q-item-label>{{ row.name }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-icon name="ph ph-caret-right" color="grey-6" />
            </q-item-section>
          </q-item>
          <q-item v-if="!customersLoading && !customerRows.length">
            <q-item-section class="text-grey-7 text-caption">
              No customers with shop access yet. Add access on the Access tab.
            </q-item-section>
          </q-item>
        </q-list>
        <q-inner-loading :showing="customersLoading" />
      </q-card-section>
    </q-card>

    <AppResizableOverlayPanel
      v-model="panelOpen"
      storage-key="shop_order.gifts-customer-stock-width"
      :default-width="480"
      :min-width="360"
      :max-width="720"
      aria-label="Customer gift stock"
    >
      <div class="column no-wrap full-height">
        <div class="row items-center q-pa-md shrink-0">
          <div class="col min-width-0">
            <div class="text-overline text-primary">Customer stock</div>
            <div class="text-subtitle1 text-weight-bold ellipsis">{{ selectedCustomerName }}</div>
          </div>
          <q-btn flat round dense icon="ph ph-x" color="grey-7" aria-label="Close" @click="closePanel" />
        </div>
        <q-separator />
        <div class="col scroll q-pa-md q-gutter-y-md">
          <q-table
            flat
            dense
            :rows="customerStocksQuery.data.value ?? []"
            :columns="[
              { name: 'product_name', label: 'Item', field: 'product_name', align: 'left' },
              { name: 'quantity_on_hand', label: 'On hand', field: 'quantity_on_hand', align: 'right' },
            ]"
            row-key="id"
            :loading="customerStocksQuery.isLoading.value"
            no-data-label="No stock yet for this customer"
          />
          <div class="text-caption text-weight-medium">Add stock</div>
          <div class="row q-col-gutter-sm items-end">
            <div class="col-12 col-sm-7">
              <q-input v-model="receiveItemName" dense outlined label="Name" />
            </div>
            <div class="col-6 col-sm-3">
              <q-input v-model.number="receiveQty" type="number" dense outlined label="Qty" min="1" />
            </div>
            <div class="col-6 col-sm-2">
              <q-btn
                color="primary"
                unelevated
                no-caps
                class="full-width"
                label="Add"
                :loading="savingReceive"
                :disable="!receiveItemName.trim()"
                @click="receiveStock"
              />
            </div>
          </div>
        </div>
      </div>
    </AppResizableOverlayPanel>

    <q-card flat bordered>
      <q-card-section>
        <div class="text-subtitle2 text-weight-bold">Auto gifts</div>
        <p class="text-caption text-grey-7 q-mb-md">
          Added once when an order enters processing. Recipient always gets these free.
        </p>
        <q-table
          flat
          dense
          :rows="autoGiftsQuery.data.value ?? []"
          :columns="[
            { name: 'product_id', label: 'Product ID', field: 'product_id', align: 'left' },
            { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right' },
            { name: 'gift_source', label: 'Source', field: 'gift_source', align: 'left' },
            { name: 'gift_cost_amount', label: 'Cost', field: 'gift_cost_amount', align: 'right' },
            { name: 'is_active', label: 'Active', field: 'is_active', align: 'center' },
            { name: 'actions', label: '', field: 'id', align: 'right' },
          ]"
          row-key="id"
          :loading="autoGiftsQuery.isLoading.value"
          no-data-label="No auto gifts configured"
        >
          <template #body-cell-is_active="props">
            <q-td :props="props">
              <q-toggle
                :model-value="props.row.is_active"
                dense
                @update:model-value="toggleAutoGift(props.row)"
              />
            </q-td>
          </template>
          <template #body-cell-actions="props">
            <q-td :props="props">
              <q-btn flat dense color="negative" icon="delete" @click="deleteAutoGift(props.row.id)" />
            </q-td>
          </template>
        </q-table>

        <q-separator class="q-my-md" />
        <div class="text-caption text-weight-medium q-mb-sm">Add auto gift</div>
        <div class="row q-col-gutter-sm">
          <div class="col-12 col-md-4">
            <q-input v-model="giftSearch" dense outlined label="Search product" @keyup.enter="runGiftSearch">
              <template #append>
                <q-btn flat dense icon="ph ph-magnifying-glass" aria-label="Search" @click="runGiftSearch" />
              </template>
            </q-input>
            <q-select
              v-if="giftCatalogSearch.results.value.length"
              v-model="giftForm.product_id"
              dense
              outlined
              class="q-mt-sm"
              label="Product"
              emit-value
              map-options
              :options="giftCatalogSearch.results.value.map((p) => ({ label: p.product_name, value: p.product_id }))"
            />
          </div>
          <div class="col-6 col-md-2">
            <q-input v-model.number="giftForm.quantity" type="number" dense outlined label="Qty" min="1" />
          </div>
          <div class="col-6 col-md-3">
            <q-select
              v-model="giftForm.gift_source"
              dense
              outlined
              label="Source"
              :options="[
                { label: 'Customer stock', value: 'customer_stock' },
                { label: 'Warehouse stock', value: 'stock' },
              ]"
              emit-value
              map-options
            />
          </div>
          <template v-if="giftForm.gift_source === 'stock'">
            <div class="col-6 col-md-2">
              <q-input v-model.number="giftForm.gift_cost_amount" type="number" dense outlined label="Cost" min="0" />
            </div>
            <div class="col-6 col-md-3">
              <q-select
                v-model="giftForm.gift_cost_charged_to"
                dense
                outlined
                label="Charge to"
                :disable="giftForm.gift_cost_amount <= 0"
                :options="[
                  { label: 'Reseller profit', value: 'reseller' },
                  { label: 'Tenant', value: 'tenant' },
                ]"
                emit-value
                map-options
              />
            </div>
          </template>
          <div class="col-12 col-md-2">
            <q-btn
              color="primary"
              unelevated
              no-caps
              class="full-width"
              label="Save"
              :loading="savingGift"
              :disable="!giftForm.product_id"
              @click="saveAutoGift"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>
