<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Shop &amp; Order</div>
          <h1 class="text-h5 q-my-none">Customer Groups</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Add customer groups and members. Grant shop access from each shop’s Access Matrix.
          </p>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            কাস্টমার গ্রুপ ও সদস্য যোগ করুন। শপ অ্যাক্সেস প্রতিটি শপের Access Matrix থেকে দিন।
          </p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="group_add"
            label="Add Customer Group"
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
            label="Dismiss"
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
          Loading customer groups…
        </q-card-section>

        <q-card-section
          v-else-if="store.customerGroups.length === 0"
          class="text-grey-6 text-center q-pa-xl"
        >
          <q-icon name="groups" size="48px" class="q-mb-sm block" />
          No customer groups yet.
          <div class="q-mt-md">
            <q-btn
              color="primary"
              outline
              no-caps
              icon="group_add"
              label="Add Customer Group"
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
                <q-tooltip>Edit group</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="group"
                color="primary"
                @click="goToMembers(props.row.id)"
              >
                <q-tooltip>Manage members</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="o_delete"
                color="negative"
                @click="openDeleteDialog(props.row)"
              >
                <q-tooltip>Delete group</q-tooltip>
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
          <div class="text-h6">{{ form.id ? 'Edit Customer Group' : 'Add Customer Group' }}</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-gutter-md">
          <q-input v-model="form.name" label="Group Name *" outlined dense />
          <q-input
            v-model="form.accentColor"
            label="Accent Color Hex (e.g. #B45F34)"
            outlined
            dense
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
          <span class="q-ml-sm text-subtitle1 text-weight-bold">Delete Customer Group</span>
        </q-card-section>
        <q-card-section class="q-pt-none">
          Delete <strong>{{ groupToDelete?.name }}</strong
          >? This also removes all members in the group.
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            unelevated
            no-caps
            label="Delete"
            :loading="groupStore.loading"
            @click="confirmDelete"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import type { CustomerGroup } from 'src/modules/tenant/types';
import { useShopPermissionsStore } from '../stores/shopPermissionsStore';

const authStore = useAuthStore();
const store = useShopPermissionsStore();
const groupStore = useCustomerGroupStore();
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

const columns = [
  { name: 'accent', label: '', field: 'accent_color', align: 'left' as const },
  { name: 'name', label: 'Group Name', field: 'name', align: 'left' as const, sortable: true },
  { name: 'is_active', label: 'Active', field: 'is_active', align: 'center' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
];

const load = () => {
  if (tenantId.value) {
    void store.fetchCustomerGroups(tenantId.value);
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
