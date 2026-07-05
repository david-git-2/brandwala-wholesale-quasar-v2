<template>
  <q-page class="q-pa-md admin-tenant-management-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">{{ pageTitle }}</div>
            <div v-if="tenant" class="text-caption text-grey-8">
              {{ tenant.name }} · {{ tenant.slug }}
            </div>
          </div>
          <div class="col-auto">
            <q-chip
              dense
              square
              class="costing-status-chip"
              :style="tenant?.is_active ? activeStatusStyle : inactiveStatusStyle"
            >
              <span class="status-dot" :style="{ backgroundColor: tenant?.is_active ? '#2f8b5d' : '#66758c' }" />
              {{ tenant?.is_active ? 'Active' : 'Inactive' }}
            </q-chip>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-banner v-if="pageError" class="bg-negative text-white q-mb-md" rounded>
      {{ pageError }}
    </q-banner>

    <PageInitialLoader v-if="pageLoading" />

    <template v-else>
      <div v-if="!tenant" class="text-grey-7 q-pa-lg text-center">Tenant not found.</div>

    <div v-else class="row q-col-gutter-lg">
      <div class="col-12 col-lg-4">
        <q-card v-if="showCustomerGroupManagement" flat class="q-mb-lg floating-surface shadow-1">
          <q-card-section class="row items-start justify-between">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">{{ tenant.name }}</div>
              <div class="text-caption text-grey-7">{{ tenant.slug }}</div>
            </div>

            <q-chip
              dense
              square
              class="costing-status-chip"
              :style="tenant.is_active ? activeStatusStyle : inactiveStatusStyle"
            >
              <span class="status-dot" :style="{ backgroundColor: tenant.is_active ? '#2f8b5d' : '#66758c' }" />
              {{ tenant.is_active ? 'Active' : 'Inactive' }}
            </q-chip>
          </q-card-section>

          <q-separator />

          <q-card-section class="q-gutter-sm">
            <div class="row items-center justify-between q-py-xs border-bottom">
              <div class="text-grey-8">Tenant ID</div>
              <div class="text-weight-bold">#{{ tenant.id }}</div>
            </div>

            <q-card flat class="q-pa-sm inner-card">
              <div class="text-caption text-grey-7 q-mb-xs">Admin Login</div>
              <div class="row items-center justify-between q-gutter-sm">
                <a :href="adminLoginUrl" class="text-primary ellipsis col" target="_blank" rel="noopener noreferrer">
                  {{ adminLoginUrl }}
                </a>
                <q-btn flat round dense icon="content_copy" aria-label="Copy admin login URL" @click="copyLoginUrl(adminLoginUrl, 'Admin login URL copied.')" />
              </div>
            </q-card>

            <q-card flat class="q-pa-sm inner-card">
              <div class="text-caption text-grey-7 q-mb-xs">Customer Login</div>
              <div class="row items-center justify-between q-gutter-sm">
                <a :href="customerLoginUrl" class="text-primary ellipsis col" target="_blank" rel="noopener noreferrer">
                  {{ customerLoginUrl }}
                </a>
                <q-btn flat round dense icon="content_copy" aria-label="Copy customer login URL" @click="copyLoginUrl(customerLoginUrl, 'Customer login URL copied.')" />
              </div>
            </q-card>
          </q-card-section>
        </q-card>

        <q-card v-if="showCustomerGroupManagement" flat class="q-mb-lg floating-surface shadow-1">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Customer Name</div>
              <div class="text-caption text-grey-7">
                Organize customer-side access by company or buying team.
              </div>
            </div>

            <q-btn color="primary" class="pill-btn slim-btn" no-caps size="sm" icon="groups" label="Add Group" @click="openCreateGroupDialog" />
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
                  <q-btn flat round dense icon="o_edit" @click.stop="openEditGroupDialog(group)" />
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="o_delete"
                    @click.stop="openDeleteGroupDialog(group)"
                  />
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <div class="col-12 col-lg-8">
        <q-card v-if="showStaffManagement" flat class="q-mb-lg floating-surface shadow-1">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Internal Members</div>
              <div class="text-caption text-grey-7">
                Manage staff and viewer memberships that belong to this tenant.
              </div>
            </div>

            <div class="row items-center q-gutter-sm">
              <q-btn
                outline
                color="primary"
                class="pill-btn slim-btn"
                no-caps
                size="sm"
                icon="visibility"
                label="Add Viewer"
                @click="onClickAddMember('viewer')"
              />
              <q-btn
                color="primary"
                class="pill-btn slim-btn"
                no-caps
                size="sm"
                icon="person_add"
                label="Add Staff"
                @click="onClickAddMember('staff')"
              />
            </div>
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
              row-key="id"
              :rows="staffMembers"
              :columns="internalMemberColumns"
              :dense="$q.screen.lt.md"
              hide-bottom
              class="tenant-detail-card__table costing-list-table"
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
                    icon="o_delete"
                    @click="onClickDeleteMember(props.row)"
                  />
                </q-td>
              </template>
            </q-table>
            <div v-else class="text-grey-6">No staff found.</div>

            <q-separator class="q-my-lg" />

            <div class="row items-center justify-between q-mb-sm">
              <div>
                <div class="text-subtitle1">Viewers</div>
                <div class="text-caption text-grey-7">
                  Viewers can access assigned costing files with read-only access.
                </div>
              </div>
            </div>

            <q-table
              v-if="viewerMembers.length"
              flat
              row-key="id"
              :rows="viewerMembers"
              :columns="internalMemberColumns"
              :dense="$q.screen.lt.md"
              hide-bottom
              class="tenant-detail-card__table costing-list-table"
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
                    icon="o_delete"
                    @click="onClickDeleteMember(props.row)"
                  />
                </q-td>
              </template>
            </q-table>
            <div v-else class="text-grey-6">No viewers found.</div>
          </q-card-section>
        </q-card>

        <q-card v-if="showInvestorManagement" flat class="q-mb-lg floating-surface shadow-1">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Investor Members</div>
              <div class="text-caption text-grey-7">
                Manage portal access for external capital partners on this tenant.
              </div>
            </div>

            <q-btn
              color="primary"
              class="pill-btn slim-btn"
              no-caps
              size="sm"
              icon="person_add"
              label="Add Investor"
              @click="onClickAddMember('investor')"
            />
          </q-card-section>

          <q-separator />

          <q-card-section v-if="tenantMembersLoading" class="text-grey-7">
            Loading investor members...
          </q-card-section>

          <q-card-section v-else-if="investorMembers.length === 0" class="text-grey-7">
            No investor members found.
          </q-card-section>

          <q-card-section v-else>
            <q-table
              flat
              row-key="id"
              :rows="investorMembers"
              :columns="internalMemberColumns"
              :dense="$q.screen.lt.md"
              hide-bottom
              class="tenant-detail-card__table costing-list-table"
            >
              <template #body-cell-email="props">
                <q-td :props="props">{{ props.row.email }}</q-td>
              </template>

              <template #body-cell-role="props">
                <q-td :props="props">
                  {{ props.row.role }}
                  <span v-if="props.row.investor_id" class="text-caption text-grey-6">
                    ({{ investorNameById(props.row.investor_id) }})
                  </span>
                </q-td>
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
                    icon="o_delete"
                    @click="onClickDeleteMember(props.row)"
                  />
                </q-td>
              </template>
            </q-table>
          </q-card-section>
        </q-card>

        <q-card v-if="showCustomerGroupManagement" flat class="q-mb-lg floating-surface shadow-1">
          <q-card-section class="row items-center justify-between">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Customer Group Members</div>
              <div class="text-caption text-grey-7">
                Add customer admins, negotiators, and staff inside the selected group.
              </div>
            </div>

            <q-btn
              color="primary"
              class="pill-btn slim-btn"
              no-caps
              size="sm"
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
              row-key="id"
              :rows="sortedCustomerGroupMembers"
              :columns="customerGroupMemberColumns"
              :pagination="{ rowsPerPage: 0 }"
              :dense="$q.screen.lt.md"
              hide-bottom
              class="tenant-detail-card__table costing-list-table"
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
                  <div class="row items-center q-gutter-xs">
                    <q-btn
                      flat
                      round
                      dense
                      icon="o_edit"
                      @click="openEditCustomerMemberDialog(props.row)"
                    />
                    <q-btn
                      flat
                      round
                      dense
                      color="negative"
                      icon="o_delete"
                      @click="openDeleteCustomerMemberDialog(props.row)"
                    />
                  </div>
                </q-td>
              </template>
            </q-table>
          </template>
        </q-card>

        <q-card v-if="showCustomerGroupManagement && showCostingFilesSection" flat class="q-mb-lg tenant-detail-card floating-surface shadow-1">
          <q-card-section class="row items-center justify-between tenant-detail-card__head">
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Costing Files</div>
              <div class="text-caption text-grey-8">
                Admins can create, edit, and delete costing files for this tenant.
              </div>
            </div>

            <q-btn
              color="primary"
              class="pill-btn slim-btn"
              no-caps
              size="sm"
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
            row-key="id"
            :rows="costingFiles"
            :columns="costingFileColumns"
            :dense="$q.screen.lt.md"
            hide-bottom
            class="tenant-detail-card__table costing-list-table"
          >
            <template #body-cell-customer_group_id="props">
              <q-td :props="props">
                {{ customerGroupNameById(props.row.customer_group_id) }}
              </q-td>
            </template>

            <template #body-cell-status="props">
              <q-td :props="props">
                <q-chip
                  dense
                  square
                  class="costing-status-chip"
                  :style="String(props.row.status).toLowerCase() === 'live' || String(props.row.status).toLowerCase() === 'approved' ? activeStatusStyle : inactiveStatusStyle"
                >
                  <span class="status-dot" :style="{ backgroundColor: String(props.row.status).toLowerCase() === 'live' || String(props.row.status).toLowerCase() === 'approved' ? '#2f8b5d' : '#66758c' }" />
                  {{ props.row.status }}
                </q-chip>
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
                    icon="o_edit"
                    @click="openEditCostingFileDialog(props.row)"
                  />
                  <q-btn
                    flat
                    round
                    dense
                    color="negative"
                    icon="o_delete"
                    @click="openDeleteCostingFileDialog(props.row)"
                  />
                </div>
              </q-td>
            </template>
          </q-table>
        </q-card>

        <q-card v-if="showModuleManagement" flat class="tenant-detail-card floating-surface shadow-1">
          <q-card-section class="row items-center justify-between tenant-detail-card__head">
            <div class="text-subtitle1 text-weight-bold text-grey-9">Module Features</div>
          </q-card-section>

          <q-separator />

          <q-card-section v-if="modulesLoading" class="text-grey-7">
            Loading module features...
          </q-card-section>

          <q-card-section v-else>
            <div class="row q-col-gutter-md">
              <div v-if="canManageModules" class="col-12 col-md-6">
                <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-8">Available Features</div>
                <q-list bordered separator class="rounded-borders">
                  <q-item v-for="feature in availableModules" :key="feature.id">
                    <q-item-section>
                      <q-item-label class="text-weight-medium">{{ feature.name }}</q-item-label>
                      <q-item-label caption>{{ feature.key }}</q-item-label>
                    </q-item-section>
                    <q-item-section side>
                      <q-btn
                        color="primary"
                        dense
                        flat
                        no-caps
                        label="Add"
                        @click="addTenantFeature(feature.key)"
                      />
                    </q-item-section>
                  </q-item>
                  <q-item v-if="availableModules.length === 0">
                    <q-item-section class="text-grey-7">No available features.</q-item-section>
                  </q-item>
                </q-list>
              </div>

              <div :class="canManageModules ? 'col-12 col-md-6' : 'col-12'">
                <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-8">Tenant Features</div>
                <q-list bordered separator class="rounded-borders">
                  <template v-for="feature in modules" :key="feature.id">
                    <q-item>
                      <q-item-section>
                        <q-item-label class="text-weight-medium">{{ feature.module_key }}</q-item-label>
                        <q-item-label caption>
                          {{ feature.is_active ? 'Active' : 'Inactive' }}
                        </q-item-label>
                      </q-item-section>
                      <q-item-section side v-if="canManageModules">
                        <q-btn
                          color="negative"
                          dense
                          flat
                          no-caps
                          label="Remove"
                          @click="removeTenantFeature(feature.id)"
                        />
                      </q-item-section>
                    </q-item>
                    <SubmoduleAccessPanel
                      v-if="tenantId && moduleStore.submodulesOf(feature.module_key).length > 0"
                      :tenant-id="tenantId"
                      :parent-module-key="feature.module_key"
                      :read-only="!canManageModules"
                    />
                  </template>
                  <q-item v-if="modules.length === 0">
                    <q-item-section class="text-grey-7">No tenant features assigned.</q-item-section>
                  </q-item>
                </q-list>
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>    <q-dialog v-model="openAddMemberDialog" persistent>
      <q-card style="min-width: 420px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">
            {{
              selectedMemberRole === 'viewer'
                ? 'Add Viewer'
                : selectedMemberRole === 'investor'
                  ? 'Add Investor'
                  : 'Add Staff'
            }}
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="memberEmail" label="Email" type="email" outlined dense class="soft-input" />
          <q-input :model-value="selectedMemberRole" label="Role" outlined dense class="soft-input" readonly />
          <q-select
            v-if="selectedMemberRole === 'investor'"
            v-model="selectedInvestorId"
            outlined
            dense
            label="Link Investor Profile"
            emit-value
            map-options
            :options="tenantInvestorsOptions"
            class="soft-input"
          />
          <div class="row items-center justify-between">
            <div class="text-subtitle2 text-grey-8">Status</div>
            <q-toggle
              v-model="memberIsActive"
              :label="memberIsActive ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openAddMemberDialog = false" />
          <q-btn color="primary" unelevated class="pill-btn" no-caps label="Save" @click="handleSaveMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteMemberDialog" persistent>
      <q-card style="min-width: 350px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Confirm Delete</div>
        </q-card-section>

        <q-card-section>
          Are you sure you want to delete member
          <strong>{{ memberToDelete?.email }}</strong>?
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openDeleteMemberDialog = false" />
          <q-btn color="negative" unelevated class="pill-btn" no-caps label="Delete" @click="confirmDeleteMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteCustomerMemberDialogModel" persistent>
      <q-card style="min-width: 350px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Delete Customer User</div>
        </q-card-section>

        <q-card-section>
          Delete customer user
          <strong>{{ customerGroupMemberToDelete?.email }}</strong>?
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openDeleteCustomerMemberDialogModel = false" />
          <q-btn color="negative" unelevated class="pill-btn" no-caps label="Delete" @click="confirmDeleteCustomerGroupMember" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openCostingFileDialog" persistent>
      <q-card style="min-width: 460px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">
            {{ costingFileForm.id ? 'Edit Costing File' : 'Add Costing File' }}
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="costingFileForm.name"
            label="Name"
            outlined
            dense
            class="soft-input"
          />
          <q-input
            v-model="costingFileForm.market"
            label="Market"
            outlined
            dense
            class="soft-input"
          />
          <q-select
            v-model="costingFileForm.customerGroupId"
            :options="costingFileCustomerGroupOptions"
            emit-value
            map-options
            label="Customer Group"
            outlined
            dense
            class="soft-input"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openCostingFileDialog = false" />
          <q-btn
            color="primary"
            unelevated
            class="pill-btn"
            no-caps
            label="Save"
            :loading="costingFileMutationLoading"
            :disable="!canSaveCostingFile"
            @click="saveCostingFile"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteCostingFileDialogModel" persistent>
      <q-card style="min-width: 360px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Delete Costing File</div>
        </q-card-section>

        <q-card-section>
          Delete costing file <strong>{{ costingFileToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openDeleteCostingFileDialogModel = false" />
          <q-btn
            color="negative"
            unelevated
            class="pill-btn"
            no-caps
            label="Delete"
            :loading="costingFileMutationLoading"
            @click="confirmDeleteCostingFile"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openCustomerGroupDialog" persistent>
      <q-card style="min-width: 460px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">
            {{ customerGroupForm.id ? 'Edit Customer Group' : 'Add Customer Group' }}
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input
            v-model="customerGroupForm.name"
            label="Group name"
            outlined
            dense
            class="soft-input"
            :error="customerGroupNameError !== null"
            :error-message="customerGroupNameError ?? undefined"
          />
          <q-input
            v-model="customerGroupForm.accent_color"
            label="Accent color"
            outlined
            dense
            class="soft-input"
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
            <div class="text-subtitle2 text-grey-8">Status</div>
            <q-toggle
              v-model="customerGroupForm.is_active"
              :label="customerGroupForm.is_active ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
          <div v-if="!customerGroupForm.id" class="customer-group-admin-block q-gutter-md">
            <div>
              <div class="text-subtitle2 text-weight-bold">First customer admin</div>
              <div class="text-caption text-grey-7">
                Add the first customer admin now, or leave this blank and add them later.
              </div>
            </div>
            <q-input v-model="customerGroupAdminForm.name" label="Admin name" outlined dense class="soft-input" />
            <q-input
              v-model="customerGroupAdminForm.email"
              label="Admin email"
              type="email"
              outlined
              dense
              class="soft-input"
              :error="customerGroupAdminEmailError !== null"
              :error-message="customerGroupAdminEmailError ?? undefined"
            />
            <div class="row items-center justify-between">
              <div class="text-subtitle2 text-grey-8">Admin status</div>
              <q-toggle
                v-model="customerGroupAdminForm.is_active"
                :label="customerGroupAdminForm.is_active ? 'Active' : 'Inactive'"
                color="positive"
                keep-color
              />
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openCustomerGroupDialog = false" />
          <q-btn
            color="primary"
            unelevated
            class="pill-btn"
            no-caps
            label="Save"
            :disable="customerGroupFormInvalid"
            @click="saveCustomerGroup"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openDeleteCustomerGroupDialog" persistent>
      <q-card style="min-width: 360px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Delete Customer Group</div>
        </q-card-section>

        <q-card-section>
          Delete customer group <strong>{{ customerGroupToDelete?.name }}</strong>?
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openDeleteCustomerGroupDialog = false" />
          <q-btn color="negative" unelevated class="pill-btn" no-caps label="Delete" @click="confirmDeleteCustomerGroup" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="openCustomerMemberDialog" persistent>
      <q-card style="min-width: 460px; border-radius: 12px;">
        <q-card-section>
          <div class="text-h6 text-weight-bold">
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
            class="soft-input"
            :error="customerGroupMemberNameError !== null"
            :error-message="customerGroupMemberNameError ?? undefined"
          />
          <q-input
            v-model="customerGroupMemberForm.email"
            label="Email"
            type="email"
            outlined
            dense
            class="soft-input"
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
            class="soft-input"
          />
          <div class="row items-center justify-between">
            <div class="text-subtitle2 text-grey-8">Status</div>
            <q-toggle
              v-model="customerGroupMemberForm.is_active"
              :label="customerGroupMemberForm.is_active ? 'Active' : 'Inactive'"
              color="positive"
              keep-color
            />
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" @click="openCustomerMemberDialog = false" />
          <q-btn
            color="primary"
            unelevated
            class="pill-btn"
            no-caps
            label="Save"
            :disable="customerGroupMemberFormInvalid"
            @click="saveCustomerGroupMember"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { copyToClipboard, useQuasar } from 'quasar'
import { useRoute } from 'vue-router'
import { storeToRefs } from 'pinia'
import { watch } from 'vue'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useMembershipStore } from 'src/modules/membership/stores/membershipStore'
import { useInvestorCapitalStore } from 'src/modules/investor_capital/stores/investorCapitalStore'
import type { Membership, TenantMembershipRole } from 'src/modules/membership/types'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import { useModuleStore } from 'src/modules/featureCatalog/stores/moduleStore'
import type { CostingFileListEntry } from 'src/modules/costingFile/types'
import { formatAppDateTime } from 'src/utils/dateTime'
import { useCustomerGroupStore } from '../stores/customerGroupStore'
import { useTenantModuleStore } from '../stores/tenantModuleStore'
import { useTenantStore } from '../stores/tenantStore'
import SubmoduleAccessPanel from '../components/SubmoduleAccessPanel.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import type {
  CustomerGroup,
  CustomerGroupMember,
  CustomerGroupRole,
  Tenant,
} from '../types'

const activeStatusStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
  boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
}

const inactiveStatusStyle = {
  backgroundColor: '#dbe5f3',
  color: '#3b4b66',
  border: '1px solid #b9c8dd',
  boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
}

const props = withDefaults(
  defineProps<{
    view?: 'customer-groups' | 'staff' | 'investors' | 'modules'
  }>(),
  {
    view: 'customer-groups',
  },
)

const route = useRoute()
const $q = useQuasar()
const authStore = useAuthStore()

const tenantStore = useTenantStore()
const tenantModuleStore = useTenantModuleStore()
const moduleStore = useModuleStore()
const membershipStore = useMembershipStore()
const customerGroupStore = useCustomerGroupStore()
const costingFileStore = useCostingFileStore()
const capitalStore = useInvestorCapitalStore()

const canManageModules = computed(() => {
  return authStore.matchedRole === 'superadmin' && authStore.scope === 'platform'
})

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
const openDeleteCustomerMemberDialogModel = ref(false)
const openCostingFileDialog = ref(false)
const openDeleteCostingFileDialogModel = ref(false)
const openCustomerGroupDialog = ref(false)
const openDeleteCustomerGroupDialog = ref(false)
const openCustomerMemberDialog = ref(false)
const showCostingFilesSection = false

const memberToDelete = ref<Membership | null>(null)
const customerGroupMemberToDelete = ref<CustomerGroupMember | null>(null)
const costingFileToDelete = ref<CostingFileListEntry | null>(null)
const customerGroupToDelete = ref<CustomerGroup | null>(null)

const memberEmail = ref('')
const memberIsActive = ref(true)
const selectedInvestorId = ref<number | null>(null)

const tenantInvestorsOptions = computed(() =>
  capitalStore.investors.map((item) => ({
    label: item.name,
    value: item.investor_id,
  }))
)

const investorNameById = (id: number) => {
  return capitalStore.investors.find((item) => item.investor_id === id)?.name ?? `#${id}`
}
const selectedMemberRole = ref<TenantMembershipRole>('staff')

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

const showCustomerGroupManagement = computed(() => props.view === 'customer-groups')
const showStaffManagement = computed(() => props.view === 'staff')
const showInvestorManagement = computed(() => props.view === 'investors')
const showModuleManagement = computed(() => props.view === 'modules')
const pageTitle = computed(() => {
  if (props.view === 'staff') {
    return 'Staff Management'
  }
  if (props.view === 'investors') {
    return 'Investor Management'
  }
  if (props.view === 'modules') {
    return 'Enable Modules'
  }
  return 'Customer Group Management'
})

const tenantId = computed(() => Number(route.params.id))

const tenant = computed<Tenant | null>(
  () => items.value.find((item) => item.id === tenantId.value) ?? null,
)

const baseUrl = computed(() =>
  typeof window === 'undefined' ? '' : window.location.origin,
)

const adminLoginUrl = computed(() =>
  tenant.value?.slug ? `${baseUrl.value}/${tenant.value.slug}/app/login` : `${baseUrl.value}/app/login`,
)

const customerLoginUrl = computed(() =>
  tenant.value?.slug ? `${baseUrl.value}/${tenant.value.slug}/shop/login` : `${baseUrl.value}/shop/login`,
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

const viewerMembers = computed(() =>
  tenantMembers.value.filter((member) => member.role === 'viewer'),
)

const investorMembers = computed(() =>
  tenantMembers.value.filter((member) => member.role === 'investor'),
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

const tenantModuleKeys = computed(
  () => new Set(modules.value.map((item) => item.module_key)),
)

const availableModules = computed(() =>
  moduleStore.assignableModules.filter(
    (item) => item.is_active && !tenantModuleKeys.value.has(item.key),
  ),
)

const customerGroupMemberColumns = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const },
  { name: 'role', label: 'Role', field: 'role', align: 'left' as const },
  { name: 'active', label: 'Active', field: 'is_active', align: 'left' as const },
  { name: 'edit', label: 'Actions', field: 'id', align: 'left' as const },
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

  return formatAppDateTime(value, '-')
}

const customerGroupNameById = (customerGroupId: number) =>
  customerGroups.value.find((group) => group.id === customerGroupId)?.name ?? `#${customerGroupId}`

const copyLoginUrl = async (url: string, successMessage: string) => {
  if (!url) {
    return
  }

  try {
    await copyToClipboard(url)
    $q.notify({
      type: 'positive',
      message: successMessage,
    })
  } catch {
    $q.notify({
      type: 'negative',
      message: 'Failed to copy login URL.',
    })
  }
}

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

    tenantMembers.value = result.data ?? []
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to load members.'
    tenantMembers.value = []
  } finally {
    tenantMembersLoading.value = false
  }
}

const loadCostingFiles = async () => {
  if (!showCostingFilesSection) {
    return
  }

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

  const [tenantModulesResult, catalogModulesResult] = await Promise.all([
    tenantModuleStore.fetchTenantModules(tenant.value.id),
    moduleStore.fetchModules(),
  ])

  if (!tenantModulesResult.success) {
    pageError.value = tenantModulesResult.error || 'Failed to load module features.'
    return
  }

  if (!catalogModulesResult.success) {
    pageError.value = catalogModulesResult.error || 'Failed to load module catalog.'
  }
}

const addTenantFeature = async (moduleKey: string) => {
  if (!tenant.value?.id) {
    return
  }

  const result = await tenantModuleStore.createTenantModule({
    tenant_id: tenant.value.id,
    module_key: moduleKey,
    is_active: true,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to add tenant feature.'
  }
}

const removeTenantFeature = async (moduleId: number) => {
  const result = await tenantModuleStore.deleteTenantModule({
    id: moduleId,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to remove tenant feature.'
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
      capitalStore.fetchInvestorsByTenant(tenantId.value),
    ])

    await loadCostingFiles()
  } catch (error) {
    console.error(error)
    pageError.value = 'Failed to load tenant details.'
  } finally {
    pageLoading.value = false
  }
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

const onClickAddMember = (role: TenantMembershipRole) => {
  selectedMemberRole.value = role
  memberEmail.value = ''
  memberIsActive.value = true
  selectedInvestorId.value = route.query.investor_id ? Number(route.query.investor_id) : (capitalStore.investors[0]?.investor_id || null)
  openAddMemberDialog.value = true
}

const handleSaveMember = async () => {
  if (!tenant.value?.id || !memberEmail.value.trim()) return

  const result = await membershipStore.createMembership({
    tenant_id: tenant.value.id,
    email: memberEmail.value,
    role: selectedMemberRole.value,
    is_active: memberIsActive.value,
    investor_id: selectedMemberRole.value === 'investor' ? selectedInvestorId.value : null,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to create member.'
    return
  }

  openAddMemberDialog.value = false
  await loadTenantMembers()
}

watch(
  () => [route.query.investor_id, props.view, capitalStore.investors],
  ([investorId, view, investors]) => {
    if (investorId && view === 'investors' && investors.length > 0 && !openAddMemberDialog.value) {
      onClickAddMember('investor')
    }
  },
  { immediate: true }
)

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
    market: file.market ?? '',
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

const openDeleteCustomerMemberDialog = (member: CustomerGroupMember) => {
  customerGroupMemberToDelete.value = member
  openDeleteCustomerMemberDialogModel.value = true
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

const confirmDeleteCustomerGroupMember = async () => {
  if (!customerGroupMemberToDelete.value || !selectedCustomerGroup.value) {
    return
  }

  const deletedId = customerGroupMemberToDelete.value.id

  const result = await customerGroupStore.deleteCustomerGroupMember({
    id: deletedId,
  })

  if (!result.success) {
    pageError.value = result.error ?? 'Failed to delete customer group member.'
    return
  }

  customerGroupStore.members = customerGroupMembers.value.filter(
    (member) => member.id !== deletedId,
  )
  customerGroupMembersByGroupId.value = {
    ...customerGroupMembersByGroupId.value,
    [selectedCustomerGroup.value.id]: [...customerGroupStore.members],
  }

  openDeleteCustomerMemberDialogModel.value = false
  customerGroupMemberToDelete.value = null
}

onMounted(() => {
  void loadPageData()
})
</script>

<style scoped>
.admin-tenant-management-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.inner-card {
  border-radius: 12px;
  border: 1px solid rgba(34, 56, 101, 0.06);
  background: rgba(255, 255, 255, 0.5);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.05);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.costing-list-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

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
