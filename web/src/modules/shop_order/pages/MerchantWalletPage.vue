<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Merchant portal</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Merchant wallet</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Available balance, pending profit, and ledger history for your dropship account.
          </p>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            outline
            color="primary"
            no-caps
            icon="ph ph-arrow-left"
            label="My Orders"
            :to="{ name: 'shop-orders-page' }"
          />
        </div>
      </section>

      <MerchantWalletSkeleton v-if="isLoading" />

      <template v-else-if="isError">
        <q-banner class="bg-negative text-white rounded-borders" rounded>
          {{ errorMessage }}
        </q-banner>
      </template>

      <template v-else>
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-card flat bordered class="q-pa-md">
              <div class="text-caption text-grey-7">Available</div>
              <div class="text-h5 text-weight-bold text-positive">
                ৳{{ formatAmt(summary?.available_balance) }}
              </div>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat bordered class="q-pa-md">
              <div class="text-caption text-grey-7">Pending settlement</div>
              <div class="text-h5 text-weight-bold text-amber-9">
                ৳{{ formatAmt(summary?.pending_balance) }}
              </div>
            </q-card>
          </div>
          <div class="col-12 col-sm-4">
            <q-card flat bordered class="q-pa-md">
              <div class="text-caption text-grey-7">Locked (COD in transit)</div>
              <div class="text-h5 text-weight-bold text-grey-8">
                ৳{{ formatAmt(summary?.locked_balance) }}
              </div>
            </q-card>
          </div>
        </div>

        <q-card flat bordered>
          <q-card-section class="row items-center justify-between">
            <div class="text-subtitle1 text-weight-bold">Ledger</div>
            <div class="text-caption text-grey-6">
              Profile #{{ summary?.billing_profile_id || '—' }} · {{ summary?.currency || 'BDT' }}
            </div>
          </q-card-section>
          <q-separator />
          <q-markup-table flat dense wrap-cells>
            <thead>
              <tr>
                <th class="text-left">When</th>
                <th class="text-left">Type</th>
                <th class="text-right">Amount</th>
                <th class="text-right">Balance after</th>
                <th class="text-left">Order</th>
                <th class="text-left">Note</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!ledger.length">
                <td colspan="6" class="text-center text-grey-6 q-pa-lg">No wallet entries yet</td>
              </tr>
              <tr v-for="row in ledger" :key="row.id">
                <td>{{ formatWhen(row.created_at) }}</td>
                <td>{{ row.transaction_type }}</td>
                <td class="text-right" :class="row.amount >= 0 ? 'text-positive' : 'text-negative'">
                  ৳{{ formatAmt(row.amount) }}
                </td>
                <td class="text-right">৳{{ formatAmt(row.balance_after) }}</td>
                <td>
                  <router-link
                    v-if="row.order_id"
                    class="text-primary"
                    :to="{ name: 'shop-order-detail-page', params: { id: row.order_id } }"
                  >
                    #{{ row.order_id }}
                  </router-link>
                  <span v-else class="text-grey-5">—</span>
                </td>
                <td class="text-grey-7">{{ row.note || '—' }}</td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { date } from 'quasar';
import { useMerchantWalletQuery } from '../composables/useMerchantWalletQuery';
import MerchantWalletSkeleton from '../components/MerchantWalletSkeleton.vue';
import { parseSupabaseError } from 'src/utils/appFeedback';

const { summary, ledger, isLoading, isError, error } = useMerchantWalletQuery(true);

const errorMessage = computed(() =>
  parseSupabaseError(error.value, 'Unable to load merchant wallet'),
);

function formatAmt(n: number | null | undefined) {
  return Number(n || 0).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  });
}

function formatWhen(iso: string) {
  return date.formatDate(iso, 'D MMM YYYY, HH:mm');
}
</script>
