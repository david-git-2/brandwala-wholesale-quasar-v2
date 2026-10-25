<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import {
  BOOKS_CUSTOMER_GROUPS_STALE_MS,
  seedBooksCustomerGroups,
} from '../utils/booksCustomerGroupsCache';
import { resolveBooksTenantId } from 'src/modules/tenant/utils/resolveBooksTenantId';
import type { Shop } from '../types';
import { showErrorNotification, showSuccessNotification, parseSupabaseError } from 'src/utils/appFeedback';

const props = defineProps<{ shop: Shop }>();

const authStore = useAuthStore();
const queryClient = useQueryClient();
const scopeTenantId = computed(() => authStore.tenantId as number);
const customerSearch = ref('');
const customersLoading = ref(false);
const accessRows = ref<Array<{ customer_group_id: number }>>([]);
const groupNameById = ref<Record<number, string>>({});

const panelOpen = ref(false);
const selectedCustomerGroupId = ref<number | null>(null);
const receiveItemName = ref('');
const receiveQty = ref(1);
const savingReceive = ref(false);

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
  if (!scopeTenantId.value) return;
  customersLoading.value = true;
  try {
    const bundle = await queryClient.fetchQuery({
      queryKey: shopOrderQueryKeys.shopCustomerAccessPage(
        scopeTenantId.value,
        props.shop.id,
      ),
      queryFn: () =>
        shopOrderRepository.getShopCustomerAccessPage(props.shop.id, scopeTenantId.value),
      staleTime: BOOKS_CUSTOMER_GROUPS_STALE_MS,
    });
    seedBooksCustomerGroups(
      queryClient,
      resolveBooksTenantId(scopeTenantId.value, authStore.selectedTenant?.parent_id),
      bundle.customer_groups,
    );
    accessRows.value = bundle.access_overrides;
    const names: Record<number, string> = {};
    for (const g of bundle.customer_groups) {
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
          Dropshippers who can use this shop. Click a dropshipper to view gift stock and add items they left with you.
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
            :active="panelOpen && selectedCustomerGroupId === row.customer_group_id"
            active-class="bg-primary text-white"
            @click="openCustomerPanel(row.customer_group_id)"
          >
            <q-item-section avatar>
              <q-icon name="ph ph-user" :color="panelOpen && selectedCustomerGroupId === row.customer_group_id ? 'white' : 'primary'" />
            </q-item-section>
            <q-item-section>
              <q-item-label>{{ row.name }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-icon
                name="ph ph-caret-right"
                :color="panelOpen && selectedCustomerGroupId === row.customer_group_id ? 'white' : 'grey-6'"
              />
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
  </div>
</template>
