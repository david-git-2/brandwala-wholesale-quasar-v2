<template>
  <q-page class="q-pa-md">
    <div class="max-width-container q-gutter-y-md">
      <!-- Header Section -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Shop &amp; Order — Dropship</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Merchant Payout Center</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Monitor merchant margins, locked courier escrow, available wallet balances, and dispense merchant payouts.
          </p>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            color="primary"
            icon="ph ph-plus"
            label="Add Merchant Profile"
            no-caps
            unelevated
            class="rounded-btn"
            @click="openAddDialog"
          />
        </div>
      </section>

      <!-- Loading State: Dedicated Skeleton Loader -->
      <DropshipMerchantsSkeleton v-if="isLoading" />

      <!-- Loaded State -->
      <template v-else>
        <!-- Search & Quick Filters Toolbar -->
        <q-card flat bordered class="rounded-card q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-md">
            <div class="col-12 col-sm-6 col-md-4">
              <q-input
                v-model="searchQuery"
                dense
                outlined
                placeholder="Search reseller name, email, phone..."
                clearable
              >
                <template #prepend>
                  <q-icon name="ph ph-magnifying-glass" />
                </template>
              </q-input>
            </div>
            <div class="col-auto row q-gutter-xs items-center">
              <q-chip
                clickable
                :outline="balanceFilter !== 'all'"
                :color="balanceFilter === 'all' ? 'primary' : 'grey-4'"
                :text-color="balanceFilter === 'all' ? 'white' : 'grey-9'"
                @click="balanceFilter = 'all'"
              >
                All Resellers ({{ merchantList.length }})
              </q-chip>
              <q-chip
                clickable
                :outline="balanceFilter !== 'payable'"
                :color="balanceFilter === 'payable' ? 'positive' : 'grey-4'"
                :text-color="balanceFilter === 'payable' ? 'white' : 'grey-9'"
                @click="balanceFilter = 'payable'"
              >
                Payable ({{ payableCount }})
              </q-chip>
              <q-chip
                clickable
                :outline="balanceFilter !== 'locked'"
                :color="balanceFilter === 'locked' ? 'amber-9' : 'grey-4'"
                :text-color="balanceFilter === 'locked' ? 'white' : 'grey-9'"
                @click="balanceFilter = 'locked'"
              >
                Has Locked Escrow ({{ lockedCount }})
              </q-chip>
            </div>
          </div>
        </q-card>

        <!-- Merchant Financial Balances Table -->
        <q-card flat bordered class="rounded-card">
          <q-markup-table flat borderless class="q-mb-none soft-table">
            <thead>
              <tr>
                <th class="text-left">Merchant / Reseller Profile</th>
                <th class="text-left">Contact Info</th>
                <th class="text-right">Locked Margin (Pending Courier)</th>
                <th class="text-right">Available Wallet Balance</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="filteredMerchants.length === 0">
                <td colspan="5" class="text-center text-grey-6 q-pa-lg">
                  No merchant profiles found.
                </td>
              </tr>
              <tr v-for="m in filteredMerchants" :key="m.billing_profile_id" class="hover-row">
                <td>
                  <div class="row items-center q-gutter-x-sm">
                    <q-avatar size="36px" :color="getAvatarColor(m.name)" text-color="white" class="text-weight-bold">
                      {{ getInitials(m.name) }}
                    </q-avatar>
                    <div>
                      <div class="text-weight-bold text-grey-9">{{ m.name }}</div>
                      <div class="text-caption text-grey-7">ID: #{{ m.billing_profile_id }}</div>
                    </div>
                  </div>
                </td>
                <td>
                  <div class="text-weight-medium text-grey-9">{{ m.phone || '—' }}</div>
                  <div class="text-caption text-grey-7">{{ m.email || 'No email registered' }}</div>
                </td>
                <td class="text-right">
                  <div class="text-weight-bold text-amber-9">
                    🔒 ৳{{ (m.locked_margin || 0).toLocaleString() }}
                  </div>
                  <div class="text-caption text-grey-6">Courier Escrow</div>
                </td>
                <td class="text-right">
                  <div class="text-weight-bold" :class="m.available_balance > 0 ? 'text-positive' : 'text-grey-7'">
                    🟢 ৳{{ (m.available_balance || 0).toLocaleString() }}
                  </div>
                  <div class="text-caption text-grey-6">Ready for Dispense</div>
                </td>
                <td class="text-right">
                  <q-btn
                    color="primary"
                    icon="ph ph-bank"
                    label="Dispense in Finance Hub"
                    no-caps
                    unelevated
                    size="sm"
                    class="rounded-btn"
                    :disable="m.available_balance <= 0"
                    :to="{ name: 'app-shop-dropship-finance-hub-page', query: { merchantId: m.billing_profile_id, step: 'middleman_payout' } }"
                  >
                    <q-tooltip v-if="m.available_balance <= 0">
                      No available balance for payout
                    </q-tooltip>
                  </q-btn>
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-card>
      </template>

      <!-- Dialog: Add Merchant Profile placeholder/integration -->
      <q-dialog v-model="addDialogOpen" persistent>
        <q-card style="min-width: 450px; max-width: 90vw;" class="q-pa-sm">
          <q-card-section class="row items-center justify-between">
            <div class="text-h6 text-weight-bold">Add Merchant Profile</div>
            <q-btn v-close-popup flat round dense icon="ph ph-x" />
          </q-card-section>
          <q-separator />
          <q-card-section class="q-gutter-y-md">
            <q-input v-model="newMerchantForm.merchant_name" label="Merchant Name *" dense outlined />
            <q-input v-model="newMerchantForm.phone_primary" label="Primary Phone *" dense outlined />
            <q-input v-model="newMerchantForm.pickup_address" label="Pickup Address *" dense outlined type="textarea" rows="2" />
          </q-card-section>
          <q-separator />
          <q-card-actions align="right" class="q-pa-md">
            <q-btn v-close-popup flat label="Cancel" no-caps />
            <q-btn color="primary" label="Create" no-caps unelevated class="rounded-btn" @click="handleCreateMerchant" />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { getInitials, getAvatarColor } from 'src/shared/utils/avatarUtils';
import { useMerchantPayoutQuery } from '../composables/useMerchantPayoutQuery';
import DropshipMerchantsSkeleton from '../components/DropshipMerchantsSkeleton.vue';

const authStore = useAuthStore();
const currentTenantId = computed(() => (authStore.selectedTenant?.id ? Number(authStore.selectedTenant.id) : null));

// Queries & Mutations
const { merchants, isLoading } = useMerchantPayoutQuery(currentTenantId);

// Filters
const searchQuery = ref('');
const balanceFilter = ref<'all' | 'payable' | 'locked'>('all');

// Modals
const addDialogOpen = ref(false);
const newMerchantForm = ref({
  merchant_name: '',
  phone_primary: '',
  pickup_address: '',
});

const merchantList = computed(() => merchants.value || []);

const payableCount = computed(() => merchantList.value.filter((m) => m.available_balance > 0).length);
const lockedCount = computed(() => merchantList.value.filter((m) => m.locked_margin > 0).length);

const filteredMerchants = computed(() => {
  return merchantList.value.filter((m) => {
    const matchesSearch =
      !searchQuery.value ||
      m.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      (m.email && m.email.toLowerCase().includes(searchQuery.value.toLowerCase())) ||
      (m.phone && m.phone.includes(searchQuery.value));

    const matchesFilter =
      balanceFilter.value === 'all' ||
      (balanceFilter.value === 'payable' && m.available_balance > 0) ||
      (balanceFilter.value === 'locked' && m.locked_margin > 0);

    return matchesSearch && matchesFilter;
  });
});



function openAddDialog() {
  newMerchantForm.value = { merchant_name: '', phone_primary: '', pickup_address: '' };
  addDialogOpen.value = true;
}

function handleCreateMerchant() {
  addDialogOpen.value = false;
}
</script>

<style scoped>
.max-width-container {
  max-width: 1200px;
  margin: 0 auto;
}
.rounded-card {
  border-radius: 8px;
}
.rounded-btn {
  border-radius: 8px;
}
.soft-table th {
  font-weight: 600;
  color: #555;
}
.hover-row:hover {
  background-color: #f9fafb;
}
</style>
