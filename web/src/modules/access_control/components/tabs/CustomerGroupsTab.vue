<template>
  <div class="row q-col-gutter-md">
    <!-- Customer Groups List Sidebar -->
    <div class="col-12 col-md-4">
      <q-card flat class="floating-surface shadow-1">
        <q-card-section class="row items-center justify-between">
          <div class="text-subtitle1 text-weight-bold text-grey-9">Customer Groups</div>
          <q-btn
            color="primary"
            dense
            flat
            round
            icon="ph ph-plus"
            @click="emit('create-group')"
          />
        </q-card-section>
        <q-separator />
        <q-card-section v-if="groupsLoading" class="text-grey-7">
          Loading groups...
        </q-card-section>
        <q-card-section v-else class="q-pa-xs">
          <q-list separator>
            <q-item
              v-for="group in sortedCustomerGroups"
              :key="group.id"
              clickable
              v-ripple
              :class="{
                'customer-group-item--active': group.id === selectedGroupId,
              }"
              @click="emit('select-group', group.id)"
            >
              <q-item-section side>
                <span
                  class="customer-group-chip"
                  :style="{ backgroundColor: group.accent_color || '#1976D2' }"
                />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ group.name }}</q-item-label>
                <q-item-label caption>{{ group.is_active ? 'Active' : 'Inactive' }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <div class="row items-center q-gutter-xs">
                  <q-btn
                    flat
                    dense
                    round
                    icon="ph ph-pencil-simple"
                    size="sm"
                    color="grey-7"
                    @click.stop="emit('edit-group', group)"
                  />
                  <q-btn
                    flat
                    dense
                    round
                    icon="ph ph-trash"
                    size="sm"
                    color="negative"
                    @click.stop="emit('delete-group', group)"
                  />
                </div>
              </q-item-section>
            </q-item>
            <q-item v-if="sortedCustomerGroups.length === 0">
              <q-item-section class="text-grey-7 text-center q-py-md">
                No customer groups found.
              </q-item-section>
            </q-item>
          </q-list>
        </q-card-section>
      </q-card>
    </div>

    <!-- Customer Group Details & Members -->
    <div class="col-12 col-md-8">
      <q-card flat class="floating-surface shadow-1">
        <template v-if="selectedGroup">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center q-gutter-xs">
                <span
                  class="customer-group-chip customer-group-chip--large"
                  :style="{ backgroundColor: selectedGroup.accent_color || '#1976D2' }"
                />
                <span>{{ selectedGroup.name }}</span>
              </div>
              <div class="text-caption text-grey-7">
                Manage members and access permissions for this customer group.
              </div>
            </div>
            <div class="row items-center q-gutter-sm">
              <q-btn
                color="primary"
                unelevated
                class="pill-btn"
                no-caps
                icon="ph ph-user-plus"
                label="Add Member"
                @click="emit('create-member')"
              />
            </div>
          </q-card-section>

          <q-separator />

          <!-- Linked Billing Profiles Section -->
          <q-card-section class="bg-grey-1 q-py-sm">
            <div class="row items-center justify-between q-mb-xs">
              <div class="text-subtitle2 text-weight-bold text-grey-8">
                Linked Billing Profiles
              </div>
              <q-btn
                flat
                dense
                no-caps
                size="sm"
                color="primary"
                icon="ph ph-link"
                label="Link Billing Profile"
                @click="emit('open-link-profile')"
              />
            </div>
            <div v-if="linkedBillingProfiles.length === 0" class="text-caption text-grey-6">
              No billing profiles linked to this group.
            </div>
            <div v-else class="row q-gutter-xs">
              <q-chip
                v-for="prof in linkedBillingProfiles"
                :key="prof.id"
                removable
                dense
                color="blue-1"
                text-color="blue-9"
                @remove="emit('unlink-profile', prof)"
              >
                {{ prof.name }}
              </q-chip>
            </div>
          </q-card-section>

          <q-separator />

          <q-card-section v-if="membersLoading" class="text-grey-7">
            Loading group members...
          </q-card-section>

          <q-card-section v-else class="q-pa-none">
            <q-table
              flat
              dense
              :rows="sortedMembers"
              :columns="customerGroupMemberColumns"
              row-key="id"
              :pagination="{ rowsPerPage: 50 }"
            >
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
                      shopRoles.length > 0
                        ? shopRoles.map((r: any) => ({ label: r.name, value: r.id }))
                        : [
                            { label: 'Customer Staff', value: 'staff' },
                            { label: 'Customer Manager', value: 'manager' },
                            { label: 'Customer Admin', value: 'admin' },
                          ]
                    "
                    @update:model-value="(val) => emit('change-member-role', props.row, val)"
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
                    :color="hasCgmOverridesMap[props.row.id] ? 'warning' : 'primary'"
                    :icon="hasCgmOverridesMap[props.row.id] ? 'ph ph-sliders' : 'ph ph-sliders-horizontal'"
                    :label="hasCgmOverridesMap[props.row.id] ? 'Has Overrides' : 'Configure'"
                    @click="emit('open-overrides', props.row, 'shop')"
                  />
                </q-td>
              </template>

              <template #body-cell-active="props">
                <q-td :props="props" align="center">
                  <q-toggle
                    :model-value="props.row.is_active"
                    color="positive"
                    dense
                    @update:model-value="(val) => emit('toggle-member-active', props.row, val)"
                  />
                </q-td>
              </template>

              <template #body-cell-edit="props">
                <q-td :props="props" align="center">
                  <div class="row items-center justify-center q-gutter-xs">
                    <q-btn
                      flat
                      dense
                      round
                      icon="ph ph-pencil-simple"
                      color="grey-7"
                      @click="emit('edit-member', props.row)"
                    />
                    <q-btn
                      flat
                      dense
                      round
                      icon="ph ph-trash"
                      color="negative"
                      @click="emit('delete-member', props.row)"
                    />
                  </div>
                </q-td>
              </template>
            </q-table>
          </q-card-section>
        </template>

        <div v-else class="text-grey-7 text-center q-pa-xl">
          Select a customer group to view details.
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { CustomerGroup, CustomerGroupMember } from 'src/modules/tenant/types';

interface Props {
  groupsLoading: boolean;
  membersLoading: boolean;
  sortedCustomerGroups: CustomerGroup[];
  selectedGroupId: number | null;
  selectedGroup: CustomerGroup | null;
  sortedMembers: CustomerGroupMember[];
  linkedBillingProfiles: any[];
  shopRoles: Array<{ id: number; name: string }>;
  hasCgmOverridesMap: Record<number, boolean>;
}

defineProps<Props>();

const emit = defineEmits<{
  (e: 'create-group'): void;
  (e: 'edit-group', group: CustomerGroup): void;
  (e: 'delete-group', group: CustomerGroup): void;
  (e: 'select-group', groupId: number): void;
  (e: 'create-member'): void;
  (e: 'edit-member', member: CustomerGroupMember): void;
  (e: 'delete-member', member: CustomerGroupMember): void;
  (e: 'change-member-role', member: CustomerGroupMember, roleId: number): void;
  (e: 'toggle-member-active', member: CustomerGroupMember, val: boolean): void;
  (e: 'open-link-profile'): void;
  (e: 'unlink-profile', profile: any): void;
  (e: 'open-overrides', member: CustomerGroupMember, scope: 'shop'): void;
}>();

const customerGroupMemberColumns = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const },
  { name: 'role', label: 'Role Template', field: 'role', align: 'left' as const },
  { name: 'overrides', label: 'Custom Overrides', field: 'id', align: 'center' as const },
  { name: 'active', label: 'Status', field: 'is_active', align: 'center' as const },
  { name: 'edit', label: 'Actions', field: 'id', align: 'center' as const },
];
</script>

<style scoped>
.pill-btn {
  border-radius: 8px;
}

.customer-group-chip {
  width: 16px;
  height: 16px;
  border-radius: 4px;
}

.customer-group-chip--large {
  width: 24px;
  height: 24px;
}

.customer-group-item--active {
  background-color: rgba(34, 56, 101, 0.05);
  border-left: 4px solid var(--q-primary);
}

.soft-input {
  border-radius: 8px;
}
</style>
