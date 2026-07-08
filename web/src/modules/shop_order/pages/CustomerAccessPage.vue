<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Shop &amp; Order</div>
          <h1 class="text-h5 q-my-none">Customer Access</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Define default shop capabilities per customer group. Use shop-specific access matrix for
            overrides.
          </p>
        </div>
      </section>

      <!-- Error banner -->
      <q-banner v-if="store.error" class="text-white bg-negative" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" label="Dismiss" @click="store.clearError()" />
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
          <q-icon name="group" size="48px" class="q-mb-sm block" />
          No customer groups found for this tenant.
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
          <!-- Status -->
          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-icon
                :name="props.row.is_active ? 'check_circle' : 'cancel'"
                :color="props.row.is_active ? 'positive' : 'grey-5'"
                size="20px"
              />
            </q-td>
          </template>

          <!-- Actions -->
          <template #body-cell-actions="props">
            <q-td :props="props">
              <q-btn
                flat
                round
                dense
                icon="security"
                color="primary"
                @click="goToPermissions(props.row.id)"
              >
                <q-tooltip>Manage default shop profile permissions</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopPermissionsStore } from '../stores/shopPermissionsStore';

const authStore = useAuthStore();
const store = useShopPermissionsStore();
const router = useRouter();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const columns = [
  { name: 'name', label: 'Group Name', field: 'name', align: 'left' as const, sortable: true },
  { name: 'is_active', label: 'Active', field: 'is_active', align: 'center' as const },
  { name: 'actions', label: '', field: 'id', align: 'right' as const },
];

const load = () => {
  if (tenantId.value) {
    void store.fetchCustomerGroups(tenantId.value);
  }
};

const goToPermissions = (groupId: number) => {
  void router.push({
    name: 'app-shop-customer-group-permissions-page',
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
