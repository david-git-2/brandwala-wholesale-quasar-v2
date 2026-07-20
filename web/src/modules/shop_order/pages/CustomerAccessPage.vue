<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
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
            icon="group_add"
            :label="$t('shop_admin.add_customer_group')"
            @click="openCreateDialog"
          />
        </div>
      </section>

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
        <q-card-section v-if="store.loadingGroups" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          {{ $t('shop_admin.loading_customer_groups') }}
        </q-card-section>

        <q-card-section
          v-else-if="store.customerGroups.length === 0"
          class="text-grey-6 text-center q-pa-xl"
        >
          <q-icon name="groups" size="48px" class="q-mb-sm block" />
          {{ $t('shop_admin.no_customer_groups') }}
          <div class="q-mt-md">
            <q-btn
              color="primary"
              outline
              no-caps
              icon="group_add"
              :label="$t('shop_admin.add_customer_group')"
              @click="openCreateDialog"
            />
          </div>
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="store.customerGroups"
          :columns="columns"
          :pagination="{ rowsPerPage: 25 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-accent="props">
            <q-td :props="props">
              <div
                class="accent-swatch"
                :style="{ backgroundColor: props.row.accent_color || '#B45F34' }"
              />
            </q-td>
          </template>

          <template #body-cell-billing_profiles="props">
            <q-td :props="props">
              <div v-if="getBillingProfilesForGroup(props.row.id).length > 0" class="row q-gutter-xs">
                <q-chip
                  v-for="profile in getBillingProfilesForGroup(props.row.id)"
                  :key="profile.id"
                  dense
                  outline
                  color="primary"
                  text-color="primary"
                  removable
                  @remove="unlinkProfile(profile)"
                >
                  {{ profile.name }}
                </q-chip>
              </div>
              <div v-else class="row items-center q-gutter-x-xs text-amber-9 text-caption text-weight-medium bg-amber-1 q-px-sm q-py-xs rounded-borders" style="display: inline-flex; border: 1px dashed #ffb300;">
                <q-icon name="warning" size="14px" />
                <span>{{ $t('shop_admin.none_required_dropship') }}</span>
              </div>
            </q-td>
          </template>

          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-icon
                :name="props.row.is_active ? 'check_circle' : 'cancel'"
                :color="props.row.is_active ? 'positive' : 'grey-5'"
                size="20px"
              />
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props">
              <q-btn
                flat
                round
                dense
                icon="o_edit"
                color="grey-7"
                @click="openEditDialog(props.row)"
              >
                <q-tooltip>{{ $t('shop_admin.edit_group') }}</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="link"
                color="primary"
                @click="openLinkProfileDialog(props.row)"
              >
                <q-tooltip>{{ $t('shop_admin.connect_billing_profile') }}</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="group"
                color="primary"
                @click="goToMembers(props.row.id)"
              >
                <q-tooltip>{{ $t('shop_admin.manage_members') }}</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="o_delete"
                color="negative"
                @click="openDeleteDialog(props.row)"
              >
                <q-tooltip>{{ $t('shop_admin.delete_group') }}</q-tooltip>
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
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="form.name" :label="$t('shop_admin.group_name') + ' *'" outlined dense />
          <q-input
            v-model="form.accentColor"
            :label="$t('shop_admin.accent_color')"
            outlined
            dense
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
            :label="$t('shop_admin.save')"
            :loading="groupStore.loading"
            :disable="!form.name.trim()"
            @click="saveGroup"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Delete confirm -->
    <q-dialog v-model="deleteOpen" persistent>
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
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
          <q-btn icon="close" flat round dense v-close-popup />
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
                icon="add"
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
            :loading="billingProfileStore.saving"
            :disable="!profileToLink"
            @click="submitLinkProfile"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import type { CustomerGroup } from 'src/modules/tenant/types';
import { useShopPermissionsStore } from '../stores/shopPermissionsStore';
import { useBillingProfileStore } from 'src/modules/sales_invoice/stores/billingProfileStore';

const authStore = useAuthStore();
const store = useShopPermissionsStore();
const groupStore = useCustomerGroupStore();
const billingProfileStore = useBillingProfileStore();
const router = useRouter();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const dialogOpen = ref(false);
const deleteOpen = ref(false);
const groupToDelete = ref<CustomerGroup | null>(null);
const form = reactive({
  id: null as number | null,
  name: '',
  accentColor: '',
  isActive: true,
});

const { t } = useI18n();

const columns = computed(() => [
  { name: 'accent', label: '', field: 'accent_color', align: 'left' as const },
  { name: 'name', label: t('shop_admin.group_name'), field: 'name', align: 'left' as const, sortable: true },
  { name: 'billing_profiles', label: t('shop_admin.col_billing_profiles'), field: 'id', align: 'left' as const },
  { name: 'is_active', label: t('shop_admin.active'), field: 'is_active', align: 'center' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
]);

const load = () => {
  if (tenantId.value) {
    void store.fetchCustomerGroups(tenantId.value);
    void billingProfileStore.fetchBillingProfiles({ tenant_id: tenantId.value, page_size: 1000 });
  }
};

const openCreateDialog = () => {
  form.id = null;
  form.name = '';
  form.accentColor = '';
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
  dialogOpen.value = true;
};

const openDeleteDialog = (group: CustomerGroup) => {
  groupToDelete.value = group;
  deleteOpen.value = true;
};

const saveGroup = async () => {
  if (!tenantId.value || !form.name.trim()) return;

  const result = form.id
    ? await groupStore.updateCustomerGroup({
        id: form.id,
        tenant_id: tenantId.value,
        name: form.name.trim(),
        accent_color: form.accentColor || null,
        is_active: form.isActive,
      })
    : await groupStore.createCustomerGroup({
        tenant_id: tenantId.value,
        name: form.name.trim(),
        accent_color: form.accentColor || null,
        is_active: form.isActive,
      });

  if (!result.success) return;
  dialogOpen.value = false;
  load();
};

const confirmDelete = async () => {
  if (!groupToDelete.value) return;
  const result = await groupStore.deleteCustomerGroup({ id: groupToDelete.value.id });
  if (!result.success) return;
  deleteOpen.value = false;
  groupToDelete.value = null;
  load();
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
  return billingProfileStore.items.filter(p => p.customer_group_id === groupId);
};

const linkProfileDialogOpen = ref(false);
const activeGroupForLink = ref<any>(null);
const profileToLink = ref<number | null>(null);

const openLinkProfileDialog = (group: any) => {
  activeGroupForLink.value = group;
  profileToLink.value = null;
  linkProfileDialogOpen.value = true;
};

const unassociatedProfileOptions = computed(() => {
  if (!activeGroupForLink.value) return [];
  return billingProfileStore.items
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
  const profile = billingProfileStore.items.find(p => p.id === profileToLink.value);
  if (!profile) return;
  
  const res = await billingProfileStore.updateBillingProfile({
    id: profile.id,
    tenant_id: profile.tenant_id,
    name: profile.name,
    customer_group_id: activeGroupForLink.value.id,
    email: profile.email || null,
    phone: profile.phone || null,
    address: profile.address || null,
    color: profile.color || null,
  });
  if (res.success) {
    linkProfileDialogOpen.value = false;
    load();
  }
};

const unlinkProfile = async (profile: any) => {
  const res = await billingProfileStore.updateBillingProfile({
    id: profile.id,
    tenant_id: profile.tenant_id,
    name: profile.name,
    customer_group_id: null,
    email: profile.email || null,
    phone: profile.phone || null,
    address: profile.address || null,
    color: profile.color || null,
  });
  if (res.success) {
    load();
  }
};

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

onMounted(load);
watch(tenantId, (v) => {
  if (v) load();
});
</script>

<style scoped>
.accent-swatch {
  width: 14px;
  height: 14px;
  border-radius: 4px;
}
</style>
