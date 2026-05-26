<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h6">App Store Access - Customer Groups</div>
    </div>

    <q-table
      flat
      bordered
      row-key="id"
      :rows="customerGroupStore.groups"
      :columns="columns"
      :loading="customerGroupStore.loading"
      @row-click="onRowClick"
      class="clickable-rows-table"
      :pagination="pagination"
    >
      <template #body-cell-accent_color="props">
        <q-td :props="props">
          <div
            v-if="props.row.accent_color"
            class="accent-badge text-caption"
            :style="{ backgroundColor: props.row.accent_color, color: getContrastYIQ(props.row.accent_color) }"
          >
            {{ props.row.accent_color }}
          </div>
          <span v-else class="text-grey-6">-</span>
        </q-td>
      </template>

      <template #body-cell-actions>
        <q-td align="right">
          <q-icon name="chevron_right" size="sm" class="text-grey-6" />
        </q-td>
      </template>
    </q-table>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { QTableColumn } from 'quasar'

import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore'
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import type { CustomerGroup } from 'src/modules/tenant/types'

const router = useRouter()
const authStore = useAuthStore()
const tenantStore = useTenantStore()
const customerGroupStore = useCustomerGroupStore()

const pagination = ref({
  rowsPerPage: 0
})

const columns: QTableColumn<CustomerGroup>[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Group Name', field: 'name', align: 'left', sortable: true },
  { name: 'accent_color', label: 'Accent Color', field: 'accent_color', align: 'left' },
  { name: 'actions', label: '', field: (row) => row.id, align: 'right' },
]

const getContrastYIQ = (hexcolor: string) => {
  const r = parseInt(hexcolor.substring(1, 3), 16)
  const g = parseInt(hexcolor.substring(3, 5), 16)
  const b = parseInt(hexcolor.substring(5, 7), 16)
  const yiq = (r * 299 + g * 587 + b * 114) / 1000
  return yiq >= 128 ? 'black' : 'white'
}

const navigateToGroupAccess = async (groupId: number) => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/stores/manage-access/group/${groupId}`)
}

const onRowClick = (_evt: unknown, row: CustomerGroup) => {
  void navigateToGroupAccess(row.id)
}

onMounted(async () => {
  const tenantId = tenantStore.selectedTenant?.id ?? 0
  if (tenantId) {
    await customerGroupStore.fetchCustomerGroupsByTenant(tenantId)
  }
})
</script>

<style scoped>
.accent-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 4px;
  font-family: monospace;
}

.clickable-rows-table :deep(.q-table tbody tr) {
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.clickable-rows-table :deep(.q-table tbody tr:hover) {
  background-color: rgba(0, 0, 0, 0.03);
}

.body--dark .clickable-rows-table :deep(.q-table tbody tr:hover) {
  background-color: rgba(255, 255, 255, 0.05);
}
</style>
