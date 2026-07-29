<template>
  <component :is="isEmbedded ? 'div' : 'q-page'" :class="isEmbedded ? '' : 'bw-page'">
    <section class="bw-page__stack">
      <!-- Header (Hidden when embedded in hub) -->
      <section v-if="!isEmbedded" class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">{{ $t('shop_admin.shop_and_order') }}</div>
          <h1 class="text-h5 q-my-none">{{ $t('navigation.customer_groups') }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ $t('shop_admin.customer_groups_subtitle') }}
          </p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-user-plus"
            :label="$t('shop_admin.add_customer_group')"
            @click="openCreateDialog"
          />
        </div>
      </section>

      <!-- Embedded Top Action Bar -->
      <div v-else class="row items-center justify-between q-mb-xs">
        <div class="text-subtitle1 text-weight-medium text-grey-8">
          Customer Groups
        </div>
        <div>
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-user-plus"
            :label="$t('shop_admin.add_customer_group')"
            @click="openCreateDialog"
          />
        </div>
      </div>

      <!-- Error banner -->
      <q-banner v-if="store.error || groupStore.error" class="text-white bg-negative" rounded>
        {{ store.error || groupStore.error }}
        <template #action>
          <q-btn
            flat
            color="white"
            :label="$t('shop_admin.dismiss')"
            @click="
              store.clearError();
              groupStore.clearError();
            "
          />
        </template>
      </q-banner>

      <!-- Table / Card -->
      <q-card flat bordered>
        <q-card-section v-if="groupStore.loading" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          {{ $t('shop_admin.loading_customer_groups') }}
        </q-card-section>

        <q-card-section
          v-else-if="groupStore.groups.length === 0"
          class="column items-center justify-center q-pa-xl text-center"
        >
          <q-avatar size="64px" color="primary-soft" class="q-mb-md">
            <q-icon name="ph ph-users-three" size="32px" color="primary" />
          </q-avatar>
          <div class="text-h6 text-weight-bold text-grey-9 q-mb-xs">
            {{ $t('shop_admin.no_customer_groups') }}
          </div>
          <p class="text-body2 text-grey-6 q-mb-md" style="max-width: 400px">
            Organize customer access levels, discounts, and custom billing rules by adding customer groups.
          </p>
          <div>
            <q-btn
              color="primary"
              unelevated
              no-caps
              class="pill-btn"
              icon="ph ph-plus"
              :label="$t('shop_admin.add_customer_group')"
              @click="openCreateDialog"
            />
          </div>
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="groupStore.groups"
          :columns="columns"
          :pagination="{ rowsPerPage: 25 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-accent="props">
            <q-td :props="props">
              <div
                class="accent-swatch shadow-1"
                :style="{ backgroundColor: props.row.accent_color || '#B45F34' }"
              >
                <q-tooltip>{{ props.row.accent_color || 'Default' }}</q-tooltip>
              </div>
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props">
              <div class="text-weight-bold text-grey-9">{{ props.row.name }}</div>
            </q-td>
          </template>

          <template #body-cell-admin_name="props">
            <q-td :props="props">
              <div v-if="getGroupAdminInfo(props.row.id)" class="column">
                <span class="text-weight-medium text-grey-9">{{ getGroupAdminInfo(props.row.id)?.name || 'Admin' }}</span>
                <span class="text-caption text-grey-6">{{ getGroupAdminInfo(props.row.id)?.email || '-' }}</span>
              </div>
              <span v-else class="text-caption text-grey-5">-</span>
            </q-td>
          </template>

          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-toggle
                :model-value="props.row.is_active"
                color="positive"
                dense
                @update:model-value="toggleGroupActive(props.row, $event)"
              />
            </q-td>
          </template>

          <template #body-cell-manage_members="props">
            <q-td :props="props" class="text-center">
              <q-btn
                flat
                dense
                no-caps
                color="primary"
                icon="ph ph-users"
                label="Manage Members"
                class="rounded-borders"
                @click="goToMembers(props.row.id)"
              />
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="text-right">
              <q-btn flat round dense icon="ph ph-dots-three-vertical">
                <q-menu auto-close>
                  <q-list dense style="min-width: 160px">
                    <q-item clickable @click="openEditDialog(props.row)">
                      <q-item-section avatar class="min-width-auto q-pr-sm">
                        <q-icon name="ph ph-pencil-simple" size="18px" color="grey-7" />
                      </q-item-section>
                      <q-item-section>{{ $t('shop_admin.edit_group') }}</q-item-section>
                    </q-item>
                    <q-separator />
                    <q-item clickable class="text-negative" @click="openDeleteDialog(props.row)">
                      <q-item-section avatar class="min-width-auto q-pr-sm">
                        <q-icon name="ph ph-trash" size="18px" color="negative" />
                      </q-item-section>
                      <q-item-section>{{ $t('shop_admin.delete_group') }}</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <!-- Create / Edit dialog -->
    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="min-width: 400px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">
            {{ form.id ? $t('shop_admin.edit_customer_group') : $t('shop_admin.add_customer_group') }}
          </div>
          <q-space />
          <q-btn icon="ph ph-x" flat round dense v-close-popup />
        </q-card-section>

        <q-form ref="formRef" @submit.prevent="saveGroup">
          <q-card-section class="q-gutter-md">
            <q-input
              v-model="form.name"
              :label="$t('shop_admin.group_name') + ' *'"
              outlined
              dense
              :rules="[val => !!val && !!val.trim() || 'Group Name is required']"
            />
            <div>
              <div class="text-caption text-grey-7 q-mb-xs font-weight-medium">Accent Color *</div>
              <q-input
                v-model="form.accentColor"
                :label="$t('shop_admin.accent_color') + ' *'"
                outlined
                dense
                clearable
                :rules="[val => !!val && !!val.trim() || 'Accent Color is required']"
              >
                <template #prepend>
                  <div
                    class="cursor-pointer rounded-borders shadow-1"
                    :style="{
                      width: '24px',
                      height: '24px',
                      backgroundColor: form.accentColor || '#B45F34',
                      border: '1px solid rgba(0,0,0,0.12)'
                    }"
                  >
                    <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                      <q-color v-model="form.accentColor" no-header-tabs />
                    </q-popup-proxy>
                  </div>
                </template>
                <template #append>
                  <q-icon name="ph ph-palette" class="cursor-pointer">
                    <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                      <q-color v-model="form.accentColor" no-header-tabs />
                    </q-popup-proxy>
                  </q-icon>
                </template>
              </q-input>

              <!-- Quick Preset Swatches -->
              <div class="row items-center q-gutter-xs q-mt-xs">
                <span class="text-caption text-grey-6 q-mr-xs">Quick Set:</span>
                <div
                  v-for="color in presetColors"
                  :key="color"
                  class="cursor-pointer preset-swatch shadow-1"
                  :class="{ 'preset-swatch--active': form.accentColor === color }"
                  :style="{ backgroundColor: color }"
                  @click="form.accentColor = color"
                >
                  <q-tooltip>{{ color }}</q-tooltip>
                </div>
              </div>
            </div>
            <q-input
              v-model="form.adminName"
              label="Admin Name *"
              outlined
              dense
              hint="Name of the group contact / administrator"
              :rules="[val => !!val && !!val.trim() || 'Admin Name is required']"
            />
            <q-input
              v-model="form.adminEmail"
              label="Admin Email *"
              type="email"
              outlined
              dense
              hint="Used for group admin member and billing profile email"
              :rules="[
                val => !!val && !!val.trim() || 'Admin Email is required',
                val => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val.trim()) || 'Please enter a valid email address'
              ]"
            />
            <q-input
              v-model="form.phone"
              label="Phone (Optional)"
              outlined
              dense
              hint="Billing profile contact phone"
            />
            <q-input
              v-model="form.address"
              label="Address (Optional)"
              type="textarea"
              rows="2"
              outlined
              dense
              hint="Billing profile address"
            />
            <div class="row items-center justify-between">
              <div class="text-subtitle2 text-grey-8">{{ $t('shop_admin.status') }}</div>
              <q-toggle
                v-model="form.isActive"
                :label="form.isActive ? $t('shop_admin.active') : $t('shop_admin.inactive')"
                color="positive"
                keep-color
              />
            </div>
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
            <q-btn
              color="primary"
              unelevated
              no-caps
              type="submit"
              :label="$t('shop_admin.save')"
              :loading="groupStore.loading"
              :disable="!isFormValid"
            />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>

    <!-- Delete confirm -->
    <q-dialog v-model="deleteOpen" persistent>
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <q-avatar icon="ph ph-warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-subtitle1 text-weight-bold">{{ $t('shop_admin.delete_group') }}</span>
        </q-card-section>
        <q-card-section class="q-pt-none">
          {{ $t('shop_admin.delete_group_confirm', { name: groupToDelete?.name }) }}
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            no-caps
            :label="$t('shop_admin.delete')"
            :loading="groupStore.loading"
            @click="confirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Link Billing Profile Dialog -->
    <q-dialog v-model="linkProfileDialogOpen" persistent>
      <q-card style="min-width: 400px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-weight-bold">{{ $t('shop_admin.link_billing_profile') }}</div>
          <q-space />
          <q-btn icon="ph ph-x" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-py-md">
          <div class="text-caption text-grey-7 q-mb-md">
            {{ $t('shop_admin.link_billing_hint') }}
            <strong>{{ activeGroupForLink?.name }}</strong>
          </div>
          
          <template v-if="unassociatedProfileOptions.length > 0">
            <q-select
              v-model="profileToLink"
              :options="unassociatedProfileOptions"
              :label="$t('shop_admin.billing_profile')"
              outlined
              dense
              emit-value
              map-options
              class="soft-input"
              :rules="[v => !!v || $t('shop_admin.select_profile_required')]"
            />
          </template>
          
          <template v-else>
            <div class="text-center q-pa-md text-grey-7">
              <div class="q-mb-md">{{ $t('shop_admin.no_profiles_to_link') }}</div>
              <q-btn
                color="primary"
                no-caps
                unelevated
                class="pill-btn"
                icon="ph ph-plus"
                :label="$t('shop_admin.create_billing_profile')"
                @click="goToBillingProfileCreate"
              />
            </div>
          </template>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
          <q-btn
            v-if="unassociatedProfileOptions.length > 0"
            color="primary"
            unelevated
            class="pill-btn"
            no-caps
            :label="$t('shop_admin.link')"
            :loading="updateBillingProfileMutation.isPending.value"
            :disable="!profileToLink"
            @click="submitLinkProfile"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </component>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { CustomerGroup } from 'src/modules/tenant/types';
import { useCustomerGroupsQuery } from 'src/modules/tenant/composables/useCustomerGroupQuery';
import { useCustomerGroupMutations } from 'src/modules/tenant/composables/useCustomerGroupMutations';
import { useBillingProfilesQuery } from 'src/modules/sales_invoice/composables/useBillingProfileQuery';
import { useBillingProfileMutations } from 'src/modules/sales_invoice/composables/useBillingProfileMutations';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

defineProps<{
  isEmbedded?: boolean;
}>();

const authStore = useAuthStore();
const router = useRouter();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

// TanStack Query & Mutations
const { data: groupsData, isLoading: groupsLoading, error: groupsError } = useCustomerGroupsQuery(tenantId);
const { data: billingProfilesData } = useBillingProfilesQuery(tenantId);

const { createGroupMutation, updateGroupMutation, deleteGroupMutation } = useCustomerGroupMutations();
const { updateBillingProfileMutation } = useBillingProfileMutations();

const groups = computed(() => groupsData.value ?? []);
const billingProfiles = computed(() => billingProfilesData.value?.data ?? []);
const isSaving = computed(
  () =>
    createGroupMutation.isPending.value ||
    updateGroupMutation.isPending.value ||
    deleteGroupMutation.isPending.value
);
const errorMessage = computed(
  () => (groupsError.value ? (groupsError.value as Error).message : '')
);

const groupStore = computed(() => ({
  loading: groupsLoading.value || isSaving.value,
  groups: groups.value,
  error: errorMessage.value,
  clearError: () => {},
}));

const store = computed(() => ({
  error: '',
  clearError: () => {},
}));

const formRef = ref<any>(null);
const dialogOpen = ref(false);
const deleteOpen = ref(false);
const groupToDelete = ref<CustomerGroup | null>(null);
const form = reactive({
  id: null as number | null,
  name: '',
  accentColor: '',
  adminName: '',
  adminEmail: '',
  phone: '',
  address: '',
  isActive: true,
});

const isEmailValid = (email: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
const isFormValid = computed(() => {
  return (
    !!form.name.trim() &&
    !!form.accentColor.trim() &&
    !!form.adminName.trim() &&
    !!form.adminEmail.trim() &&
    isEmailValid(form.adminEmail)
  );
});

const { t } = useI18n();

const columns = computed(() => [
  { name: 'accent', label: 'Color', field: 'accent_color', align: 'left' as const },
  { name: 'name', label: t('shop_admin.group_name'), field: 'name', align: 'left' as const, sortable: true },
  { name: 'admin_name', label: 'Admin', field: 'id', align: 'left' as const },
  { name: 'is_active', label: t('shop_admin.active'), field: 'is_active', align: 'center' as const },
  { name: 'manage_members', label: 'Members', field: 'id', align: 'center' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
]);

const getGroupAdminInfo = (groupId: number) => {
  const profile = billingProfiles.value.find(p => p.customer_group_id === groupId);
  if (!profile) return null;
  return {
    name: profile.name,
    email: profile.email,
  };
};

const toggleGroupActive = async (group: any, activeVal: boolean) => {
  try {
    await updateGroupMutation.mutateAsync({
      id: group.id,
      tenant_id: tenantId.value,
      is_active: activeVal,
    });
    showSuccessNotification(`Customer group ${activeVal ? 'activated' : 'deactivated'}`);
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to toggle status');
  }
};

const openCreateDialog = () => {
  form.id = null;
  form.name = '';
  form.accentColor = '';
  form.adminName = '';
  form.adminEmail = '';
  form.phone = '';
  form.address = '';
  form.isActive = true;
  dialogOpen.value = true;
};

const openEditDialog = (group: {
  id: number;
  name: string;
  accent_color?: string | null;
  is_active: boolean;
}) => {
  form.id = group.id;
  form.name = group.name;
  form.accentColor = group.accent_color || '';
  form.isActive = group.is_active;

  const groupProfiles = getBillingProfilesForGroup(group.id);
  const matchedBp = groupProfiles[0];
  form.adminName = matchedBp?.name || '';
  form.adminEmail = matchedBp?.email || '';
  form.phone = matchedBp?.phone || '';
  form.address = matchedBp?.address || '';

  dialogOpen.value = true;
};

const openDeleteDialog = (group: CustomerGroup) => {
  groupToDelete.value = group;
  deleteOpen.value = true;
};

const saveGroup = async () => {
  if (!tenantId.value || !form.name.trim()) return;

  try {
    if (form.id) {
      await updateGroupMutation.mutateAsync({
        id: form.id,
        tenant_id: tenantId.value,
        name: form.name.trim(),
        accent_color: form.accentColor || null,
        is_active: form.isActive,
        admin_name: form.adminName.trim() || null,
        email: form.adminEmail.trim() || null,
        phone: form.phone.trim() || null,
        address: form.address.trim() || null,
      } as any);
      showSuccessNotification('Customer group updated successfully');
    } else {
      await createGroupMutation.mutateAsync({
        tenant_id: tenantId.value,
        name: form.name.trim(),
        accent_color: form.accentColor || null,
        is_active: form.isActive,
        admin_name: form.adminName.trim() || null,
        admin_email: form.adminEmail.trim() || null,
        phone: form.phone.trim() || null,
        address: form.address.trim() || null,
      } as any);
      showSuccessNotification('Customer group created successfully');
    }
    dialogOpen.value = false;
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to save customer group');
  }
};

const confirmDelete = async () => {
  if (!groupToDelete.value) return;
  try {
    await deleteGroupMutation.mutateAsync({
      id: groupToDelete.value.id,
      tenant_id: tenantId.value,
    });
    showSuccessNotification('Customer group deleted successfully');
    deleteOpen.value = false;
    groupToDelete.value = null;
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to delete customer group');
  }
};

const goToMembers = (groupId: number) => {
  void router.push({
    name: 'app-shop-customer-group-members-page',
    params: {
      tenantSlug: tenantSlug.value,
      groupId: String(groupId),
    },
  });
};

const getBillingProfilesForGroup = (groupId: number) => {
  return billingProfiles.value.filter(p => p.customer_group_id === groupId);
};

const linkProfileDialogOpen = ref(false);
const activeGroupForLink = ref<any>(null);
const profileToLink = ref<number | null>(null);

const openLinkProfileDialog = (group: any) => {
  activeGroupForLink.value = group;
  profileToLink.value = null;
  linkProfileDialogOpen.value = true;
};
void openLinkProfileDialog;

const unassociatedProfileOptions = computed(() => {
  if (!activeGroupForLink.value) return [];
  return billingProfiles.value
    .filter((p) => p.customer_group_id !== activeGroupForLink.value.id)
    .map((p) => ({
      label: p.customer_group_id 
        ? `${p.name} (Group #${p.customer_group_id})` 
        : p.name,
      value: p.id,
    }));
});

const submitLinkProfile = async () => {
  if (!profileToLink.value || !activeGroupForLink.value) return;
  const profile = billingProfiles.value.find(p => p.id === profileToLink.value);
  if (!profile) return;
  
  try {
    await updateBillingProfileMutation.mutateAsync({
      id: profile.id,
      tenant_id: tenantId.value,
      patch: {
        name: profile.name,
        customer_group_id: activeGroupForLink.value.id,
        email: profile.email || null,
        phone: profile.phone || null,
        address: profile.address || null,
        color: profile.color || null,
      },
    });
    showSuccessNotification('Billing profile linked successfully');
    linkProfileDialogOpen.value = false;
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to link billing profile');
  }
};

const unlinkProfile = async (profile: any) => {
  try {
    await updateBillingProfileMutation.mutateAsync({
      id: profile.id,
      tenant_id: tenantId.value,
      patch: {
        name: profile.name,
        customer_group_id: null,
        email: profile.email || null,
        phone: profile.phone || null,
        address: profile.address || null,
        color: profile.color || null,
      },
    });
    showSuccessNotification('Billing profile unlinked successfully');
  } catch (err: any) {
    showErrorNotification(err?.message || 'Failed to unlink billing profile');
  }
};
void unlinkProfile;

const presetColors = [
  '#B45F34', // Brand Rust
  '#2563EB', // Primary Blue
  '#059669', // Emerald Green
  '#D97706', // Amber / Orange
  '#7C3AED', // Violet / Purple
  '#DB2777', // Pink
  '#4B5563', // Slate Slate
  '#000000', // Black
];

const goToBillingProfileCreate = () => {
  linkProfileDialogOpen.value = false;
  void router.push({
    name: 'app-global-billing-profiles',
    params: {
      tenantSlug: authStore.tenantSlug || '',
    },
    query: {
      create: 'true',
    },
  });
};
</script>

<style scoped>
.accent-swatch {
  width: 14px;
  height: 14px;
  border-radius: 4px;
}
.preset-swatch {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  border: 2px solid transparent;
  transition: transform 0.15s ease, border-color 0.15s ease;
}
.preset-swatch:hover {
  transform: scale(1.15);
}
.preset-swatch--active {
  border-color: var(--q-primary, #2563eb);
  transform: scale(1.1);
}
</style>
