<template>
  <q-page class="invoice-desk-page theme-app">
    <div class="invoice-desk-page__stack">
      <InvoiceDeskChrome
        :invoice-no="loadedInvoiceNo"
        :type-chip-label="isExistingInvoice ? typeChipLabel : undefined"
        :status-chip-label="statusChipLabel"
        :status-chip-color="statusChipStyle.color"
        :status-chip-text-color="statusChipStyle.textColor"
        :payment-chip-label="paymentChipLabel"
        :payment-chip-color="paymentChipStyle.color"
        :payment-chip-text-color="paymentChipStyle.textColor"
        :show-payment-chip="loadedInvoiceStatus === 'issued'"
        :validation-reasons="!canSaveDraft ? validationReasons : []"
      >
        <template v-if="!isExistingInvoice" #type>
          <q-btn-toggle
            :model-value="composerBillType"
            unelevated
            dense
            no-caps
            toggle-color="primary"
            :options="billTypeToggleOptions"
            class="composer-type-toggle"
            @update:model-value="onComposerBillTypeChange"
          />
        </template>

        <template #secondary>
          <template v-if="loadedInvoiceStatus === 'issued'">
            <q-btn
              outline
              dense
              no-caps
              color="primary"
              icon="ph ph-clock-counter-clockwise"
              label="Payment history"
              class="invoice-desk-chrome__btn text-weight-bold"
              @click="paymentHistoryOpen = true"
            />
          </template>
          <template v-else-if="loadedInvoiceStatus === 'proforma_generated'">
            <q-btn
              outline
              dense
              no-caps
              color="primary"
              icon="ph ph-printer"
              label="Preview"
              class="invoice-desk-chrome__btn text-weight-bold"
              @click="openPreview"
            />
          </template>
        </template>

        <template #primary>
          <template v-if="loadedInvoiceStatus === 'issued'">
            <q-btn
              v-if="canRecordPayment"
              unelevated
              dense
              no-caps
              color="primary"
              icon="ph ph-money"
              label="Record payment"
              class="invoice-desk-chrome__btn text-weight-bold"
              @click="openCollectDialog"
            />
          </template>
          <template v-else-if="loadedInvoiceStatus === 'proforma_generated'">
            <q-btn
              outline
              dense
              no-caps
              color="primary"
              icon="ph ph-floppy-disk"
              label="Save"
              class="invoice-desk-chrome__btn text-weight-bold"
              :disable="!canSaveDraft || isSaving"
              :loading="isSaving && selectedSaveStatus === 'draft'"
              @click="handleSyncSave"
            />
            <q-btn
              unelevated
              dense
              no-caps
              color="primary"
              icon="ph ph-check-circle"
              label="Issue"
              class="invoice-desk-chrome__btn text-weight-bold"
              :disable="!canSaveDraft || isSaving"
              :loading="isSaving && selectedSaveStatus === 'issued'"
              @click="handleSaveInvoice('issued')"
            />
          </template>
          <template v-else-if="existingInvoiceId && loadedInvoiceStatus === 'draft'">
            <q-btn
              outline
              dense
              no-caps
              color="primary"
              icon="ph ph-floppy-disk"
              label="Save"
              class="invoice-desk-chrome__btn text-weight-bold"
              :disable="!canSaveDraft || isSaving"
              :loading="isSaving && selectedSaveStatus === 'draft'"
              @click="handleSaveInvoice('draft')"
            />
            <q-btn
              unelevated
              dense
              no-caps
              color="primary"
              icon="ph ph-check-circle"
              label="Issue"
              class="invoice-desk-chrome__btn text-weight-bold"
              :disable="!canSaveDraft || isSaving"
              :loading="isSaving && selectedSaveStatus === 'issued'"
              @click="handleSaveInvoice('issued')"
            />
          </template>
          <q-btn
            v-else
            unelevated
            dense
            no-caps
            color="primary"
            icon="ph ph-floppy-disk"
            label="Save draft"
            class="invoice-desk-chrome__btn text-weight-bold"
            :disable="!canSaveDraft || isSaving"
            :loading="isSaving && selectedSaveStatus === 'draft'"
            @click="handleSaveInvoice('draft')"
          />
        </template>

        <template #overflow>
          <q-btn-dropdown
            v-if="existingInvoiceId && loadedInvoiceStatus === 'draft'"
            flat
            dense
            no-caps
            color="grey-8"
            icon="ph ph-dots-three-vertical"
            label="More"
            class="invoice-desk-chrome__btn"
            :disable="!canSaveDraft || isSaving"
          >
            <q-list dense>
              <q-item
                v-close-popup
                clickable
                :disable="isSaving"
                @click="handleSaveInvoice('proforma_generated')"
              >
                <q-item-section avatar>
                  <q-icon name="ph ph-file-text" color="primary" />
                </q-item-section>
                <q-item-section>Make proforma</q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
        </template>
      </InvoiceDeskChrome>

      <WholesaleInvoicePaper
        v-model:selected-brand-id="selectedBrandId"
        v-model:selected-billing-profile-id="selectedBillingProfileId"
        v-model:overall-discount-input="overallDiscountInput"
        v-model:stock-search-text="stockSearchText"
        :brand-options="brandOptions"
        :brands-loading="brandsLoading"
        :billing-profile-options="billingProfileOptions"
        :billing-profiles-loading="billingProfilesLoading"
        :invoice-items="invoiceItems"
        :has-returned-items="hasReturnedItems"
        :is-searching-stock="isSearchingStock"
        :stock-search-results="stockSearchResults"
        :total-quantity="totalQuantity"
        :total-return-quantity="totalReturnQuantity"
        :total-return-credit="totalReturnCredit"
        :subtotal-amount="subtotalAmount"
        :total-discount-amount="totalDiscountAmount"
        :grand-total-amount="grandTotalAmount"
        :overall-discount-locked="loadedInvoiceStatus === 'issued'"
        @filter-billing-profiles="filterBillingProfiles"
        @stock-search-input="onStockSearchInput"
        @search-focus="onSearchFocus"
        @clear-stock-search="clearStockSearch"
        @add-stock="addStockToInvoice"
        @remove-item="removeInvoiceItem"
        @apply-overall-discount="applyOverallDiscountEqually"
      />
    </div>

    <WholesaleCollectPaymentDialog
      v-model="collectDialogOpen"
      :due-amount="loadedDueAmount"
      :paid-amount="loadedPaidAmount"
      :store-credit="storeCreditBalance"
      :saving="collectSaving"
      @submit="onCollectPayment"
    />

    <InvoicePaymentHistoryDrawer
      v-model="paymentHistoryOpen"
      :tenant-id="effectiveTenantId"
      :invoice-id="existingInvoiceId"
      :invoice-no="loadedInvoiceNo"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { useQuasar } from 'quasar';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import {
  invoiceRepository,
  type InvoiceBrand,
  type SalesInvoiceFromPayloadInput,
  type SalesInvoicePayloadItem,
  type SalesInvoiceStockItem,
} from '../repositories/invoiceRepository';
import type { BillingProfile } from '../repositories/billingProfileRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import WholesaleCollectPaymentDialog from '../components/WholesaleCollectPaymentDialog.vue';
import InvoicePaymentHistoryDrawer from '../components/InvoicePaymentHistoryDrawer.vue';
import InvoiceDeskChrome from '../components/InvoiceDeskChrome.vue';
import WholesaleInvoicePaper from '../components/WholesaleInvoicePaper.vue';
import type { InvoiceLineDraftItem } from '../types/wholesaleInvoiceDraft';
import type { WholesaleCollectPaymentPayload } from '../types';
import { walletRepository } from 'src/modules/wallet/repositories/walletRepository';
import WholesaleIssueConfirmDialog, {
  type WholesaleIssueDialogItem,
} from '../components/WholesaleIssueConfirmDialog.vue';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';

type BillingProfileWithTenant = BillingProfile & {
  tenant?: { id: number; name: string; slug: string } | null;
  parent_tenant?: { id: number; name: string; slug: string } | null;
};

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

const existingInvoiceId = computed(() => {
  const qId = route.query.id;
  if (typeof qId === 'string' && qId) return Number(qId);
  const pId = route.params.id;
  if (typeof pId === 'string' && pId) return Number(pId);
  return null;
});

const isExistingInvoice = computed(() => Boolean(existingInvoiceId.value));
const loadedInvoiceNo = ref('');

type ComposerBillType = 'wholesale' | 'retail';
const parseComposerBillType = (raw: unknown): ComposerBillType =>
  raw === 'retail' ? 'retail' : 'wholesale';
const composerBillType = ref<ComposerBillType>(parseComposerBillType(route.query.type));
const billTypeToggleOptions = [
  { label: 'Trade', value: 'wholesale' },
  { label: 'Retail', value: 'retail' },
];
const typeChipLabel = computed(() => (composerBillType.value === 'retail' ? 'Retail' : 'Trade'));
const onComposerBillTypeChange = (value: string | number | boolean | null) => {
  const next: ComposerBillType = value === 'retail' ? 'retail' : 'wholesale';
  composerBillType.value = next;
  const nextQuery = { ...route.query };
  if (next === 'retail') nextQuery.type = 'retail';
  else delete nextQuery.type;
  void router.replace({ query: nextQuery });
};

usePageBreadcrumbs(() => {
  const tenantSlug =
    (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : '') ||
    authStore.selectedTenant?.slug ||
    '';
  return [
    {
      label: authStore.selectedTenant?.name || tenantStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    {
      label: 'Invoices',
      to: { name: 'app-global-invoices-page', params: tenantSlug ? { tenantSlug } : {} },
    },
    {
      label: loadedInvoiceNo.value ? `#${loadedInvoiceNo.value}` : 'New bill',
    },
  ];
});
const loadedInvoiceStatus = ref('');
const loadedPaymentStatus = ref('due');
const loadedDueAmount = ref(0);
const loadedPaidAmount = ref(0);
const loadedItemIds = ref<number[]>([]);
const collectDialogOpen = ref(false);
const collectSaving = ref(false);
const storeCreditBalance = ref(0);
const paymentHistoryOpen = ref(false);
const effectivePaymentStatus = computed(() => loadedPaymentStatus.value || 'due');

const statusChipLabel = computed(() => {
  if (!existingInvoiceId.value) return 'New';
  const status = loadedInvoiceStatus.value;
  if (status === 'proforma_generated') return 'Proforma';
  if (status === 'issued') return 'Issued';
  if (status === 'draft') return 'Draft';
  return status ? status.replace(/_/g, ' ') : 'New';
});

const statusChipStyle = computed(() => {
  const status = loadedInvoiceStatus.value;
  if (status === 'issued') return { color: 'green-1', textColor: 'green-9' };
  if (status === 'proforma_generated') return { color: 'blue-1', textColor: 'blue-9' };
  if (status === 'draft') return { color: 'grey-2', textColor: 'grey-9' };
  return { color: 'amber-1', textColor: 'amber-10' };
});

const paymentChipLabel = computed(() => {
  const ps = effectivePaymentStatus.value;
  if (ps === 'paid') return 'Paid';
  if (ps === 'partial') return 'Partial';
  if (ps === 'due' || ps === 'unpaid') return 'Due';
  return ps.replace(/_/g, ' ');
});

const paymentChipStyle = computed(() => {
  const ps = effectivePaymentStatus.value;
  if (ps === 'paid') return { color: 'green-1', textColor: 'green-9' };
  if (ps === 'partial') return { color: 'blue-1', textColor: 'blue-9' };
  return { color: 'red-1', textColor: 'red-9' };
});

const canRecordPayment = computed(() => {
  if (loadedInvoiceStatus.value !== 'issued') return false;
  if ((loadedDueAmount.value || 0) <= 0) return false;
  const ps = loadedPaymentStatus.value;
  return ps === 'due' || ps === 'partial' || ps === 'partially_paid';
});
const isLoadingInvoice = ref(false);

const loadExistingInvoice = async () => {
  const invId = existingInvoiceId.value;
  if (!invId) return;

  isLoadingInvoice.value = true;
  try {
    const [inv, invItems] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(invId),
      invoiceRepository.listGlobalInvoiceItems(invId),
    ]);

    if (inv) {
      loadedInvoiceNo.value = inv.invoice_no;
      loadedInvoiceStatus.value = inv.invoice_status;
      loadedPaymentStatus.value = inv.payment_status || 'due';
      loadedDueAmount.value = Number(inv.due_amount ?? 0);
      loadedPaidAmount.value = Number(inv.paid_amount ?? 0);
      selectedBillingProfileId.value = inv.billing_profile_id ?? null;
      overallDiscountInput.value = inv.discount_amount ?? 0;
      if (inv.invoice_type === 'retail') composerBillType.value = 'retail';
      else composerBillType.value = 'wholesale';
      if (inv.invoice_status === 'issued' || inv.invoice_status === 'voided') {
        void router.replace({
          name: 'app-global-invoice-details-page',
          params: {
            tenantSlug: route.params.tenantSlug,
            id: String(invId),
          },
        });
        return;
      }
    }

    loadedItemIds.value = (invItems ?? []).map((item) => item.id);

    if (invItems && invItems.length > 0) {
      invoiceItems.value = invItems.map((item) => ({
        id: item.id,
        global_stock_id: item.global_stock_id,
        shipment_item_id: 0,
        product_id: null,
        name: item.name_snapshot,
        barcode: null,
        product_code: null,
        image_url: item.image_url ?? null,
        quantity: Number(item.quantity),
        available_atp: item.available_atp != null ? Number(item.available_atp) : Number(item.quantity),
        unit_cost_price: Number(item.unit_cost_price ?? 0),
        sell_price_amount: Number(item.sell_price_amount),
        return_quantity: Number(item.return_quantity ?? 0),
        line_discount_amount: Number(item.line_discount_amount),
        shipment_id: 0,
        shipment_name: 'Shipment',
        holding_tenant_id: effectiveTenantId.value ?? 0,
        holding_tenant_name: '',
        is_allocated_to_tenant: true,
      }));
    }
  } catch (err) {
    console.error('Error loading existing wholesale invoice:', err);
  } finally {
    isLoadingInvoice.value = false;
  }
};

watch(
  existingInvoiceId,
  (newVal) => {
    if (newVal) {
      void loadExistingInvoice();
    }
  },
  { immediate: true },
);

const effectiveTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  if (!current) return authStore.tenantId;
  return current.id;
});

const effectiveParentTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  return current?.parent_id ?? current?.id ?? authStore.tenantId;
});

// 1. Query Invoice Brands
const brandsQuery = useQuery({
  queryKey: computed(() =>
    salesInvoiceQueryKeys.brands(effectiveTenantId.value, {
      parentTenantId: effectiveParentTenantId.value,
    }),
  ),
  queryFn: async () => {
    const tenantId = effectiveTenantId.value;
    if (!tenantId) return [];

    const tenantIds = new Set<number>([tenantId]);
    if (effectiveParentTenantId.value) {
      tenantIds.add(effectiveParentTenantId.value);
    }

    const lists = await Promise.all(
      [...tenantIds].map((id) => invoiceRepository.listInvoiceBrands({ parent_tenant_id: id })),
    );

    const merged = new Map<number, InvoiceBrand>();
    for (const list of lists) {
      for (const brand of list) {
        merged.set(brand.id, brand);
      }
    }

    return [...merged.values()].sort((a, b) => a.name.localeCompare(b.name));
  },
  enabled: computed(() => !!effectiveTenantId.value),
  placeholderData: (prev) => prev,
});

const brands = computed(() => brandsQuery.data.value ?? []);
const brandOptions = computed(() => brands.value);
const brandsLoading = computed(() => brandsQuery.isFetching.value);
const selectedBrandId = ref<number | null>(null);

// Auto-select if only 1 brand exists
watch(
  brands,
  (loadedBrands) => {
    if (!selectedBrandId.value && loadedBrands.length === 1 && loadedBrands[0]) {
      selectedBrandId.value = loadedBrands[0].id;
    }
  },
  { immediate: true },
);

// 2. Query Billing Profiles (Customers) with Tenant metadata
const billingProfilesQuery = useQuery({
  queryKey: computed(() =>
    salesInvoiceQueryKeys.billingProfiles(effectiveTenantId.value, {
      parentTenantId: effectiveParentTenantId.value,
    }),
  ),
  queryFn: async () => {
    let query = supabase
      .from('billing_profiles')
      .select('*, tenant:tenant_id(id, name, slug), parent_tenant:parent_tenant_id(id, name, slug)');

    if (effectiveParentTenantId.value) {
      query = query.or(
        `parent_tenant_id.eq.${effectiveParentTenantId.value},tenant_id.eq.${effectiveParentTenantId.value}`,
      );
    } else if (effectiveTenantId.value) {
      query = query.eq('tenant_id', effectiveTenantId.value);
    }

    const { data, error } = await query.order('name', { ascending: true });
    if (error) throw error;
    return (data || []) as BillingProfileWithTenant[];
  },
  enabled: computed(() => !!effectiveTenantId.value),
  placeholderData: (prev) => prev,
});

const billingProfiles = computed(() => billingProfilesQuery.data.value ?? []);
const billingProfileFilterText = ref('');
const billingProfilesLoading = computed(() => billingProfilesQuery.isFetching.value);
const selectedBillingProfileId = ref<number | null>(null);

const billingProfileOptions = computed(() => {
  const needle = billingProfileFilterText.value.trim().toLowerCase();
  if (!needle) return billingProfiles.value;
  return billingProfiles.value.filter(
    (p) =>
      p.name.toLowerCase().includes(needle) ||
      (p.phone && p.phone.toLowerCase().includes(needle)) ||
      (p.email && p.email.toLowerCase().includes(needle)) ||
      (p.tenant?.name && p.tenant.name.toLowerCase().includes(needle)),
  );
});

const filterBillingProfiles = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    billingProfileFilterText.value = val;
  });
};

// 3. Invoice Items & Live Stock Search Menu
const invoiceItems = ref<InvoiceLineDraftItem[]>([]);
const hasReturnedItems = computed(() =>
  invoiceItems.value.some((item) => (item.return_quantity || 0) > 0),
);
const stockSearchText = ref('');
const isSearchingStock = ref(false);
const stockSearchResults = ref<SalesInvoiceStockItem[]>([]);
let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

const performStockSearch = async () => {
  const tenantId = effectiveTenantId.value;
  if (!tenantId) return;

  isSearchingStock.value = true;
  try {
    const results = await invoiceRepository.searchSalesInvoiceStock({
      tenantId,
      search: stockSearchText.value,
      limit: 30,
    });
    stockSearchResults.value = results;
  } catch (err) {
    console.error('Error searching stock:', err);
    stockSearchResults.value = [];
  } finally {
    isSearchingStock.value = false;
  }
};

const onStockSearchInput = () => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(() => {
    void performStockSearch();
  }, 250);
};

const onSearchFocus = () => {
  if (!stockSearchResults.value.length) {
    void performStockSearch();
  }
};

const clearStockSearch = () => {
  stockSearchText.value = '';
  void performStockSearch();
};

const addStockToInvoice = (stock: SalesInvoiceStockItem) => {
  if (invoiceItems.value.some((item) => item.global_stock_id === stock.global_stock_id)) return;

  const cost = Number(stock.unit_cost_price) || 0;
  // Default prefill is 20% markup over unit cost price (user can edit freely)
  const defaultSellPrice = cost > 0 ? Math.round(cost * 1.2 * 100) / 100 : (Number(stock.suggested_sell_price) || 0);

  invoiceItems.value.push({
    global_stock_id: stock.global_stock_id,
    shipment_item_id: stock.shipment_item_id,
    product_id: stock.product_id,
    name: stock.name,
    barcode: stock.barcode,
    product_code: stock.product_code,
    image_url: stock.image_url,
    quantity: 1,
    available_atp: Number(stock.available_atp) || 1,
    unit_cost_price: cost,
    sell_price_amount: Number(defaultSellPrice) || 0,
    return_quantity: 0,
    line_discount_amount: 0,
    shipment_id: stock.shipment_id,
    shipment_name: stock.shipment_name,
    holding_tenant_id: stock.holding_tenant_id,
    holding_tenant_name: stock.holding_tenant_name,
    is_allocated_to_tenant: stock.is_allocated_to_tenant,
  });
};

const removeInvoiceItem = (index: number) => {
  invoiceItems.value.splice(index, 1);
};

const overallDiscountInput = ref<number | null>(null);

const applyOverallDiscountEqually = (val: string | number | null) => {
  const count = invoiceItems.value.length;
  if (!count) return;

  const totalDiscount = Number(val) || 0;
  if (totalDiscount <= 0) {
    invoiceItems.value.forEach((item) => {
      item.line_discount_amount = 0;
    });
    return;
  }

  // Distribute equally across items, with cent rounding remainder applied to the first item
  const baseLineDiscount = Math.floor((totalDiscount / count) * 100) / 100;
  const remainder = Math.round((totalDiscount - baseLineDiscount * count) * 100) / 100;

  invoiceItems.value.forEach((item, index) => {
    const extra = index === 0 ? remainder : 0;
    const allocated = baseLineDiscount + extra;
    const maxDiscount = (item.quantity || 0) * (item.sell_price_amount || 0);
    item.line_discount_amount = Math.min(maxDiscount, Math.max(0, Math.round(allocated * 100) / 100));
  });
};

const totalQuantity = computed(() =>
  invoiceItems.value.reduce((acc, item) => acc + (Number(item.quantity) || 0), 0),
);

const totalReturnQuantity = computed(() =>
  invoiceItems.value.reduce((acc, item) => acc + (Number(item.return_quantity) || 0), 0),
);

const totalReturnCredit = computed(() =>
  invoiceItems.value.reduce(
    (acc, item) => acc + (Number(item.return_quantity) || 0) * (Number(item.sell_price_amount) || 0),
    0,
  ),
);

const subtotalAmount = computed(() =>
  invoiceItems.value.reduce(
    (acc, item) => acc + (Number(item.quantity) || 0) * (Number(item.sell_price_amount) || 0),
    0,
  ),
);

const totalDiscountAmount = computed(() =>
  invoiceItems.value.reduce((acc, item) => acc + (Number(item.line_discount_amount) || 0), 0),
);

const grandTotalAmount = computed(() =>
  Math.max(0, subtotalAmount.value - totalDiscountAmount.value - totalReturnCredit.value),
);

// Save Invoice States (Default: Draft)
export type WholesaleInvoiceSaveStatus = 'draft' | 'proforma_generated' | 'issued';
const selectedSaveStatus = ref<WholesaleInvoiceSaveStatus>('draft');
const isSaving = ref(false);

const openCollectDialog = async () => {
  collectDialogOpen.value = true;
  const profileId = selectedBillingProfileId.value;
  const tenantId = effectiveParentTenantId.value;
  if (!profileId || !tenantId) {
    storeCreditBalance.value = 0;
    return;
  }
  try {
    storeCreditBalance.value = await walletRepository.fetchLatestBalance({
      tenantId,
      entityType: 'customer',
      entityId: profileId,
    });
  } catch {
    storeCreditBalance.value = 0;
  }
};

const onCollectPayment = async (payload: WholesaleCollectPaymentPayload) => {
  const invId = existingInvoiceId.value;
  if (!invId) return;
  collectSaving.value = true;
  try {
    await invoiceRepository.collectWholesaleInvoicePayment({
      invoice_id: invId,
      instruments: payload.instruments,
      wallet_amount: payload.walletAmount,
      settlement_amount: payload.settlementAmount,
      note: payload.note,
      received_on: payload.receivedOn,
    });
    collectDialogOpen.value = false;
    await loadExistingInvoice();
    showSuccessNotification('Payment recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Payment failed.');
  } finally {
    collectSaving.value = false;
  }
};

const openPreview = () => {
  const invId = existingInvoiceId.value;
  if (!invId) return;
  const routeData = router.resolve({
    name: 'app-global-invoice-preview',
    params: {
      tenantSlug: authStore.tenantSlug || '',

      id: String(invId),
    },
  });
  window.open(routeData.href, '_blank');
};

const buildPayloadItems = (): SalesInvoicePayloadItem[] =>
  invoiceItems.value.map((item) => ({
    ...(item.id ? { id: item.id } : {}),
    global_stock_id: item.global_stock_id,
    quantity: item.quantity,
    sell_price_amount: item.sell_price_amount,
    line_discount_amount: item.line_discount_amount || 0,
  }));

const buildComposerPayload = (issue: boolean, invoiceNo?: string): SalesInvoiceFromPayloadInput => ({
  invoice: {
    ...(invoiceNo ? { invoice_no: invoiceNo } : {}),
    invoice_type: composerBillType.value,
    billing_profile_id: selectedBillingProfileId.value!,
    invoice_date: new Date().toISOString().slice(0, 10),
    discount_amount: totalDiscountAmount.value,
    ...(composerBillType.value === 'retail' ? { retail_billing_mode: 'account' as const } : {}),
  },
  items: buildPayloadItems(),
  issue,
});

const syncExistingDraft = async (invoiceId: number, tenantId: number) => {
  const currentIds = new Set(
    invoiceItems.value.map((item) => item.id).filter((id): id is number => typeof id === 'number'),
  );
  const removeItemIds = loadedItemIds.value.filter((id) => !currentIds.has(id));

  await invoiceRepository.updateSalesInvoiceFromPayload(tenantId, invoiceId, {
    invoice: {
      billing_profile_id: selectedBillingProfileId.value!,
      discount_amount: totalDiscountAmount.value,
    },
    items: buildPayloadItems(),
    remove_item_ids: removeItemIds,
    options: { recompute_totals: true },
  });

  loadedItemIds.value = invoiceItems.value
    .map((item) => item.id)
    .filter((id): id is number => typeof id === 'number');
};

const persistInvoiceResult = async (
  invoiceId: number,
  invoiceNo?: string | null,
  invoiceStatus?: string | null,
  paymentStatus?: string | null,
  dueAmount?: number | null,
  paidAmount?: number | null,
) => {
  if (invoiceNo) loadedInvoiceNo.value = invoiceNo;
  if (invoiceStatus) loadedInvoiceStatus.value = invoiceStatus;
  if (paymentStatus) loadedPaymentStatus.value = paymentStatus;
  if (dueAmount != null) loadedDueAmount.value = Number(dueAmount);
  if (paidAmount != null) loadedPaidAmount.value = Number(paidAmount);
  void router.replace({
    query: { ...route.query, id: String(invoiceId) },
  });
};

const issueWholesaleFromDialog = async (
  targetInvoiceId: number | null,
  tenantId: number,
  isNewInvoice: boolean,
) => {
  const stockIds = invoiceItems.value.map((i) => i.global_stock_id);
  const { data: stocksData, error: stocksError } = await supabase
    .from('global_stocks')
    .select('id, quantity')
    .in('id', stockIds);

  if (stocksError) {
    console.error('Error fetching stock availability:', stocksError);
  }

  const stockMap = new Map((stocksData || []).map((s) => [s.id, Number(s.quantity)]));

  $q.dialog({
    component: WholesaleIssueConfirmDialog,
    componentProps: {
      invoiceId: targetInvoiceId,
      invoiceNo: loadedInvoiceNo.value || (targetInvoiceId ? String(targetInvoiceId) : 'New'),
      items: invoiceItems.value.map((i) => ({
        id: i.id,
        global_stock_id: i.global_stock_id,
        name: i.name,
        image_url: i.image_url,
        shipment_name: i.shipment_name,
        available_stock: stockMap.has(i.global_stock_id)
          ? (stockMap.get(i.global_stock_id) ?? 0)
          : i.available_atp,
        quantity: i.quantity,
      })),
    },
  }).onOk((data: { items: WholesaleIssueDialogItem[] }) => {
    void (async () => {
      isSaving.value = true;
      try {
        for (const updatedItem of data.items) {
          const existing = invoiceItems.value.find(
            (i) => i.global_stock_id === updatedItem.global_stock_id,
          );
          if (existing) {
            existing.quantity = updatedItem.quantity;
          }
        }

        if (isNewInvoice) {
          const invoiceNo =
            loadedInvoiceNo.value ||
            (await invoiceRepository.generateInvoiceNumber(tenantId, composerBillType.value));
          const result = await invoiceRepository.createSalesInvoiceFromPayload(
            tenantId,
            buildComposerPayload(true, invoiceNo),
          );
          if (!result.invoice_id) throw new Error('Invoice was not created');
          void router.replace({
            name: 'app-global-invoice-details-page',
            params: {
              tenantSlug: route.params.tenantSlug,
              id: String(result.invoice_id),
            },
          });
        } else if (targetInvoiceId) {
          await invoiceRepository.issueWholesaleInvoice(
            targetInvoiceId,
            data.items.map((i) => ({
              ...(i.id ? { id: i.id } : {}),
              global_stock_id: i.global_stock_id,
              quantity: i.quantity,
            })),
          );
          void router.replace({
            name: 'app-global-invoice-details-page',
            params: {
              tenantSlug: route.params.tenantSlug,
              id: String(targetInvoiceId),
            },
          });
        }

        showSuccessNotification('Invoice issued and stock deducted successfully.');
      } catch (err) {
        console.error('Error issuing invoice:', err);
        showWarningDialog(err instanceof Error ? err.message : 'Error issuing invoice');
      } finally {
        isSaving.value = false;
      }
    })();
  }).onDismiss(() => {
    isSaving.value = false;
  });
};

const handleSyncSave = async () => {
  selectedSaveStatus.value = 'draft';
  if (!canSaveDraft.value || isSaving.value) return;

  const tenantId = effectiveTenantId.value;
  const targetInvoiceId = existingInvoiceId.value;
  if (!tenantId || !targetInvoiceId) return;

  isSaving.value = true;
  try {
    await syncExistingDraft(targetInvoiceId, tenantId);
    showSuccessNotification('Invoice saved.');
  } catch (err) {
    console.error('Error saving invoice:', err);
    showWarningDialog(err instanceof Error ? err.message : 'Error saving invoice');
  } finally {
    isSaving.value = false;
  }
};

const handleSaveInvoice = async (status: WholesaleInvoiceSaveStatus) => {
  selectedSaveStatus.value = status;
  if (!canSaveDraft.value || isSaving.value) return;

  const tenantId = effectiveTenantId.value;
  const parentTenantId = effectiveParentTenantId.value;
  if (!tenantId || !parentTenantId || !selectedBillingProfileId.value) return;

  if (status === 'issued') {
    isSaving.value = true;
    try {
      const currentId = existingInvoiceId.value;
      if (currentId) {
        await syncExistingDraft(currentId, tenantId);
      }
      await issueWholesaleFromDialog(currentId, tenantId, !currentId);
    } catch (err) {
      console.error('Error preparing wholesale invoice issue:', err);
      showWarningDialog(err instanceof Error ? err.message : 'Error issuing invoice');
      isSaving.value = false;
    }
    return;
  }

  isSaving.value = true;
  try {
    let targetInvoiceId = existingInvoiceId.value;

    if (targetInvoiceId) {
      await syncExistingDraft(targetInvoiceId, tenantId);
      if (status === 'proforma_generated') {
        await invoiceRepository.markInvoiceProformaGenerated(targetInvoiceId);
        await persistInvoiceResult(targetInvoiceId, loadedInvoiceNo.value, 'proforma_generated');
        showSuccessNotification('Proforma saved. Preview is now available.');
        return;
      }

      await persistInvoiceResult(targetInvoiceId, loadedInvoiceNo.value, 'draft');
      showSuccessNotification('Invoice saved.');
      return;
    }

    const invoiceNo = await invoiceRepository.generateInvoiceNumber(tenantId, composerBillType.value);
    const result = await invoiceRepository.createSalesInvoiceFromPayload(
      tenantId,
      buildComposerPayload(false, invoiceNo),
    );
    targetInvoiceId = result.invoice_id ?? null;
    if (!targetInvoiceId) throw new Error('Invoice was not created');

    loadedItemIds.value = invoiceItems.value
      .map((item) => item.id)
      .filter((id): id is number => typeof id === 'number');

    if (status === 'proforma_generated') {
      await invoiceRepository.markInvoiceProformaGenerated(targetInvoiceId);
      await persistInvoiceResult(
        targetInvoiceId,
        result.invoice_no,
        'proforma_generated',
        result.payment_status,
        result.due_amount,
        result.paid_amount,
      );
      showSuccessNotification('Proforma saved. Preview is now available.');
      return;
    }

    await persistInvoiceResult(
      targetInvoiceId,
      result.invoice_no,
      result.invoice_status,
      result.payment_status,
      result.due_amount,
      result.paid_amount,
    );
    showSuccessNotification('Invoice saved as draft.');
  } catch (err) {
    console.error('Error saving invoice:', err);
    showWarningDialog(err instanceof Error ? err.message : 'Error saving invoice');
  } finally {
    isSaving.value = false;
  }
};

const validationReasons = computed(() => {
  const reasons: string[] = [];
  if (!selectedBrandId.value) reasons.push('1. Select an Invoice Brand');
  if (!selectedBillingProfileId.value) reasons.push('2. Select a Customer Billing Profile');
  if (!invoiceItems.value.length) reasons.push('3. Add at least 1 item from stock');
  return reasons;
});

const canSaveDraft = computed(() => validationReasons.value.length === 0);
</script>

<style scoped lang="scss">
@import '../styles/invoice-desk.scss';

.composer-type-toggle {
  border-radius: var(--bw-radius-sm, 8px);
}
</style>
