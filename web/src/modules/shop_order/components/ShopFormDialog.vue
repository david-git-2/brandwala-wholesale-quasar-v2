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
          Shop Features Guide
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
        <q-tab name="types" label="Shop Types" />
        <q-tab name="modes" label="Order Modes" />
        <q-tab name="settings" label="Settings" />
      </q-tabs>

      <q-separator />

      <!-- Tab Panels Content -->
      <q-tab-panels v-model="helpTab" animated class="q-pa-xs">
        <!-- Shop Types -->
        <q-tab-panel name="types" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="storefront" color="blue-1" text-color="blue-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Vendor Catalog</div>
              <div class="text-caption text-grey-7">
                Directly displays a supplier's catalog. Perfect for collecting bulk or low-MOQ procurement requests. No stock allocation is required.
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="local_offer" color="green-1" text-color="green-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Fixed Price</div>
              <div class="text-caption text-grey-7">
                Sells inventory from your child-tenant's allocated stock pool at a set, non-negotiable retail price.
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="local_shipping" color="orange-1" text-color="orange-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Dropship</div>
              <div class="text-caption text-grey-7">
                Lets dropshippers define their own retail prices and markup on allocated stock, with a hard minimum floor price constraint. Negotiation is disabled.
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- Order Modes -->
        <q-tab-panel name="modes" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="assignment" color="purple-1" text-color="purple-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Procurement Intent</div>
              <div class="text-caption text-grey-7">
                Customers add products to request quotes. Staff review, price, and transition requests into central warehouse procurement orders.
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="shopping_cart" color="teal-1" text-color="teal-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Fixed Checkout</div>
              <div class="text-caption text-grey-7">
                Traditional retail checkout: customer builds a cart, completes purchase at the listed price, generating an immediate invoice.
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="business" color="indigo-1" text-color="indigo-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Wholesale Checkout</div>
              <div class="text-caption text-grey-7">
                A custom invoicing and order workflow optimized specifically for bulk, account-based B2B transactions.
              </div>
            </div>
          </div>
        </q-tab-panel>

        <!-- Settings -->
        <q-tab-panel name="settings" class="q-gutter-y-sm">
          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="forum" color="pink-1" text-color="pink-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Negotiable</div>
              <div class="text-caption text-grey-7">
                Enables active price negotiations. Buyers and staff can submit counter-offers on orders. (Must be disabled for Dropship).
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="visibility" color="cyan-1" text-color="cyan-8" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Show Stock Qty</div>
              <div class="text-caption text-grey-7">
                If enabled, customer storefronts show precise stock counts. If disabled, they only see simple "In Stock / Out of Stock" status.
              </div>
            </div>
          </div>
          <q-separator inset />

          <div class="row items-start no-wrap q-py-sm">
            <q-avatar icon="check_circle" color="positive" size="md" class="q-mr-md" />
            <div>
              <div class="text-weight-bold text-grey-9 text-subtitle2">Active</div>
              <div class="text-caption text-grey-7">
                Controls the storefront's general visibility. If inactive, customers cannot access or view the shop.
              </div>
            </div>
          </div>
        </q-tab-panel>
      </q-tab-panels>

      <q-separator />

      <!-- Footer Actions -->
      <q-card-actions align="right" class="q-pr-md q-pb-md">
        <q-btn label="Got It" color="primary" unelevated v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>


</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import type { Shop, ShopType, ShopOrderMode } from 'src/modules/shop_order/types';
import { vendorService } from 'src/modules/vendor/services/vendorService';
import type { Vendor } from 'src/modules/vendor/types';

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
    });
  }
};
</script>
