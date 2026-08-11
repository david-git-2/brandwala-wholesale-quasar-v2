<template>
  <q-page class="q-pa-md thrift-return-details-page">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn
              flat
              dense
              icon="ph ph-arrow-left"
              color="grey-7"
              :to="returnsListPath"
              aria-label="Back to Returns"
            />
            <div>
              <div class="text-overline text-primary">Thrift / Sales / Returns</div>
              <h1 class="text-h5 text-weight-bold q-my-none">
                {{ detail?.returnNumber || 'Return details' }}
              </h1>
            </div>
          </div>
        </div>
      </section>

      <q-inner-loading :showing="isLoading" />

      <template v-if="detail">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-5">
            <q-card flat bordered>
              <q-card-section class="q-gutter-y-sm">
                <div class="row justify-between">
                  <span class="text-grey-7">Invoice</span>
                  <router-link class="text-primary text-weight-medium" :to="invoicePath">
                    {{ detail.invoiceNumber }}
                  </router-link>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-7">Customer</span>
                  <span>{{ detail.customerName || detail.customerPhone || '—' }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-7">Refund</span>
                  <span class="text-weight-bold">
                    {{ formatThriftAmount(detail.refundAmount) }}
                  </span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-7">Return courier</span>
                  <span>{{ formatThriftAmount(detail.returnCourierAmount) }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-7">Created</span>
                  <span>{{ formatDate(detail.createdAt) }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-7">By</span>
                  <span>{{ detail.createdBy || '—' }}</span>
                </div>
                <div v-if="detail.notes" class="q-mt-sm">
                  <div class="text-caption text-grey-6">Notes</div>
                  <div>{{ detail.notes }}</div>
                </div>
              </q-card-section>
            </q-card>
          </div>

          <div class="col-12 col-md-7">
            <q-card flat bordered>
              <q-card-section class="q-pb-none">
                <div class="text-subtitle1 text-weight-bold">
                  Lines ({{ detail.items.length }})
                </div>
              </q-card-section>
              <q-table
                flat
                :rows="detail.items"
                :columns="itemColumns"
                row-key="id"
                hide-pagination
                :rows-per-page-options="[0]"
              >
                <template #body-cell-item="props">
                  <q-td :props="props">
                    <div class="text-weight-medium">
                      {{ props.row.stockName || `Stock #${props.row.stockId}` }}
                    </div>
                    <div v-if="props.row.barcode" class="text-caption text-grey-7">
                      {{ props.row.barcode }}
                    </div>
                  </q-td>
                </template>
                <template #body-cell-condition="props">
                  <q-td :props="props">
                    <q-badge
                      :color="props.row.condition === 'DAMAGED' ? 'negative' : 'positive'"
                      outline
                      :label="props.row.condition"
                    />
                  </q-td>
                </template>
                <template #body-cell-refundAmount="props">
                  <q-td :props="props" class="text-right">
                    {{ formatThriftAmount(props.row.refundAmount) }}
                  </q-td>
                </template>
              </q-table>
            </q-card>
          </div>
        </div>
      </template>

      <q-card v-else-if="!isLoading" flat bordered class="q-pa-xl text-center">
        <div class="text-subtitle1">Return not found</div>
        <q-btn
          class="q-mt-md"
          color="primary"
          unelevated
          no-caps
          label="Back to Returns"
          :to="returnsListPath"
        />
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { useThriftSalesReturnDetailQuery } from '../composables/useThriftSalesQuery';
import type { ThriftSalesReturnItemDetail } from '../repositories/thriftSalesRepository';

const route = useRoute();
const authStore = useAuthStore();
const { tenantId, tenantSlug } = storeToRefs(authStore);

const returnId = computed(() => Number(route.params.returnId));

const { data: detail, isLoading } = useThriftSalesReturnDetailQuery(tenantId, returnId);

const returnsListPath = computed(
  () => `/${tenantSlug.value || 'tenant'}/app/thrift/sales/returns`,
);

const invoicePath = computed(() => {
  const id = detail.value?.invoiceId;
  return `/${tenantSlug.value || 'tenant'}/app/thrift/sales/${id || ''}`;
});

const itemColumns: QTableColumn<ThriftSalesReturnItemDetail>[] = [
  { name: 'item', label: 'Item', field: 'stockName', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'center' },
  { name: 'condition', label: 'Condition', field: 'condition', align: 'left' },
  { name: 'refundAmount', label: 'Refund', field: 'refundAmount', align: 'right' },
];

function formatDate(value: string): string {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString();
}
</script>
