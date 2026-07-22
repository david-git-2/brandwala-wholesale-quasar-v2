<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Invoices</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Billing Profiles</h1>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            class="pill-btn"
            label="Create Billing Profile"
            @click="createOpen = true"
          />
        </div>
      </section>

      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-auto row items-center q-gutter-sm">
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
              v-model="searchText"
              outlined
              dense
              clearable
              class="soft-input toolbar-search"
              label="Search Billing Profile"
              @clear="onSearchChange"
              @keyup.enter="onSearchChange"
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
          <div class="col-auto"></div>
        </div>
      </q-card>

      <q-card flat class="floating-surface shadow-1">
      <q-markup-table flat wrap-cells class="billing-profiles-table">
        <thead>
          <tr>
            <th class="text-left">Name</th>
            <th class="text-left">Customer Group</th>
            <th class="text-left">Email</th>
            <th class="text-left">Phone</th>
            <th class="text-left">Address</th>
            <th class="text-right" style="width: 80px">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!store.items.length && !store.loading">
            <td colspan="6" class="text-center text-grey-7">No billing profiles found.</td>
          </tr>
          <tr v-for="row in filteredItems" :key="row.id">
            <td>
              <div class="row items-center no-wrap">
                <q-avatar
                  size="36px"
                  :color="getAvatarStyleAndColor(row).color"
                  :style="getAvatarStyleAndColor(row).style"
                  text-color="white"
                  class="q-mr-sm text-weight-bold"
                >
                  {{ getInitials(row.name) }}
                </q-avatar>
                <div>
                  <div class="text-weight-bold text-black">{{ row.name }}</div>
                  <div class="text-caption text-grey-7 text-xs">
                    {{ row.email || row.phone || '' }}
                  </div>
                </div>
              </div>
            </td>
            <td>
              <q-chip v-if="row.customer_group_id" dense outline size="sm">
                {{ customerGroupNameMap[row.customer_group_id] ?? '-' }}
              </q-chip>
              <span v-else class="text-grey-6 text-caption">Others</span>
            </td>
            <td>{{ row.email ?? '-' }}</td>
            <td>{{ row.phone ?? '-' }}</td>
            <td>{{ row.address ?? '-' }}</td>
            <td class="text-right">
              <q-btn flat round dense icon="more_vert">
                <q-menu auto-close>
                  <q-list dense style="min-width: 140px">
                    <q-item clickable @click="onOpenEdit(row.id)">
                      <q-item-section>Edit</q-item-section>
                    </q-item>
                    <q-item clickable class="text-negative" @click="onOpenDelete(row.id)">
                      <q-item-section>Delete</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <q-input
        v-model="emailFilter"
        filled
        dense
        clearable
        class="soft-input q-mb-sm"
        label="Email Contains"
        @update:model-value="onSearchChange"
      />
      <q-input
        v-model="phoneFilter"
        filled
        dense
        clearable
        class="soft-input q-mb-md"
        label="Phone Contains"
        @update:model-value="onSearchChange"
      />
      <div class="row q-gutter-sm justify-end">
        <q-btn flat no-caps label="Reset" @click="onResetFilters" />
      </div>
    </FilterSidebar>

    <BillingProfileCreateDialog
      v-model="createOpen"
      :tenant-id="authStore.tenantId"
      :saving="store.saving"
      @submit="onCreate"
    />

    <BillingProfileEditDialog
      v-model="editOpen"
      :profile="selectedProfile"
      :saving="store.saving"
      @submit="onEdit"
    />

    <q-dialog v-model="deleteOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Delete Billing Profile</q-card-section>
        <q-card-section> Are you sure you want to delete this billing profile? </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            no-caps
            label="Delete"
            :loading="store.saving"
            @click="onDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import BillingProfileCreateDialog from '../components/BillingProfileCreateDialog.vue';
import BillingProfileEditDialog from '../components/BillingProfileEditDialog.vue';
import { useBillingProfileStore } from '../stores/billingProfileStore';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import type {
  BillingProfile,
  CreateBillingProfileInput,
} from '../repositories/billingProfileRepository';

const authStore = useAuthStore();
const route = useRoute();
const store = useBillingProfileStore();
const customerGroupStore = useCustomerGroupStore();

const createOpen = ref(false);
const showSearchInput = ref(false);
const filterDrawerOpen = ref(false);
const searchText = ref('');
const emailFilter = ref('');
const phoneFilter = ref('');
const editOpen = ref(false);
const deleteOpen = ref(false);
const selectedId = ref<number | null>(null);

const selectedProfile = computed<BillingProfile | null>(
  () => store.items.find((row) => row.id === selectedId.value) ?? null,
);
const filteredItems = computed(() => {
  const search = searchText.value.trim().toLowerCase();
  const email = emailFilter.value.trim().toLowerCase();
  const phone = phoneFilter.value.trim().toLowerCase();
  return store.items.filter((row) => {
    const matchesSearch =
      !search ||
      [row.name, row.email ?? '', row.phone ?? '', row.address ?? ''].some((value) =>
        value.toLowerCase().includes(search),
      );
    const matchesEmail = !email || (row.email ?? '').toLowerCase().includes(email);
    const matchesPhone = !phone || (row.phone ?? '').toLowerCase().includes(phone);
    return matchesSearch && matchesEmail && matchesPhone;
  });
});
const activeFilterCount = computed(() => {
  let count = 0;
  if (emailFilter.value.trim()) count += 1;
  if (phoneFilter.value.trim()) count += 1;
  return count;
});

const customerGroupNameMap = computed<Record<number, string>>(() =>
  customerGroupStore.groups.reduce<Record<number, string>>((acc, g) => {
    acc[g.id] = g.name;
    return acc;
  }, {}),
);

const customerGroupColorMap = computed<Record<number, string | null>>(() =>
  customerGroupStore.groups.reduce<Record<number, string | null>>((acc, g) => {
    acc[g.id] = g.accent_color;
    return acc;
  }, {}),
);

const load = async () => {
  if (!authStore.tenantId) return;
  await Promise.all([
    store.fetchBillingProfiles({
      tenant_id: authStore.tenantId,
      page: 1,
      page_size: 50,
      sortBy: 'created_at',
      sortOrder: 'desc',
    }),
    customerGroupStore.fetchCustomerGroupsByTenant(authStore.tenantId),
  ]);
};

const onCreate = async (payload: CreateBillingProfileInput) => {
  const result = await store.createBillingProfile(payload);
  if (result.success) {
    createOpen.value = false;
  }
};

const onOpenEdit = (id: number) => {
  selectedId.value = id;
  editOpen.value = true;
};

const onEdit = async (payload: {
  id: number;
  patch: {
    name: string;
    email: string | null;
    phone: string | null;
    address: string | null;
    customer_group_id: number | null;
    color: string | null;
  };
}) => {
  const result = await store.updateBillingProfile(payload);
  if (result.success) {
    editOpen.value = false;
  }
};

const onOpenDelete = (id: number) => {
  selectedId.value = id;
  deleteOpen.value = true;
};

const onDelete = async () => {
  if (selectedId.value === null) return;
  const result = await store.deleteBillingProfile(selectedId.value);
  if (result.success) {
    deleteOpen.value = false;
    selectedId.value = null;
  }
};

const onSearchChange = () => {};
const onCloseSearch = () => {
  showSearchInput.value = false;
  searchText.value = '';
};
const getInitials = (name?: string | null) => {
  if (!name) return 'U';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'U';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'U';
};

const getAvatarColor = (name?: string | null) => {
  if (!name) return 'grey-6';
  const colors = ['purple-5', 'teal-5', 'blue-5', 'orange-5', 'cyan-5', 'indigo-5', 'green-5'];
  let sum = 0;
  for (let i = 0; i < name.length; i++) {
    sum += name.charCodeAt(i);
  }
  return colors[sum % colors.length];
};

const getAvatarStyleAndColor = (row: BillingProfile) => {
  if (row.color) {
    if (row.color.startsWith('#')) {
      return { style: { backgroundColor: row.color }, color: undefined };
    }
    return { style: {}, color: row.color };
  }

  if (row.customer_group_id) {
    const groupColor = customerGroupColorMap.value[row.customer_group_id];
    if (groupColor) {
      if (groupColor.startsWith('#')) {
        return { style: { backgroundColor: groupColor }, color: undefined };
      }
      return { style: {}, color: groupColor };
    }
  }

  const fallbackColor = getAvatarColor(row.name) || 'grey-6';
  if (fallbackColor.startsWith('#')) {
    return { style: { backgroundColor: fallbackColor }, color: undefined };
  }
  return { style: {}, color: fallbackColor };
};

const onResetFilters = () => {
  emailFilter.value = '';
  phoneFilter.value = '';
};

onMounted(() => {
  void load();
  if (route.query.create === 'true') {
    createOpen.value = true;
  }
});
</script>

<style scoped>
.color-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 6px;
}
.hero-surface {
  border-radius: 16px;
}
.pill-btn {
  border-radius: 999px;
}
.slim-btn {
  min-height: 32px;
  padding-left: 14px;
  padding-right: 14px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
