<template>
  <q-page class="q-pa-md">
    <div class="text-h5 text-weight-bold q-mb-md">Customer Payments</div>

    <q-markup-table flat bordered wrap-cells>
      <thead>
        <tr>
          <th class="text-left">Customer</th>
          <th class="text-left">Phone</th>
          <th class="text-left">Email</th>
          <th class="text-left">Address</th>
          <th class="text-right">Action</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!billingProfileStore.items.length && !billingProfileStore.loading">
          <td colspan="5" class="text-center text-grey-7">No customers found.</td>
        </tr>
        <tr
          v-for="customer in billingProfileStore.items"
          :key="customer.id"
        >
          <td>{{ customer.name }}</td>
          <td>{{ customer.phone ?? '-' }}</td>
          <td>{{ customer.email ?? '-' }}</td>
          <td>{{ customer.address ?? '-' }}</td>
          <td class="text-right">
            <q-btn
              color="primary"
              no-caps
              label="View Transactions"
              @click="openCustomerTransactions(customer.id)"
            />
          </td>
        </tr>
      </tbody>
    </q-markup-table>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useBillingProfileStore } from 'src/modules/invoice/stores/billingProfileStore'

const router = useRouter()
const authStore = useAuthStore()
const billingProfileStore = useBillingProfileStore()

const loadCustomers = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) return

  await billingProfileStore.fetchBillingProfiles({
    tenant_id: tenantId,
    page: 1,
    page_size: 500,
    sortBy: 'name',
    sortOrder: 'asc',
  })
}

const openCustomerTransactions = async (billingProfileId: number) => {
  await router.push({
    name: 'app-accounting-customer-payment-details-page',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      billingProfileId,
    },
  })
}

onMounted(() => {
  void loadCustomers()
})
</script>
