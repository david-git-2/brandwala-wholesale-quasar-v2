<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import CatalogOrderBillStockDialog from '../../components/CatalogOrderBillStockDialog.vue';
import { shopOrderRepository } from '../../repositories/shopOrderRepository';
import { qtyOnBillForOrderItem } from '../../utils/catalogBillKernelLines';
import { useShopOrderBillItemCoverage } from '../../composables/useShopOrderBillItemCoverage';
import { shopOrderQueryKeys } from '../../shared/queryKeys/shopOrderQueryKeys';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { billDetailRoute } from 'src/modules/finance/submodules/bills_pays/utils/billRoutes';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { catalogOrderCustomerQuantity } from '../../utils/catalogOrderStatus';
import type { ShopOrderItem } from '../../types';
import {
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
  requestConfirmation,
} from 'src/utils/appFeedback';
import type { Database } from 'src/types/database.types';

type BillSettlementKind = Database['public']['Enums']['bill_settlement_kind'];

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const queryClient = useQueryClient();

const orderId = computed(() => Number(route.params.id || 0));
const billId = computed(() => Number(route.query.bill || 0));
const deskTenantId = computed(() => authStore.tenantId ?? null);
const booksTenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId ?? null,
);

const billLinesQuery = useQuery({
  queryKey: computed(() => ['shopOrder', 'catalogBillLines', billId.value]),
  queryFn: () => shopOrderRepository.loadCatalogDraftBillLineRows(billId.value),
  enabled: computed(() => billId.value > 0),
});

const billLines = computed(() => billLinesQuery.data.value ?? []);

const settlementKind = ref<BillSettlementKind>('take');
const settlementHydrating = ref(false);
const settlementSaving = ref(false);
const deleteBillLoading = ref(false);

const billSettlementQuery = useQuery({
  queryKey: computed(() => ['shopOrder', 'catalogBillSettlement', billId.value]),
  queryFn: () => shopOrderRepository.getCatalogDraftBillSettlement(billId.value),
  enabled: computed(() => billId.value > 0),
});

watch(
  () => billSettlementQuery.data.value?.settlement_kind,
  (kind) => {
    if (kind == null) return;
    settlementHydrating.value = true;
    settlementKind.value = kind;
    queueMicrotask(() => {
      settlementHydrating.value = false;
    });
  },
);

const orderQuery = useQuery({
  queryKey: computed(() => ['shopOrder', 'createBill', deskTenantId.value, orderId.value]),
  queryFn: () =>
    shopOrderRepository.getShopOrderById(deskTenantId.value!, orderId.value, { itemsLimit: 500 }),
  enabled: computed(() => deskTenantId.value != null && orderId.value > 0),
});

const order = computed(() => orderQuery.data.value?.order ?? null);
const items = computed(() => orderQuery.data.value?.items ?? []);

const coverageQuery = useShopOrderBillItemCoverage({
  tenantId: deskTenantId,
  orderId,
  enabled: computed(
    () =>
      order.value?.shop_type_snapshot === 'vendor_catalog' && deskTenantId.value != null,
  ),
});

const pickDialogOpen = ref(false);
const pickTargetItem = ref<ShopOrderItem | null>(null);

const pickDialogQuantities = computed(() => {
  const item = pickTargetItem.value;
  if (!item) {
    return { neededQuantity: 0, onThisBill: 0 };
  }
  const row = tableRows.value.find((r) => r.item.id === item.id);
  const neededQuantity = row?.customerQty ?? catalogOrderCustomerQuantity(item);
  const onThisBill = row?.picked ?? qtyOnBillForOrderItem(billLines.value, item.id);
  return { neededQuantity, onThisBill };
});

const tableRows = computed(() =>
  items.value.map((item, index) => {
    const cov = coverageQuery.coverageByItemId.value.get(item.id);
    const customerQty = catalogOrderCustomerQuantity(item);
    const onBills = cov?.billed_quantity ?? 0;
    const remaining = Math.max(customerQty - onBills, 0);
    const picked = qtyOnBillForOrderItem(billLines.value, item.id);
    return {
      item,
      sl: index + 1,
      customerQty,
      onBills,
      remaining,
      picked,
    };
  }),
);

const totalOnBill = computed(() => tableRows.value.reduce((s, r) => s + r.picked, 0));

const pickHint = computed(() => {
  if (billId.value <= 0) {
    return t(
      'shop_admin.catalog_bill_pick_requires_draft',
      'Open a draft bill from the order Bills tab first.',
    );
  }
  return t(
    'shop_admin.catalog_bill_pick_adds_line',
    'Update qty per shipment to add or change lines on this draft bill.',
  );
});

const columns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'center' as const },
  { name: 'image', label: '', field: 'image', align: 'center' as const },
  { name: 'name', label: 'Product', field: 'name', align: 'left' as const },
  {
    name: 'customerQty',
    label: t('shop_admin.catalog_bill_customer_qty', 'Customer qty'),
    field: 'customerQty',
    align: 'center' as const,
  },
  { name: 'on_bills', label: t('shop_admin.catalog_bill_on_bills', 'On bills'), field: 'onBills', align: 'center' as const },
  { name: 'remaining', label: t('shop_admin.catalog_bill_remaining', 'Remaining'), field: 'remaining', align: 'center' as const },
  {
    name: 'picked',
    label: t('shop_admin.catalog_bill_on_this_bill', 'This bill'),
    field: 'picked',
    align: 'center' as const,
  },
  { name: 'actions', label: '', field: 'actions', align: 'right' as const },
];

const pageTitle = computed(() =>
  billId.value > 0
    ? t('shop_admin.catalog_bill_page_title', 'Bill #{id}', { id: billId.value })
    : t('shop_admin.catalog_create_bill', 'Create bill'),
);

const breadcrumbItems = computed(() => [
  { label: t('shop_admin.orders', 'Orders'), to: { name: 'app-shop-orders-page' } },
  {
    label: order.value?.order_no ?? `#${orderId.value}`,
    to: { name: 'app-shop-order-detail-page', params: { id: String(orderId.value) } },
  },
  { label: pageTitle.value },
]);
usePageBreadcrumbs(() => breadcrumbItems.value);

const invalidateAll = async () => {
  const booksId = booksTenantId.value;
  const deskId = deskTenantId.value;
  if (booksId != null && orderId.value > 0) {
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.billsForShopOrder(booksId, orderId.value),
    });
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.billItemCoverage(deskId ?? booksId, orderId.value),
    });
  }
  await coverageQuery.refetch();
  if (billId.value > 0) {
    await queryClient.invalidateQueries({
      queryKey: ['shopOrder', 'catalogBillLines', billId.value],
    });
  }
};

const refreshPickMeta = async () => {
  await invalidateAll();
  await billLinesQuery.refetch();
};

const openPick = (row: (typeof tableRows.value)[number]) => {
  if (row.remaining <= 0) return;
  pickTargetItem.value = row.item;
  pickDialogOpen.value = true;
};

const onBillStockUpdated = async () => {
  await refreshPickMeta();
};

const canDeleteDraftBill = computed(
  () =>
    billId.value > 0 &&
    (billSettlementQuery.data.value?.invoice_status == null ||
      billSettlementQuery.data.value?.invoice_status === 'draft'),
);

const onDeleteDraftBill = async () => {
  if (billId.value <= 0) return;
  const confirmed = await requestConfirmation(
    t(
      'shop_admin.catalog_delete_draft_bill_confirm',
      'Delete this draft bill? Stock held for its lines will be released back to sellable.',
    ),
    t('shop_admin.catalog_delete_draft_bill', 'Delete draft bill'),
    t('common.delete', 'Delete'),
  );
  if (!confirmed) return;

  deleteBillLoading.value = true;
  try {
    await shopOrderRepository.deleteCatalogShopOrderDraftBill(billId.value);
    showSuccessNotification(
      t('shop_admin.catalog_delete_draft_bill_done', 'Draft bill deleted.'),
    );
    await invalidateAll();
    await router.push({
      name: 'app-shop-order-detail-page',
      params: { id: String(orderId.value) },
    });
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to delete draft bill'));
  } finally {
    deleteBillLoading.value = false;
  }
};

const onSettlementKindChange = async (kind: BillSettlementKind) => {
  if (settlementHydrating.value) {
    settlementKind.value = kind;
    return;
  }
  const deskId = deskTenantId.value;
  if (deskId == null || billId.value <= 0) return;

  const persisted = billSettlementQuery.data.value?.settlement_kind;
  if (persisted === kind) {
    settlementKind.value = kind;
    return;
  }

  const previous = settlementKind.value;
  settlementKind.value = kind;
  settlementSaving.value = true;
  try {
    const res = await shopOrderRepository.patchCatalogDraftBillSettlement(
      deskId,
      billId.value,
      kind,
    );
    if (!res.success) {
      throw new Error(res.error ?? 'Failed to update settlement');
    }
    queryClient.setQueryData(
      ['shopOrder', 'catalogBillSettlement', billId.value],
      (old: { settlement_kind: BillSettlementKind; invoice_status: string | null } | undefined) => ({
        settlement_kind: res.settlement_kind ?? kind,
        invoice_status: old?.invoice_status ?? 'draft',
      }),
    );
  } catch (err) {
    settlementKind.value = previous;
    showErrorNotification(parseSupabaseError(err, 'Failed to update settlement'));
  } finally {
    settlementSaving.value = false;
  }
};

watch(order, (o) => {
  if (o && o.shop_type_snapshot !== 'vendor_catalog') {
    void router.replace({ name: 'app-shop-order-detail-page', params: { id: String(orderId.value) } });
  }
});
</script>

<template>
  <q-page class="q-pa-md column q-gutter-y-md">
    <div v-if="orderQuery.isLoading.value" class="row justify-center q-pa-xl">
      <q-spinner color="primary" size="32px" />
    </div>

    <template v-else-if="order && billId <= 0">
      <q-banner dense rounded class="bg-orange-1 text-orange-10">
        {{ pickHint }}
      </q-banner>
      <q-btn
        flat
        no-caps
        icon="ph ph-arrow-left"
        :label="$t('common.back', 'Back')"
        @click="router.push({ name: 'app-shop-order-detail-page', params: { id: String(orderId) } })"
      />
    </template>

    <template v-else-if="order">
      <div class="row items-center justify-between wrap q-gutter-sm">
        <div>
          <div class="text-h6 text-weight-bold">{{ pageTitle }}</div>
          <div class="text-caption text-grey-7">
            {{ order.order_no }} · {{ order.name }}
          </div>
        </div>
        <div class="row items-center q-gutter-x-sm">
          <q-btn
            v-if="billId > 0"
            flat
            no-caps
            color="primary"
            icon="ph ph-receipt"
            :label="$t('shop_admin.catalog_open_bill_detail', 'Open bill')"
            @click="router.push(billDetailRoute(billId, authStore.tenantSlug || undefined))"
          />
          <q-btn
            v-if="canDeleteDraftBill"
            flat
            no-caps
            color="negative"
            icon="ph ph-trash"
            :label="$t('shop_admin.catalog_delete_draft_bill', 'Delete draft bill')"
            :loading="deleteBillLoading"
            :disable="deleteBillLoading"
            @click="onDeleteDraftBill"
          />
          <q-btn
            flat
            no-caps
            icon="ph ph-arrow-left"
            :label="$t('common.back', 'Back')"
            @click="router.push({ name: 'app-shop-order-detail-page', params: { id: String(orderId) } })"
          />
        </div>
      </div>

      <q-banner
        v-if="(coverageQuery.data.value?.bills_count ?? 0) > 0"
        dense
        rounded
        class="bg-blue-1 text-blue-10"
      >
        {{ $t('shop_admin.catalog_create_bill_partial_banner', 'Partial billing — remaining qty per line below.') }}
      </q-banner>

      <div class="compose-kind-group row items-center no-wrap q-gutter-x-sm">
        <div class="column">
          <div class="text-caption text-weight-bold text-grey-8 q-mb-xs">
            {{ $t('shop_admin.catalog_bill_settlement', 'Settlement') }}
          </div>
          <q-btn-toggle
          :model-value="settlementKind"
          no-caps
          unelevated
          toggle-color="primary"
          @update:model-value="onSettlementKindChange"
          :options="[
            {
              label: $t('shop_admin.catalog_bill_take', 'Take'),
              value: 'take',
              icon: 'ph ph-arrow-circle-down',
              disable: settlementSaving,
            },
            {
              label: $t('shop_admin.catalog_bill_condition', 'Condition'),
              value: 'condition',
              icon: 'ph ph-seal-check',
              disable: settlementSaving,
            },
          ]"
          />
        </div>
        <q-spinner v-if="settlementSaving" size="16px" color="primary" class="q-mt-lg" />
      </div>

      <q-table
        flat
        bordered
        :rows="tableRows"
        :row-key="(row) => row.item.id"
        :columns="columns"
        :loading="coverageQuery.isLoading.value"
        hide-pagination
        :pagination="{ rowsPerPage: 0 }"
      >
        <template #body-cell-image="props">
          <q-td :props="props">
            <q-img
              v-if="props.row.item.image_url || props.row.item.product_image_url"
              :src="(props.row.item.image_url || props.row.item.product_image_url)!"
              ratio="1"
              width="40px"
              class="rounded-borders"
            />
            <q-icon v-else name="ph ph-image" size="28px" color="grey-5" />
          </q-td>
        </template>
        <template #body-cell-name="props">
          <q-td :props="props">
            <div class="text-body2 text-weight-medium">{{ props.row.item.name }}</div>
          </q-td>
        </template>
        <template #body-cell-actions="props">
          <q-td :props="props">
            <q-btn
              dense
              no-caps
              unelevated
              color="primary"
              :disable="props.row.remaining <= 0 || billId <= 0"
              :label="$t('shop_admin.catalog_pick_stock', 'Pick stock')"
              @click="openPick(props.row)"
            />
          </q-td>
        </template>
      </q-table>

      <div class="text-caption text-grey-7 q-pt-sm">{{ pickHint }}</div>
    </template>

    <CatalogOrderBillStockDialog
      v-model="pickDialogOpen"
      :order-item="pickTargetItem"
      :order-id="orderId"
      :desk-tenant-id="deskTenantId"
      :bill-id="billId"
      :books-tenant-id="booksTenantId"
      :bill-lines="billLines"
      :needed-quantity="pickDialogQuantities.neededQuantity"
      :on-this-bill-quantity="pickDialogQuantities.onThisBill"
      @updated="onBillStockUpdated"
    />
  </q-page>
</template>