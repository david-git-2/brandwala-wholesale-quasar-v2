<template>
  <q-page class="q-pa-md">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm row items-center justify-between">
        <div>
          <div class="text-h6 text-weight-bold">Category Management</div>
          <div class="text-caption text-grey-8">Manage product categories</div>
        </div>
        <q-btn
          color="primary"
          no-caps
          size="sm"
          class="pill-btn slim-btn"
          label="Add Category"
          @click="openCreate"
        />
      </q-card-section>
    </q-card>

    <q-card flat class="q-mb-md floating-surface shadow-1">
      <q-card-section>
        <div class="row items-center justify-between q-gutter-sm">
          <div class="row items-center q-gutter-sm toolbar-left">
            <q-btn
              v-if="!showSearchInput"
              flat
              round
              dense
              icon="search"
              aria-label="Show search"
              @click="showSearchInput = true"
            />
            <q-input
              v-else
              v-model="search"
              outlined
              dense
              clearable
              autofocus
              class="soft-input toolbar-search"
              label="Search category"
            >
              <template #prepend>
                <q-icon name="search" />
              </template>
              <template #append>
                <q-btn
                  flat
                  round
                  dense
                  icon="close"
                  aria-label="Hide search"
                  @click="onCloseSearch"
                />
              </template>
            </q-input>
            <q-btn
              flat
              round
              dense
              icon="filter_alt"
              aria-label="Filters"
              @click="filterDrawerOpen = true"
            >
              <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                {{ activeFilterCount }}
              </q-badge>
            </q-btn>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-card-section>
        <q-table
          :rows="filteredRows"
          :columns="columns"
          row-key="id"
          flat
          :pagination="{ rowsPerPage: 0 }"
          hide-pagination
        >
          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn flat round dense icon="more_vert">
                <q-menu auto-close>
                  <q-list dense>
                    <q-item clickable @click="openEdit(props.row)"
                      ><q-item-section>Edit</q-item-section></q-item
                    >
                    <q-item clickable @click="remove(props.row)"
                      ><q-item-section class="text-negative">Delete</q-item-section></q-item
                    >
                  </q-list>
                </q-menu>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-select
        v-model="vendorCode"
        :options="vendorOptions"
        emit-value
        map-options
        outlined
        dense
        clearable
        class="soft-input q-mb-md"
        label="Vendor"
      />
      <div class="row justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetFilters" />
      </div>
    </FilterSidebar>

    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="min-width: 420px">
        <q-card-section class="text-h6">{{
          editingId ? 'Edit Category' : 'Add Category'
        }}</q-card-section>
        <q-card-section class="q-gutter-sm">
          <q-input v-model="form.name" outlined dense class="soft-input" label="Name" />
          <q-input
            v-model="form.value"
            outlined
            dense
            class="soft-input"
            label="Value (lowercase)"
          />
          <q-select
            v-model="form.vendor_code"
            :options="vendorOptions"
            emit-value
            map-options
            outlined
            dense
            class="soft-input"
            label="Vendor"
            clearable
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="dialogOpen = false" />
          <q-btn color="primary" label="Save" @click="save" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { productService } from '../services/productService';
import type { ProductCategory } from '../types';
import { handleApiFailure, showSuccessNotification } from 'src/utils/appFeedback';
import FilterSidebar from 'src/components/FilterSidebar.vue';

const authStore = useAuthStore();
const vendorStore = useVendorStore();

const rows = ref<ProductCategory[]>([]);
const search = ref('');
const showSearchInput = ref(false);
const filterDrawerOpen = ref(false);
const vendorCode = ref<string | null>(null);
const dialogOpen = ref(false);
const editingId = ref<number | null>(null);
const form = reactive<{ name: string; value: string; vendor_code: string | null }>({
  name: '',
  value: '',
  vendor_code: null,
});

const vendorOptions = computed(() => [
  { label: 'All vendors', value: null as string | null },
  ...vendorStore.items.map((v) => ({ label: `${v.name} (${v.code})`, value: v.code })),
]);

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' },
  { name: 'value', label: 'Value', field: 'value', align: 'left' },
  { name: 'vendor_code', label: 'Vendor', field: 'vendor_code', align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' },
];

const filteredRows = computed(() => {
  const term = search.value.trim().toLowerCase();
  return rows.value.filter((r) => {
    const vendorMatch = !vendorCode.value || r.vendor_code === vendorCode.value;
    const searchMatch =
      !term ||
      [r.name, r.value, r.vendor_code]
        .filter(Boolean)
        .some((x) => String(x).toLowerCase().includes(term));
    return vendorMatch && searchMatch;
  });
});
const activeFilterCount = computed(() => (vendorCode.value ? 1 : 0));

const load = async () => {
  const result = await productService.listProductCategories({
    vendorCode: vendorCode.value,
    tenantId: authStore.tenantId ?? null,
  });
  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to load categories.');
    return;
  }
  rows.value = result.data ?? [];
};

const openCreate = () => {
  editingId.value = null;
  form.name = '';
  form.value = '';
  form.vendor_code = vendorCode.value;
  dialogOpen.value = true;
};

const openEdit = (row: ProductCategory) => {
  editingId.value = row.id;
  form.name = row.name;
  form.value = row.value ?? '';
  form.vendor_code = row.vendor_code;
  dialogOpen.value = true;
};

const save = async () => {
  const selectedVendor = vendorStore.items.find((v) => v.code === form.vendor_code);
  const payload = {
    name: form.name.trim(),
    value: (form.value.trim() || form.name.trim()).toLowerCase(),
    vendor_code: form.vendor_code,
    vendor_id: selectedVendor ? selectedVendor.id : null,
  };

  if (!payload.name) return;

  const result = editingId.value
    ? await productService.updateProductCategory({ id: editingId.value, ...payload })
    : await productService.createProductCategory(payload);

  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to save category.');
    return;
  }

  showSuccessNotification(
    editingId.value ? 'Category updated successfully.' : 'Category created successfully.',
  );
  dialogOpen.value = false;
  await load();
};

const remove = async (row: ProductCategory) => {
  const result = await productService.deleteProductCategory({ id: row.id });
  if (!result.success) {
    handleApiFailure(result, result.error ?? 'Failed to delete category.');
    return;
  }
  showSuccessNotification('Category deleted successfully.');
  await load();
};

const onCloseSearch = () => {
  showSearchInput.value = false;
  search.value = '';
};

const onResetFilters = () => {
  vendorCode.value = null;
  filterDrawerOpen.value = false;
};

watch(vendorCode, () => {
  void load();
});

onMounted(async () => {
  await vendorStore.fetchVendors(authStore.tenantId ?? null);
  await load();
});
</script>

<style scoped>
.hero-surface {
  border-radius: 16px;
}
.pill-btn {
  border-radius: 999px;
}
.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
.toolbar-left {
  min-width: 0;
}
.toolbar-search {
  width: min(320px, 75vw);
}
</style>
