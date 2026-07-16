<template>
  <q-dialog v-model="localModelValue" persistent>
    <q-card style="min-width: 560px; max-width: 96vw; border-radius: 12px">
      <!-- Header -->
      <q-card-section class="row items-center justify-between q-px-lg q-py-md">
        <div>
          <div class="text-h6 text-weight-medium">{{ isEdit ? 'Edit Shop' : 'Create Shop' }}</div>
          <div v-if="isEdit" class="text-caption text-grey-6 q-mt-xs">
            Shop type is locked after creation.
          </div>
        </div>
        <q-btn
          flat
          round
          dense
          icon="info"
          color="primary"
          @click="showHelpDialog = true"
        >
          <q-tooltip>Shop Functionality Guide</q-tooltip>
        </q-btn>
      </q-card-section>

      <!-- Form Body -->
      <q-card-section class="q-px-lg q-pt-none q-pb-md">
        <!-- Name + Slug -->
        <div class="row q-col-gutter-md items-start q-mb-md">
          <div class="col-7">
            <q-input
              v-model="form.name"
              label="Shop name *"
              outlined
              dense
              :error="!!errors.name"
              :error-message="errors.name"
              @update:model-value="(val) => syncSlug(String(val ?? ''))"
            />
          </div>
          <div class="col-5">
            <q-input
              v-model="form.slug"
              label="Slug *"
              outlined
              dense
              hint="URL-safe identifier"
              :error="!!errors.slug"
              :error-message="errors.slug"
              @update:model-value="
                () => {
                  form.slug = form.slug.toLowerCase().replace(/[^a-z0-9-]/g, '-');
                }
              "
            />
          </div>
        </div>

        <!-- Shop type (create-only) -->
        <q-select
          v-if="!isEdit"
          v-model="form.shop_type"
          :options="shopTypeOptions"
          emit-value
          map-options
          label="Shop type *"
          outlined
          dense
          class="q-mb-md"
          :error="!!errors.shop_type"
          :error-message="errors.shop_type"
        />

        <!-- vendor_code — only for vendor_catalog, create-only -->
        <q-select
          v-if="!isEdit && form.shop_type === 'vendor_catalog'"
          v-model="form.vendor_code"
          :options="vendorOptions"
          option-value="code"
          option-label="label"
          emit-value
          map-options
          :loading="loadingVendors"
          label="Vendor *"
          outlined
          dense
          class="q-mb-md"
          hint="Products will be filtered to this vendor"
          :error="!!errors.vendor_code"
          :error-message="errors.vendor_code"
        >
          <template #no-option>
            <q-item>
              <q-item-section class="text-grey-6">
                {{ loadingVendors ? 'Loading vendors…' : 'No vendors available' }}
              </q-item-section>
            </q-item>
          </template>
        </q-select>

        <!-- Shop type locked label when editing -->
        <div v-if="isEdit && shopTypeLabel" class="q-mb-md q-pa-sm bg-grey-2 rounded-borders">
          <div class="text-caption text-grey-6">Shop type</div>
          <div class="text-body2 text-weight-medium text-grey-8">{{ shopTypeLabel }}</div>
        </div>

        <!-- Order mode -->
        <q-select
          v-model="form.order_mode"
          :options="orderModeOptions"
          emit-value
          map-options
          label="Order mode *"
          outlined
          dense
          class="q-mb-md"
        />

        <!-- Currencies Selection -->
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-6">
            <q-select
              v-model="form.buy_currency_id"
              :options="currencyOptions"
              emit-value
              map-options
              :loading="loadingCurrencies"
              label="Buy Currency (ক্রয় কারেন্সি) *"
              outlined
              dense
              :rules="[val => !!val || 'Buy currency is required']"
            />
          </div>
          <div class="col-6">
            <q-select
              v-model="form.sell_currency_id"
              :options="currencyOptions"
              emit-value
              map-options
              :loading="loadingCurrencies"
              label="Sell Currency (বিক্রয় কারেন্সি) *"
              outlined
              dense
              :rules="[val => !!val || 'Sell currency is required']"
            />
          </div>
        </div>

        <!-- Retail Shop Specific Configurations -->
        <div 
          v-if="form.shop_type === 'fixed_price' || (isEdit && shopTypeSnapshot === 'fixed_price')" 
          class="q-pa-md bg-blue-50 rounded-borders q-mb-md border-blue-100"
          style="background-color: #f0f7ff; border: 1px solid #d0e7ff; border-radius: 8px"
        >
          <div class="text-subtitle2 text-blue-9 text-weight-medium q-mb-sm">
            Retail Pricing & Quantity (খুচরা মূল্য ও পরিমাণ সেটিংস)
          </div>
          
          <div class="row q-col-gutter-md items-center q-mb-sm">
            <div class="col-6">
              <q-select
                v-model="form.pricing_method"
                :options="[
                  { value: 'direct_cost', label: 'Direct Cost (সরাসরি খরচ)' },
                  { value: 'markup', label: 'Markup Percentage (মার্কআপ)' }
                ]"
                emit-value
                map-options
                label="Pricing Method *"
                outlined
                dense
              />
            </div>
            <div class="col-6" v-if="form.pricing_method === 'markup'">
              <q-input
                v-model.number="form.markup_percentage"
                type="number"
                label="Markup % *"
                suffix="%"
                outlined
                dense
                :rules="[
                  val => val !== null && val !== undefined || 'Markup % is required',
                  val => val >= 0 || 'Markup % must be non-negative'
                ]"
              />
            </div>
          </div>

          <div class="row q-mb-sm">
            <div class="col-12">
              <q-select
                v-model="form.quantity_display_mode"
                :options="[
                  { value: 'original', label: 'Show Original Stock Qty (আসল স্টক)' },
                  { value: 'custom_override', label: 'Show Custom Override Qty (কাস্টম সংখ্যা)' }
                ]"
                emit-value
                map-options
                label="Quantity Display Mode *"
                outlined
                dense
              />
            </div>
          </div>
        </div>

        <!-- Flags row -->
        <div class="row q-col-gutter-md items-center q-mb-md">
          <div class="col-auto">
            <q-toggle
              v-model="form.is_negotiable"
              :disable="
                form.shop_type === 'dropship' || (isEdit && shopTypeSnapshot === 'dropship')
              "
              label="Negotiable"
              color="primary"
            />
          </div>
          <div class="col-auto">
            <q-toggle v-model="form.show_stock_quantity" label="Show stock qty" color="primary" />
          </div>
          <div class="col-auto">
            <q-toggle v-model="form.is_active" label="Active" color="positive" />
          </div>
          <div
            v-if="form.shop_type === 'fixed_price' || (isEdit && shopTypeSnapshot === 'fixed_price')"
            class="col-auto"
          >
            <q-toggle v-model="form.allow_delivery" label="Allow Delivery" color="primary" />
          </div>
        </div>

        <!-- Error banner -->
        <q-banner v-if="saveError" class="text-white bg-negative q-mt-md" rounded dense>
          {{ saveError }}
        </q-banner>
      </q-card-section>

      <!-- Actions -->
      <q-card-actions align="right" class="q-px-lg q-pb-md q-pt-none">
        <q-btn flat label="Cancel" :disable="saving" @click="localModelValue = false" />
        <q-btn
          color="primary"
          unelevated
          :label="isEdit ? 'Update' : 'Create Shop'"
          :loading="saving"
          :disable="saving"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>

  <!-- Help Dialog explaining functionalities -->
  <q-dialog v-model="showHelpDialog">
    <q-card style="min-width: 500px; max-width: 90vw; border-radius: 12px">
      <!-- Header -->
      <q-card-section class="row items-center justify-between q-py-md bg-primary text-white">
        <div class="text-h6 row items-center no-wrap">
          <q-icon name="help_outline" class="q-mr-sm" size="24px" />
          Shop Features Guide / দোকানের ফিচার গাইড
        </div>
        <q-btn icon="close" flat round dense v-close-popup color="white" />
      </q-card-section>

      <!-- Tabs Navigation -->
      <q-tabs
        v-model="helpTab"
        dense
        class="text-grey-7"
        active-color="primary"
        indicator-color="primary"
        align="justify"
        narrow-indicator
      >
        <q-tab name="types" label="Shop Types / ধরন" />
        <q-tab name="modes" label="Order Modes / অর্ডার" />
        <q-tab name="settings" label="Settings / সেটিংস" />
      </q-tabs>

      <q-separator />

      <!-- Tab Panels Content -->
      <q-tab-panels v-model="helpTab" animated class="q-pa-xs">
        <!-- Shop Types -->
        <q-tab-panel name="types" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="storefront" color="blue-1" text-color="blue-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Vendor Catalog / ভেন্ডর ক্যাটালগ</div>
              <div class="text-caption text-grey-7">
                Shows a supplier's product list directly. Customers request what they want to buy (bulk or low MOQ). You do not need allocated stock.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                সাপ্লায়ারের পণ্য তালিকা সরাসরি দেখায়। কাস্টমার কি কিনতে চায় অনুরোধ করে। আগে থেকে স্টক বরাদ্দ লাগে না।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="local_offer" color="green-1" text-color="green-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Fixed Price / নির্ধারিত দাম</div>
              <div class="text-caption text-grey-7">
                Sells from your branch/child-tenant stock at a fixed retail price. Price cannot be changed by the customer.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                আপনার শাখা/চাইল্ড-টেন্যান্টের স্টক থেকে নির্ধারিত খুচরা দামে বিক্রি। কাস্টমার দাম বদলাতে পারে না।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="local_shipping" color="orange-1" text-color="orange-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Dropship / ড্রপশিপ</div>
              <div class="text-caption text-grey-7">
                Reseller sets their own selling price on allocated stock, but cannot go below a minimum floor price. Negotiation stays off.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                রিসেলার বরাদ্দ স্টকে নিজের বিক্রয়মূল্য সেট করে, তবে ন্যূনতম দামের নিচে নামতে পারে না। দরকষাকষি বন্ধ থাকে।
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- Order Modes -->
        <q-tab-panel name="modes" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="assignment" color="purple-1" text-color="purple-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Procurement Intent / ক্রয় অনুরোধ</div>
              <div class="text-caption text-grey-7">
                Customer picks products and asks for a quote. Staff review, set price, then turn it into a warehouse procurement order.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                কাস্টমার পণ্য বেছে কোটেশন চায়। স্টাফ দেখে দাম নির্ধারণ করে, তারপর ওয়্যারহাউজ প্রকিউরমেন্ট অর্ডারে রূপান্তর করে।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="shopping_cart" color="teal-1" text-color="teal-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Fixed Checkout / নির্ধারিত চেকআউট</div>
              <div class="text-caption text-grey-7">
                Normal retail buy: cart → pay at listed price → invoice is created right away.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                সাধারণ খুচরা কেনা: কার্ট → তালিকাভুক্ত দামে কেনা → সাথে সাথে ইনভয়েস তৈরি।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="business" color="indigo-1" text-color="indigo-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Wholesale Checkout / পাইকারি চেকআউট</div>
              <div class="text-caption text-grey-7">
                For bulk B2B orders with accounts: custom invoice/order flow instead of simple retail checkout.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                অ্যাকাউন্টভিত্তিক বাল্ক B2B অর্ডারের জন্য: সাধারণ খুচরা চেকআউটের বদলে কাস্টম ইনভয়েস/অর্ডার প্রক্রিয়া।
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- Settings -->
        <q-tab-panel name="settings" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="forum" color="pink-1" text-color="pink-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Negotiable / দরকষাকষি</div>
              <div class="text-caption text-grey-7">
                On: buyers and staff can send counter-offers. Off for Dropship shops (required).
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                চালু থাকলে ক্রেতা ও স্টাফ কাউন্টার অফার পাঠাতে পারে। ড্রপশিপ দোকানে অবশ্যই বন্ধ রাখতে হবে।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="visibility" color="cyan-1" text-color="cyan-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Show Stock Qty / স্টক সংখ্যা দেখান</div>
              <div class="text-caption text-grey-7">
                On: show exact stock number. Off: only show “In Stock / Out of Stock”.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                চালু: সঠিক স্টক সংখ্যা দেখায়। বন্ধ: শুধু “স্টকে আছে / নেই” দেখায়।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="monetization_on" color="yellow-2" text-color="yellow-9" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Shop Currencies / কারেন্সি সেটিংস</div>
              <div class="text-caption text-grey-7">
                Buy Currency: original purchase costing currency. Sell Currency: display & checkout currency. Negotiations must happen in Sell Currency.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                ক্রয় কারেন্সি: কেনা দামের আসল কারেন্সি। বিক্রয় কারেন্সি: কাস্টমারের প্রদর্শন ও পেমেন্ট কারেন্সি। সমস্ত দরকষাকষি বিক্রয় কারেন্সিতে হতে হবে।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="calculate" color="indigo-1" text-color="indigo-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Retail Pricing Method / খুচরা মূল্য সেটিংস</div>
              <div class="text-caption text-grey-7">
                Direct Cost: sell price equals original procurement cost. Markup: sell price includes the set markup percentage.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                সরাসরি খরচ: ক্রয়মূল্যই বিক্রয়মূল্য হিসেবে দেখাবে। মার্কআপ: ক্রয়মূল্যের সাথে নির্দিষ্ট মার্কআপ শতাংশ যোগ হয়ে দেখাবে।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="bar_chart" color="cyan-1" text-color="cyan-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Quantity Display Mode / স্টক পরিমাণ সেটিংস</div>
              <div class="text-caption text-grey-7">
                Show Original Stock Qty: displays warehouse physical stock. Custom Override: displays custom marketing override value if set.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                আসল স্টক: গুদামের ফিজিক্যাল আসল স্টক দেখাবে। কাস্টম সংখ্যা: নির্দিষ্ট কাস্টম ওভাররাইড সংখ্যা মার্কেটিং হিসেবে দেখাবে।
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="check_circle" color="positive" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Active / সক্রিয়</div>
              <div class="text-caption text-grey-7">
                On: shop is visible to customers. Off: customers cannot open or view the shop.
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                চালু: কাস্টমার দোকান দেখতে পায়। বন্ধ: কাস্টমার দোকান খুলতে বা দেখতে পারে না।
              </div>
            </div>
          </div>
        </q-tab-panel>
      </q-tab-panels>

      <q-separator />

      <!-- Footer Actions -->
      <q-card-actions align="right" class="q-pr-md q-pb-md">
        <q-btn label="Got It / বুঝেছি" color="primary" unelevated v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>


</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import type { Shop, ShopType, ShopOrderMode } from 'src/modules/shop_order/types';
import { vendorService } from 'src/modules/vendor/services/vendorService';
import type { Vendor } from 'src/modules/vendor/types';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';
import type { GlobalCurrency } from 'src/modules/global_reference/types';

// ---- types ---------------------------------------------------------

type ShopForm = {
  id?: number;
  tenant_id: number;
  name: string;
  slug: string;
  shop_type: ShopType | null;
  vendor_code: string;
  order_mode: ShopOrderMode;
  is_negotiable: boolean;
  show_stock_quantity: boolean;
  is_active: boolean;
  allow_delivery: boolean;
  buy_currency_id: number | null;
  sell_currency_id: number | null;
  pricing_method: 'direct_cost' | 'markup';
  markup_percentage: number;
  quantity_display_mode: 'original' | 'custom_override';
};

type FormErrors = {
  name?: string;
  slug?: string;
  shop_type?: string;
  vendor_code?: string;
};

// ---- props / emits -------------------------------------------------

const props = defineProps<{
  modelValue: boolean;
  initialData?: Shop | null;
  tenantId: number;
  saving?: boolean;
  saveError?: string | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'save', value: any): void;
}>();

// ---- local state ---------------------------------------------------

const localModelValue = computed({
  get: () => props.modelValue,
  set: (v: boolean) => emit('update:modelValue', v),
});

const showHelpDialog = ref(false);
const helpTab = ref('types');

const vendors = ref<Vendor[]>([]);
const loadingVendors = ref(false);

const vendorOptions = computed(() =>
  vendors.value.map((v) => ({ code: v.code, label: `${v.name} (${v.code})` })),
);

const loadVendors = async () => {
  loadingVendors.value = true;
  const result = await vendorService.listVendors(props.tenantId);
  vendors.value = result.success && result.data ? result.data : [];
  loadingVendors.value = false;
};

const currencies = ref<GlobalCurrency[]>([]);
const loadingCurrencies = ref(false);

const currencyOptions = computed(() =>
  currencies.value.map((c) => ({ value: c.id, label: `${c.name} (${c.code})` })),
);

const loadCurrencies = async () => {
  loadingCurrencies.value = true;
  try {
    currencies.value = await globalReferenceRepository.listCurrencies();
  } catch (e) {
    console.error('Failed to load currencies', e);
  } finally {
    loadingCurrencies.value = false;
  }
};

const errors = reactive<FormErrors>({});
// snapshot of shop_type on edit open (immutable field guard)
const shopTypeSnapshot = ref<ShopType | null>(null);

const defaultForm = (): ShopForm => ({
  tenant_id: props.tenantId,
  name: '',
  slug: '',
  shop_type: null,
  vendor_code: '',
  order_mode: 'procurement_intent',
  is_negotiable: false,
  show_stock_quantity: true,
  is_active: true,
  allow_delivery: false,
  buy_currency_id: null,
  sell_currency_id: null,
  pricing_method: 'direct_cost',
  markup_percentage: 0,
  quantity_display_mode: 'original',
});

const form = reactive<ShopForm>(defaultForm());

const isEdit = computed(() => typeof form.id === 'number');

// ---- label helpers -------------------------------------------------

const shopTypeOptions = [
  { value: 'vendor_catalog', label: 'Vendor Catalog' },
  { value: 'fixed_price', label: 'Fixed Price' },
  { value: 'dropship', label: 'Dropship' },
];

const orderModeOptions = [
  { value: 'procurement_intent', label: 'Procurement Intent' },
  { value: 'checkout_fixed', label: 'Checkout Fixed' },
  { value: 'checkout_wholesale', label: 'Checkout Wholesale' },
];

const shopTypeLabel = computed(() => {
  const found = shopTypeOptions.find((o) => o.value === shopTypeSnapshot.value);
  return found?.label ?? shopTypeSnapshot.value ?? '';
});

// ---- slug auto-fill ------------------------------------------------

const syncSlug = (val: string) => {
  if (isEdit.value) return;
  form.slug = val
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');
};

// ---- watch open ----------------------------------------------------

watch(
  [() => props.modelValue, () => props.initialData, () => props.tenantId],
  ([opened, initialData, tenantId]) => {
    if (!opened) return;

    Object.keys(errors).forEach((k) => delete (errors as any)[k]);

    void loadVendors();
    void loadCurrencies();

    if (initialData) {
      shopTypeSnapshot.value = initialData.shop_type;
      Object.assign(form, {
        id: initialData.id,
        tenant_id: initialData.tenant_id,
        name: initialData.name,
        slug: initialData.slug,
        shop_type: initialData.shop_type,
        vendor_code: initialData.vendor_code ?? '',
        order_mode: initialData.order_mode,
        is_negotiable: initialData.is_negotiable,
        show_stock_quantity: initialData.show_stock_quantity,
        is_active: initialData.is_active,
        allow_delivery: initialData.allow_delivery || false,
        buy_currency_id: initialData.buy_currency_id,
        sell_currency_id: initialData.sell_currency_id,
        pricing_method: initialData.pricing_method || 'direct_cost',
        markup_percentage: initialData.markup_percentage || 0,
        quantity_display_mode: initialData.quantity_display_mode || 'original',
      });
    } else {
      shopTypeSnapshot.value = null;
      Object.assign(form, { ...defaultForm(), tenant_id: tenantId });
    }
  },
  { immediate: true },
);

// ---- validation + save ---------------------------------------------

const validate = (): boolean => {
  Object.keys(errors).forEach((k) => delete (errors as any)[k]);
  let ok = true;

  if (!form.name.trim()) {
    errors.name = 'Name is required.';
    ok = false;
  }
  if (!form.slug.trim()) {
    errors.slug = 'Slug is required.';
    ok = false;
  }
  if (!isEdit.value && !form.shop_type) {
    errors.shop_type = 'Shop type is required.';
    ok = false;
  }
  if (!isEdit.value && form.shop_type === 'vendor_catalog' && !form.vendor_code.trim()) {
    errors.vendor_code = 'Vendor code is required for vendor catalog shops.';
    ok = false;
  }

  return ok;
};

const onSave = () => {
  if (!validate()) return;

  if (isEdit.value) {
    emit('save', {
      id: form.id,
      tenant_id: form.tenant_id,
      name: form.name.trim(),
      slug: form.slug.trim(),
      order_mode: form.order_mode,
      is_negotiable: form.is_negotiable,
      show_stock_quantity: form.show_stock_quantity,
      is_active: form.is_active,
      allow_delivery: form.allow_delivery,
      buy_currency_id: form.buy_currency_id,
      sell_currency_id: form.sell_currency_id,
      pricing_method: form.pricing_method,
      markup_percentage: Number(form.markup_percentage || 0),
      quantity_display_mode: form.quantity_display_mode,
    });
  } else {
    emit('save', {
      tenant_id: form.tenant_id,
      name: form.name.trim(),
      slug: form.slug.trim(),
      shop_type: form.shop_type,
      vendor_code: form.shop_type === 'vendor_catalog' ? form.vendor_code.trim() : null,
      order_mode: form.order_mode,
      is_negotiable: form.is_negotiable,
      show_stock_quantity: form.show_stock_quantity,
      is_active: form.is_active,
      allow_delivery: form.allow_delivery,
      buy_currency_id: form.buy_currency_id,
      sell_currency_id: form.sell_currency_id,
      pricing_method: form.pricing_method,
      markup_percentage: Number(form.markup_percentage || 0),
      quantity_display_mode: form.quantity_display_mode,
    });
  }
};
</script>
