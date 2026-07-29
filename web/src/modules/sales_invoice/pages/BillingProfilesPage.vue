<template>
  <component :is="isEmbedded ? 'div' : 'q-page'" :class="isEmbedded ? '' : 'q-pa-md'">
    <div class="q-gutter-y-md">
      <section v-if="!isEmbedded" class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Invoices</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Billing Profiles</h1>
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
              icon="ph ph-magnifying-glass"
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
                <q-icon name="ph ph-magnifying-glass" />
              </template>
              <template #append>
                <q-btn
                  flat
                  round
                  dense
                  icon="ph ph-x"
                  aria-label="Hide search"
                  @click="onCloseSearch"
                />
              </template>
            </q-input>

            <q-btn
              flat
              round
              dense
              icon="ph ph-funnel"
              aria-label="Filters"
              @click="filterDrawerOpen = true"
            >
              <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
                {{ activeFilterCount }}
              </q-badge>
            </q-btn>
          </div>
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
            <td colspan="6" class="q-pa-none">
              <div class="column items-center justify-center q-pa-xl text-center">
                <q-avatar size="64px" color="primary-soft" class="q-mb-md">
                  <q-icon name="ph ph-receipt" size="32px" color="primary" />
                </q-avatar>
                <div class="text-h6 text-weight-bold text-grey-9 q-mb-xs">
                  No Billing Profiles Found
                </div>
                <p class="text-body2 text-grey-6 q-mb-md" style="max-width: 400px">
                  Billing profiles are automatically managed per Customer Group. Create a Customer Group to generate its billing profile.
                </p>
              </div>
            </td>
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
              <q-btn
                flat
                round
                dense
                color="primary"
                icon="ph ph-wallet"
                @click="onOpenWalletDrawer(row)"
              >
                <q-tooltip>Wallet &amp; Ledger</q-tooltip>
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

    <BillingProfileDetailsDrawer
      v-model="walletDrawerOpen"
      :tenant-id="authStore.tenantId"
      :billing-profile-id="selectedProfileForWallet?.id ?? null"
      :profile-name="selectedProfileForWallet?.name ?? ''"
      :email="selectedProfileForWallet?.email"
      :phone="selectedProfileForWallet?.phone"
      :net-balance="0"
    />
  </div>
  </component>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import BillingProfileCreateDialog from '../components/BillingProfileCreateDialog.vue';
import BillingProfileEditDialog from '../components/BillingProfileEditDialog.vue';
import BillingProfileDetailsDrawer from '../components/BillingProfileDetailsDrawer.vue';
import { useBillingProfilesQuery } from '../composables/useBillingProfileQuery';
import { useBillingProfileMutations } from '../composables/useBillingProfileMutations';
import { useCustomerGroupsQuery } from 'src/modules/tenant/composables/useCustomerGroupQuery';
import type {
  BillingProfile,
  CreateBillingProfileInput,
} from '../repositories/billingProfileRepository';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const props = withDefaults(
  defineProps<{
    isEmbedded?: boolean;
  }>(),
  {
    isEmbedded: false,
  }
);

const authStore = useAuthStore();
const route = useRoute();

const tenantId = computed(() => authStore.tenantId as number);

// TanStack Query & Mutations
const { data: billingProfilesData, isLoading: profilesLoading } = useBillingProfilesQuery(tenantId);
const { data: customerGroupsData } = useCustomerGroupsQuery(tenantId);

const {
  createBillingProfileMutation,
  updateBillingProfileMutation,
  deleteBillingProfileMutation,
} = useBillingProfileMutations();

const items = computed(() => billingProfilesData.value?.data ?? []);
const customerGroups = computed(() => customerGroupsData.value ?? []);
const isSaving = computed(
  () =>
    createBillingProfileMutation.isPending.value ||
    updateBillingProfileMutation.isPending.value ||
    deleteBillingProfileMutation.isPending.value
);

const store = computed(() => ({
  items: items.value,
  loading: profilesLoading.value,
  saving: isSaving.value,
}));

const createOpen = ref(false);
const showSearchInput = ref(false);
const filterDrawerOpen = ref(false);
const searchText = ref('');
const emailFilter = ref('');
const phoneFilter = ref('');
const editOpen = ref(false);
const deleteOpen = ref(false);
const selectedId = ref<number | null>(null);
const walletDrawerOpen = ref(false);
const selectedProfileForWallet = ref<BillingProfile | null>(null);

const onOpenWalletDrawer = (profile: BillingProfile) => {
  selectedProfileForWallet.value = profile;
  walletDrawerOpen.value = true;
};

const selectedProfile = computed<BillingProfile | null>(
  () => items.value.find((row) => row.id === selectedId.value) ?? null,
);
const filteredItems = computed(() => {
  const search = searchText.value.trim().toLowerCase();
  const email = emailFilter.value.trim().toLowerCase();
  const phone = phoneFilter.value.trim().toLowerCase();
  return items.value.filter((row) => {
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
  customerGroups.value.reduce<Record<number, string>>((acc, g) => {
    acc[g.id] = g.name;
    return acc;
  }, {}),
);

const customerGroupColorMap = computed<Record<number, string | null>>(() =>
  customerGroups.value.reduce<Record<number, string | null>>((acc, g) => {
    acc[g.id] = g.accent_color;
    return acc;
  }, {}),
);

const onCreate = async (payload: CreateBillingProfileInput) => {
  try {
    await createBillingProfileMutation.mutateAsync(payload);
    showSuccessNotification('Billing profile created successfully');
    createOpen.value = false;
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to create billing profile');
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
  try {
    await updateBillingProfileMutation.mutateAsync({
      ...payload,
      tenant_id: tenantId.value,
    });
    showSuccessNotification('Billing profile updated successfully');
    editOpen.value = false;
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to update billing profile');
  }
};

const onOpenDelete = (id: number) => {
  selectedId.value = id;
  deleteOpen.value = true;
};

const onDelete = async () => {
  if (selectedId.value === null) return;
  try {
    await deleteBillingProfileMutation.mutateAsync({
      id: selectedId.value,
      tenant_id: tenantId.value,
    });
    showSuccessNotification('Billing profile deleted successfully');
    deleteOpen.value = false;
    selectedId.value = null;
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to delete billing profile');
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
