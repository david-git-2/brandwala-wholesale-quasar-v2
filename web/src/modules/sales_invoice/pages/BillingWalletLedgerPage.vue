<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Invoices &amp; Accounting</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Billing Profile Wallets</h1>
          <div class="text-caption text-grey-7">
            Unified ledger and net wallet balances across wholesale buyers and middle-men
          </div>
        </div>
        <div class="col-auto row q-gutter-sm items-center">
          <q-btn
            flat
            dense
            no-caps
            icon="ph ph-arrows-clockwise"
            label="Refresh"
            @click="onRefresh"
          />
        </div>
      </section>

      <!-- Metric Cards Header -->
      <section class="row q-col-gutter-md">
        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md">
            <div class="row items-center justify-between">
              <div>
                <div class="text-caption text-grey-7 text-uppercase text-weight-medium">
                  Total Middle-Man Payout Due
                </div>
                <div class="text-h5 text-weight-bolder text-positive q-mt-xs">
                  {{ formatBdt(totalPayoutDue) }}
                </div>
              </div>
              <q-avatar color="green-1" text-color="positive" icon="ph ph-hand-coins" size="44px" />
            </div>
          </q-card>
        </div>

        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md">
            <div class="row items-center justify-between">
              <div>
                <div class="text-caption text-grey-7 text-uppercase text-weight-medium">
                  Total Wholesale Debt Outstanding
                </div>
                <div class="text-h5 text-weight-bolder text-negative q-mt-xs">
                  {{ formatBdt(totalDebtOutstanding) }}
                </div>
              </div>
              <q-avatar color="red-1" text-color="negative" icon="ph ph-receipt" size="44px" />
            </div>
          </q-card>
        </div>

        <div class="col-12 col-sm-4">
          <q-card flat bordered class="q-pa-md">
            <div class="row items-center justify-between">
              <div>
                <div class="text-caption text-grey-7 text-uppercase text-weight-medium">
                  System Net Position
                </div>
                <div
                  class="text-h5 text-weight-bolder q-mt-xs"
                  :class="systemNetPosition >= 0 ? 'text-positive' : 'text-negative'"
                >
                  {{ formatBdt(systemNetPosition) }}
                </div>
              </div>
              <q-avatar color="blue-1" text-color="primary" icon="ph ph-scales" size="44px" />
            </div>
          </q-card>
        </div>
      </section>

      <!-- Filter & Search Toolbar -->
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-auto row items-center q-gutter-sm">
            <q-btn-toggle
              v-model="tabFilter"
              flat
              dense
              no-caps
              toggle-color="primary"
              :options="[
                { label: 'All Profiles', value: 'all' },
                { label: 'Payout Due (+ Credit)', value: 'payout_due' },
                { label: 'Debt Outstanding (- Debt)', value: 'debt' },
              ]"
            />
          </div>
          <div class="col-auto">
            <q-input
              v-model="searchText"
              outlined
              dense
              clearable
              class="soft-input toolbar-search"
              placeholder="Search Profile / Email / Phone"
              style="width: 260px"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
        </div>
      </q-card>

      <!-- Main Ledger Table -->
      <q-card flat class="floating-surface shadow-1">
        <q-markup-table flat wrap-cells class="wallet-table">
          <thead>
            <tr>
              <th class="text-left">Billing Profile</th>
              <th class="text-right">Total Billed (-)</th>
              <th class="text-right">Payments (+)</th>
              <th class="text-right">Dropship Profit (+)</th>
              <th class="text-right">Payouts Paid (-)</th>
              <th class="text-right">Net Wallet Balance</th>
              <th class="text-center" style="width: 140px">Actions</th>
            </tr>
          </thead>
          <tbody v-if="isLoading">
            <tr v-for="n in 5" :key="n">
              <td>
                <div class="row items-center no-wrap">
                  <q-skeleton type="QAvatar" size="36px" class="q-mr-sm" />
                  <div style="width: 140px">
                    <q-skeleton type="text" width="100%" height="18px" />
                    <q-skeleton type="text" width="70%" height="12px" />
                  </div>
                </div>
              </td>
              <td class="text-right"><q-skeleton type="text" width="70px" class="q-ml-auto" /></td>
              <td class="text-right"><q-skeleton type="text" width="70px" class="q-ml-auto" /></td>
              <td class="text-right"><q-skeleton type="text" width="70px" class="q-ml-auto" /></td>
              <td class="text-right"><q-skeleton type="text" width="70px" class="q-ml-auto" /></td>
              <td class="text-right">
                <q-skeleton type="text" width="80px" class="q-ml-auto" />
                <q-skeleton type="QBadge" width="90px" height="18px" class="q-ml-auto q-mt-xs" />
              </td>
              <td class="text-center">
                <div class="row justify-center q-gutter-x-xs">
                  <q-skeleton type="QBtn" width="32px" height="32px" />
                  <q-skeleton type="QBtn" width="90px" height="28px" />
                </div>
              </td>
            </tr>
          </tbody>
          <tbody v-else>
            <tr v-if="!filteredProfiles.length">
              <td colspan="7" class="text-center text-grey-7 q-py-lg">
                No billing profile wallets match the filter.
              </td>
            </tr>
            <tr v-for="row in filteredProfiles" :key="row.billing_profile_id">
              <td>
                <div class="row items-center no-wrap cursor-pointer" @click="openProfileDrawer(row)">
                  <q-avatar size="36px" color="primary" text-color="white" class="q-mr-sm text-weight-bold">
                    {{ getInitials(row.profile_name) }}
                  </q-avatar>
                  <div>
                    <div class="text-weight-bold text-black text-subtitle2">{{ row.profile_name }}</div>
                    <div class="text-caption text-grey-7 text-xs">
                      {{ row.email || row.phone || 'No contact info' }}
                    </div>
                  </div>
                </div>
              </td>
              <td class="text-right text-grey-8">{{ formatBdt(row.total_billed) }}</td>
              <td class="text-right text-grey-8">{{ formatBdt(row.total_payments) }}</td>
              <td class="text-right text-positive text-weight-medium">{{ formatBdt(row.total_dropship_profit) }}</td>
              <td class="text-right text-blue-8">{{ formatBdt(row.total_payouts_paid) }}</td>
              <td class="text-right">
                <span
                  class="text-weight-bolder text-subtitle2"
                  :class="row.net_balance > 0 ? 'text-positive' : row.net_balance < 0 ? 'text-negative' : 'text-grey-7'"
                >
                  {{ formatBdt(row.net_balance) }}
                </span>
                <div>
                  <q-badge
                    v-if="row.net_balance > 0"
                    color="green-1"
                    text-color="positive"
                    label="Payout Available"
                    dense
                  />
                  <q-badge
                    v-else-if="row.net_balance < 0"
                    color="red-1"
                    text-color="negative"
                    label="Debt Due"
                    dense
                  />
                </div>
              </td>
              <td class="text-center">
                <div class="row justify-center q-gutter-x-xs">
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-receipt"
                    color="primary"
                    aria-label="View Ledger Drawer"
                    @click="openProfileDrawer(row)"
                  >
                    <q-tooltip>View Wallet Ledger</q-tooltip>
                  </q-btn>

                  <q-btn
                    v-if="row.net_balance > 0"
                    unelevated
                    dense
                    color="positive"
                    no-caps
                    icon="ph ph-hand-coins"
                    label="Settle Payout"
                    class="q-px-sm text-caption"
                    @click="openPayoutDialog(row)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>
    </div>

    <!-- Payout Dialog -->
    <SettleWalletPayoutDialog
      v-model="payoutDialogOpen"
      :profile="selectedProfile"
      :saving="createPayoutMutation.isPending.value"
      @submit="handlePayoutSubmit"
    />

    <!-- Details Drawer -->
    <BillingProfileDetailsDrawer
      v-model="drawerOpen"
      :tenant-id="tenantId"
      :billing-profile-id="selectedProfile?.billing_profile_id ?? null"
      :profile-name="selectedProfile?.profile_name ?? ''"
      :email="selectedProfile?.email"
      :phone="selectedProfile?.phone"
      :net-balance="selectedProfile?.net_balance ?? 0"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBillingWalletBalancesQuery } from '../composables/useBillingWalletQuery';
import { useCreateWalletPayoutMutation } from '../composables/useBillingWalletMutations';
import type { BillingProfileWalletSummary } from '../repositories/billingWalletRepository';
import SettleWalletPayoutDialog from '../components/SettleWalletPayoutDialog.vue';
import BillingProfileDetailsDrawer from '../components/BillingProfileDetailsDrawer.vue';

const $q = useQuasar();
const authStore = useAuthStore();
const tenantId = computed(() => authStore.tenantId);

const { data: profiles, isLoading, refetch } = useBillingWalletBalancesQuery(tenantId);
const createPayoutMutation = useCreateWalletPayoutMutation();

const tabFilter = ref<'all' | 'payout_due' | 'debt'>('all');
const searchText = ref('');
const payoutDialogOpen = ref(false);
const drawerOpen = ref(false);
const selectedProfile = ref<BillingProfileWalletSummary | null>(null);

const filteredProfiles = computed(() => {
  if (!profiles.value) return [];
  const search = searchText.value.trim().toLowerCase();

  return profiles.value.filter((p) => {
    const matchesSearch =
      !search ||
      [p.profile_name, p.email ?? '', p.phone ?? ''].some((val) =>
        val.toLowerCase().includes(search),
      );

    if (!matchesSearch) return false;

    if (tabFilter.value === 'payout_due') return p.net_balance > 0;
    if (tabFilter.value === 'debt') return p.net_balance < 0;
    return true;
  });
});

const totalPayoutDue = computed(() => {
  if (!profiles.value) return 0;
  return profiles.value.reduce((acc, p) => (p.net_balance > 0 ? acc + p.net_balance : acc), 0);
});

const totalDebtOutstanding = computed(() => {
  if (!profiles.value) return 0;
  return profiles.value.reduce((acc, p) => (p.net_balance < 0 ? acc + Math.abs(p.net_balance) : acc), 0);
});

const systemNetPosition = computed(() => totalPayoutDue.value - totalDebtOutstanding.value);

const formatBdt = (val: number) =>
  new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT' }).format(val);

const getInitials = (name: string) => (name ? name.split(' ').map((n) => n[0]).join('').substring(0, 2).toUpperCase() : 'BP');

const onRefresh = () => {
  void refetch();
};

const openProfileDrawer = (profile: BillingProfileWalletSummary) => {
  selectedProfile.value = profile;
  drawerOpen.value = true;
};

const openPayoutDialog = (profile: BillingProfileWalletSummary) => {
  selectedProfile.value = profile;
  payoutDialogOpen.value = true;
};

const handlePayoutSubmit = ({ amount, notes }: { amount: number; notes: string }) => {
  if (!selectedProfile.value || !tenantId.value) return;

  createPayoutMutation.mutate(
    {
      tenant_id: tenantId.value,
      billing_profile_id: selectedProfile.value.billing_profile_id,
      amount,
      reference_notes: notes,
    },
    {
      onSuccess: () => {
        $q.notify({
          type: 'positive',
          message: 'Bulk wallet payout issued successfully.',
        });
        payoutDialogOpen.value = false;
        void refetch();
      },
      onError: (err: any) => {
        $q.notify({
          type: 'negative',
          message: err?.message || 'Failed to issue payout',
        });
      },
    },
  );
};
</script>
