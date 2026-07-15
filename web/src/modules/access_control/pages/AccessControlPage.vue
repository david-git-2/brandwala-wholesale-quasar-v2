<template>
  <q-page class="q-pa-md admin-access-control-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold">Access Control</div>
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
              <span
                class="status-dot"
                :style="{ backgroundColor: tenant?.is_active ? '#2f8b5d' : '#66758c' }"
              />
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
        <!-- Main Content Area -->
        <div class="col-12">
          <q-tab-panels
            v-model="activeTab"
            animated
            swipeable
            vertical
            transition-prev="jump-up"
            transition-next="jump-up"
            class="bg-transparent"
          >
            <!-- 1. MODULES PANEL -->
            <q-tab-panel name="modules" class="q-pa-none">
              <q-card flat class="floating-surface shadow-1">
                <q-card-section class="row items-center justify-between">
                  <div>
                    <div class="text-subtitle1 text-weight-bold text-grey-9">Module Features</div>
                    <div class="text-caption text-grey-7">
                      Manage which modules are active for this workspace.
                    </div>
                  </div>
                </q-card-section>

                <q-separator />

                <q-card-section v-if="modulesLoading" class="text-grey-7">
                  Loading module features...
                </q-card-section>

                <q-card-section v-else>
                  <div class="row q-col-gutter-md">
                    <div v-if="canManageModules" class="col-12 col-md-6">
                      <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-8">
                        Available Features
                      </div>
                      <q-list bordered separator class="rounded-borders">
                        <template v-for="feature in availableModules" :key="feature.key">
                          <q-item>
                            <q-item-section>
                              <q-item-label class="text-weight-medium">{{
                                feature.name
                              }}</q-item-label>
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
                          <div
                            v-if="moduleStore.submodulesOf(feature.key).length > 0"
                            class="q-pl-lg q-pb-sm q-pr-md"
                          >
                            <div class="text-caption text-grey-7 q-mb-xs">Includes submodules:</div>
                            <q-list dense bordered class="bg-grey-1 rounded-borders">
                              <q-item
                                v-for="sub in moduleStore.submodulesOf(feature.key)"
                                :key="sub.key"
                                class="q-py-xs"
                              >
                                <q-item-section>
                                  <q-item-label class="text-caption text-weight-medium text-grey-8">{{ sub.name }}</q-item-label>
                                  <q-item-label caption class="text-caption">{{ sub.key }}</q-item-label>
                                </q-item-section>
                              </q-item>
                            </q-list>
                          </div>
                        </template>
                        <q-item v-if="availableModules.length === 0">
                          <q-item-section class="text-grey-7">No available features.</q-item-section>
                        </q-item>
                      </q-list>
                    </div>

                    <div :class="canManageModules ? 'col-12 col-md-6' : 'col-12'">
                      <div class="text-subtitle2 text-weight-bold q-mb-sm text-grey-8">
                        Workspace Features
                      </div>
                      <q-list bordered separator class="rounded-borders">
                        <template v-for="feature in modules" :key="feature.id">
                          <q-item>
                            <q-item-section>
                              <q-item-label class="text-weight-medium">{{
                                formatModuleKey(feature.module_key)
                              }}</q-item-label>
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
                            v-if="
                              tenantId && moduleStore.submodulesOf(feature.module_key).length > 0
                            "
                            :tenant-id="tenantId"
                            :parent-module-key="feature.module_key"
                            :read-only="!canManageModules"
                          />
                        </template>
                        <q-item v-if="modules.length === 0">
                          <q-item-section class="text-grey-7"
                            >No workspace features assigned.</q-item-section
                          >
                        </q-item>
                      </q-list>
                    </div>
                  </div>
                </q-card-section>
              </q-card>
            </q-tab-panel>

            <!-- 2. ROLES PANEL -->
            <q-tab-panel name="roles" class="q-pa-none">
              <div class="column q-gutter-md">
                <!-- Roles Header & Scope Selector -->
                <q-card flat class="floating-surface shadow-1">
                  <q-card-section class="row items-center justify-between q-py-sm">
                    <div>
                      <div class="text-subtitle1 text-weight-bold text-grey-9">
                        Workspace & Shop Roles
                      </div>
                      <div class="text-caption text-grey-7">
                        Define scopes of authority and grant rules for members.
                      </div>
                    </div>
                    <div class="row q-gutter-sm items-center">
                      <q-btn-toggle
                        v-model="rolesScopeFilter"
                        toggle-color="primary"
                        color="grey-2"
                        text-color="grey-8"
                        dense
                        no-caps
                        unelevated
                        :options="[
                          { label: 'Workspace Roles', value: 'app' },
                          { label: 'Shop Roles', value: 'shop' },
                        ]"
                      />
                      <q-btn
                        color="primary"
                        class="pill-btn"
                        no-caps
                        icon="add"
                        label="Add Role"
                        @click="openCreateRoleDialog"
                      />
                    </div>
                  </q-card-section>
                </q-card>

                <!-- Roles Grid -->
                <div v-if="rolesLoading" class="row justify-center q-my-lg">
                  <q-spinner-dots size="40px" color="primary" />
                </div>

                <div
                  v-else-if="filteredRoles.length === 0"
                  class="text-center text-grey-7 q-pa-xl floating-surface bg-white shadow-1"
                >
                  <q-icon name="admin_panel_settings" size="48px" class="q-mb-sm" />
                  <div>No roles found for the selected scope.</div>
                </div>

                <div v-else class="row q-col-gutter-md">
                  <div
                    v-for="role in filteredRoles"
                    :key="role.id"
                    class="col-12 col-sm-6 col-lg-4"
                  >
                    <q-card
                      flat
                      class="floating-surface shadow-1 full-height column justify-between"
                    >
                      <q-card-section>
                        <div class="row items-center justify-between q-mb-sm">
                          <div class="text-subtitle2 text-weight-bold text-grey-9">
                            {{ role.name }}
                          </div>
                          <div class="row q-gutter-xs">
                            <q-chip
                              v-if="role.is_system"
                              label="System"
                              dense
                              color="blue-2"
                              text-color="blue-9"
                            />
                            <q-chip
                              v-if="role.is_admin"
                              label="Admin"
                              dense
                              color="purple-2"
                              text-color="purple-9"
                            />
                          </div>
                        </div>
                        <div class="text-caption text-grey-6 q-mb-md">Slug: {{ role.slug }}</div>
                        <div class="text-caption text-grey-7">
                          {{
                            role.is_admin
                              ? 'Implicit access to all workspace actions.'
                              : 'Access rules are configurable via the grants matrix.'
                          }}
                        </div>
                      </q-card-section>

                      <div>
                        <q-separator />
                        <q-card-actions class="justify-between">
                          <div>
                            <q-btn
                              v-if="!role.is_admin"
                              flat
                              no-caps
                              color="primary"
                              icon="admin_panel_settings"
                              label="Configure Grants"
                              @click="navigateToGrants(role.id)"
                            />
                            <span v-else class="text-caption text-grey-5 q-px-sm">Full Access</span>
                          </div>
                          <div class="row q-gutter-xs">
                            <q-btn
                              v-if="!role.is_system"
                              flat
                              round
                              dense
                              icon="edit"
                              color="grey-7"
                              @click="openEditRoleDialog(role)"
                            />
                            <q-btn
                              v-if="!role.is_system"
                              flat
                              round
                              dense
                              icon="delete"
                              color="negative"
                              @click="openDeleteRoleDialog(role)"
                            />
                          </div>
                        </q-card-actions>
                      </div>
                    </q-card>
                  </div>
                </div>
              </div>
            </q-tab-panel>

            <!-- 3. TEAM PANEL -->
            <q-tab-panel name="team" class="q-pa-none">
              <q-card flat class="floating-surface shadow-1">
                <q-card-section class="row items-center justify-between">
                  <div>
                    <div class="text-subtitle1 text-weight-bold text-grey-9">
                      Workspace Team & Members
                    </div>
                    <div class="text-caption text-grey-7">
                      Manage internal members, role assignments, and member-level overrides.
                    </div>
                  </div>
                  <div class="row items-center q-gutter-sm">
                    <q-btn
                      color="primary"
                      class="pill-btn slim-btn"
                      no-caps
                      size="sm"
                      icon="person_add"
                      label="Add Member"
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
                  <!-- Staff Section -->
                  <div class="text-subtitle2 text-grey-8 q-mb-sm">Staff & Admins</div>
                  <q-table
                    v-if="staffMembers.length"
                    flat
                    row-key="id"
                    :rows="staffMembers"
                    :columns="internalMemberColumns"
                    hide-bottom
                    class="costing-list-table border-bottom"
                  >
                    <template #body-cell-email="props">
                      <q-td :props="props">
                        <div class="row items-center q-gutter-xs">
                          <span>{{ props.row.email }}</span>
                          <q-chip
                            v-if="hasOverridesMap[props.row.id]"
                            label="Custom"
                            dense
                            color="orange-2"
                            text-color="orange-9"
                            icon="shield"
                          />
                        </div>
                      </q-td>
                    </template>

                    <template #body-cell-role="props">
                      <q-td :props="props">
                        <q-select
                          v-if="props.row.tenant_role_id !== undefined"
                          :model-value="props.row.tenant_role_id"
                          :options="appRoles.map((r) => ({ label: r.name, value: r.id }))"
                          emit-value
                          map-options
                          outlined
                          dense
                          options-dense
                          style="min-width: 150px"
                          @update:model-value="(val) => onChangeMemberRole(props.row, val)"
                        />
                        <span v-else>{{ props.row.role }}</span>
                      </q-td>
                    </template>

                    <template #body-cell-overrides="props">
                      <q-td :props="props">
                        <q-btn
                          size="sm"
                          color="primary"
                          flat
                          no-caps
                          icon="admin_panel_settings"
                          label="Grants"
                          @click="openOverridesDialog(props.row, 'app')"
                        />
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
                          v-if="props.row.role !== 'admin'"
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
                  <div v-else class="text-grey-6 q-pa-sm">No staff found.</div>

                  <q-separator class="q-my-lg" />

                  <!-- Viewers Section -->
                  <div class="text-subtitle2 text-grey-8 q-mb-xs">Viewers</div>
                  <div class="text-caption text-grey-7 q-mb-sm">
                    Viewers can access assigned costing files with read-only access.
                  </div>

                  <q-table
                    v-if="viewerMembers.length"
                    flat
                    row-key="id"
                    :rows="viewerMembers"
                    :columns="internalMemberColumns"
                    hide-bottom
                    class="costing-list-table"
                  >
                    <template #body-cell-email="props">
                      <q-td :props="props">
                        <div class="row items-center q-gutter-xs">
                          <span>{{ props.row.email }}</span>
                          <q-chip
                            v-if="hasOverridesMap[props.row.id]"
                            label="Custom"
                            dense
                            color="orange-2"
                            text-color="orange-9"
                            icon="shield"
                          />
                        </div>
                      </q-td>
                    </template>

                    <template #body-cell-role="props">
                      <q-td :props="props">
                        <q-select
                          v-if="props.row.tenant_role_id !== undefined"
                          :model-value="props.row.tenant_role_id"
                          :options="appRoles.map((r) => ({ label: r.name, value: r.id }))"
                          emit-value
                          map-options
                          outlined
                          dense
                          options-dense
                          style="min-width: 150px"
                          @update:model-value="(val) => onChangeMemberRole(props.row, val)"
                        />
                        <span v-else>{{ props.row.role }}</span>
                      </q-td>
                    </template>

                    <template #body-cell-overrides="props">
                      <q-td :props="props">
                        <q-btn
                          size="sm"
                          color="primary"
                          flat
                          no-caps
                          icon="admin_panel_settings"
                          label="Grants"
                          @click="openOverridesDialog(props.row, 'app')"
                        />
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
                          v-if="props.row.role !== 'admin'"
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
                  <div v-else class="text-grey-6 q-pa-sm">No viewers found.</div>
                </q-card-section>
              </q-card>
            </q-tab-panel>

            <!-- 4. CUSTOMER GROUPS PANEL -->
            <q-tab-panel name="customer-groups" class="q-pa-none">
              <div class="row q-col-gutter-md">
                <!-- Left Sidebar: Customer Groups -->
                <div class="col-12 col-md-5 col-lg-4">
                  <q-card flat class="floating-surface shadow-1">
                    <q-card-section class="row items-center justify-between q-py-sm">
                      <div>
                        <div class="text-subtitle2 text-weight-bold text-grey-9">
                          Customer Groups
                        </div>
                        <div class="text-caption text-grey-7">Group by company/buying team.</div>
                      </div>
                      <q-btn
                        color="primary"
                        class="pill-btn slim-btn"
                        no-caps
                        size="sm"
                        icon="groups"
                        label="Add"
                        @click="openCreateGroupDialog"
                      />
                    </q-card-section>

                    <q-separator />

                    <q-card-section v-if="customerGroupsLoading" class="text-grey-7 text-center">
                      <q-spinner-dots size="30px" color="primary" />
                    </q-card-section>

                    <q-card-section
                      v-else-if="customerGroups.length === 0"
                      class="text-grey-7 text-center"
                    >
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
                          <q-item-label class="text-weight-bold text-grey-8">{{
                            group.name
                          }}</q-item-label>
                          <q-item-label caption>
                            #{{ group.id }} · {{ group.is_active ? 'Active' : 'Inactive' }}
                          </q-item-label>
                        </q-item-section>

                        <q-item-section side>
                          <div class="row items-center q-gutter-xs">
                            <q-btn
                              flat
                              round
                              dense
                              icon="o_edit"
                              @click.stop="openEditGroupDialog(group)"
                            />
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

                <!-- Right Side: Selected Group Members & Shop Access -->
                <div class="col-12 col-md-7 col-lg-8">
                  <q-card flat class="floating-surface shadow-1">
                    <q-card-section class="row items-center justify-between">
                      <div>
                        <div class="text-subtitle1 text-weight-bold text-grey-9">
                          Customer Group Members
                        </div>
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

                    <q-card-section
                      v-if="!selectedCustomerGroup"
                      class="text-grey-7 text-center q-pa-lg"
                    >
                      Select a customer group from the list on the left to manage members and shop
                      configurations.
                    </q-card-section>

                    <template v-else>
                      <!-- Group Summary & Status -->
                      <q-card-section class="row items-center justify-between q-py-sm">
                        <div class="row items-center q-gutter-sm">
                          <div
                            class="customer-group-chip customer-group-chip--large"
                            :style="{
                              backgroundColor: selectedCustomerGroup.accent_color || '#B45F34',
                            }"
                          />
                          <div>
                            <div class="text-subtitle2 text-weight-bold">
                              {{ selectedCustomerGroup.name }}
                            </div>
                            <div class="text-caption text-grey-7">
                              ID: #{{ selectedCustomerGroup.id }}
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

                      <q-separator />

                      <!-- Customer Group Members Table -->
                      <q-card-section
                        v-if="customerGroupMembersLoading"
                        class="text-center text-grey-7"
                      >
                        <q-spinner-dots size="30px" color="primary" />
                      </q-card-section>

                      <q-card-section
                        v-else-if="customerGroupMembers.length === 0"
                        class="text-grey-7 text-center"
                      >
                        No members found for this customer group.
                      </q-card-section>

                      <q-card-section v-else class="q-pa-none">
                        <q-table
                          flat
                          row-key="id"
                          :rows="sortedCustomerGroupMembers"
                          :columns="customerGroupMemberColumns"
                          :pagination="{ rowsPerPage: 0 }"
                          hide-bottom
                          class="costing-list-table"
                        >
                          <template #body-cell-email="props">
                            <q-td :props="props">
                              <div class="row items-center q-gutter-xs">
                                <span>{{ props.row.email }}</span>
                                <q-chip
                                  v-if="hasCgmOverridesMap[props.row.id]"
                                  label="Custom"
                                  dense
                                  color="orange-2"
                                  text-color="orange-9"
                                  icon="shield"
                                />
                              </div>
                            </q-td>
                          </template>

                          <template #body-cell-role="props">
                            <q-td :props="props">
                              <q-select
                                v-if="props.row.tenant_role_id !== undefined"
                                :model-value="props.row.tenant_role_id"
                                :options="shopRoles.map((r) => ({ label: r.name, value: r.id }))"
                                emit-value
                                map-options
                                outlined
                                dense
                                options-dense
                                style="min-width: 150px"
                                @update:model-value="
                                  (val) => onChangeCustomerMemberRole(props.row, val)
                                "
                              />
                              <span v-else>{{ formatCustomerRole(props.row.role) }}</span>
                            </q-td>
                          </template>

                          <template #body-cell-overrides="props">
                            <q-td :props="props">
                              <q-btn
                                size="sm"
                                color="primary"
                                flat
                                no-caps
                                icon="admin_panel_settings"
                                label="Grants"
                                @click="openOverridesDialog(props.row, 'shop')"
                              />
                            </q-td>
                          </template>

                          <template #body-cell-active="props">
                            <q-td :props="props">
                              <q-toggle
                                :model-value="props.row.is_active"
                                color="positive"
                                keep-color
                                @update:model-value="
                                  (value) => onToggleCustomerGroupMemberActive(props.row, value)
                                "
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
                      </q-card-section>
                    </template>
                  </q-card>
                </div>
              </div>
            </q-tab-panel>

            <!-- 5. INVESTORS PANEL -->
            <q-tab-panel name="investors" class="q-pa-none">
              <q-card flat class="floating-surface shadow-1">
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

                <q-card-section
                  v-else-if="investorMembers.length === 0"
                  class="text-grey-7 text-center"
                >
                  No investor members found.
                </q-card-section>

                <q-card-section v-else>
                  <q-table
                    flat
                    row-key="id"
                    :rows="investorMembers"
                    :columns="internalMemberColumns"
                    hide-bottom
                    class="costing-list-table"
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

                    <template #body-cell-overrides="props">
                      <q-td :props="props">
                        <span>-</span>
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
                          v-if="props.row.role !== 'admin'"
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
            </q-tab-panel>
          </q-tab-panels>
        </div>
      </div>
    </template>

    <!-- ========================================================= -->
    <!-- DIALOGS & OVERLAYS                                        -->
    <!-- ========================================================= -->

    <!-- Add/Edit Role Dialog -->
    <q-dialog v-model="roleDialogOpen" persistent>
      <q-card style="min-width: 380px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-weight-bold">{{ isRoleEdit ? 'Edit Role' : 'Create Role' }}</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-py-md">
          <q-input
            v-model="roleForm.name"
            label="Role Name"
            outlined
            dense
            class="q-mb-md soft-input"
            :rules="[(val) => !!val || 'Name is required']"
          />

          <q-input
            v-model="roleForm.slug"
            label="Role Slug"
            outlined
            dense
            class="q-mb-md soft-input"
            hint="Lowercase alphanumeric and hyphens only (e.g. tech-staff)"
            :disable="isRoleEdit"
            :rules="[
              (val) => !!val || 'Slug is required',
              (val) => /^[a-z0-9-]+$/.test(val) || 'Invalid slug format',
            ]"
          />

          <q-toggle
            v-model="roleForm.is_admin"
            label="Administrator Role (Implicit Full Access)"
            color="purple"
            class="q-mb-sm"
            :disable="isRoleEdit && selectedRole?.is_system"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            class="pill-btn"
            no-caps
            :label="isRoleEdit ? 'Save' : 'Create'"
            :loading="roleSubmitting"
            @click="saveRole"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Delete Role Dialog -->
    <q-dialog v-model="roleDeleteDialogOpen" persistent>
      <q-card style="min-width: 350px; border-radius: 12px">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-subtitle1 text-weight-bold">Delete Role</span>
        </q-card-section>

        <q-card-section class="q-pt-none">
          Are you sure you want to delete the role <strong>{{ selectedRole?.name }}</strong
          >? This action cannot be undone.
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            class="pill-btn"
            no-caps
            label="Delete"
            :loading="roleDeleting"
            @click="confirmDeleteRole"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Overrides Dialog -->
    <q-dialog v-model="overridesDialogOpen" persistent>
      <q-card style="min-width: 520px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div>
            <div class="text-h6 text-weight-bold">Access Overrides</div>
            <div class="text-caption text-grey-7">
              Configure explicit Allow/Deny overrides for
              <strong>{{ overridesDialogMember?.email }}</strong
              >.
            </div>
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-py-md">
          <div v-if="overridesLoading" class="row justify-center q-my-md">
            <q-spinner-dots size="30px" color="primary" />
          </div>
          <div v-else-if="overridesActions.length === 0" class="text-center text-grey-6 q-my-md">
            No configurable modules active for this workspace.
          </div>
          <div v-else style="max-height: 400px; overflow-y: auto">
            <q-list separator>
              <q-item v-for="act in overridesActions" :key="act.id">
                <q-item-section>
                  <q-item-label class="text-weight-medium text-grey-8">
                    {{ formatModuleKey(act.module_key) }} × {{ act.action }}
                  </q-item-label>
                  <q-item-label caption class="text-grey-6">
                    {{ act.description || 'No description' }}
                  </q-item-label>
                </q-item-section>

                <q-item-section side>
                  <q-btn-toggle
                    :model-value="overridesGrants[`${act.module_key}:${act.action}`] || 'inherit'"
                    toggle-color="primary"
                    color="grey-3"
                    text-color="grey-8"
                    dense
                    no-caps
                    unelevated
                    :options="[
                      { label: 'Inherit', value: 'inherit' },
                      { label: 'Allow', value: 'allow' },
                      { label: 'Deny', value: 'deny' },
                    ]"
                    :disable="overridesSavingMap[`${act.module_key}:${act.action}`]"
                    @update:model-value="(val) => toggleOverride(act.module_key, act.action, val)"
                  />
                </q-item-section>
              </q-item>
            </q-list>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Close" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Add/Edit Internal Member Dialog -->
    <q-dialog v-model="openAddMemberDialog" persistent>
      <q-card style="min-width: 420px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-weight-bold">
            {{
              selectedMemberRole === 'viewer'
                ? 'Add Viewer'
                : selectedMemberRole === 'investor'
                  ? 'Add Investor'
                  : selectedMemberRole === 'admin'
                    ? 'Add Admin'
                    : 'Add Staff'
            }}
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-py-md q-gutter-md">
          <q-input
            v-model="memberEmail"
            label="Email"
            type="email"
            outlined
            dense
            class="soft-input"
          />
          <q-select
            v-model="selectedMemberRole"
            outlined
            dense
            label="Role"
            :options="memberRoleOptions"
            emit-value
            map-options
            class="soft-input"
          />

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
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            unelevated
            class="pill-btn"
            no-caps
            label="Save"
            @click="handleSaveMember"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Delete Internal Member Dialog -->
    <q-dialog v-model="openDeleteMemberDialog" persistent>
      <q-card style="min-width: 350px; border-radius: 12px">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-subtitle1 text-weight-bold">Confirm Delete</span>
        </q-card-section>

        <q-card-section class="q-pt-none">
          Are you sure you want to delete member
          <strong>{{ memberToDelete?.email }}</strong
          >?
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            class="pill-btn"
            no-caps
            label="Delete"
            @click="confirmDeleteMember"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Create/Edit Customer Group Dialog -->
    <q-dialog v-model="openCustomerGroupDialog" persistent>
      <q-card style="min-width: 400px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-weight-bold">
            {{ customerGroupForm.id ? 'Edit Customer Group' : 'Create Customer Group' }}
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-py-md q-gutter-md">
          <q-input
            v-model="customerGroupForm.name"
            label="Group Name"
            outlined
            dense
            class="soft-input"
          />
          <q-input
            v-model="customerGroupForm.accentColor"
            label="Accent Color Hex (e.g. #B45F34)"
            outlined
            dense
            class="soft-input"
          />
          <div class="row items-center justify-between">
            <div class="text-subtitle2 text-grey-8">Status</div>
            <q-toggle
              v-model="customerGroupForm.isActive"
              :label="customerGroupForm.isActive ? 'Active' : 'Inactive'"
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
            class="pill-btn"
            no-caps
            label="Save"
            @click="handleSaveCustomerGroup"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Delete Customer Group Dialog -->
    <q-dialog v-model="openDeleteCustomerGroupDialog" persistent>
      <q-card style="min-width: 350px; border-radius: 12px">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-subtitle1 text-weight-bold">Delete Customer Group</span>
        </q-card-section>

        <q-card-section class="q-pt-none">
          Are you sure you want to delete customer group
          <strong>{{ customerGroupToDelete?.name }}</strong
          >? This will delete all members inside this group.
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            class="pill-btn"
            no-caps
            label="Delete"
            @click="confirmDeleteCustomerGroup"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Add/Edit Customer Member Dialog -->
    <q-dialog v-model="openCustomerMemberDialog" persistent>
      <q-card style="min-width: 440px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-weight-bold">
            {{
              customerGroupMemberForm.id
                ? 'Edit Customer Group Member'
                : 'Add Customer Group Member'
            }}
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-py-md q-gutter-md">
          <q-input
            v-model="customerGroupMemberForm.email"
            label="Email"
            outlined
            dense
            class="soft-input"
            :disable="!!customerGroupMemberForm.id"
          />
          <q-input
            v-model="customerGroupMemberForm.name"
            label="Name (Optional)"
            outlined
            dense
            class="soft-input"
          />

          <div class="row items-center justify-between">
            <div class="text-subtitle2 text-grey-8">Status</div>
            <q-toggle
              v-model="customerGroupMemberForm.isActive"
              :label="customerGroupMemberForm.isActive ? 'Active' : 'Inactive'"
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
            class="pill-btn"
            no-caps
            label="Save"
            @click="handleSaveCustomerGroupMember"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Delete Customer Member Dialog -->
    <q-dialog v-model="openDeleteCustomerMemberDialogModel" persistent>
      <q-card style="min-width: 350px; border-radius: 12px">
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-subtitle1 text-weight-bold">Confirm Delete</span>
        </q-card-section>

        <q-card-section class="q-pt-none">
          Are you sure you want to delete customer user
          <strong>{{ customerGroupMemberToDelete?.email }}</strong
          >?
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            class="pill-btn"
            no-caps
            label="Delete"
            @click="confirmDeleteCustomerGroupMember"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { supabase } from 'src/boot/supabase';
import { showSuccessNotification } from 'src/utils/appFeedback';
import { useRouter, useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';

import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useMembershipStore } from 'src/modules/membership/stores/membershipStore';
import type { Membership, TenantMembershipRole } from 'src/modules/membership/types';
import { useModuleStore } from 'src/modules/featureCatalog/stores/moduleStore';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import { useTenantModuleStore } from 'src/modules/tenant/stores/tenantModuleStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import SubmoduleAccessPanel from 'src/modules/tenant/components/SubmoduleAccessPanel.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type {
  CustomerGroup,
  CustomerGroupMember,
  Tenant,
  CustomerGroupRole,
} from 'src/modules/tenant/types';

// Styling helpers
const activeStatusStyle = {
  backgroundColor: '#c3e8d2',
  color: '#1f5d3c',
  border: '1px solid #9fd4b7',
  boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
};

const inactiveStatusStyle = {
  backgroundColor: '#dbe5f3',
  color: '#3b4b66',
  border: '1px solid #b9c8dd',
  boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
};

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

// Main stores
const tenantStore = useTenantStore();
const tenantModuleStore = useTenantModuleStore();
const moduleStore = useModuleStore();
const membershipStore = useMembershipStore();
const customerGroupStore = useCustomerGroupStore();

const tenantId = computed(() => authStore.tenantId);
const tenant = computed<Tenant | null>(
  () => tenantStore.items.find((t) => t.id === tenantId.value) || null,
);

const pageLoading = ref(false);
const pageError = ref<string | null>(null);
const activeTab = computed(() => String(route.params.tab || 'modules'));

// Superadmin bypass check
const canManageModules = computed(() => {
  return authStore.matchedRole === 'superadmin' && authStore.scope === 'platform';
});

// Stores data
const { items: modules, loading: modulesLoading } = storeToRefs(tenantModuleStore);
const {
  groups: customerGroups,
  members: customerGroupMembers,
  loading: customerGroupsLoading,
  membersLoading: customerGroupMembersLoading,
} = storeToRefs(customerGroupStore);

// -------------------------------------------------------------
// 1. MODULES FUNCTIONALITY
// -------------------------------------------------------------
const allCatalogModules = ref<any[]>([]);

const loadTenantModules = async () => {
  if (!tenantId.value) return;
  await tenantModuleStore.fetchTenantModules(tenantId.value);
  const { data } = await supabase.from('modules').select('*');
  allCatalogModules.value = data || [];
};

const availableModules = computed(() => {
  const activeKeys = modules.value.map((m) => m.module_key);
  return allCatalogModules.value.filter(
    (m) => !m.parent_module_key && !activeKeys.includes(m.key),
  );
});

const addTenantFeature = async (moduleKey: string) => {
  if (!tenantId.value) return;
  const { error } = await supabase.from('tenant_modules').insert({
    tenant_id: tenantId.value,
    module_key: moduleKey,
    is_active: true,
  });
  if (error) {
    pageError.value = error.message;
  } else {
    showSuccessNotification('Feature added successfully.');
    await loadTenantModules();
  }
};

const removeTenantFeature = async (id: number) => {
  const { error } = await supabase.from('tenant_modules').delete().eq('id', id);
  if (error) {
    pageError.value = error.message;
  } else {
    showSuccessNotification('Feature removed successfully.');
    await loadTenantModules();
  }
};

const formatModuleKey = (key: string): string => {
  return key
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

// -------------------------------------------------------------
// 2. ROLES FUNCTIONALITY
// -------------------------------------------------------------
const rolesScopeFilter = ref<'app' | 'shop'>('app');
const allRoles = ref<any[]>([]);
const rolesLoading = ref(false);
const roleDialogOpen = ref(false);
const roleDeleteDialogOpen = ref(false);
const isRoleEdit = ref(false);
const selectedRole = ref<any>(null);
const roleSubmitting = ref(false);
const roleDeleting = ref(false);

const roleForm = ref({
  name: '',
  slug: '',
  is_admin: false,
});

const loadRoles = async () => {
  if (!tenantId.value) return;
  rolesLoading.value = true;
  try {
    const { data: appData } = await supabase.rpc('list_tenant_roles', {
      p_tenant_id: tenantId.value,
      p_scope: 'app',
    });
    const { data: shopData } = await supabase.rpc('list_tenant_roles', {
      p_tenant_id: tenantId.value,
      p_scope: 'shop',
    });
    allRoles.value = [...(appData || []), ...(shopData || [])];
  } catch (err: any) {
    console.error('Failed to load roles:', err);
  } finally {
    rolesLoading.value = false;
  }
};

const filteredRoles = computed(() => {
  return allRoles.value.filter((r) => r.scope === rolesScopeFilter.value);
});

const appRoles = computed(() => allRoles.value.filter((r) => r.scope === 'app'));
const shopRoles = computed(() => allRoles.value.filter((r) => r.scope === 'shop'));

const openCreateRoleDialog = () => {
  isRoleEdit.value = false;
  selectedRole.value = null;
  roleForm.value = {
    name: '',
    slug: '',
    is_admin: false,
  };
  roleDialogOpen.value = true;
};

const openEditRoleDialog = (role: any) => {
  isRoleEdit.value = true;
  selectedRole.value = role;
  roleForm.value = {
    name: role.name,
    slug: role.slug,
    is_admin: role.is_admin,
  };
  roleDialogOpen.value = true;
};

const openDeleteRoleDialog = (role: any) => {
  selectedRole.value = role;
  roleDeleteDialogOpen.value = true;
};

const saveRole = async () => {
  if (!tenantId.value || !roleForm.value.name.trim() || !roleForm.value.slug.trim()) return;
  roleSubmitting.value = true;
  try {
    if (isRoleEdit.value && selectedRole.value) {
      const { error } = await supabase.rpc('update_tenant_role', {
        p_role_id: selectedRole.value.id,
        p_name: roleForm.value.name,
        p_is_admin: roleForm.value.is_admin,
      });
      if (error) throw error;
      showSuccessNotification('Role updated successfully.');
    } else {
      const { error } = await supabase.rpc('create_tenant_role', {
        p_tenant_id: tenantId.value,
        p_scope: rolesScopeFilter.value,
        p_name: roleForm.value.name,
        p_slug: roleForm.value.slug,
        p_is_admin: roleForm.value.is_admin,
      });
      if (error) throw error;
      showSuccessNotification('Role created successfully.');
    }
    roleDialogOpen.value = false;
    await loadRoles();
  } catch (err: any) {
    pageError.value = err.message || 'Failed to save role';
  } finally {
    roleSubmitting.value = false;
  }
};

const confirmDeleteRole = async () => {
  if (!selectedRole.value) return;
  roleDeleting.value = true;
  try {
    const { error } = await supabase.rpc('delete_tenant_role', {
      p_role_id: selectedRole.value.id,
    });
    if (error) throw error;
    showSuccessNotification('Role deleted successfully.');
    roleDeleteDialogOpen.value = false;
    await loadRoles();
  } catch (err: any) {
    pageError.value = err.message || 'Failed to delete role';
  } finally {
    roleDeleting.value = false;
  }
};

const navigateToGrants = (roleId: number) => {
  const tenantSlug = authStore.tenantSlug;
  if (tenantSlug) {
    void router.push(`/${tenantSlug}/app/access-control/roles/${roleId}/grants`);
  } else {
    void router.push(`/app/access-control/roles/${roleId}/grants`);
  }
};

// -------------------------------------------------------------
// 3. TEAM FUNCTIONALITY (App Members)
// -------------------------------------------------------------
const tenantMembers = ref<Membership[]>([]);
const tenantMembersLoading = ref(false);
const openAddMemberDialog = ref(false);
const openDeleteMemberDialog = ref(false);
const memberToDelete = ref<Membership | null>(null);
const memberEmail = ref('');
const selectedMemberRole = ref<TenantMembershipRole>('staff');
const memberRoleOptions = [
  { label: 'Admin', value: 'admin' },
  { label: 'Staff', value: 'staff' },
  { label: 'Viewer', value: 'viewer' },
  { label: 'Investor', value: 'investor' },
];
const selectedInvestorId = ref<number | null>(null);
const memberIsActive = ref(true);

// Overrides tracking
const hasOverridesMap = ref<Record<number, boolean>>({});

const loadTenantMembers = async () => {
  if (!tenantId.value) return;
  tenantMembersLoading.value = true;
  try {
    const result = await membershipStore.fetchMembershipsByTenantId(tenantId.value);
    if (result.success) {
      tenantMembers.value = result.data ?? [];
      const { data } = await supabase.rpc('list_membership_ids_with_overrides', {
        p_tenant_id: tenantId.value,
      });
      const ids = new Set((data || []).map((row: any) => row.membership_id));
      hasOverridesMap.value = tenantMembers.value.reduce(
        (acc, m) => {
          acc[m.id] = ids.has(m.id);
          return acc;
        },
        {} as Record<number, boolean>,
      );
    }
  } catch (err) {
    console.error(err);
  } finally {
    tenantMembersLoading.value = false;
  }
};

const staffMembers = computed(() => {
  return tenantMembers.value.filter((m) => m.role === 'admin' || m.role === 'staff');
});

const viewerMembers = computed(() => {
  return tenantMembers.value.filter((m) => m.role === 'viewer');
});

const investorMembers = computed(() => {
  return tenantMembers.value.filter((m) => m.role === 'investor');
});

const internalMemberColumns = [
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const },
  { name: 'role', label: 'Role Template', field: 'role', align: 'left' as const },
  { name: 'overrides', label: 'Custom Overrides', field: 'id', align: 'center' as const },
  { name: 'active', label: 'Status', field: 'is_active', align: 'center' as const },
  { name: 'delete', label: 'Actions', field: 'id', align: 'center' as const },
];

const onClickAddMember = (roleType: TenantMembershipRole) => {
  selectedMemberRole.value = roleType;
  memberEmail.value = '';
  selectedInvestorId.value = null;
  memberIsActive.value = true;
  openAddMemberDialog.value = true;
};

const handleSaveMember = async () => {
  if (!tenantId.value || !memberEmail.value.trim()) return;
  try {
    const result = await membershipStore.createMembership({
      tenant_id: tenantId.value,
      email: memberEmail.value,
      role: selectedMemberRole.value,
      is_active: memberIsActive.value,
      investor_id: selectedInvestorId.value || null,
    });
    if (result.success) {
      showSuccessNotification('Member added successfully.');
      openAddMemberDialog.value = false;
      await loadTenantMembers();
    } else {
      pageError.value = result.error || 'Failed to save member.';
    }
  } catch (err) {
    console.error(err);
  }
};

const onChangeMemberRole = async (member: any, roleId: number) => {
  try {
    const { error } = await supabase.rpc('assign_membership_role', {
      p_membership_id: member.id,
      p_tenant_role_id: roleId,
    });
    if (error) {
      pageError.value = error.message;
      await loadTenantMembers();
    } else {
      showSuccessNotification('Member role updated successfully.');
      await loadTenantMembers();
    }
  } catch (err) {
    console.error(err);
    pageError.value = 'Failed to update member role.';
  }
};

const onToggleMemberActive = async (member: Membership, isActive: boolean) => {
  try {
    const result = await membershipStore.updateMembership({
      ...member,
      is_active: isActive,
    });
    if (!result.success) {
      pageError.value = result.error || 'Failed to update member active status.';
      member.is_active = !isActive;
    } else {
      showSuccessNotification('Member status updated.');
    }
  } catch (error) {
    console.error(error);
    member.is_active = !isActive;
  }
};

const onClickDeleteMember = (member: Membership) => {
  if (member.role === 'admin') return;
  memberToDelete.value = member;
  openDeleteMemberDialog.value = true;
};

const confirmDeleteMember = async () => {
  if (!memberToDelete.value) return;
  if (memberToDelete.value.role === 'admin') return;
  try {
    const result = await membershipStore.deleteMembership({ id: memberToDelete.value.id });
    if (result.success) {
      showSuccessNotification('Member deleted successfully.');
      openDeleteMemberDialog.value = false;
      await loadTenantMembers();
    } else {
      pageError.value = result.error || 'Failed to delete member.';
    }
  } catch (err) {
    console.error(err);
  }
};

// -------------------------------------------------------------
// 4. CUSTOMER GROUPS FUNCTIONALITY
// -------------------------------------------------------------
const selectedCustomerGroupId = ref<number | null>(null);
const openCustomerGroupDialog = ref(false);
const openDeleteCustomerGroupDialog = ref(false);
const openCustomerMemberDialog = ref(false);
const openDeleteCustomerMemberDialogModel = ref(false);
const customerGroupToDelete = ref<CustomerGroup | null>(null);
const customerGroupMemberToDelete = ref<CustomerGroupMember | null>(null);

// CGM Overrides tracking
const hasCgmOverridesMap = ref<Record<number, boolean>>({});

const customerGroupForm = ref({
  id: null as number | null,
  name: '',
  accentColor: '',
  isActive: true,
});

const customerGroupMemberForm = ref({
  id: null as number | null,
  email: '',
  name: '',
  isActive: true,
});

const selectedCustomerGroup = computed(() => {
  return customerGroups.value.find((cg) => cg.id === selectedCustomerGroupId.value) || null;
});

const sortedCustomerGroups = computed(() => {
  return [...customerGroups.value].sort((a, b) => a.name.localeCompare(b.name));
});

const sortedCustomerGroupMembers = computed(() => {
  return [...customerGroupMembers.value].sort((a, b) => (a.name || '').localeCompare(b.name || ''));
});

const selectCustomerGroup = async (groupId: number) => {
  selectedCustomerGroupId.value = groupId;
  await loadCustomerGroupMembers(groupId);
};

const loadCustomerGroupMembers = async (groupId: number) => {
  await customerGroupStore.fetchCustomerGroupMembersByGroup(groupId);
  const { data } = await supabase.rpc('list_cgm_ids_with_overrides', {
    p_customer_group_id: groupId,
  });
  const ids = new Set((data || []).map((row: any) => row.customer_group_member_id));
  hasCgmOverridesMap.value = customerGroupMembers.value.reduce(
    (acc, m) => {
      acc[m.id] = ids.has(m.id);
      return acc;
    },
    {} as Record<number, boolean>,
  );
};

const openCreateGroupDialog = () => {
  customerGroupForm.value = {
    id: null,
    name: '',
    accentColor: '',
    isActive: true,
  };
  openCustomerGroupDialog.value = true;
};

const openEditGroupDialog = (group: CustomerGroup) => {
  customerGroupForm.value = {
    id: group.id,
    name: group.name,
    accentColor: group.accent_color || '',
    isActive: group.is_active,
  };
  openCustomerGroupDialog.value = true;
};

const openDeleteGroupDialog = (group: CustomerGroup) => {
  customerGroupToDelete.value = group;
  openDeleteCustomerGroupDialog.value = true;
};

const handleSaveCustomerGroup = async () => {
  if (!tenantId.value || !customerGroupForm.value.name.trim()) return;
  try {
    if (customerGroupForm.value.id) {
      await customerGroupStore.updateCustomerGroup({
        id: customerGroupForm.value.id,
        tenant_id: tenantId.value,
        name: customerGroupForm.value.name,
        accent_color: customerGroupForm.value.accentColor,
        is_active: customerGroupForm.value.isActive,
      });
      showSuccessNotification('Customer group updated.');
    } else {
      await customerGroupStore.createCustomerGroup({
        tenant_id: tenantId.value,
        name: customerGroupForm.value.name,
        accent_color: customerGroupForm.value.accentColor,
        is_active: customerGroupForm.value.isActive,
      });
      showSuccessNotification('Customer group created.');
    }
    openCustomerGroupDialog.value = false;
    await customerGroupStore.fetchCustomerGroupsByTenant(tenantId.value);
  } catch (err) {
    console.error(err);
  }
};

const confirmDeleteCustomerGroup = async () => {
  if (!customerGroupToDelete.value) return;
  try {
    await customerGroupStore.deleteCustomerGroup({ id: customerGroupToDelete.value.id });
    showSuccessNotification('Customer group deleted.');
    openDeleteCustomerGroupDialog.value = false;
    selectedCustomerGroupId.value = null;
    await customerGroupStore.fetchCustomerGroupsByTenant(tenantId.value!);
  } catch (err) {
    console.error(err);
  }
};

const onToggleSelectedCustomerGroupActive = async (isActive: boolean) => {
  if (!selectedCustomerGroup.value || !tenantId.value) return;
  try {
    await customerGroupStore.updateCustomerGroup({
      ...selectedCustomerGroup.value,
      is_active: isActive,
    });
    showSuccessNotification('Customer group status updated.');
    await customerGroupStore.fetchCustomerGroupsByTenant(tenantId.value);
  } catch (err) {
    console.error(err);
  }
};

const openCreateCustomerMemberDialog = () => {
  customerGroupMemberForm.value = {
    id: null,
    email: '',
    name: '',
    isActive: true,
  };
  openCustomerMemberDialog.value = true;
};

const openEditCustomerMemberDialog = (member: CustomerGroupMember) => {
  customerGroupMemberForm.value = {
    id: member.id,
    email: member.email,
    name: member.name || '',
    isActive: member.is_active,
  };
  openCustomerMemberDialog.value = true;
};

const openDeleteCustomerMemberDialog = (member: CustomerGroupMember) => {
  customerGroupMemberToDelete.value = member;
  openDeleteCustomerMemberDialogModel.value = true;
};

const handleSaveCustomerGroupMember = async () => {
  if (!selectedCustomerGroupId.value) return;
  try {
    if (customerGroupMemberForm.value.id) {
      await customerGroupStore.updateCustomerGroupMember({
        id: customerGroupMemberForm.value.id,
        customer_group_id: selectedCustomerGroupId.value,
        name: customerGroupMemberForm.value.name,
        email: customerGroupMemberForm.value.email,
        is_active: customerGroupMemberForm.value.isActive,
      });
      showSuccessNotification('Customer user updated.');
    } else {
      await customerGroupStore.createCustomerGroupMember({
        customer_group_id: selectedCustomerGroupId.value,
        name: customerGroupMemberForm.value.name,
        email: customerGroupMemberForm.value.email,
        is_active: customerGroupMemberForm.value.isActive,
        role: 'staff', // default enum role
      });
      showSuccessNotification('Customer user created.');
    }
    openCustomerMemberDialog.value = false;
    await loadCustomerGroupMembers(selectedCustomerGroupId.value);
  } catch (err) {
    console.error(err);
  }
};

const onChangeCustomerMemberRole = async (member: any, roleId: number) => {
  try {
    const { error } = await supabase.rpc('assign_customer_group_member_role', {
      p_cgm_id: member.id,
      p_tenant_role_id: roleId,
    });
    if (error) {
      pageError.value = error.message;
    } else {
      showSuccessNotification('Customer member role updated successfully.');
      if (selectedCustomerGroupId.value) {
        await loadCustomerGroupMembers(selectedCustomerGroupId.value);
      }
    }
  } catch (err) {
    console.error(err);
    pageError.value = 'Failed to update customer member role.';
  }
};

const onToggleCustomerGroupMemberActive = async (
  member: CustomerGroupMember,
  isActive: boolean,
) => {
  if (!selectedCustomerGroupId.value) return;
  try {
    await customerGroupStore.updateCustomerGroupMember({
      ...member,
      is_active: isActive,
    });
    showSuccessNotification('Customer user status updated.');
    await loadCustomerGroupMembers(selectedCustomerGroupId.value);
  } catch (err) {
    console.error(err);
  }
};

const confirmDeleteCustomerGroupMember = async () => {
  if (!customerGroupMemberToDelete.value || !selectedCustomerGroupId.value) return;
  try {
    await customerGroupStore.deleteCustomerGroupMember({
      id: customerGroupMemberToDelete.value.id,
    });
    showSuccessNotification('Customer user deleted.');
    openDeleteCustomerMemberDialogModel.value = false;
    await loadCustomerGroupMembers(selectedCustomerGroupId.value);
  } catch (err) {
    console.error(err);
  }
};

const formatCustomerRole = (role: CustomerGroupRole): string => {
  if (role === 'admin') return 'Customer Admin';
  if (role === 'negotiator') return 'Customer Negotiator';
  return 'Customer Staff';
};

const customerGroupMemberColumns = [
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const },
  { name: 'email', label: 'Email', field: 'email', align: 'left' as const },
  { name: 'role', label: 'Role Template', field: 'role', align: 'left' as const },
  { name: 'overrides', label: 'Custom Overrides', field: 'id', align: 'center' as const },
  { name: 'active', label: 'Status', field: 'is_active', align: 'center' as const },
  { name: 'edit', label: 'Actions', field: 'id', align: 'center' as const },
];

// -------------------------------------------------------------
// 5. INVESTOR DETAILS / LOOKUP
// -------------------------------------------------------------
const allInvestors = ref<any[]>([]);
const loadInvestors = async () => {
  if (!tenantId.value) return;
  try {
    const { data } = await supabase
      .from('investor_profiles')
      .select('*')
      .eq('tenant_id', tenantId.value);
    allInvestors.value = data || [];
  } catch (err) {
    console.error(err);
  }
};

const tenantInvestorsOptions = computed(() => {
  return allInvestors.value.map((i) => ({
    label: i.name,
    value: i.id,
  }));
});

const investorNameById = (id: number): string => {
  return allInvestors.value.find((i) => i.id === id)?.name || `ID #${id}`;
};

// -------------------------------------------------------------
// 6. ACCESSIBILITY OVERRIDES OVERLAY DIALOG
// -------------------------------------------------------------
const overridesDialogOpen = ref(false);
const overridesLoading = ref(false);
const overridesDialogMember = ref<any>(null);
const overridesDialogScope = ref<'app' | 'shop'>('app');
const overridesActions = ref<any[]>([]);
const overridesGrants = ref<Record<string, 'allow' | 'deny' | 'inherit'>>({});
const overridesSavingMap = ref<Record<string, boolean>>({});

const openOverridesDialog = async (member: any, scope: 'app' | 'shop') => {
  if (!tenantId.value) return;
  overridesDialogMember.value = member;
  overridesDialogScope.value = scope;
  overridesDialogOpen.value = true;
  overridesLoading.value = true;
  overridesGrants.value = {};

  try {
    const { data: actionsData } = await supabase.rpc('list_configurable_module_actions', {
      p_scope: scope,
      p_tenant_id: tenantId.value,
    });
    overridesActions.value = actionsData || [];

    if (scope === 'app') {
      const { data: grantsData } = await supabase.rpc('list_membership_grants', {
        p_membership_id: member.id,
      });

      const grantsMap: Record<string, 'allow' | 'deny' | 'inherit'> = {};
      (grantsData || []).forEach((g: any) => {
        grantsMap[`${g.module_key}:${g.action}`] = g.effect as 'allow' | 'deny';
      });
      overridesGrants.value = grantsMap;
    } else {
      const { data: grantsData } = await supabase.rpc('list_customer_group_member_grants', {
        p_cgm_id: member.id,
      });

      const grantsMap: Record<string, 'allow' | 'deny' | 'inherit'> = {};
      (grantsData || []).forEach((g: any) => {
        grantsMap[`${g.module_key}:${g.action}`] = g.effect as 'allow' | 'deny';
      });
      overridesGrants.value = grantsMap;
    }
  } catch (error) {
    console.error('Failed to load member overrides:', error);
  } finally {
    overridesLoading.value = false;
  }
};

const toggleOverride = async (
  moduleKey: string,
  action: string,
  effect: 'allow' | 'deny' | 'inherit',
) => {
  const member = overridesDialogMember.value;
  const scope = overridesDialogScope.value;
  if (!member) return;

  const key = `${moduleKey}:${action}`;
  overridesSavingMap.value[key] = true;

  try {
    if (effect === 'inherit') {
      if (scope === 'app') {
        await supabase.rpc('delete_membership_grant', {
          p_membership_id: member.id,
          p_module_key: moduleKey,
          p_action: action,
        });
      } else {
        await supabase.rpc('delete_customer_group_member_grant', {
          p_cgm_id: member.id,
          p_module_key: moduleKey,
          p_action: action,
        });
      }
      overridesGrants.value[key] = 'inherit';
    } else {
      if (scope === 'app') {
        await supabase.rpc('upsert_membership_grant', {
          p_membership_id: member.id,
          p_module_key: moduleKey,
          p_action: action,
          p_effect: effect,
        });
      } else {
        await supabase.rpc('upsert_customer_group_member_grant', {
          p_cgm_id: member.id,
          p_module_key: moduleKey,
          p_action: action,
          p_effect: effect,
        });
      }
      overridesGrants.value[key] = effect;
    }
    // Update local status map
    if (scope === 'app') {
      await loadTenantMembers();
    } else if (selectedCustomerGroupId.value) {
      await loadCustomerGroupMembers(selectedCustomerGroupId.value);
    }
  } catch (error) {
    console.error('Failed to save override:', error);
  } finally {
    overridesSavingMap.value[key] = false;
  }
};

// -------------------------------------------------------------
// LIFE CYCLE
// -------------------------------------------------------------
const loadPageData = async () => {
  pageLoading.value = true;
  pageError.value = null;
  try {
    if (!tenantId.value) return;
    await tenantStore.fetchTenantDetailsByMembership({ tenantId: tenantId.value });
    await Promise.all([
      loadTenantModules(),
      moduleStore.fetchModules(),
      loadRoles(),
      loadTenantMembers(),
      customerGroupStore.fetchCustomerGroupsByTenant(tenantId.value),
      loadInvestors(),
    ]);
    // Select first customer group if any
    const firstGroup = sortedCustomerGroups.value[0];
    if (firstGroup) {
      await selectCustomerGroup(firstGroup.id);
    }
  } catch (err) {
    console.error(err);
    pageError.value = 'Failed to load access control details.';
  } finally {
    pageLoading.value = false;
  }
};

onMounted(() => {
  void loadPageData();
});
</script>

<style scoped>
.admin-access-control-page {
  background: transparent;
}

.hero-surface {
  border-radius: 16px;
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
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

.tab-align-left {
  justify-content: flex-start !important;
  text-align: left;
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
