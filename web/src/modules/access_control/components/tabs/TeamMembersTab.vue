<template>
  <q-card flat class="floating-surface shadow-1">
    <q-card-section class="row items-center justify-between">
      <div>
        <div class="text-subtitle1 text-weight-bold text-grey-9">Workspace Team</div>
        <div class="text-caption text-grey-7">
          Manage team memberships and explicit user permission overrides.
        </div>
      </div>
      <div class="row items-center q-gutter-sm">
        <q-btn
          color="primary"
          unelevated
          class="pill-btn"
          no-caps
          icon="ph ph-plus"
          label="Add Member"
          @click="emit('add-member', 'staff')"
        />
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section v-if="isLoading" class="text-grey-7">
      Loading workspace team...
    </q-card-section>

    <q-card-section v-else class="q-pa-none">
      <q-table
        flat
        dense
        :rows="tenantMembers"
        :columns="internalMemberColumns"
        row-key="id"
        :pagination="{ rowsPerPage: 50 }"
      >
        <template #body-cell-email="props">
          <q-td :props="props">
            <div class="text-weight-medium">{{ props.row.email }}</div>
            <div v-if="props.row.investor_id" class="text-caption text-grey-6">
              Linked Investor: {{ investorNameById(props.row.investor_id) }}
            </div>
          </q-td>
        </template>

        <template #body-cell-role="props">
          <q-td :props="props">
            <q-select
              :model-value="props.row.tenant_role_id || props.row.role"
              dense
              outlined
              options-dense
              emit-value
              map-options
              style="min-width: 140px"
              class="soft-input"
              :options="
                appRoles.length > 0
                  ? appRoles.map((r: any) => ({ label: r.name, value: r.id }))
                  : memberRoleOptions
              "
              @update:model-value="(val) => emit('change-role', props.row, val)"
            />
          </q-td>
        </template>

        <template #body-cell-overrides="props">
          <q-td :props="props" align="center">
            <q-btn
              dense
              flat
              no-caps
              size="sm"
              :color="hasOverridesMap[props.row.id] ? 'warning' : 'primary'"
              :icon="hasOverridesMap[props.row.id] ? 'ph ph-sliders' : 'ph ph-sliders-horizontal'"
              :label="hasOverridesMap[props.row.id] ? 'Has Overrides' : 'Configure'"
              @click="emit('open-overrides', props.row, 'app')"
            />
          </q-td>
        </template>

        <template #body-cell-active="props">
          <q-td :props="props" align="center">
            <q-toggle
              :model-value="props.row.is_active"
              color="positive"
              dense
              @update:model-value="(val) => emit('toggle-active', props.row, val)"
            />
          </q-td>
        </template>

        <template #body-cell-delete="props">
          <q-td :props="props" align="center">
            <q-btn
              flat
              dense
              round
              icon="ph ph-trash"
              color="negative"
              :disable="props.row.role === 'admin'"
              @click="emit('delete-member', props.row)"
            />
          </q-td>
        </template>
      </q-table>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import type { Membership, TenantMembershipRole } from 'src/modules/membership/types';

interface Props {
  isLoading: boolean;
  tenantMembers: Membership[];
  appRoles: Array<{ id: number; name: string }>;
  hasOverridesMap: Record<number, boolean>;
  investorNameById: (id: number) => string;
}

defineProps<Props>();

const emit = defineEmits<{
  (e: 'add-member', roleType: TenantMembershipRole): void;
  (e: 'change-role', member: Membership, roleId: number): void;
  (e: 'toggle-active', member: Membership, val: boolean): void;
  (e: 'delete-member', member: Membership): void;
  (e: 'open-overrides', member: Membership, scope: 'app'): void;
}>();

const memberRoleOptions = [
  { label: 'Admin', value: 'admin' },
  { label: 'Staff', value: 'staff' },
  { label: 'Viewer', value: 'viewer' },
  { label: 'Investor', value: 'investor' },
];

const internalMemberColumns = [
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const },
  { name: 'role', label: 'Role Template', field: 'role', align: 'left' as const },
  { name: 'overrides', label: 'Custom Overrides', field: 'id', align: 'center' as const },
  { name: 'active', label: 'Status', field: 'is_active', align: 'center' as const },
  { name: 'delete', label: 'Actions', field: 'id', align: 'center' as const },
];
</script>

<style scoped>
.pill-btn {
  border-radius: 8px;
}

.soft-input {
  border-radius: 8px;
}
</style>
