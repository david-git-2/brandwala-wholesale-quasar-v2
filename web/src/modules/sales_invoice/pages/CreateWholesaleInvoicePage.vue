<template>
  <q-page class="create-wholesale-invoice-page bw-page-fill q-py-md">
    <div class="column no-wrap create-wholesale-invoice-page__stack">
      <div
        v-if="existingInvoiceId"
        class="row items-center justify-between bg-white q-pa-xs q-px-sm rounded-borders-8 border-light shadow-1 create-wholesale-invoice-page__workflow"
      >
        <div class="row items-center q-gutter-xs">
          <!-- Draft Status -->
          <q-btn
            :color="loadedInvoiceStatus === 'draft' ? 'grey-8' : 'grey-4'"
            :text-color="loadedInvoiceStatus === 'draft' ? 'white' : 'grey-8'"
            :unelevated="loadedInvoiceStatus === 'draft'"
            :outline="loadedInvoiceStatus !== 'draft'"
            dense
            no-caps
            class="q-px-sm text-caption text-weight-bold"
            :loading="isSaving && selectedSaveStatus === 'draft'"
            :disable="isSaving"
            @click="handleSaveInvoice('draft')"
          >
            <q-icon
              v-if="loadedInvoiceStatus === 'draft'"
              name="ph ph-check-circle"
              size="13px"
              class="q-mr-xs"
            />
            Saved as Draft
          </q-btn>

          <q-icon name="ph ph-caret-right" color="grey-5" size="14px" />

          <!-- Proforma Status -->
          <q-btn
            :color="loadedInvoiceStatus === 'proforma_generated' ? 'primary' : 'grey-4'"
            :text-color="loadedInvoiceStatus === 'proforma_generated' ? 'white' : 'primary'"
            :unelevated="loadedInvoiceStatus === 'proforma_generated'"
            :outline="loadedInvoiceStatus !== 'proforma_generated'"
            dense
            no-caps
            class="q-px-sm text-caption text-weight-bold"
            :loading="isSaving && selectedSaveStatus === 'proforma_generated'"
            :disable="isSaving"
            @click="handleSaveInvoice('proforma_generated')"
          >
            <q-icon
              v-if="loadedInvoiceStatus === 'proforma_generated'"
              name="ph ph-check-circle"
              size="13px"
              class="q-mr-xs"
            />
            {{ loadedInvoiceStatus === 'proforma_generated' ? 'PF Generated' : 'Save as PF' }}
          </q-btn>

          <q-icon name="ph ph-caret-right" color="grey-5" size="14px" />

          <!-- Issued Status -->
          <q-btn
            :color="loadedInvoiceStatus === 'issued' ? 'positive' : 'grey-4'"
            :text-color="loadedInvoiceStatus === 'issued' ? 'white' : 'positive'"
            :unelevated="loadedInvoiceStatus === 'issued'"
            :outline="loadedInvoiceStatus !== 'issued'"
            dense
            no-caps
            class="q-px-sm text-caption text-weight-bold"
            :loading="isSaving && selectedSaveStatus === 'issued'"
            :disable="isSaving || loadedInvoiceStatus === 'issued'"
            @click="handleSaveInvoice('issued')"
          >
            <q-icon
              v-if="loadedInvoiceStatus === 'issued'"
              name="ph ph-check-circle"
              size="13px"
              class="q-mr-xs"
            />
            {{ loadedInvoiceStatus === 'issued' ? 'ISSUED' : 'Save as ISSUED' }}
          </q-btn>

          <!-- Payment Status Button-like badge when Issued -->
          <template v-if="loadedInvoiceStatus === 'issued'">
            <q-separator vertical class="q-mx-xs" />
            <q-badge
              :color="
                effectivePaymentStatus === 'paid'
                  ? 'green-1'
                  : effectivePaymentStatus === 'partial'
                    ? 'blue-1'
                    : 'red-1'
              "
              :text-color="
                effectivePaymentStatus === 'paid'
                  ? 'green-9'
                  : effectivePaymentStatus === 'partial'
                    ? 'blue-9'
                    : 'red-9'
              "
              class="text-weight-bolder text-uppercase q-px-sm q-py-xs rounded-borders"
              style="font-size: 11px; height: 28px; line-height: 20px"
            >
              <q-icon
                :name="
                  effectivePaymentStatus === 'paid'
                    ? 'ph ph-check-circle'
                    : effectivePaymentStatus === 'partial'
                      ? 'ph ph-chart-pie'
                      : 'ph ph-clock'
                "
                size="13px"
                class="q-mr-xs"
              />
              PAYMENT: {{ effectivePaymentStatus }}
            </q-badge>
          </template>
        </div>

        <!-- Right Side: Process Return Button -->
        <div class="row items-center q-gutter-xs">
          <q-btn
            v-if="canRecordPayment"
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-money"
            label="Record Payment"
            class="q-px-sm text-caption text-weight-bold"
            @click="openCollectDialog"
          />
          <q-btn
            v-if="loadedInvoiceStatus === 'issued'"
            flat
            dense
            no-caps
            color="purple"
            icon="ph ph-arrow-u-down-left"
            label="Process Return"
            class="q-px-sm text-caption text-weight-bold"
            @click="goToProcessReturn"
          >
            <q-tooltip>Record wholesale item returns & issue credit note</q-tooltip>
          </q-btn>
        </div>
      </div>

      <WholesaleInvoicePaper
        v-model:selected-brand-id="selectedBrandId"
        v-model:selected-billing-profile-id="selectedBillingProfileId"
        v-model:overall-discount-input="overallDiscountInput"
        v-model:stock-search-text="stockSearchText"
        v-model:stock-menu-open="stockMenuOpen"
        :is-existing-invoice="isExistingInvoice"
        :loaded-invoice-no="loadedInvoiceNo"
        :loaded-invoice-status="loadedInvoiceStatus"
        :effective-payment-status="effectivePaymentStatus"
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

      <div class="row items-center justify-end q-gutter-sm create-wholesale-invoice-page__footer">
        <q-btn
          v-if="existingInvoiceId && loadedInvoiceStatus === 'proforma_generated'"
          outline
          color="primary"
          icon="ph ph-printer"
          label="Preview Proforma"
          no-caps
          class="action-btn text-weight-bold"
          @click="openPreview"
        >
          <q-tooltip>Preview and print proforma invoice</q-tooltip>
        </q-btn>

        <q-btn
          v-if="!existingInvoiceId"
          unelevated
          color="primary"
          icon="ph ph-floppy-disk"
          label="Save as Draft"
          no-caps
          class="action-btn text-weight-bold"
          :disable="!canSaveDraft || isSaving"
          :loading="isSaving"
          @click="handleSaveInvoice('draft')"
        >
          <q-tooltip v-if="!canSaveDraft" anchor="top middle" self="bottom middle" class="bg-grey-9 text-caption shadow-4">
            <div class="text-weight-bold q-mb-xs text-amber-3">Complete required fields to save:</div>
            <div v-for="(reason, rIdx) in validationReasons" :key="rIdx" class="q-py-xxs text-white">
              • {{ reason }}
            </div>
          </q-tooltip>
        </q-btn>
      </div>
    </div>

    <WholesaleCollectPaymentDialog
      v-model="collectDialogOpen"
      :due-amount="loadedDueAmount"
      :paid-amount="loadedPaidAmount"
      :store-credit="storeCreditBalance"
      :saving="collectSaving"
      @submit="onCollectPayment"
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
  type SalesInvoiceStockItem,
} from '../repositories/invoiceRepository';
import type { BillingProfile } from '../repositories/billingProfileRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import WholesaleCollectPaymentDialog from '../components/WholesaleCollectPaymentDialog.vue';
import WholesaleInvoicePaper from '../components/WholesaleInvoicePaper.vue';
import type { InvoiceLineDraftItem } from '../types/wholesaleInvoiceDraft';
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

usePageBreadcrumbs(() => {
  const tenantSlug = authStore.selectedTenant?.slug || (route.params.tenantSlug as string);
  const basePrefix = tenantSlug ? `/${tenantSlug}/app/sales/invoices` : '/app/sales/invoices';
  return [
    {
      label: authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    {
      label: 'Sales',
    },
    {
      label: 'Invoices',
      to: `${basePrefix}/list`,
    },
  ];
});

const existingInvoiceId = computed(() => {
  const qId = route.query.id;
  if (typeof qId === 'string' && qId) return Number(qId);
  const pId = route.params.id;
  if (typeof pId === 'string' && pId) return Number(pId);
  return null;
});

const isExistingInvoice = computed(() => Boolean(existingInvoiceId.value));
const loadedInvoiceNo = ref('');
const loadedInvoiceStatus = ref('');
const loadedPaymentStatus = ref('due');
const loadedDueAmount = ref(0);
const loadedPaidAmount = ref(0);
const collectDialogOpen = ref(false);
const collectSaving = ref(false);
const storeCreditBalance = ref(0);
const effectivePaymentStatus = computed(() => loadedPaymentStatus.value || 'due');
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
      if (inv.invoice_status === 'issued') {
        selectedSaveStatus.value = 'issued';
      }
    }

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
      [...tenantIds].map((id) => invoiceRepository.listInvoiceBrands({ tenant_id: id })),
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
const stockMenuOpen = ref(false);
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
    stockMenuOpen.value = true;
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
  } else {
    stockMenuOpen.value = true;
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

const onCollectPayment = async (payload: {
  cashAmount: number;
  cashMethod: string;
  walletAmount: number;
  settlementAmount: number;
}) => {
  const invId = existingInvoiceId.value;
  if (!invId) return;
  collectSaving.value = true;
  try {
    await invoiceRepository.collectWholesaleInvoicePayment({
      invoice_id: invId,
      cash_amount: payload.cashAmount,
      cash_method: payload.cashMethod,
      wallet_amount: payload.walletAmount,
      settlement_amount: payload.settlementAmount,
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

const goToProcessReturn = () => {
  const invId = existingInvoiceId.value;
  if (!invId) return;
  void router.push({
    name: 'app-global-invoice-return-page',
    params: {
      tenantSlug: authStore.tenantSlug || '',
      id: String(invId),
    },
  });
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

const handleSaveInvoice = async (status: WholesaleInvoiceSaveStatus) => {
  selectedSaveStatus.value = status;
  if (!canSaveDraft.value || isSaving.value) return;

  const tenantId = effectiveTenantId.value;
  const parentTenantId = effectiveParentTenantId.value;
  if (!tenantId || !parentTenantId || !selectedBillingProfileId.value) return;

  isSaving.value = true;
  try {
    let targetInvoiceId = existingInvoiceId.value;

    if (!targetInvoiceId) {
      // Generate invoice number
      const invoiceNo = await invoiceRepository.generateInvoiceNumber(
        tenantId,
        'wholesale',
      );

      // Create the global invoice record
      const createdInvoice = await invoiceRepository.createGlobalInvoice({
        tenant_id: tenantId,
        invoice_no: invoiceNo,
        invoice_type: 'wholesale',
        invoice_date: new Date().toISOString().slice(0, 10),
        billing_profile_id: selectedBillingProfileId.value,
      });
      targetInvoiceId = createdInvoice?.id ?? null;
      if (createdInvoice?.invoice_no) {
        loadedInvoiceNo.value = createdInvoice.invoice_no;
      }

      if (targetInvoiceId) {
        // Add invoice line items
        for (const item of invoiceItems.value) {
          await invoiceRepository.addGlobalInvoiceItem({
            invoice_id: targetInvoiceId,
            global_stock_id: item.global_stock_id,
            quantity: item.quantity,
            sell_price_amount: item.sell_price_amount,
            line_discount_amount: item.line_discount_amount || 0,
          });
        }
      }
    }

    if (status === 'proforma_generated') {
      loadedInvoiceStatus.value = 'proforma_generated';
      if (targetInvoiceId) {
        void router.replace({
          query: { ...route.query, id: String(targetInvoiceId) },
        });
      }
      showSuccessNotification('Proforma invoice generated. Preview is now available.');
      return;
    }

    if (status === 'issued') {
      if (!targetInvoiceId) return;

      // 1. Fetch live available quantities from global_stocks for all line items
      const stockIds = invoiceItems.value.map((i) => i.global_stock_id);
      const { data: stocksData, error: stocksError } = await supabase
        .from('global_stocks')
        .select('id, quantity')
        .in('id', stockIds);

      if (stocksError) {
        console.error('Error fetching stock availability:', stocksError);
      }

      const stockMap = new Map((stocksData || []).map((s) => [s.id, Number(s.quantity)]));

      // 2. Open WholesaleIssueConfirmDialog
      $q.dialog({
        component: WholesaleIssueConfirmDialog,
        componentProps: {
          invoiceId: targetInvoiceId,
          invoiceNo: loadedInvoiceNo.value || String(targetInvoiceId),
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
            // 3. Update local line item quantities
            for (const updatedItem of data.items) {
              const existing = invoiceItems.value.find(
                (i) => i.global_stock_id === updatedItem.global_stock_id,
              );
              if (existing) {
                existing.quantity = updatedItem.quantity;
              }
            }

            // 4. Single atomic RPC: updates items in batch, deducts stock, creates movements, and issues invoice
            await invoiceRepository.issueWholesaleInvoice(
              targetInvoiceId,
              data.items.map((i) => ({
                ...(i.id ? { id: i.id } : {}),
                global_stock_id: i.global_stock_id,
                quantity: i.quantity,
              })),
            );

            loadedInvoiceStatus.value = 'issued';
            loadedPaymentStatus.value = 'due';
            if (targetInvoiceId) {
              void router.replace({
                query: { ...route.query, id: String(targetInvoiceId) },
              });
            }
            showSuccessNotification('Wholesale invoice issued and stock deducted successfully.');
          } catch (err) {
            console.error('Error issuing wholesale invoice:', err);
            showWarningDialog(err instanceof Error ? err.message : 'Error issuing wholesale invoice');
          } finally {
            isSaving.value = false;
          }
        })();
      });
      return;
    }

    // Default: Save as draft
    loadedInvoiceStatus.value = 'draft';
    if (targetInvoiceId) {
      void router.replace({
        query: { ...route.query, id: String(targetInvoiceId) },
      });
    }
    showSuccessNotification('Invoice saved as draft.');
  } catch (err) {
    console.error('Error saving wholesale invoice:', err);
    showWarningDialog(err instanceof Error ? err.message : 'Error saving wholesale invoice');
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

<style scoped>
.create-wholesale-invoice-page {
  max-width: none;
  margin: 0;
  background-color: #e8ecf1;
  min-height: calc(100vh - 55px);
  width: 100%;
  box-sizing: border-box;
  display: flex;
  justify-content: center;
  padding-inline: clamp(0.75rem, 2vw, 1.25rem);
}

.create-wholesale-invoice-page__stack {
  width: min(100%, 1200px);
  max-width: 1200px;
  margin-inline: auto;
  gap: 0.75rem;
}

.create-wholesale-invoice-page__workflow,
.create-wholesale-invoice-page__footer {
  width: 100%;
  box-sizing: border-box;
}

.rounded-borders-8 {
  border-radius: 8px;
}

.border-light {
  border: 1px solid #e2e8f0;
}

.action-btn {
  border-radius: 8px;
  min-height: 38px;
  padding: 0 16px;
}
</style>
