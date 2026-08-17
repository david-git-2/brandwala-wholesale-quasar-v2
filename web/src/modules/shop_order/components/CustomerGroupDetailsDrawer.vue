<template>
  <q-dialog :model-value="modelValue" position="right" @update:model-value="$emit('update:modelValue', $event)">
    <q-card class="group-details-panel column no-wrap">
      <q-card-section class="row items-center q-pb-sm">
        <div
          class="accent-swatch q-mr-sm"
          :style="{ backgroundColor: group?.accent_color || 'var(--bw-theme-primary)' }"
        />
        <div class="col">
          <div class="text-overline text-primary">{{ $t('shop_admin.access_group_details') }}</div>
          <div class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
            {{ group?.name }}
          </div>
        </div>
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          :aria-label="$t('shop_admin.cancel')"
          @click="$emit('update:modelValue', false)"
        />
      </q-card-section>

      <q-separator />

      <div class="col scroll q-pa-md q-gutter-y-md">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-caption text-grey-7 text-weight-bold q-mb-sm">
              {{ $t('shop_admin.access_group_admin') }}
            </div>
            <template v-if="billingProfile">
              <div class="text-weight-medium text-grey-9">{{ billingProfile.name }}</div>
              <div class="text-caption text-grey-7">{{ billingProfile.email || '—' }}</div>
              <div v-if="billingProfile.phone" class="text-caption text-grey-7">
                {{ billingProfile.phone }}
              </div>
            </template>
            <div v-else class="text-caption text-grey-6">
              {{ $t('shop_admin.access_group_no_admin') }}
            </div>
          </q-card-section>
        </q-card>

        <div class="row items-center justify-between">
          <div class="text-subtitle2 text-weight-bold text-grey-9">
            {{ $t('shop_admin.members') }}
          </div>
          <q-btn
            unelevated
            no-caps
            dense
            color="primary"
            icon="ph ph-user-plus"
            :label="$t('shop_admin.add_member')"
            data-test="access-add-member-btn"
            @click="openCreateDialog"
          />
        </div>

        <div v-if="loading" class="q-gutter-y-sm">
          <q-skeleton v-for="n in 3" :key="n" type="rect" height="56px" class="rounded-borders" />
        </div>

        <div v-else-if="sortedMembers.length === 0" class="column items-center text-center q-pa-lg text-grey-6">
          <q-icon name="ph ph-users" size="32px" color="grey-5" class="q-mb-sm" />
          <div>{{ $t('shop_admin.no_members') }}</div>
        </div>

        <q-list v-else bordered separator class="rounded-borders">
          <q-item v-for="member in sortedMembers" :key="member.id" class="q-py-sm">
            <q-item-section>
              <q-item-label class="text-weight-medium text-grey-9">
                {{ member.name || member.email }}
              </q-item-label>
              <q-item-label v-if="member.name" caption>{{ member.email }}</q-item-label>
              <q-select
                :model-value="member.tenant_role_id"
                :options="shopRoleOptions"
                emit-value
                map-options
                outlined
                dense
                options-dense
                class="q-mt-xs"
                :loading="roleSavingId === member.id"
                :label="$t('shop_admin.shop_role_col')"
                @update:model-value="(val) => onChangeRole(member, val)"
              />
            </q-item-section>
            <q-item-section side>
              <div class="column items-end q-gutter-y-xs">
                <q-toggle
                  :model-value="member.is_active"
                  dense
                  color="positive"
                  @update:model-value="(val) => onToggleActive(member, val)"
                />
                <div class="row no-wrap">
                  <q-btn
                    flat
                    round
                    dense
                    size="sm"
                    icon="ph ph-pencil-simple"
                    color="grey-7"
                    :aria-label="$t('shop_admin.edit_member_tooltip')"
                    @click="openEditDialog(member)"
                  />
                  <q-btn
                    flat
                    round
                    dense
                    size="sm"
                    icon="ph ph-trash"
                    color="negative"
                    :aria-label="$t('shop_admin.delete_member_tooltip')"
                    @click="openDeleteDialog(member)"
                  />
                </div>
              </div>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </q-card>
  </q-dialog>

  <q-dialog v-model="memberDialogOpen" persistent>
      <q-card style="min-width: 360px; max-width: 92vw">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">
            {{ form.id ? $t('shop_admin.edit_member') : $t('shop_admin.add_member') }}
          </div>
          <q-space />
          <q-btn icon="ph ph-x" flat round dense v-close-popup />
        </q-card-section>
        <q-card-section class="q-gutter-md">
          <q-input
            v-model="form.email"
            :label="$t('shop_admin.email') + ' *'"
            type="email"
            outlined
            dense
            :disable="!!form.id"
          />
          <q-input v-model="form.name" :label="$t('shop_admin.name_optional')" outlined dense />
          <q-select
            v-if="!form.id"
            v-model="form.tenantRoleId"
            :options="shopRoleOptions"
            :label="$t('shop_admin.shop_role')"
            outlined
            dense
            emit-value
            map-options
            clearable
          />
          <div class="row items-center justify-between">
            <div class="text-subtitle2 text-grey-8">{{ $t('shop_admin.active') }}</div>
            <q-toggle v-model="form.isActive" color="positive" keep-color />
          </div>
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            no-caps
            :label="$t('shop_admin.save')"
            :loading="saving"
            :disable="!form.email.trim()"
            @click="saveMember"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="deleteOpen" persistent>
      <q-card style="min-width: 320px">
        <q-card-section class="text-subtitle1 text-weight-bold">
          {{ $t('shop_admin.delete_member') }}
        </q-card-section>
        <q-card-section class="q-pt-none">
          {{ $t('shop_admin.delete_member_confirm', { email: memberToDelete?.email }) }}
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps :label="$t('shop_admin.cancel')" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            no-caps
            :label="$t('shop_admin.delete')"
            :loading="saving"
            @click="confirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import type { CustomerGroupMember } from 'src/modules/tenant/types';

interface ShopRole {
  id: number;
  name: string;
}

const props = defineProps<{
  modelValue: boolean;
  group: { id: number; name: string; accent_color: string | null } | null;
  billingProfile: { name: string; email: string | null; phone: string | null } | null;
}>();

defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const authStore = useAuthStore();
const groupStore = useCustomerGroupStore();

const tenantId = computed(() => authStore.tenantId as number);
const groupId = computed(() => props.group?.id ?? 0);

const members = ref<CustomerGroupMember[]>([]);
const shopRoles = ref<ShopRole[]>([]);
const loading = ref(false);
const saving = ref(false);
const roleSavingId = ref<number | null>(null);
const memberDialogOpen = ref(false);
const deleteOpen = ref(false);
const memberToDelete = ref<CustomerGroupMember | null>(null);

const form = reactive({
  id: null as number | null,
  email: '',
  name: '',
  isActive: true,
  tenantRoleId: null as number | null,
});

const sortedMembers = computed(() =>
  [...members.value].sort((a, b) => (a.name || a.email).localeCompare(b.name || b.email)),
);

const shopRoleOptions = computed(() => shopRoles.value.map((r) => ({ label: r.name, value: r.id })));

const loadMembers = async () => {
  if (!groupId.value) return;
  loading.value = true;
  try {
    const result = await groupStore.fetchCustomerGroupMembersByGroup(groupId.value);
    members.value = result.success ? (result.data ?? groupStore.members) : [];
  } finally {
    loading.value = false;
  }
};

const loadShopRoles = async () => {
  if (!tenantId.value) return;
  const { data } = await supabase.rpc('list_tenant_roles', {
    p_tenant_id: tenantId.value,
    p_scope: 'shop',
  });
  shopRoles.value = (data as ShopRole[] | null) ?? [];
};

const load = async () => {
  await Promise.all([loadMembers(), loadShopRoles()]);
};

watch(
  () => [props.modelValue, groupId.value] as const,
  ([open, id]) => {
    if (open && id) void load();
  },
);

const openCreateDialog = () => {
  form.id = null;
  form.email = '';
  form.name = '';
  form.isActive = true;
  form.tenantRoleId = shopRoles.value[0]?.id ?? null;
  memberDialogOpen.value = true;
};

const openEditDialog = (member: CustomerGroupMember) => {
  form.id = member.id;
  form.email = member.email;
  form.name = member.name || '';
  form.isActive = member.is_active;
  form.tenantRoleId = member.tenant_role_id;
  memberDialogOpen.value = true;
};

const openDeleteDialog = (member: CustomerGroupMember) => {
  memberToDelete.value = member;
  deleteOpen.value = true;
};

const saveMember = async () => {
  if (!groupId.value || !form.email.trim()) return;
  saving.value = true;
  try {
    if (form.id) {
      const result = await groupStore.updateCustomerGroupMember({
        id: form.id,
        customer_group_id: groupId.value,
        name: form.name,
        email: form.email.trim(),
        is_active: form.isActive,
      });
      if (!result.success) return;
    } else {
      const result = await groupStore.createCustomerGroupMember({
        customer_group_id: groupId.value,
        name: form.name,
        email: form.email.trim(),
        is_active: form.isActive,
        role: 'staff',
        tenant_role_id: form.tenantRoleId,
      });
      if (!result.success) return;
    }
    memberDialogOpen.value = false;
    await loadMembers();
  } finally {
    saving.value = false;
  }
};

const onChangeRole = async (member: CustomerGroupMember, roleId: number | null) => {
  if (roleId == null) return;
  roleSavingId.value = member.id;
  try {
    const { error } = await supabase.rpc('assign_customer_group_member_role', {
      p_cgm_id: member.id,
      p_tenant_role_id: roleId,
    });
    if (!error) await loadMembers();
  } finally {
    roleSavingId.value = null;
  }
};

const onToggleActive = async (member: CustomerGroupMember, isActive: boolean) => {
  const result = await groupStore.updateCustomerGroupMember({
    id: member.id,
    customer_group_id: groupId.value,
    is_active: isActive,
  });
  if (result.success) await loadMembers();
};

const confirmDelete = async () => {
  if (!memberToDelete.value) return;
  saving.value = true;
  try {
    const result = await groupStore.deleteCustomerGroupMember({ id: memberToDelete.value.id });
    if (!result.success) return;
    deleteOpen.value = false;
    memberToDelete.value = null;
    await loadMembers();
  } finally {
    saving.value = false;
  }
};
</script>

<style scoped>
.group-details-panel {
  width: 420px;
  max-width: 100vw;
  height: 100vh;
  border-radius: 0;
}

.accent-swatch {
  width: 14px;
  height: 14px;
  border-radius: 4px;
  flex-shrink: 0;
}
</style>
