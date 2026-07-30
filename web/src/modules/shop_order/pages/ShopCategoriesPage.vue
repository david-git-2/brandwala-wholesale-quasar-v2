<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Standard Page Header DNA -->
      <div class="row items-center justify-between q-col-gutter-md">
        <div class="col-12 col-sm-auto">
          <div class="text-overline text-primary">{{ $t('shop_admin.shop_and_order') }}</div>
          <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('shop_admin.shop_categories_title') }}</h1>
          <p class="text-body2 text-grey-7 q-mb-none">
            {{ $t('shop_admin.shop_categories_subtitle') }}
          </p>
        </div>
        <div class="col-12 col-sm-auto row items-center q-gutter-sm">
          <LearnMoreHelpBtn guide-id="shop_categories" tab="workflows" />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            :label="$t('shop_admin.add_category')"
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
              :placeholder="$t('shop_admin.search_category_placeholder')"
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
              :aria-label="$t('shop_admin.refresh_categories')"
              :loading="loading"
              @click="() => fetchCategories()"
            >
              <q-tooltip>{{ $t('shop_admin.refresh_categories') }}</q-tooltip>
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
          :no-data-label="$t('shop_admin.no_categories_found')"
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
                {{ props.value ? $t('shop_admin.active') : $t('shop_admin.inactive') }}
              </q-chip>
            </q-td>
          </template>

          <!-- Custom Icon Column -->
          <template #body-cell-icon="props">
            <q-td :props="props">
              <div class="row items-center q-gutter-x-xs">
                <q-icon :name="props.value || 'ph ph-squares-four'" size="sm" color="primary" />
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
                  :aria-label="$t('shop_admin.edit')"
                  @click="openEditDialog(props.row)"
                >
                  <q-tooltip>{{ $t('shop_admin.edit') }}</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-trash"
                  color="negative"
                  :aria-label="$t('shop_admin.delete')"
                  @click="confirmDelete(props.row)"
                >
                  <q-tooltip>{{ $t('shop_admin.delete') }}</q-tooltip>
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
                    <q-icon :name="props.row.icon || 'ph ph-squares-four'" color="primary" size="sm" />
                    <span class="text-subtitle1 text-weight-bold">{{ props.row.name }}</span>
                  </div>
                  <q-chip
                    dense
                    :color="props.row.is_active ? 'positive' : 'grey-5'"
                    text-color="white"
                  >
                    {{ props.row.is_active ? $t('shop_admin.active') : $t('shop_admin.inactive') }}
                  </q-chip>
                </div>
                <div class="text-caption text-grey-7 q-mb-sm">
                  {{ $t('shop_admin.slug') }}: <code class="bg-grey-2 q-px-xs rounded">{{ props.row.slug }}</code>
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
                    :label="$t('shop_admin.edit')"
                    color="primary"
                    @click="openEditDialog(props.row)"
                  />
                  <q-btn
                    flat
                    dense
                    no-caps
                    icon="ph ph-trash"
                    :label="$t('shop_admin.delete')"
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
            {{ isEditing ? $t('shop_admin.edit_category') : $t('shop_admin.create_category') }}
          </div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
        </q-card-section>

        <q-separator />

        <q-card-section class="q-gutter-y-sm">
          <q-input
            v-model="form.name"
            :label="$t('shop_admin.category_name') + ' *'"
            outlined
            dense
            :rules="[(val) => !!val || $t('shop_admin.category_name_required')]"
            @update:model-value="onNameChange"
          />

          <q-input
            v-model="form.slug"
            :label="$t('shop_admin.slug') + ' *'"
            outlined
            dense
            :hint="$t('shop_admin.slug_hint')"
            :rules="[(val) => !!val || $t('shop_admin.slug_required')]"
          />

          <q-select
            v-model="form.icon"
            :label="$t('shop_admin.icon_label')"
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
            :label="$t('shop_admin.description_label')"
            outlined
            dense
            type="textarea"
            rows="3"
            :hint="$t('shop_admin.description_hint')"
          />

          <q-toggle
            v-model="form.is_active"
            :label="$t('shop_admin.active_category')"
            color="positive"
          />
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            no-caps
            :label="isEditing ? $t('shop_admin.save_changes') : $t('shop_admin.create_category')"
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
          <span class="q-ml-sm text-subtitle1">{{ $t('shop_admin.delete_category_title') }}</span>
        </q-card-section>

        <q-card-section class="q-pt-none text-body2 text-grey-7">
          {{ $t('shop_admin.delete_category_confirm', { name: categoryToDelete?.name }) }}
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            no-caps
            :label="$t('shop_admin.delete')"
            :loading="deleting"
            @click="handleDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useQuasar } from 'quasar';
import { useI18n } from 'vue-i18n';
import LearnMoreHelpBtn from 'src/modules/help/components/LearnMoreHelpBtn.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ShopCategory } from '../types';
import { useShopCategoryListQuery } from '../composables/useShopCategoryQuery';
import {
  useCreateShopCategoryMutation,
  useUpdateShopCategoryMutation,
  useDeleteShopCategoryMutation,
} from '../composables/useShopCategoryMutations';

const $q = useQuasar();
const { t } = useI18n();
const authStore = useAuthStore();

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
  // General & Storefront
  { label: 'Grid / All Categories', value: 'ph ph-squares-four' },
  { label: 'Storefront / Shop', value: 'ph ph-storefront' },
  { label: 'Shopping Bag', value: 'ph ph-shopping-bag' },
  { label: 'Shopping Cart', value: 'ph ph-shopping-cart' },
  { label: 'Tag / Specials', value: 'ph ph-tag' },
  { label: 'Star / Featured', value: 'ph ph-star' },
  { label: 'Sparkle / New Arrival', value: 'ph ph-sparkle' },
  { label: 'Gift / Sets & Combos', value: 'ph ph-gift' },

  // Personal Care, Washing & Bathing
  { label: 'Soap & Hand Wash', value: 'ph ph-hand-soap' },
  { label: 'Shower Gel & Body Wash', value: 'ph ph-shower' },
  { label: 'Bubble Bath & Bath Oils', value: 'ph ph-bathtub' },
  { label: 'Deodorants & Roll-On', value: 'ph ph-gender-male' },
  { label: 'Sanitary & Feminine Hygiene', value: 'ph ph-heart' },

  // Dental & Oral Care (Mouthwash, Toothpaste, Toothbrushes)
  { label: 'Dental & Oral Care', value: 'ph ph-smiley' },
  { label: 'Toothbrush & Hygiene', value: 'ph ph-first-aid-kit' },

  // Hair Care & Hair Styling Tools
  { label: 'Hair Care & Shampoo', value: 'ph ph-sparkles' },
  { label: 'Hair Styling Tools & Accessories', value: 'ph ph-scissors' },
  { label: 'Hair Dryer / Electricals', value: 'ph ph-wind' },
  { label: 'Hair Dye & Treatments', value: 'ph ph-drop' },

  // Skincare, Cosmetics & Beauty
  { label: 'Skin Care & Lotions', value: 'ph ph-flower' },
  { label: 'Face Wash & Cleanser', value: 'ph ph-waves' },
  { label: 'Cosmetics / Face & Eye Makeup', value: 'ph ph-palette' },
  { label: 'Make-up Remover & Wipes', value: 'ph ph-textbox' },
  { label: 'Lip Care & Lipsticks', value: 'ph ph-smiley-wink' },
  { label: 'Sun Protection & Aftersun', value: 'ph ph-sun' },
  { label: 'Nail Polish Remover & Foot Care', value: 'ph ph-hand' },

  // Baby Care, Nursery & Feeding
  { label: 'Baby Accessories & Care', value: 'ph ph-baby' },
  { label: 'Baby Bottles & Feeding', value: 'ph ph-flask' },
  { label: 'Baby Wipes & Nappies', value: 'ph ph-check-circle' },
  { label: 'Teething & Soothers', value: 'ph ph-heartbeat' },
  { label: 'Baby Blankets & Bedding', value: 'ph ph-bed' },

  // Health, Medicine & Pharmacy
  { label: 'Medicine & Pharmacy', value: 'ph ph-pill' },
  { label: 'Vitamins & Energy', value: 'ph ph-lightning' },
  { label: 'First Aid & Plasters', value: 'ph ph-first-aid' },
  { label: 'Contraceptives & Family', value: 'ph ph-shield-check' },

  // Grocery, Foods & Beverages
  { label: 'Grocery & Packaged Food', value: 'ph ph-shopping-bag-open' },
  { label: 'Rice, Pasta & Noodles', value: 'ph ph-bowl-food' },
  { label: 'Biscuits & Bakery', value: 'ph ph-cookie' },
  { label: 'Crisps & Savoury Snacks', value: 'ph ph-popcorn' },
  { label: 'Chocolate & Sweets / Confectionery', value: 'ph ph-cake' },
  { label: 'Breakfast Cereals & Snack Bars', value: 'ph ph-grain' },
  { label: 'Cooking & Table Sauces', value: 'ph ph-cooking-pot' },
  { label: 'Soft Drinks & Beverages', value: 'ph ph-pint-glass' },
  { label: 'Flavoured Milk & Dairy', value: 'ph ph-drop-half-bottom' },

  // Household, Cleaning & Air Care
  { label: 'Multi-Purpose & Surface Cleaner', value: 'ph ph-broom' },
  { label: 'Dishwashing & Tabs', value: 'ph ph-circle' },
  { label: 'Stain Remover & Laundry', value: 'ph ph-t-shirt' },
  { label: 'Toilet Roll & Tissues', value: 'ph ph-paper-plane' },
  { label: 'Air Fresheners & Car Sprays', value: 'ph ph-wind' },
  { label: 'Candles & Wax Melts', value: 'ph ph-flame' },
  { label: 'Gloves, Sponges & Scourers', value: 'ph ph-hand-grabbing' },

  // Toys, Stationery & Miscellaneous
  { label: 'Toys, Games & Stationery', value: 'ph ph-puzzle-piece' },
  { label: 'Car Accessories', value: 'ph ph-car' },
  { label: 'Wholesale Bulk & Packaging', value: 'ph ph-boxes' },
  { label: 'Shipping & Delivery', value: 'ph ph-truck' },
];

const columns = computed(() => [
  { name: 'name', label: t('shop_admin.category_name'), field: 'name', align: 'left' as const, sortable: true },
  { name: 'slug', label: t('shop_admin.slug'), field: 'slug', align: 'left' as const, sortable: true },
  { name: 'icon', label: t('shop_admin.icon_label'), field: 'icon', align: 'left' as const },
  { name: 'description', label: t('shop_admin.description_label'), field: 'description', align: 'left' as const },
  { name: 'is_active', label: t('shop_admin.status'), field: 'is_active', align: 'center' as const, sortable: true },
  { name: 'actions', label: t('shop_admin.capabilities'), field: 'actions', align: 'right' as const },
]);

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);

const queryParams = computed(() => ({
  tenantId: tenantId.value,
}));

const { data: categories, isLoading: loading, refetch: fetchCategories } = useShopCategoryListQuery(queryParams);

const { mutateAsync: createCategoryMutation, isPending: isCreating } = useCreateShopCategoryMutation();
const { mutateAsync: updateCategoryMutation, isPending: isUpdating } = useUpdateShopCategoryMutation();
const { mutateAsync: deleteCategoryMutation, isPending: isDeleting } = useDeleteShopCategoryMutation();

const saving = computed(() => isCreating.value || isUpdating.value);
const deleting = computed(() => isDeleting.value);

const filteredCategories = computed(() => {
  const cats = categories.value || [];
  if (!searchQuery.value.trim()) return cats;
  const q = searchQuery.value.toLowerCase().trim();
  return cats.filter(
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
    icon: category.icon || 'ph ph-squares-four',
    is_active: category.is_active,
  };
  showDialog.value = true;
};

const saveCategory = async () => {
  if (!form.value.name.trim() || !form.value.slug.trim()) {
    $q.notify({ type: 'warning', message: t('shop_admin.name_slug_required') });
    return;
  }

  try {
    if (isEditing.value && form.value.id) {
      await updateCategoryMutation({
        id: form.value.id,
        tenant_id: tenantId.value,
        name: form.value.name,
        slug: form.value.slug,
        description: form.value.description,
        icon: form.value.icon,
        is_active: form.value.is_active,
      });
      $q.notify({ type: 'positive', message: t('shop_admin.category_updated_success') });
    } else {
      await createCategoryMutation({
        tenant_id: tenantId.value,
        name: form.value.name,
        slug: form.value.slug,
        description: form.value.description,
        icon: form.value.icon,
        is_active: form.value.is_active,
      });
      $q.notify({ type: 'positive', message: t('shop_admin.category_created_success') });
    }
    showDialog.value = false;
  } catch (error: any) {
    $q.notify({
      type: 'negative',
      message: error?.message || t('shop_admin.category_save_failed'),
    });
  }
};

const confirmDelete = (category: ShopCategory) => {
  categoryToDelete.value = category;
  showDeleteDialog.value = true;
};

const handleDelete = async () => {
  if (!categoryToDelete.value || !tenantId.value) return;
  try {
    await deleteCategoryMutation({ id: categoryToDelete.value.id, tenantId: tenantId.value });
    $q.notify({ type: 'positive', message: t('shop_admin.category_deleted_success') });
    showDeleteDialog.value = false;
  } catch (error: any) {
    $q.notify({
      type: 'negative',
      message: error?.message || t('shop_admin.category_delete_failed'),
    });
  }
};
</script>
