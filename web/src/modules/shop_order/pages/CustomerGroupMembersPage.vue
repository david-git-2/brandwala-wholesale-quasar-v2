<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center q-col-gutter-md">
        <div class="col-auto">
          <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
        </div>
        <div class="col">
          <div class="text-overline">Customer Groups</div>
          <h1 class="text-h5 q-my-none">{{ groupName || 'Members' }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Add members and assign shop roles for this customer group.
          </p>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="person_add"
            label="Add Member"
            @click="openCreateDialog"
          />
        </div>
      </section>

      <q-banner v-if="error" class="text-white bg-negative" rounded>
        {{ error }}
        <template #action>
          <q-btn flat color="white" label="Dismiss" @click="error = null" />
        </template>
      </q-banner>

      <q-card flat bordered>
        <q-card-section v-if="loading" class="text-grey-7 text-center q-pa-xl">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          Loading members…
        </q-card-section>

        <q-card-section v-else-if="members.length === 0" class="text-grey-6 text-center q-pa-xl">
          <q-icon name="person_off" size="48px" class="q-mb-sm block" />
          No members in this group yet.
          <div class="q-mt-md">
            <q-btn
              color="primary"
              outline
              no-caps
              icon="person_add"
              label="Add Member"
              @click="openCreateDialog"
            />
          </div>
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="sortedMembers"
          :columns="columns"
          :pagination="{ rowsPerPage: 25 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-role="props">
            <q-td :props="props">
              <q-select
                :model-value="props.row.tenant_role_id"
                :options="shopRoleOptions"
                emit-value
                map-options
                outlined
                dense
                options-dense
                style="min-width: 160px"
                :loading="roleSavingId === props.row.id"
                @update:model-value="(val) => onChangeRole(props.row, val)"
              />
            </q-td>
          </template>

          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-toggle
                :model-value="props.row.is_active"
                color="positive"
                dense
                @update:model-value="(val) => onToggleActive(props.row, val)"
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
                <q-tooltip>Edit member</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="o_delete"
                color="negative"
                @click="openDeleteDialog(props.row)"
              >
                <q-tooltip>Delete member</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <q-dialog v-model="dialogOpen" persistent>
      <q-card style="min-width: 400px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">{{ form.id ? 'Edit Member' : 'Add Member' }}</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="form.email"
            label="Email *"
            type="email"
            outlined
            dense
            :disable="!!form.id"
          />
          <q-input v-model="form.name" label="Name (optional)" outlined dense />
          <q-select
            v-if="!form.id"
            v-model="form.tenantRoleId"
            :options="shopRoleOptions"
            label="Shop role"
            outlined
            dense
            emit-value
            map-options
            clearable
          />
          <div class="row items-center justify-between">
            <div class="text-subtitle2 text-grey-8">Status</div>
            <q-toggle
              v-model="form.isActive"
              :label="form.isActive ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Save"
            :loading="saving"
            :disable="!form.email.trim()"
            @click="saveMember"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteOpen" persistent>
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-subtitle1 text-weight-bold">Delete Member</span>
        </q-card-section>
        <q-card-section class="q-pt-none">
          Remove <strong>{{ memberToDelete?.email }}</strong> from this group?
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            no-caps
            label="Delete"
            :loading="saving"
            @click="confirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import type { CustomerGroupMember } from 'src/modules/tenant/types';

interface ShopRole {
  id: number;
  name: string;
  scope: string;
}

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const groupStore = useCustomerGroupStore();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');
const groupId = computed(() => Number(route.params.groupId));

const groupName = ref('');
const members = ref<CustomerGroupMember[]>([]);
const shopRoles = ref<ShopRole[]>([]);
const loading = ref(false);
const saving = ref(false);
const roleSavingId = ref<number | null>(null);
const error = ref<string | null>(null);

const dialogOpen = ref(false);
const deleteOpen = ref(false);
const memberToDelete = ref<CustomerGroupMember | null>(null);
const form = reactive({
  id: null as number | null,
  email: '',
  name: '',
  isActive: true,
  tenantRoleId: null as number | null,
});

const columns = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const, sortable: true },
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const, sortable: true },
  { name: 'role', label: 'Shop Role', field: 'tenant_role_id', align: 'left' as const },
  { name: 'is_active', label: 'Active', field: 'is_active', align: 'center' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
];

const sortedMembers = computed(() =>
  [...members.value].sort((a, b) => (a.name || a.email).localeCompare(b.name || b.email)),
);

const shopRoleOptions = computed(() =>
  shopRoles.value.map((r) => ({ label: r.name, value: r.id })),
);

const loadGroup = async () => {
  if (!tenantId.value) return;
  await groupStore.fetchCustomerGroupsByTenant(tenantId.value);
  const group = groupStore.groups.find((g) => g.id === groupId.value);
  groupName.value = group?.name ?? `Group #${groupId.value}`;
};

const loadMembers = async () => {
  if (!groupId.value) return;
  loading.value = true;
  error.value = null;
  try {
    const result = await groupStore.fetchCustomerGroupMembersByGroup(groupId.value);
    if (!result.success) {
      error.value = result.error ?? 'Failed to load members.';
      members.value = [];
      return;
    }
    members.value = result.data ?? groupStore.members;
  } finally {
    loading.value = false;
  }
};

const loadShopRoles = async () => {
  if (!tenantId.value) return;
  const { data, error: rpcError } = await supabase.rpc('list_tenant_roles', {
    p_tenant_id: tenantId.value,
    p_scope: 'shop',
  });
  if (rpcError) {
    error.value = rpcError.message;
    return;
  }
  shopRoles.value = (data as ShopRole[] | null) ?? [];
};

const openCreateDialog = () => {
  form.id = null;
  form.email = '';
  form.name = '';
  form.isActive = true;
  form.tenantRoleId = shopRoles.value[0]?.id ?? null;
  dialogOpen.value = true;
};

const openEditDialog = (member: CustomerGroupMember) => {
  form.id = member.id;
  form.email = member.email;
  form.name = member.name || '';
  form.isActive = member.is_active;
  form.tenantRoleId = member.tenant_role_id;
  dialogOpen.value = true;
};

const openDeleteDialog = (member: CustomerGroupMember) => {
  memberToDelete.value = member;
  deleteOpen.value = true;
};

const saveMember = async () => {
  if (!groupId.value || !form.email.trim()) return;
  saving.value = true;
  error.value = null;
  try {
    if (form.id) {
      const result = await groupStore.updateCustomerGroupMember({
        id: form.id,
        customer_group_id: groupId.value,
        name: form.name,
        email: form.email.trim(),
        is_active: form.isActive,
      });
      if (!result.success) {
        error.value = result.error ?? 'Failed to update member.';
        return;
      }
    } else {
      const result = await groupStore.createCustomerGroupMember({
        customer_group_id: groupId.value,
        name: form.name,
        email: form.email.trim(),
        is_active: form.isActive,
        role: 'staff',
        tenant_role_id: form.tenantRoleId,
      });
      if (!result.success) {
        error.value = result.error ?? 'Failed to create member.';
        return;
      }
    }
    dialogOpen.value = false;
    await loadMembers();
  } finally {
    saving.value = false;
  }
};

const onChangeRole = async (member: CustomerGroupMember, roleId: number | null) => {
  if (roleId == null) return;
  roleSavingId.value = member.id;
  error.value = null;
  try {
    const { error: rpcError } = await supabase.rpc('assign_customer_group_member_role', {
      p_cgm_id: member.id,
      p_tenant_role_id: roleId,
    });
    if (rpcError) {
      error.value = rpcError.message;
      return;
    }
    await loadMembers();
  } finally {
    roleSavingId.value = null;
  }
};

const onToggleActive = async (member: CustomerGroupMember, isActive: boolean) => {
  error.value = null;
  const result = await groupStore.updateCustomerGroupMember({
    id: member.id,
    customer_group_id: groupId.value,
    is_active: isActive,
  });
  if (!result.success) {
    error.value = result.error ?? 'Failed to update status.';
    return;
  }
  await loadMembers();
};

const confirmDelete = async () => {
  if (!memberToDelete.value) return;
  saving.value = true;
  error.value = null;
  try {
    const result = await groupStore.deleteCustomerGroupMember({ id: memberToDelete.value.id });
    if (!result.success) {
      error.value = result.error ?? 'Failed to delete member.';
      return;
    }
    deleteOpen.value = false;
    memberToDelete.value = null;
    await loadMembers();
  } finally {
    saving.value = false;
  }
};

const goBack = () => {
  void router.push({
    name: 'app-shop-customer-groups-page',
    params: { tenantSlug: tenantSlug.value },
  });
};

const load = async () => {
  await Promise.all([loadGroup(), loadMembers(), loadShopRoles()]);
};

onMounted(load);
watch(groupId, (id) => {
  if (id) void load();
});
</script>
