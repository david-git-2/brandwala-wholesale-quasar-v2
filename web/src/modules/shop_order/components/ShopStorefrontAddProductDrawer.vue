<template>
  <q-drawer
    v-model="isOpen"
    side="right"
    overlay
    elevated
    :width="drawerWidth"
    class="shop-storefront-add-product-drawer bg-white"
  >
    <div class="column full-height">
      <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
        <div class="row items-center q-gutter-x-sm min-width-0">
          <q-btn
            v-if="showCreateForm"
            flat
            round
            dense
            icon="ph ph-arrow-left"
            @click="closeCreateForm"
          />
          <div class="min-width-0">
            <div class="text-subtitle1 text-weight-bold row items-center">
              <q-icon
                :name="showCreateForm ? 'ph ph-package' : 'ph ph-plus-circle'"
                class="q-mr-xs text-primary"
                size="20px"
              />
              <span class="ellipsis">
                {{
                  showCreateForm
                    ? $t('shop_admin.storefront_add_new_product')
                    : $t('shop_admin.storefront_add_product')
                }}
              </span>
            </div>
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense @click="isOpen = false" />
      </div>

      <q-separator />

      <div v-if="!showCreateForm" class="col scroll q-pa-md column q-gutter-y-md">
        <q-input
          v-model="search"
          outlined
          dense
          clearable
          autofocus
          :placeholder="$t('shop_admin.storefront_add_product_search_placeholder')"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>

        <q-list v-if="searchResults.length > 0" dense bordered separator class="rounded-borders">
          <q-item v-for="product in searchResults" :key="product.id" clickable>
            <q-item-section avatar>
              <q-avatar square size="48px" class="bg-grey-2">
                <q-icon name="ph ph-package" color="grey-6" />
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ product.name }}</q-item-label>
              <q-item-label caption>
                {{ [product.product_code, product.barcode].filter(Boolean).join(' · ') }}
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-btn
                unelevated
                dense
                no-caps
                color="primary"
                icon="ph ph-plus"
                :label="$t('shop_admin.storefront_add_product')"
              />
            </q-item-section>
          </q-item>
        </q-list>

        <q-list
          v-if="search.trim().length > 0"
          dense
          bordered
          class="rounded-borders"
          :class="{ 'q-mt-sm': searchResults.length > 0 }"
        >
          <q-item clickable @click="openCreateForm()">
            <q-item-section avatar>
              <q-avatar square color="primary" text-color="white" icon="ph ph-plus" size="48px" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ createNewProductLabel }}</q-item-label>
              <q-item-label caption>{{ $t('shop_admin.storefront_cant_find_create_product') }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-btn
                unelevated
                dense
                no-caps
                color="primary"
                icon="ph ph-plus"
                :label="$t('shop_admin.storefront_add_new_product')"
                @click.stop="openCreateForm()"
              />
            </q-item-section>
          </q-item>
        </q-list>

        <div
          v-if="search.trim().length > 0 && searchResults.length === 0"
          class="text-center text-grey-6 q-pa-lg"
        >
          {{ $t('shop_admin.storefront_no_products_found') }}
        </div>

        <div v-else-if="search.trim().length === 0" class="text-center text-grey-6 q-pa-lg">
          {{ $t('shop_admin.storefront_search_to_find_products') }}
        </div>
      </div>

      <div v-else class="col scroll q-pa-md">
        <ShopStorefrontCreateProductForm
          :initial-name="createFormInitialName"
          @cancel="closeCreateForm"
        />
      </div>

      <template v-if="!showCreateForm">
        <q-separator />
        <div class="q-pa-md bg-grey-1 row items-center justify-end">
          <q-btn
            flat
            :label="$t('shop_admin.cancel')"
            color="grey-8"
            no-caps
            @click="isOpen = false"
          />
        </div>
      </template>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import ShopStorefrontCreateProductForm from './ShopStorefrontCreateProductForm.vue';

interface DrawerProductOption {
  id: number;
  name: string;
  product_code: string | null;
  barcode: string | null;
}

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (event: 'update:modelValue', value: boolean): void;
}>();

const { t } = useI18n();

const search = ref('');
const showCreateForm = ref(false);
const createFormInitialName = ref('');

const catalogOptions: DrawerProductOption[] = [
  {
    id: 1,
    name: 'Premium Cotton T-Shirt — Navy Blue',
    product_code: 'TSH-NVY-001',
    barcode: '8901234567890',
  },
  {
    id: 2,
    name: 'Wireless Bluetooth Earbuds Pro',
    product_code: 'AUD-BT-200',
    barcode: '8901234567891',
  },
  {
    id: 3,
    name: 'Stainless Steel Water Bottle 1L',
    product_code: 'BTL-SS-1L',
    barcode: '8901234567892',
  },
  {
    id: 4,
    name: 'Organic Green Tea — 100 Bags',
    product_code: 'TEA-GRN-100',
    barcode: '8901234567893',
  },
  {
    id: 5,
    name: 'Running Shoes — Size 42',
    product_code: 'SHO-RUN-42',
    barcode: '8901234567894',
  },
];

const isOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const drawerWidth = computed(() => (showCreateForm.value ? 720 : 520));

const searchResults = computed(() => {
  const query = search.value.trim().toLowerCase();
  if (!query) return [];

  return catalogOptions.filter((product) => {
    const haystack = [product.name, product.product_code, product.barcode]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    return haystack.includes(query);
  });
});

const createNewProductLabel = computed(() => {
  const query = search.value.trim();
  return query
    ? t('shop_admin.storefront_create_named_product', { name: query })
    : t('shop_admin.storefront_add_new_product');
});

const openCreateForm = () => {
  createFormInitialName.value = search.value.trim();
  showCreateForm.value = true;
};

const closeCreateForm = () => {
  showCreateForm.value = false;
  createFormInitialName.value = '';
};

const resetDrawer = () => {
  search.value = '';
  showCreateForm.value = false;
  createFormInitialName.value = '';
};

watch(isOpen, (open) => {
  if (!open) {
    resetDrawer();
  }
});
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
</style>
