<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Standard Page Header DNA -->
      <div class="row items-center justify-between q-col-gutter-md">
        <div class="col-12 col-sm-auto">
          <div class="text-overline text-primary">SHOP & ORDER</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Shop Categories</h1>
          <p class="text-body2 text-grey-7 q-mb-none">
            Manage tenant shop categories displayed across customer storefronts.
          </p>
        </div>
        <div class="col-12 col-sm-auto row items-center q-gutter-sm">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Add Category"
            class="pill-btn"
            style="min-height: 44px"
            @click="openCreateDialog"
          />
        </div>
      </div>

      <!-- Filters & Search Toolbar -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm-6 col-md-4">
            <q-input
              v-model="searchQuery"
              dense
              outlined
              placeholder="Search category by name or slug..."
              clearable
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-auto">
            <q-btn
              flat
              dense
              round
              icon="ph ph-arrows-clockwise"
              aria-label="Refresh categories"
              :loading="loading"
              @click="fetchCategories"
            >
              <q-tooltip>Refresh Categories</q-tooltip>
            </q-btn>
          </div>
        </div>
      </q-card>

      <!-- Categories Table / Mobile Grid -->
      <q-card flat bordered>
        <q-table
          flat
          :rows="filteredCategories"
          :columns="columns"
          row-key="id"
          :loading="loading"
          :grid="$q.screen.lt.sm"
          no-data-label="No shop categories found"
          :pagination="{ rowsPerPage: 15 }"
        >
          <!-- Custom Status Column -->
          <template #body-cell-is_active="props">
            <q-td :props="props">
              <q-chip
                dense
                :color="props.value ? 'positive' : 'grey-5'"
                text-color="white"
                class="text-weight-bold"
              >
                {{ props.value ? 'Active' : 'Inactive' }}
              </q-chip>
            </q-td>
          </template>

          <!-- Custom Icon Column -->
          <template #body-cell-icon="props">
            <q-td :props="props">
              <div class="row items-center q-gutter-x-xs">
                <q-icon :name="props.value || 'category'" size="sm" color="primary" />
                <span class="text-caption text-grey-8">{{ props.value }}</span>
              </div>
            </q-td>
          </template>

          <!-- Actions Column -->
          <template #body-cell-actions="props">
            <q-td :props="props" align="right">
              <div class="row items-center justify-end q-gutter-xs">
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-pencil-simple"
                  color="primary"
                  aria-label="Edit Category"
                  @click="openEditDialog(props.row)"
                >
                  <q-tooltip>Edit</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-trash"
                  color="negative"
                  aria-label="Delete Category"
                  @click="confirmDelete(props.row)"
                >
                  <q-tooltip>Delete</q-tooltip>
                </q-btn>
              </div>
            </q-td>
          </template>

          <!-- Mobile Card View -->
          <template #item="props">
            <div class="col-12 q-pa-xs">
              <q-card flat bordered class="q-pa-md">
                <div class="row items-center justify-between q-mb-xs">
                  <div class="row items-center q-gutter-x-xs">
                    <q-icon :name="props.row.icon || 'category'" color="primary" size="sm" />
                    <span class="text-subtitle1 text-weight-bold">{{ props.row.name }}</span>
                  </div>
                  <q-chip
                    dense
                    :color="props.row.is_active ? 'positive' : 'grey-5'"
                    text-color="white"
                  >
                    {{ props.row.is_active ? 'Active' : 'Inactive' }}
                  </q-chip>
                </div>
                <div class="text-caption text-grey-7 q-mb-sm">
                  Slug: <code class="bg-grey-2 q-px-xs rounded">{{ props.row.slug }}</code>
                </div>
                <p v-if="props.row.description" class="text-body2 text-grey-9 q-mb-sm">
                  {{ props.row.description }}
                </p>
                <div class="row justify-end q-gutter-xs">
                  <q-btn
                    flat
                    dense
                    no-caps
                    icon="ph ph-pencil-simple"
                    label="Edit"
                    color="primary"
                    @click="openEditDialog(props.row)"
                  />
                  <q-btn
                    flat
                    dense
                    no-caps
                    icon="ph ph-trash"
                    label="Delete"
                    color="negative"
                    @click="confirmDelete(props.row)"
                  />
                </div>
              </q-card>
            </div>
          </template>
        </q-table>
      </q-card>
    </div>

    <!-- Create / Edit Dialog -->
    <q-dialog v-model="showDialog" persistent>
      <q-card style="min-width: 400px; max-width: 500px">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6 text-weight-bold">
            {{ isEditing ? 'Edit Category' : 'Create Shop Category' }}
          </div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>

        <q-separator />

        <q-card-section class="q-gutter-y-sm">
          <q-input
            v-model="form.name"
            label="Category Name *"
            outlined
            dense
            :rules="[(val) => !!val || 'Name is required']"
            @update:model-value="onNameChange"
          />

          <q-input
            v-model="form.slug"
            label="Slug *"
            outlined
            dense
            hint="URL-friendly identifier"
            :rules="[(val) => !!val || 'Slug is required']"
          />

          <q-select
            v-model="form.icon"
            label="Icon"
            outlined
            dense
            emit-value
            map-options
            :options="iconOptions"
          >
            <template #option="scope">
              <q-item v-bind="scope.itemProps">
                <q-item-section avatar>
                  <q-icon :name="scope.opt.value" color="primary" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ scope.opt.label }}</q-item-label>
                </q-item-section>
              </q-item>
            </template>
            <template #selected>
              <div class="row items-center q-gutter-x-xs" v-if="form.icon">
                <q-icon :name="form.icon" color="primary" />
                <span>{{ form.icon }}</span>
              </div>
            </template>
          </q-select>

          <q-input
            v-model="form.description"
            label="Description"
            outlined
            dense
            type="textarea"
            rows="3"
            hint="Brief description of products in this category"
          />

          <q-toggle
            v-model="form.is_active"
            label="Active Category"
            color="positive"
          />
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            no-caps
            :label="isEditing ? 'Save Changes' : 'Create Category'"
            :loading="saving"
            style="min-height: 40px"
            @click="saveCategory"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Delete Confirmation Dialog -->
    <q-dialog v-model="showDeleteDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <q-avatar icon="ph ph-warning" color="negative" text-color="white" />
          <span class="q-ml-sm text-subtitle1">Delete Category?</span>
        </q-card-section>

        <q-card-section class="q-pt-none text-body2 text-grey-7">
          Are you sure you want to delete category
          <strong class="text-grey-10">{{ categoryToDelete?.name }}</strong>?
          This action cannot be undone.
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            no-caps
            label="Delete"
            :loading="deleting"
            @click="handleDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopCategoryRepository } from '../repositories/shopCategoryRepository';
import type { ShopCategory } from '../types';

const $q = useQuasar();
const authStore = useAuthStore();

const categories = ref<ShopCategory[]>([]);
const loading = ref(false);
const saving = ref(false);
const deleting = ref(false);
const searchQuery = ref('');

const showDialog = ref(false);
const isEditing = ref(false);
const showDeleteDialog = ref(false);
const categoryToDelete = ref<ShopCategory | null>(null);

const form = ref<{
  id?: number;
  name: string;
  slug: string;
  description: string;
  icon: string;
  is_active: boolean;
}>({
  name: '',
  slug: '',
  description: '',
  icon: 'ph ph-squares-four',
  is_active: true,
});

const iconOptions = [
  { label: 'Category', value: 'category' },
  { label: 'Checkroom (Apparel)', value: 'checkroom' },
  { label: 'Shopping Bag', value: 'shopping_bag' },
  { label: 'Storefront', value: 'storefront' },
  { label: 'Style', value: 'style' },
  { label: 'Devices (Electronics)', value: 'devices' },
  { label: 'Local Mall', value: 'local_mall' },
  { label: 'Inventory', value: 'inventory_2' },
  { label: 'Star / Featured', value: 'star' },
];

const columns = [
  { name: 'name', label: 'Category Name', field: 'name', align: 'left' as const, sortable: true },
  { name: 'slug', label: 'Slug', field: 'slug', align: 'left' as const, sortable: true },
  { name: 'icon', label: 'Icon', field: 'icon', align: 'left' as const },
  { name: 'description', label: 'Description', field: 'description', align: 'left' as const },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'center' as const, sortable: true },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'right' as const },
];

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);

const filteredCategories = computed(() => {
  if (!searchQuery.value.trim()) return categories.value;
  const q = searchQuery.value.toLowerCase().trim();
  return categories.value.filter(
    (c) => c.name.toLowerCase().includes(q) || c.slug.toLowerCase().includes(q),
  );
});

const slugify = (text: string) => {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-');
};

const onNameChange = (val: string | number | null) => {
  if (!isEditing.value) {
    form.value.slug = slugify(String(val ?? ''));
  }
};

const fetchCategories = async () => {
  if (!tenantId.value) return;
  loading.value = true;
  try {
    categories.value = await shopCategoryRepository.listCategories(tenantId.value);
  } catch (error: any) {
    $q.notify({
      type: 'negative',
      message: error?.message || 'Failed to load shop categories.',
    });
  } finally {
    loading.value = false;
  }
};

const openCreateDialog = () => {
  isEditing.value = false;
  form.value = {
    name: '',
    slug: '',
    description: '',
    icon: 'ph ph-squares-four',
    is_active: true,
  };
  showDialog.value = true;
};

const openEditDialog = (category: ShopCategory) => {
  isEditing.value = true;
  form.value = {
    id: category.id,
    name: category.name,
    slug: category.slug,
    description: category.description || '',
    icon: category.icon || 'category',
    is_active: category.is_active,
  };
  showDialog.value = true;
};

const saveCategory = async () => {
  if (!form.value.name.trim() || !form.value.slug.trim()) {
    $q.notify({ type: 'warning', message: 'Name and slug are required.' });
    return;
  }

  saving.value = true;
  try {
    if (isEditing.value && form.value.id) {
      await shopCategoryRepository.updateCategory({
        id: form.value.id,
        tenant_id: tenantId.value,
        name: form.value.name,
        slug: form.value.slug,
        description: form.value.description,
        icon: form.value.icon,
        is_active: form.value.is_active,
      });
      $q.notify({ type: 'positive', message: 'Category updated successfully.' });
    } else {
      await shopCategoryRepository.createCategory({
        tenant_id: tenantId.value,
        name: form.value.name,
        slug: form.value.slug,
        description: form.value.description,
        icon: form.value.icon,
        is_active: form.value.is_active,
      });
      $q.notify({ type: 'positive', message: 'Category created successfully.' });
    }
    showDialog.value = false;
    await fetchCategories();
  } catch (error: any) {
    $q.notify({
      type: 'negative',
      message: error?.message || 'Failed to save shop category.',
    });
  } finally {
    saving.value = false;
  }
};

const confirmDelete = (category: ShopCategory) => {
  categoryToDelete.value = category;
  showDeleteDialog.value = true;
};

const handleDelete = async () => {
  if (!categoryToDelete.value || !tenantId.value) return;
  deleting.value = true;
  try {
    await shopCategoryRepository.deleteCategory(categoryToDelete.value.id, tenantId.value);
    $q.notify({ type: 'positive', message: 'Category deleted successfully.' });
    showDeleteDialog.value = false;
    await fetchCategories();
  } catch (error: any) {
    $q.notify({
      type: 'negative',
      message: error?.message || 'Failed to delete category.',
    });
  } finally {
    deleting.value = false;
  }
};

onMounted(() => {
  fetchCategories();
});
</script>
