<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center justify-between q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Bills" @click="goBack" />
      <div class="row items-center q-gutter-sm">
        <q-btn
          outline
          dense
          no-caps
          label="Save draft"
          :loading="composeMutation.isPending.value"
          :disable="!canSave"
          @click="saveDraft"
        />
        <q-btn
          unelevated
          dense
          no-caps
          color="primary"
          label="Issue bill"
          :loading="composeMutation.isPending.value"
          :disable="!canIssue"
          @click="issueBill"
        />
      </div>
    </div>

    <div v-if="loadingExisting" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else class="col overflow-auto">
      <div class="compose-card q-pa-md q-gutter-y-md">
        <div class="row items-center q-gutter-md">
          <q-btn-toggle
            v-model="billKind"
            spread
            no-caps
            dense
            toggle-color="primary"
            :options="[
              { label: 'Trade', value: 'trade' },
              { label: 'Walk-in', value: 'walkin' },
            ]"
          />
        </div>

        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-6">
            <div class="text-overline text-grey-7 q-mb-xs">From</div>
            <q-select
              v-model="selectedBrandId"
              :options="brandOptions"
              option-value="id"
              option-label="name"
              emit-value
              map-options
              outlined
              dense
              label="Letterhead brand"
            />
            <div v-if="selectedBrand?.address" class="text-caption text-grey-7 q-mt-xs whitespace-pre-line">
              {{ selectedBrand.address }}
            </div>
          </div>
          <div class="col-12 col-sm-6">
            <div class="text-overline text-grey-7 q-mb-xs">To</div>
            <q-select
              v-model="billingProfileId"
              :options="profileOptions"
              option-value="id"
              option-label="name"
              emit-value
              map-options
              use-input
              input-debounce="300"
              outlined
              dense
              label="Bill-to profile *"
              @filter="filterProfiles"
            />
            <div v-if="selectedProfile?.address" class="text-caption text-grey-7 q-mt-xs whitespace-pre-line">
              {{ selectedProfile.address }}
            </div>
          </div>
        </div>

        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-input v-model="invoiceDate" outlined dense label="Invoice date" readonly>
              <template #append>
                <q-icon name="ph ph-calendar" class="cursor-pointer">
                  <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                    <q-date v-model="invoiceDate" mask="YYYY-MM-DD">
                      <div class="row items-center justify-end">
                        <q-btn v-close-popup label="Close" color="primary" flat />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-4">
            <q-input
              :model-value="dueDate ?? ''"
              outlined
              dense
              label="Due date"
              readonly
              clearable
              @clear="dueDate = null"
            >
              <template #append>
                <q-icon name="ph ph-calendar" class="cursor-pointer">
                  <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                    <q-date
                      :model-value="dueDate ?? ''"
                      mask="YYYY-MM-DD"
                      @update:model-value="onDueDatePicked"
                    >
                      <div class="row items-center justify-end">
                        <q-btn v-close-popup label="Close" color="primary" flat />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
        </div>

        <q-separator />

        <div class="text-subtitle2 text-weight-bold">Add lines (FIFO)</div>
        <BillStockSearch :tenant-id="tenantId" @select="addLineFromStock" />

        <q-markup-table v-if="lines.length" flat dense class="compose-lines-table">
          <thead>
            <tr>
              <th class="text-left">Item</th>
              <th class="text-right">Qty</th>
              <th class="text-right">Sell</th>
              <th class="text-right">Line disc.</th>
              <th class="text-right">Line total</th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr v-for="(line, idx) in lines" :key="line.key">
              <td class="compose-line-item-cell">
                <BillLineItemDisplay :name="line.name" :image-url="line.image_url" />
              </td>
              <td class="text-right">
                <q-input
                  v-model.number="line.quantity"
                  type="number"
                  dense
                  outlined
                  :max="line.available_atp"
                  min="1"
                  style="max-width: 72px"
                />
              </td>
              <td class="text-right">
                <q-input
                  v-model.number="line.sell_price_amount"
                  type="number"
                  dense
                  outlined
                  min="0"
                  style="max-width: 96px"
                />
              </td>
              <td class="text-right">
                <q-input
                  v-model.number="line.line_discount_amount"
                  type="number"
                  dense
                  outlined
                  min="0"
                  style="max-width: 96px"
                />
              </td>
              <td class="text-right text-weight-medium">{{ formatAmountBdt(lineTotal(line)) }}</td>
              <td class="text-right">
                <q-btn flat round dense icon="ph ph-trash" color="negative" @click="removeLine(idx)" />
              </td>
            </tr>
          </tbody>
        </q-markup-table>

        <q-separator />

        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-6">
            <q-input v-model.number="discountAmount" outlined dense label="Header discount" type="number" min="0" />
          </div>
          <div class="col-12 col-sm-6">
            <q-input v-model.number="shippingCharge" outlined dense label="Shipping" type="number" min="0" />
          </div>
          <div class="col-12 col-sm-6">
            <q-input v-model.number="wrappingCharge" outlined dense label="Wrapping" type="number" min="0" />
          </div>
          <div class="col-12 col-sm-6">
            <q-input v-model.number="printCharge" outlined dense label="Print" type="number" min="0" />
          </div>
        </div>

        <q-input v-model="note" outlined dense label="Note" type="textarea" autogrow />

        <div class="row justify-end">
          <div class="totals-panel">
            <div class="total-row"><span>Subtotal</span><span>{{ formatAmountBdt(subtotal) }}</span></div>
            <div v-if="discountAmount" class="total-row">
              <span>Discount</span><span>−{{ formatAmountBdt(discountAmount) }}</span>
            </div>
            <div v-if="chargesSum" class="total-row">
              <span>Charges</span><span>{{ formatAmountBdt(chargesSum) }}</span>
            </div>
            <div class="total-row text-weight-bold">
              <span>Total (est.)</span><span>{{ formatAmountBdt(estimatedTotal) }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { supabase } from 'src/boot/supabase';
import { formatAmountBdt } from 'src/utils/currency';
import { requestConfirmation } from 'src/utils/appFeedback';
import type { BillingProfile } from 'src/modules/sales_invoice/repositories/billingProfileRepository';
import {
  invoiceRepository,
  type SalesInvoiceStockItem,
} from 'src/modules/sales_invoice/repositories/invoiceRepository';
import BillStockSearch from '../components/BillStockSearch.vue';
import BillLineItemDisplay from '../components/BillLineItemDisplay.vue';
import { useBillComposeMutation } from '../composables/useBillComposeMutation';

type ComposeLine = {
  key: string;
  id?: number;
  global_stock_id: number;
  name: string;
  image_url?: string | null;
  available_atp: number;
  quantity: number;
  sell_price_amount: number;
  line_discount_amount: number;
};

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const composeMutation = useBillComposeMutation();

const BRAND_STORAGE_KEY = 'bills_pays_last_invoice_brand_id';

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const parentTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return null;
  return t.parent_id ?? t.id;
});

const brandsQuery = useQuery({
  queryKey: computed(() => ['invoice_brands', parentTenantId.value]),
  queryFn: () =>
    invoiceRepository.listInvoiceBrands({ parent_tenant_id: parentTenantId.value! }),
  enabled: computed(() => parentTenantId.value != null),
});

const brandOptions = computed(() => brandsQuery.data.value ?? []);
const selectedBrandId = ref<number | null>(null);
const selectedBrand = computed(
  () => brandOptions.value.find((b) => b.id === selectedBrandId.value) ?? brandOptions.value[0],
);

watch(
  brandOptions,
  (brands) => {
    if (!brands.length) return;
    const stored = localStorage.getItem(`${BRAND_STORAGE_KEY}_${parentTenantId.value ?? 0}`);
    const storedId = stored ? Number(stored) : NaN;
    if (Number.isFinite(storedId) && brands.some((b) => b.id === storedId)) {
      selectedBrandId.value = storedId;
    } else {
      selectedBrandId.value = brands[0].id;
    }
  },
  { immediate: true },
);

watch(selectedBrandId, (id) => {
  if (id == null || parentTenantId.value == null) return;
  localStorage.setItem(`${BRAND_STORAGE_KEY}_${parentTenantId.value}`, String(id));
});

const editInvoiceId = computed(() => {
  const raw = route.query.id;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const billKind = ref<'trade' | 'walkin'>('trade');
const billingProfileId = ref<number | null>(null);
const invoiceDate = ref(new Date().toISOString().slice(0, 10));
const dueDate = ref<string | null>(null);

const onDueDatePicked = (value: string | null) => {
  dueDate.value = value && value.length ? value : null;
};
const discountAmount = ref(0);
const shippingCharge = ref(0);
const wrappingCharge = ref(0);
const printCharge = ref(0);
const note = ref('');
const lines = ref<ComposeLine[]>([]);
const removedItemIds = ref<number[]>([]);
const loadingExisting = ref(false);

const profileOptions = ref<BillingProfile[]>([]);
const selectedProfile = computed(
  () => profileOptions.value.find((p) => p.id === billingProfileId.value) ?? null,
);

const filterProfiles = async (
  val: string,
  update: (cb: () => void) => void,
) => {
  if (!tenantId.value) {
    update(() => {
      profileOptions.value = [];
    });
    return;
  }
  const needle = val.trim();
  let query = supabase
    .from('billing_profiles')
    .select('*')
    .eq('tenant_id', tenantId.value)
    .order('name', { ascending: true })
    .limit(30);
  if (needle) {
    query = query.ilike('name', `%${needle}%`);
  }
  const { data } = await query;
  update(() => {
    profileOptions.value = (data as BillingProfile[]) ?? [];
  });
};

const lineTotal = (line: ComposeLine) =>
  Math.max(line.quantity * line.sell_price_amount - (line.line_discount_amount || 0), 0);

const subtotal = computed(() => lines.value.reduce((s, l) => s + lineTotal(l), 0));
const chargesSum = computed(
  () => (shippingCharge.value || 0) + (wrappingCharge.value || 0) + (printCharge.value || 0),
);
const estimatedTotal = computed(() =>
  Math.max(subtotal.value - (discountAmount.value || 0) + chargesSum.value, 0),
);

const canSave = computed(() => !!tenantId.value && !!billingProfileId.value);
const canIssue = computed(
  () => canSave.value && lines.value.length > 0 && lines.value.every((l) => l.quantity > 0),
);

const addLineFromStock = (row: SalesInvoiceStockItem) => {
  if (row.available_atp <= 0) return;
  const existing = lines.value.find((l) => l.global_stock_id === row.global_stock_id);
  if (existing) {
    existing.quantity = Math.min(existing.quantity + 1, existing.available_atp);
    return;
  }
  lines.value.push({
    key: `new-${row.global_stock_id}-${Date.now()}`,
    global_stock_id: row.global_stock_id,
    name: row.name,
    image_url: row.image_url,
    available_atp: row.available_atp,
    quantity: 1,
    sell_price_amount: row.suggested_sell_price,
    line_discount_amount: 0,
  });
};

const removeLine = (index: number) => {
  const line = lines.value[index];
  if (line?.id) {
    removedItemIds.value.push(line.id);
  }
  lines.value.splice(index, 1);
};

const buildPayload = () => {
  const invoiceType: 'wholesale' | 'retail' = billKind.value === 'walkin' ? 'retail' : 'wholesale';
  const retailMode: 'direct' | null = billKind.value === 'walkin' ? 'direct' : null;
  return {
    invoice: {
      invoice_type: invoiceType,
      billing_profile_id: billingProfileId.value!,
      invoice_date: invoiceDate.value,
      due_date: dueDate.value || undefined,
      discount_amount: discountAmount.value || 0,
      shipping_charge: shippingCharge.value || 0,
      wrapping_charge: wrappingCharge.value || 0,
      print_charge: printCharge.value || 0,
      note: note.value.trim() || undefined,
      retail_billing_mode: retailMode,
    },
    items: lines.value.map((l) => ({
      ...(l.id ? { id: l.id } : {}),
      global_stock_id: l.global_stock_id,
      quantity: l.quantity,
      sell_price_amount: l.sell_price_amount,
      line_discount_amount: l.line_discount_amount || 0,
    })),
    issue: false,
  };
};

const saveDraft = async () => {
  if (!canSave.value) return;
  const result = await composeMutation.mutateAsync({
    tenantId: tenantId.value,
    invoiceId: editInvoiceId.value,
    payload: buildPayload(),
    removeItemIds: removedItemIds.value,
    issue: false,
  });
  const newId = result.invoice_id;
  if (newId && !editInvoiceId.value) {
    const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
    await router.replace({
      name: 'app-bill-compose-page',
      params: tenantSlug ? { tenantSlug } : {},
      query: { id: String(newId) },
    });
  }
  removedItemIds.value = [];
};

const issueBill = async () => {
  if (!canIssue.value) return;
  const ok = await requestConfirmation(
    'Sellable stock will leave inventory when you issue. You can collect payment later on Payments.',
    'Issue this bill?',
  );
  if (!ok) return;
  const result = await composeMutation.mutateAsync({
    tenantId: tenantId.value,
    invoiceId: editInvoiceId.value,
    payload: buildPayload(),
    removeItemIds: removedItemIds.value,
    issue: true,
  });
  const id = result.invoice_id ?? editInvoiceId.value;
  if (!id) return;
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-bill-detail-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(id),
    },
  });
};

const loadExisting = async (id: number) => {
  loadingExisting.value = true;
  try {
    const [bill, items] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(id),
      invoiceRepository.listGlobalInvoiceItems(id),
    ]);
    if (!['draft', 'proforma_generated'].includes(bill.invoice_status)) {
      const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
      router.replace({
        name: 'app-bill-detail-page',
        params: {
          ...(tenantSlug ? { tenantSlug } : {}),
          billId: String(id),
        },
      });
      return;
    }
    billKind.value =
      bill.invoice_type === 'retail' && bill.retail_billing_mode === 'direct' ? 'walkin' : 'trade';
    billingProfileId.value = bill.billing_profile_id ?? null;
    invoiceDate.value = bill.invoice_date?.slice(0, 10) ?? invoiceDate.value;
    dueDate.value = bill.due_date?.slice(0, 10) ?? null;
    discountAmount.value = Number(bill.discount_amount ?? 0);
    shippingCharge.value = Number(bill.shipping_charge ?? 0);
    wrappingCharge.value = Number(bill.wrapping_charge ?? 0);
    printCharge.value = Number(bill.print_charge ?? 0);
    note.value = bill.note ?? '';
    lines.value = items.map((item) => ({
      key: `item-${item.id}`,
      id: item.id,
      global_stock_id: item.global_stock_id,
      name: item.name_snapshot,
      image_url: item.image_url,
      available_atp: item.quantity,
      quantity: item.quantity,
      sell_price_amount: item.sell_price_amount,
      line_discount_amount: item.line_discount_amount,
    }));
    if (billingProfileId.value && bill.billing_profiles) {
      profileOptions.value = [
        {
          id: billingProfileId.value,
          name: bill.billing_profiles.name,
          tenant_id: tenantId.value,
        } as BillingProfile,
      ];
    }
  } finally {
    loadingExisting.value = false;
  }
};

watch(
  editInvoiceId,
  (id) => {
    if (id) void loadExisting(id);
  },
  { immediate: true },
);

watch(tenantId, () => {
  void filterProfiles('', (cb) => cb());
});

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({ name: 'app-bills-page', params: tenantSlug ? { tenantSlug } : {} });
};

void filterProfiles('', (cb) => cb());
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.compose-card {
  max-width: 960px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: 8px;
}
.totals-panel {
  min-width: 220px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 13px;
}
.total-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}
.compose-lines-table th {
  font-size: 11px;
  color: var(--bw-neutral-chrome, #64748b);
}
.compose-line-item-cell {
  vertical-align: top;
  max-width: 320px;
}
</style>
