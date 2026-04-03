<template>
  <q-page class="q-pa-sm">
    <div class="q-mb-md row items-center justify-between">
      <div class="row items-center q-gutter-sm">
        <q-btn flat round icon="arrow_back" @click="goBack" />
        <div>
          <div class="text-h5 text-weight-bold">Tenant Details</div>
          <div v-if="tenant" class="text-grey-7">
            {{ tenant.name }} · {{ tenant.slug }}
          </div>
        </div>
      </div>
    </div>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <div v-if="pageLoading" class="text-grey-7">Loading tenant details...</div>

    <div v-else-if="!tenant" class="text-grey-7">Tenant not found.</div>

    <div v-else class="row q-col-gutter-lg">
      <div class="col-12 col-lg-4">
        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-start justify-between">
            <div>
              <div class="text-h6">{{ tenant.name }}</div>
              <div class="text-caption text-grey-7">{{ tenant.slug }}</div>
            </div>

            <q-badge :color="tenant.is_active ? 'positive' : 'grey-6'">
              {{ tenant.is_active ? 'Active' : 'Inactive' }}
            </q-badge>
          </q-card-section>

          <q-separator />

          <q-card-section class="q-gutter-md">
            <div><strong>ID:</strong> #{{ tenant.id }}</div>
            <div><strong>Name:</strong> {{ tenant.name }}</div>
            <div><strong>Slug:</strong> {{ tenant.slug }}</div>
            <div>
              <strong>Status:</strong>
              {{ tenant.is_active ? 'Active' : 'Inactive' }}
            </div>
          </q-card-section>
        </q-card>

        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-h6">Customer Groups</div>
              <div class="text-caption text-grey-7">
                Organize customer-side access by company or buying team.
              </div>
            </div>

            <q-btn color="primary" icon="groups" label="Add Group" @click="openCreateGroupDialog" />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="customerGroupsLoading" class="text-grey-7">
            Loading customer groups...
          </q-card-section>

          <q-card-section v-else-if="customerGroups.length === 0" class="text-grey-7">
            No customer groups found.
          </q-card-section>

          <q-list v-else separator>
            <q-item
              v-for="group in sortedCustomerGroups"
              :key="group.id"
              clickable
              :active="selectedCustomerGroupId === group.id"
              active-class="customer-group-item--active"
              class="customer-group-item"
              @click="selectCustomerGroup(group.id)"
            >
              <q-item-section avatar>
                <div
                  class="customer-group-chip"
                  :style="{ backgroundColor: group.accent_color || '#B45F34' }"
                />
              </q-item-section>

              <q-item-section>
                <q-item-label class="row items-center q-gutter-sm">
                  <span>{{ group.name }}</span>
                  <q-badge
                    v-if="selectedCustomerGroupId === group.id"
                    color="primary"
                    outline
                    label="Selected"
                  />
                </q-item-label>
                <q-item-label caption>
                  #{{ group.id }} · {{ group.is_active ? 'Active' : 'Inactive' }}
                </q-item-label>
              </q-item-section>

              <q-item-section side>
                <div class="row items-center q-gutter-xs">
                  <q-btn flat round dense icon="edit" @click.stop="openEditGroupDialog(group)" />
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="delete"
                    @click.stop="openDeleteGroupDialog(group)"
                  />
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="col-12 col-lg-8">
        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-h6">Internal Members</div>
              <div class="text-caption text-grey-7">
                Customer-side users now belong to customer groups, not tenant memberships.
              </div>
            </div>

            <q-btn color="primary" icon="person_add" label="Add Staff" @click="onClickAddMember('staff')" />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="tenantMembersLoading" class="text-grey-7">
            Loading members...
          </q-card-section>

          <q-card-section v-else-if="tenantMembers.length === 0" class="text-grey-7">
            No members found.
          </q-card-section>

          <q-card-section v-else>
            <q-table
              v-if="staffMembers.length"
              flat
              bordered
              row-key="id"
              :rows="staffMembers"
              :columns="internalMemberColumns"
              :dense="$q.screen.lt.md"
              hide-bottom
              class="tenant-detail-card__table"
            >
              <template #body-cell-email="props">
                <q-td :props="props">{{ props.row.email }}</q-td>
              </template>

              <template #body-cell-role="props">
                <q-td :props="props">{{ props.row.role }}</q-td>
              </template>

              <template #body-cell-active="props">
                <q-td :props="props">
                  <q-toggle
                    v-model="props.row.is_active"
                    color="positive"
                    keep-color
                    @update:model-value="(value) => onToggleMemberActive(props.row, value)"
                  />
                </q-td>
              </template>

              <template #body-cell-delete="props">
                <q-td :props="props">
                  <q-btn
                    size="sm"
                    color="negative"
                    flat
                    round
                    icon="delete"
                    @click="onClickDeleteMember(props.row)"
                  />
                </q-td>
              </template>
            </q-table>
            <div v-else class="text-grey-6">No staff found.</div>
          </q-card-section>
        </q-card>

        <q-card flat bordered class="q-mb-lg">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-h6">Customer Group Members</div>
              <div class="text-caption text-grey-7">
                Add customer admins, negotiators, and staff inside the selected group.
              </div>
            </div>

            <q-btn
              color="primary"
              icon="person_add"
              label="Add Customer User"
              :disable="!selectedCustomerGroup"
              @click="openCreateCustomerMemberDialog"
            />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="!selectedCustomerGroup" class="text-grey-7">
            Select a customer group to manage its members.
          </q-card-section>

          <template v-else>
            <q-card-section class="row items-center justify-between">
              <div class="row items-center q-gutter-sm">
                <div
                  class="customer-group-chip customer-group-chip--large"
                  :style="{ backgroundColor: selectedCustomerGroup.accent_color || '#B45F34' }"
                />
                <div>
                  <div class="text-subtitle1 text-weight-bold">
                    {{ selectedCustomerGroup.name }}
                  </div>
                  <div class="text-caption text-grey-7">
                    Accent: {{ selectedCustomerGroup.accent_color || 'Not set' }}
                  </div>
                </div>
              </div>

              <q-toggle
                :model-value="selectedCustomerGroup.is_active"
                :label="selectedCustomerGroup.is_active ? 'Active' : 'Inactive'"
                color="positive"
                keep-color
                @update:model-value="onToggleSelectedCustomerGroupActive"
              />
            </q-card-section>

            <q-card-section v-if="customerGroupMembersLoading" class="text-grey-7">
              Loading customer group members...
            </q-card-section>

            <q-card-section
              v-else-if="customerGroupMembers.length === 0"
              class="text-grey-7"
            >
              No members found for this customer group.
            </q-card-section>

            <q-table
              v-else
              flat
              bordered
              row-key="id"
              :rows="sortedCustomerGroupMembers"
              :columns="customerGroupMemberColumns"
              :dense="$q.screen.lt.md"
              hide-bottom
              class="tenant-detail-card__table"
            >
              <template #body-cell-name="props">
                <q-td :props="props">{{ props.row.name }}</q-td>
              </template>

              <template #body-cell-email="props">
                <q-td :props="props">{{ props.row.email }}</q-td>
              </template>

              <template #body-cell-role="props">
                <q-td :props="props">{{ formatCustomerRole(props.row.role) }}</q-td>
              </template>

              <template #body-cell-active="props">
                <q-td :props="props">
                  <q-toggle
                    :model-value="props.row.is_active"
                    color="positive"
                    keep-color
                    @update:model-value="(value) => onToggleCustomerGroupMemberActive(props.row, value)"
                  />
                </q-td>
              </template>

              <template #body-cell-edit="props">
                <q-td :props="props">
                  <q-btn
                    flat
                    round
                    dense
                    icon="edit"
                    @click="openEditCustomerMemberDialog(props.row)"
                  />
                </q-td>
              </template>
            </q-table>
          </template>
        </q-card>

        <q-card flat bordered class="q-mb-lg tenant-detail-card">
          <q-card-section class="row items-center justify-between tenant-detail-card__head">
            <div>
              <div class="text-h6">Costing Files</div>
              <div class="text-caption text-grey-7">
                Admins can create, edit, and delete costing files for this tenant.
              </div>
            </div>

            <q-btn
              color="primary"
              icon="add"
              label="Add Costing File"
              :disable="customerGroups.length === 0"
              @click="openCreateCostingFileDialog"
            />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="costingFilesLoading" class="text-grey-7">
            Loading costing files...
          </q-card-section>

          <q-card-section v-else-if="customerGroups.length === 0" class="text-grey-7">
            Create a customer group first before adding costing files.
          </q-card-section>

          <q-card-section v-else-if="costingFiles.length === 0" class="text-grey-7">
            No costing files found for this tenant.
          </q-card-section>

          <q-table
            v-else
            flat
            bordered
            row-key="id"
            :rows="costingFiles"
            :columns="costingFileColumns"
            :dense="$q.screen.lt.md"
            hide-bottom
            class="tenant-detail-card__table"
          >
            <template #body-cell-customer_group_id="props">
              <q-td :props="props">
                {{ customerGroupNameById(props.row.customer_group_id) }}
              </q-td>
            </template>

            <template #body-cell-status="props">
              <q-td :props="props">
                <q-badge color="primary" outline>
                  {{ props.row.status }}
                </q-badge>
              </q-td>
            </template>

            <template #body-cell-updated_at="props">
              <q-td :props="props">
                {{ formatDateTime(props.row.updated_at) }}
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td :props="props">
                <div class="row items-center q-gutter-xs">
                  <q-btn
                    flat
                    round
                    dense
                    icon="edit"
                    @click="openEditCostingFileDialog(props.row)"
                  />
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="delete"
                    @click="openDeleteCostingFileDialog(props.row)"
                  />
                </div>
              </q-td>
            </template>
          </q-table>
        </q-card>

        <q-card flat bordered class="tenant-detail-card">
          <q-card-section class="row items-center justify-between tenant-detail-card__head">
            <div class="text-h6">Module Features</div>
          </q-card-section>

          <q-separator />

          <q-card-section v-if="modulesLoading" class="text-grey-7">
            Loading module features...
          </q-card-section>

          <q-card-section v-else-if="modules.length === 0" class="text-grey-7">
            No module features found.
          </q-card-section>

          <q-table
            v-else
            flat
            bordered
            row-key="id"
            :rows="modules"
            :columns="moduleFeatureColumns"
            :dense="$q.screen.lt.md"
            hide-bottom
            class="tenant-detail-card__table"
          >
            <template #body-cell-module_key="props">
              <q-td :props="props">{{ props.row.module_key }}</q-td>
            </template>

            <template #body-cell-active="props">
              <q-td :props="props">
                <q-badge :color="props.row.is_active ? 'positive' : 'grey-6'">
                  {{ props.row.is_active ? 'Active' : 'Inactive' }}
                </q-badge>
              </q-td>
            </template>
          </q-table>
        </q-card>
      </div>
    </div>

    <q-dialog v-model="openAddMemberDialog" persistent>
      <q-card style="min-width: 420px">
        <q-card-section>
          <div class="text-h6">Add Staff</div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="memberEmail" label="Email" type="email" outlined dense />
          <q-input :model-value="selectedMemberRole" label="Role" outlined dense readonly />
          <div class="row items-center justify-between">
            <div class="text-subtitle2">Status</div>
            <q-toggle
              v-model="memberIsActive"
              :label="memberIsActive ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openAddMemberDialog = false" />
          <q-btn color="primary" label="Save" @click="handleSaveMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteMemberDialog" persistent>
      <q-card style="min-width: 350px">
        <q-card-section>
          <div class="text-h6">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete member
          <strong>{{ memberToDelete?.email }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteMemberDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openCostingFileDialog" persistent>
      <q-card style="min-width: 460px">
        <q-card-section>
          <div class="text-h6">
            {{ costingFileForm.id ? 'Edit Costing File' : 'Add Costing File' }}
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="costingFileForm.name"
            label="Name"
            outlined
            dense
          />
          <q-input
            v-model="costingFileForm.market"
            label="Market"
            outlined
            dense
          />
          <q-select
            v-model="costingFileForm.customerGroupId"
            :options="costingFileCustomerGroupOptions"
            emit-value
            map-options
            label="Customer Group"
            outlined
            dense
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openCostingFileDialog = false" />
          <q-btn
            color="primary"
            label="Save"
            :loading="costingFileMutationLoading"
            :disable="!canSaveCostingFile"
            @click="saveCostingFile"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteCostingFileDialogModel" persistent>
      <q-card style="min-width: 360px">
        <q-card-section>
          <div class="text-h6">Delete Costing File</div>
        </q-card-section>

        <q-card-section>
          Delete costing file <strong>{{ costingFileToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteCostingFileDialogModel = false" />
          <q-btn
            color="negative"
            label="Delete"
            :loading="costingFileMutationLoading"
            @click="confirmDeleteCostingFile"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openCustomerGroupDialog" persistent>
      <q-card style="min-width: 460px">
        <q-card-section>
          <div class="text-h6">
            {{ customerGroupForm.id ? 'Edit Customer Group' : 'Add Customer Group' }}
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="customerGroupForm.name"
            label="Group name"
            outlined
            dense
            :error="customerGroupNameError !== null"
            :error-message="customerGroupNameError ?? undefined"
          />
          <q-input
            v-model="customerGroupForm.accent_color"
            label="Accent color"
            outlined
            dense
            placeholder="#B45F34"
            :error="customerGroupAccentError !== null"
            :error-message="customerGroupAccentError ?? undefined"
          >
            <template #append>
              <q-icon
                name="palette"
                class="cursor-pointer"
                :style="{ color: customerGroupPreviewColor }"
              >
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-card flat bordered class="customer-group-color-picker">
                    <q-card-section class="q-pa-sm">
                      <q-color
                        v-model="customerGroupForm.accent_color"
                        default-view="palette"
                        format-model="hex"
                        no-header-tabs
                        no-footer
                      />
                    </q-card-section>
                  </q-card>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
          <div class="customer-group-color-row">
            <div class="customer-group-color-preview">
              <div
                class="customer-group-chip customer-group-chip--large"
                :style="{ backgroundColor: customerGroupPreviewColor }"
              />
              <div class="text-caption text-grey-7">
                Preview: {{ customerGroupPreviewColor }}
              </div>
            </div>
            <div class="customer-group-swatches">
              <button
                v-for="swatch in customerGroupAccentPresets"
                :key="swatch"
                type="button"
                class="customer-group-swatch"
                :class="{
                  'customer-group-swatch--active': customerGroupPreviewColor === swatch,
                }"
                :style="{ backgroundColor: swatch }"
                @click="customerGroupForm.accent_color = swatch"
              />
            </div>
          </div>
          <div class="row items-center justify-between">
            <div class="text-subtitle2">Status</div>
            <q-toggle
              v-model="customerGroupForm.is_active"
              :label="customerGroupForm.is_active ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
          <div v-if="!customerGroupForm.id" class="customer-group-admin-block q-gutter-md">
            <div>
              <div class="text-subtitle2 text-weight-medium">First customer admin</div>
              <div class="text-caption text-grey-7">
                Add the first customer admin now, or leave this blank and add them later.
              </div>
            </div>
            <q-input v-model="customerGroupAdminForm.name" label="Admin name" outlined dense />
            <q-input
              v-model="customerGroupAdminForm.email"
              label="Admin email"
              type="email"
              outlined
              dense
              :error="customerGroupAdminEmailError !== null"
              :error-message="customerGroupAdminEmailError ?? undefined"
            />
            <div class="row items-center justify-between">
              <div class="text-subtitle2">Admin status</div>
              <q-toggle
                v-model="customerGroupAdminForm.is_active"
                :label="customerGroupAdminForm.is_active ? 'Active' : 'Inactive'"
                color="positive"
                keep-color
              />
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openCustomerGroupDialog = false" />
          <q-btn
            color="primary"
            label="Save"
            :disable="customerGroupFormInvalid"
            @click="saveCustomerGroup"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteCustomerGroupDialog" persistent>
      <q-card style="min-width: 360px">
        <q-card-section>
          <div class="text-h6">Delete Customer Group</div>
        </q-card-section>

        <q-card-section>
          Delete customer group <strong>{{ customerGroupToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openDeleteCustomerGroupDialog = false" />
          <q-btn color="negative" label="Delete" @click="confirmDeleteCustomerGroup" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openCustomerMemberDialog" persistent>
      <q-card style="min-width: 460px">
        <q-card-section>
          <div class="text-h6">
            {{
              customerGroupMemberForm.id
                ? 'Edit Customer Group Member'
                : 'Add Customer Group Member'
            }}
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="customerGroupMemberForm.name"
            label="Name"
            outlined
            dense
            :error="customerGroupMemberNameError !== null"
            :error-message="customerGroupMemberNameError ?? undefined"
          />
          <q-input
            v-model="customerGroupMemberForm.email"
            label="Email"
            type="email"
            outlined
            dense
            :error="customerGroupMemberEmailError !== null"
            :error-message="customerGroupMemberEmailError ?? undefined"
          />
          <q-select
            v-model="customerGroupMemberForm.role"
            :options="customerRoleOptions"
            emit-value
            map-options
            label="Role"
            outlined
            dense
          />
          <div class="row items-center justify-between">
            <div class="text-subtitle2">Status</div>
            <q-toggle
              v-model="customerGroupMemberForm.is_active"
              :label="customerGroupMemberForm.is_active ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="openCustomerMemberDialog = false" />
          <q-btn
            color="primary"
            label="Save"
            :disable="customerGroupMemberFormInvalid"
            @click="saveCustomerGroupMember"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useQuasar } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import { watch } from 'vue'

import { useMembershipStore } from 'src/modules/membership/stores/membershipStore'
import type { Membership } from 'src/modules/membership/types'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileListEntry } from 'src/modules/costingFile/types'
import { useCustomerGroupStore } from '../stores/customerGroupStore'
import { useTenantModuleStore } from '../stores/tenantModuleStore'
import { useTenantStore } from '../stores/tenantStore'
import type {
  CustomerGroup,
  CustomerGroupMember,
  CustomerGroupRole,
  Tenant,
} from '../types'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()

const tenantStore = useTenantStore()
const tenantModuleStore = useTenantModuleStore()
const membershipStore = useMembershipStore()
const customerGroupStore = useCustomerGroupStore()
const costingFileStore = useCostingFileStore()

const { items } = storeToRefs(tenantStore)
const { items: modules, loading: modulesLoading } = storeToRefs(tenantModuleStore)
const {
  items: costingFiles,
  listLoading: costingFilesLoading,
  mutationLoading: costingFileMutationLoading,
} = storeToRefs(costingFileStore)
const {
  groups: customerGroups,
  members: customerGroupMembers,
  loading: customerGroupsLoading,
  membersLoading: customerGroupMembersLoading,
} = storeToRefs(customerGroupStore)

const openAddMemberDialog = ref(false)
const openDeleteMemberDialog = ref(false)
const openCostingFileDialog = ref(false)
const openDeleteCostingFileDialogModel = ref(false)
const openCustomerGroupDialog = ref(false)
const openDeleteCustomerGroupDialog = ref(false)
const openCustomerMemberDialog = ref(false)

const memberToDelete = ref<Membership | null>(null)
const costingFileToDelete = ref<CostingFileListEntry | null>(null)
const customerGroupToDelete = ref<CustomerGroup | null>(null)

const memberEmail = ref('')
const memberIsActive = ref(true)
const selectedMemberRole = ref<'staff'>('staff')

const tenantMembers = ref<Membership[]>([])
const tenantMembersLoading = ref(false)
const pageLoading = ref(false)
const pageError = ref('')
const selectedCustomerGroupId = ref<number | null>(null)
const customerGroupMembersByGroupId = ref<Record<number, CustomerGroupMember[]>>({})

const customerGroupForm = ref<{
  id: number | null
  name: string
  accent_color: string
  is_active: boolean
}>({
  id: null,
  name: '',
  accent_color: '',
  is_active: true,
})

const customerGroupAdminForm = ref<{
  name: string
  email: string
  is_active: boolean
}>({
  name: '',
  email: '',
  is_active: true,
})

const customerGroupMemberForm = ref<{
  id: number | null
  name: string
  email: string
  role: CustomerGroupRole
  is_active: boolean
}>({
  id: null,
  name: '',
  email: '',
  role: 'staff',
  is_active: true,
})

const costingFileForm = ref<{
  id: number | null
  name: string
  market: string
  customerGroupId: number | null
}>({
  id: null,
  name: '',
  market: '',
  customerGroupId: null,
})

const customerRoleOptions = [
  { label: 'Customer Admin', value: 'admin' },
  { label: 'Customer Negotiator', value: 'negotiator' },
  { label: 'Customer Staff', value: 'staff' },
] satisfies { label: string; value: CustomerGroupRole }[]

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(
  () => items.value.find((item) => item.id === tenantId.value) ?? null,
)

const selectedCustomerGroup = computed<CustomerGroup | null>(
  () =>
    customerGroups.value.find((group) => group.id === selectedCustomerGroupId.value) ??
    null,
)

const costingFileCustomerGroupOptions = computed(() =>
  customerGroups.value.map((group) => ({
    label: group.name,
    value: group.id,
  })),
)

const sortedCustomerGroups = computed(() =>
  [...customerGroups.value].sort((left, right) => {
    if (left.is_active !== right.is_active) {
      return left.is_active ? -1 : 1
    }

    return left.name.localeCompare(right.name)
  }),
)

const selectedCustomerGroupMembers = computed(() =>
  selectedCustomerGroupId.value === null
    ? []
    : (customerGroupMembersByGroupId.value[selectedCustomerGroupId.value] ?? []),
)

const sortedCustomerGroupMembers = computed(() =>
  [...selectedCustomerGroupMembers.value].sort((left, right) => {
    if (left.is_active !== right.is_active) {
      return left.is_active ? -1 : 1
    }

    if (left.role !== right.role) {
      const roleOrder: Record<CustomerGroupRole, number> = {
        admin: 0,
        negotiator: 1,
        staff: 2,
      }

      return roleOrder[left.role] - roleOrder[right.role]
    }

    return left.name.localeCompare(right.name)
  }),
)

const staffMembers = computed(() =>
  tenantMembers.value.filter((member) => member.role === 'staff'),
)

const internalMemberColumns = [
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const },
  { name: 'role', label: 'Role', field: 'role', align: 'left' as const },
  { name: 'active', label: 'Active', field: 'is_active', align: 'left' as const },
  { name: 'delete', label: 'Delete', field: 'id', align: 'left' as const },
]

const costingFileColumns = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'market', label: 'Market', field: 'market', align: 'left' as const },
  {
    name: 'customer_group_id',
    label: 'Customer Group',
    field: 'customer_group_id',
    align: 'left' as const,
  },
  { name: 'status', label: 'Status', field: 'status', align: 'left' as const },
  { name: 'updated_at', label: 'Updated', field: 'updated_at', align: 'left' as const },
  { name: 'actions', label: 'Actions', field: 'id', align: 'left' as const },
]

const moduleFeatureColumns = [
  { name: 'module_key', label: 'Feature', field: 'module_key', align: 'left' as const },
  { name: 'active', label: 'Active', field: 'is_active', align: 'left' as const },
]

const customerGroupMemberColumns = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const },
  { name: 'role', label: 'Role', field: 'role', align: 'left' as const },
  { name: 'active', label: 'Active', field: 'is_active', align: 'left' as const },
  { name: 'edit', label: 'Edit', field: 'id', align: 'left' as const },
]

const defaultCustomerGroupAccent = '#B45F34'

const customerGroupAccentPresets = [
  '#B45F34',
  '#8E4B2B',
  '#C46A3C',
  '#6F7C4F',
  '#2F6E73',
  '#7D4E8B',
] as const

const customerGroupPreviewColor = computed(() => {
  const color = customerGroupForm.value.accent_color.trim()
  return /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(color)
    ? color.toUpperCase()
    : defaultCustomerGroupAccent
})

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const normalizeEmail = (value: string) => value.trim().toLowerCase()

const normalizeAccentColor = (value: string) => value.trim().toUpperCase()

const isValidEmail = (value: string) => emailPattern.test(normalizeEmail(value))

const isValidHexColor = (value: string) =>
  value.length === 0 || /^#([0-9A-F]{3}|[0-9A-F]{6})$/i.test(value)

const customerGroupNameError = computed(() =>
  customerGroupForm.value.name.trim() ? null : 'Group name is required.',
)

const customerGroupAccentError = computed(() => {
  const color = normalizeAccentColor(customerGroupForm.value.accent_color)
  return isValidHexColor(color) ? null : 'Use a hex color like #B45F34.'
})

const customerGroupAdminEmailError = computed(() => {
  const hasAdminName = customerGroupAdminForm.value.name.trim().length > 0
  const email = customerGroupAdminForm.value.email.trim()

  if (!hasAdminName && !email) {
    return null
  }

  if (!hasAdminName || !email) {
    return 'Add both admin name and email, or leave both blank.'
  }

  return isValidEmail(email) ? null : 'Enter a valid admin email address.'
})

const customerGroupFormInvalid = computed(
  () =>
    customerGroupNameError.value !== null ||
    customerGroupAccentError.value !== null ||
    customerGroupAdminEmailError.value !== null,
)

const customerGroupMemberNameError = computed(() =>
  customerGroupMemberForm.value.name.trim() ? null : 'Name is required.',
)

const customerGroupMemberEmailError = computed(() => {
  const email = customerGroupMemberForm.value.email.trim()
  if (!email) {
    return 'Email is required.'
  }

  return isValidEmail(email) ? null : 'Enter a valid email address.'
})

const customerGroupMemberFormInvalid = computed(
  () =>
    customerGroupMemberNameError.value !== null ||
    customerGroupMemberEmailError.value !== null,
)

const formatCustomerRole = (role: CustomerGroupRole) => {
  if (role === 'admin') return 'Customer Admin'
  if (role === 'negotiator') return 'Customer Negotiator'
  return 'Customer Staff'
}

const formatDateTime = (value: string | null) => {
  if (!value) {
    return '-'
  }

  return new Date(value).toLocaleString()
}

const customerGroupNameById = (customerGroupId: number) =>
  customerGroups.value.find((group) => group.id === customerGroupId)?.name ?? `#${customerGroupId}`

const canSaveCostingFile = computed(
  () =>
    costingFileForm.value.name.trim().length > 0 &&
    costingFileForm.value.market.trim().length > 0 &&
    costingFileForm.value.customerGroupId !== null,
)

const resetCustomerGroupForm = () => {
  customerGroupForm.value = {
    id: null,
    name: '',
    accent_color: '',
    is_active: true,
  }

  customerGroupAdminForm.value = {
    name: '',
    email: '',
    is_active: true,
  }
}

const resetCostingFileForm = () => {
  costingFileForm.value = {
    id: null,
    name: '',
    market: '',
    customerGroupId: costingFileCustomerGroupOptions.value[0]?.value ?? null,
  }
}

const resetCustomerGroupMemberForm = () => {
  customerGroupMemberForm.value = {
    id: null,
    name: '',
    email: '',
    role: 'staff',
    is_active: true,
  }
}

const loadTenantMembers = async () => {
  if (!tenant.value?.id) return

  tenantMembersLoading.value = true

  try {
    const result = await membershipStore.fetchMembershipsByTenantId(tenant.value.id)

    if (!result.success) {
      tenantMembers.value = []
      pageError.value = result.error || 'Failed to load members.'
      return
    }

    tenantMembers.value = (result.data ?? []).filter(
      (item: Membership) => item.role === 'staff',
    )
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to load members.'
    tenantMembers.value = []
  } finally {
    tenantMembersLoading.value = false
  }
}

const loadCostingFiles = async () => {
  if (!tenant.value?.id) {
    costingFileStore.items = []
    return
  }

  const result = await costingFileStore.fetchCostingFilesByTenant(tenant.value.id)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load costing files.'
  }
}

const loadTenantModules = async () => {
  if (!tenant.value?.id) return

  const result = await tenantModuleStore.fetchTenantModules(tenant.value.id)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load module features.'
  }
}

const loadCustomerGroups = async () => {
  if (!tenant.value?.id) return

  const result = await customerGroupStore.fetchCustomerGroupsByTenant(tenant.value.id)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load customer groups.'
    return
  }

  const nextSelectedId =
    customerGroups.value.find((group) => group.id === selectedCustomerGroupId.value)?.id ??
    customerGroups.value[0]?.id ??
    null

  selectedCustomerGroupId.value = nextSelectedId

  if (nextSelectedId !== null) {
    await loadCustomerGroupMembers(nextSelectedId)
  } else {
    customerGroupMembersByGroupId.value = {}
    customerGroupStore.members = []
  }
}

const loadCustomerGroupMembers = async (customerGroupId: number, force = false) => {
  if (!force && customerGroupMembersByGroupId.value[customerGroupId]) {
    customerGroupStore.members = customerGroupMembersByGroupId.value[customerGroupId] ?? []
    return
  }

  const result =
    await customerGroupStore.fetchCustomerGroupMembersByGroup(customerGroupId)

  if (!result.success) {
    pageError.value = result.error || 'Failed to load customer group members.'
    return
  }

  customerGroupMembersByGroupId.value = {
    ...customerGroupMembersByGroupId.value,
    [customerGroupId]: result.data ?? [],
  }
}

const loadPageData = async () => {
  pageLoading.value = true
  pageError.value = ''

  try {
    await tenantStore.fetchTenantDetailsByMembership({
      tenantId: tenantId.value,
    })

    if (!tenant.value) {
      pageError.value = 'Tenant not found.'
      return
    }

    await Promise.all([
      loadTenantMembers(),
      loadTenantModules(),
      loadCustomerGroups(),
      loadCostingFiles(),
    ])
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to load tenant details.'
  } finally {
    pageLoading.value = false
  }
}

const goBack = () => {
  const tenantSlug = tenantStore.selectedTenantSlug
  void router.push(tenantSlug ? `/${tenantSlug}/app/tenants` : '/app/tenants')
}

watch(
  tenant,
  (value) => {
    if (!value) {
      return
    }

    tenantStore.setSelectedTenant({
      id: value.id,
      slug: value.slug,
    })
  },
  { immediate: true },
)

const onClickAddMember = (role: 'staff') => {
  selectedMemberRole.value = role
  memberEmail.value = ''
  memberIsActive.value = true
  openAddMemberDialog.value = true
}

const handleSaveMember = async () => {
  if (!tenant.value?.id || !memberEmail.value.trim()) return

  const result = await membershipStore.createMembership({
    tenant_id: tenant.value.id,
    email: memberEmail.value,
    role: selectedMemberRole.value,
    is_active: memberIsActive.value,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to create member.'
    return
  }

  openAddMemberDialog.value = false
  await loadTenantMembers()
}

const onToggleMemberActive = async (member: Membership, value: boolean) => {
  const previousValue = !value

  try {
    const result = await membershipStore.updateMembership({
      id: member.id,
      is_active: value,
    })

    if (!result.success) {
      member.is_active = previousValue
      pageError.value = result.error ?? 'Failed to update member status.'
    }
  } catch (error) {
    member.is_active = previousValue
    console.error(error)
    pageError.value = 'Failed to update member status.'
  }
}

const onClickDeleteMember = (member: Membership) => {
  memberToDelete.value = member
  openDeleteMemberDialog.value = true
}

const confirmDeleteMember = async () => {
  if (!memberToDelete.value) return

  try {
    const result = await membershipStore.deleteMembership({
      id: memberToDelete.value.id,
    })

    if (!result.success) {
      pageError.value = result.error ?? 'Failed to delete member.'
      return
    }

    tenantMembers.value = tenantMembers.value.filter(
      (item) => item.id !== memberToDelete.value?.id,
    )

    openDeleteMemberDialog.value = false
    memberToDelete.value = null
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to delete member.'
  }
}

const openCreateCostingFileDialog = () => {
  resetCostingFileForm()
  openCostingFileDialog.value = true
}

const openEditCostingFileDialog = (file: CostingFileListEntry) => {
  costingFileForm.value = {
    id: file.id,
    name: file.name,
    market: file.market,
    customerGroupId: file.customer_group_id,
  }
  openCostingFileDialog.value = true
}

const saveCostingFile = async () => {
  const tenantId = tenant.value?.id
  const customerGroupId = costingFileForm.value.customerGroupId

  if (!tenantId || customerGroupId === null || !canSaveCostingFile.value) {
    return
  }

  const result = costingFileForm.value.id
    ? await costingFileStore.updateCostingFile({
        id: costingFileForm.value.id,
        name: costingFileForm.value.name.trim(),
        market: costingFileForm.value.market.trim(),
        customerGroupId,
      })
    : await costingFileStore.createCostingFile({
        tenantId,
        customerGroupId,
        name: costingFileForm.value.name.trim(),
        market: costingFileForm.value.market.trim(),
      })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to save costing file.'
    return
  }

  openCostingFileDialog.value = false
  await loadCostingFiles()
}

const openDeleteCostingFileDialog = (file: CostingFileListEntry) => {
  costingFileToDelete.value = file
  openDeleteCostingFileDialogModel.value = true
}

const confirmDeleteCostingFile = async () => {
  if (!costingFileToDelete.value) {
    return
  }

  const result = await costingFileStore.deleteCostingFile({
    id: costingFileToDelete.value.id,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to delete costing file.'
    return
  }

  openDeleteCostingFileDialogModel.value = false
  costingFileToDelete.value = null
  await loadCostingFiles()
}

const selectCustomerGroup = (customerGroupId: number) => {
  selectedCustomerGroupId.value = customerGroupId

  const cachedMembers = customerGroupMembersByGroupId.value[customerGroupId]
  if (cachedMembers) {
    customerGroupStore.members = cachedMembers
    return
  }

  void loadCustomerGroupMembers(customerGroupId)
}

const openCreateGroupDialog = () => {
  resetCustomerGroupForm()
  openCustomerGroupDialog.value = true
}

const openEditGroupDialog = (group: CustomerGroup) => {
  customerGroupForm.value = {
    id: group.id,
    name: group.name,
    accent_color: group.accent_color ?? '',
    is_active: group.is_active,
  }
  openCustomerGroupDialog.value = true
}

const saveCustomerGroup = async () => {
  if (!tenant.value?.id || customerGroupFormInvalid.value) return

  const shouldCreateFirstAdmin =
    !customerGroupForm.value.id &&
    (customerGroupAdminForm.value.name.trim() || customerGroupAdminForm.value.email.trim())
  const normalizedAccentColor = normalizeAccentColor(customerGroupForm.value.accent_color)

  const result = customerGroupForm.value.id
    ? await customerGroupStore.updateCustomerGroup({
        id: customerGroupForm.value.id,
        name: customerGroupForm.value.name.trim(),
        accent_color: normalizedAccentColor,
        is_active: customerGroupForm.value.is_active,
      })
    : await customerGroupStore.createCustomerGroup({
        tenant_id: tenant.value.id,
        name: customerGroupForm.value.name.trim(),
        accent_color: normalizedAccentColor,
        is_active: customerGroupForm.value.is_active,
      })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to save customer group.'
    return
  }

  const savedGroupId = result.data?.id ?? customerGroupForm.value.id

  if (shouldCreateFirstAdmin && savedGroupId) {
    const adminResult = await customerGroupStore.createCustomerGroupMember({
      customer_group_id: savedGroupId,
      name: customerGroupAdminForm.value.name.trim(),
      email: normalizeEmail(customerGroupAdminForm.value.email),
      role: 'admin',
      is_active: customerGroupAdminForm.value.is_active,
    })

    if (!adminResult.success) {
      pageError.value = adminResult.error ?? 'Customer group was created, but the admin could not be added.'
      selectedCustomerGroupId.value = savedGroupId
      openCustomerGroupDialog.value = false
      await loadCustomerGroups()
      await loadCustomerGroupMembers(savedGroupId, true)
      return
    }
  }

  openCustomerGroupDialog.value = false
  await loadCustomerGroups()

  if (savedGroupId) {
    selectedCustomerGroupId.value = savedGroupId
    await loadCustomerGroupMembers(savedGroupId, true)
  }
}

const openDeleteGroupDialog = (group: CustomerGroup) => {
  customerGroupToDelete.value = group
  openDeleteCustomerGroupDialog.value = true
}

const confirmDeleteCustomerGroup = async () => {
  if (!customerGroupToDelete.value) return

  const deletedId = customerGroupToDelete.value.id
  const result = await customerGroupStore.deleteCustomerGroup({ id: deletedId })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to delete customer group.'
    return
  }

  openDeleteCustomerGroupDialog.value = false
  customerGroupToDelete.value = null

  if (selectedCustomerGroupId.value === deletedId) {
    selectedCustomerGroupId.value = customerGroups.value[0]?.id ?? null
  }

  delete customerGroupMembersByGroupId.value[deletedId]

  if (selectedCustomerGroupId.value !== null) {
    await loadCustomerGroupMembers(selectedCustomerGroupId.value)
  }
}

const onToggleCustomerGroupActive = async (
  group: CustomerGroup,
  value: boolean,
) => {
  const previousValue = group.is_active
  group.is_active = value

  const result = await customerGroupStore.updateCustomerGroup({
    id: group.id,
    is_active: value,
  })

  if (!result.success) {
    group.is_active = previousValue
    pageError.value = result.error ?? 'Failed to update customer group.'
  }
}

const onToggleSelectedCustomerGroupActive = async (value: boolean) => {
  if (!selectedCustomerGroup.value) return

  await onToggleCustomerGroupActive(selectedCustomerGroup.value, value)
}

const openCreateCustomerMemberDialog = () => {
  resetCustomerGroupMemberForm()
  openCustomerMemberDialog.value = true
}

const openEditCustomerMemberDialog = (member: CustomerGroupMember) => {
  customerGroupMemberForm.value = {
    id: member.id,
    name: member.name,
    email: member.email,
    role: member.role,
    is_active: member.is_active,
  }
  openCustomerMemberDialog.value = true
}

const saveCustomerGroupMember = async () => {
  if (!selectedCustomerGroup.value || customerGroupMemberFormInvalid.value) {
    return
  }

  const result = customerGroupMemberForm.value.id
    ? await customerGroupStore.updateCustomerGroupMember({
        id: customerGroupMemberForm.value.id,
        name: customerGroupMemberForm.value.name.trim(),
        email: normalizeEmail(customerGroupMemberForm.value.email),
        role: customerGroupMemberForm.value.role,
        is_active: customerGroupMemberForm.value.is_active,
      })
    : await customerGroupStore.createCustomerGroupMember({
        customer_group_id: selectedCustomerGroup.value.id,
        name: customerGroupMemberForm.value.name.trim(),
        email: normalizeEmail(customerGroupMemberForm.value.email),
        role: customerGroupMemberForm.value.role,
        is_active: customerGroupMemberForm.value.is_active,
      })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to save customer group member.'
    return
  }

  openCustomerMemberDialog.value = false
  await loadCustomerGroupMembers(selectedCustomerGroup.value.id, true)
}

const onToggleCustomerGroupMemberActive = async (
  member: CustomerGroupMember,
  value: boolean,
) => {
  const previousValue = member.is_active
  member.is_active = value

  const result = await customerGroupStore.updateCustomerGroupMember({
    id: member.id,
    is_active: value,
  })

  if (!result.success) {
    member.is_active = previousValue
    pageError.value = result.error ?? 'Failed to update customer member.'
    return
  }

  if (selectedCustomerGroup.value) {
    customerGroupMembersByGroupId.value = {
      ...customerGroupMembersByGroupId.value,
      [selectedCustomerGroup.value.id]: [...customerGroupMembers.value],
    }
  }
}

onMounted(() => {
  void loadPageData()
})
</script>

<style scoped>
.customer-group-admin-block {
  padding-top: 0.5rem;
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.customer-group-item {
  border-radius: 12px;
  margin: 0.25rem 0.5rem;
}

.customer-group-item--active {
  background: rgb(180 95 52 / 0.1);
  color: inherit;
}

.customer-group-item--active :deep(.q-item__label--caption) {
  color: rgba(31, 41, 55, 0.72);
}

.customer-group-chip {
  width: 18px;
  height: 18px;
  border-radius: 999px;
  border: 2px solid rgba(255, 255, 255, 0.9);
  box-shadow: 0 0 0 1px rgba(31, 41, 55, 0.12);
}

.customer-group-chip--large {
  width: 28px;
  height: 28px;
}

.customer-group-color-picker {
  border-radius: 16px;
}

.customer-group-color-row {
  display: grid;
  gap: 0.75rem;
}

.customer-group-color-preview {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.customer-group-swatches {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.customer-group-swatch {
  width: 28px;
  height: 28px;
  padding: 0;
  border: 2px solid rgba(31, 41, 55, 0.08);
  border-radius: 999px;
  cursor: pointer;
  box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.65) inset;
}

.customer-group-swatch--active {
  border-color: rgba(31, 41, 55, 0.55);
  transform: scale(1.05);
}

.tenant-detail-card :deep(.q-btn) {
  border-radius: 8px;
}

:deep(.q-btn) {
  border-radius: 8px;
}

.tenant-detail-card__head {
  gap: 0.75rem;
}

.tenant-detail-card__list-item {
  padding-top: 0.35rem;
  padding-bottom: 0.35rem;
}

.tenant-detail-card__table :deep(th),
.tenant-detail-card__table :deep(td) {
  white-space: nowrap;
}

@media (max-width: 599px) {
  .tenant-detail-card__table :deep(th),
  .tenant-detail-card__table :deep(td) {
    padding: 0.35rem 0.45rem;
    font-size: 0.875rem;
  }

  .tenant-detail-card__head {
    align-items: flex-start;
  }

  .tenant-detail-card__side {
    align-self: flex-start;
    padding-top: 0.35rem;
  }
}
</style>
