<template>
  <q-page class="q-pa-md thrift-customers-page">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Thrift</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Customers</h1>
          <div class="text-caption text-grey-7 q-mt-xs">
            Profiles upserted from sales invoices. View only.
          </div>
        </div>
        <div class="col-12 col-sm-auto" style="min-width: 260px">
          <q-input
            v-model="searchInput"
            dense
            outlined
            clearable
            debounce="300"
            placeholder="Search name or phone"
            aria-label="Search customers"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </div>
      </section>

      <q-banner v-if="isError" class="bg-negative text-white" rounded>
        {{ errorMessage }}
      </q-banner>

      <div v-if="isLoading" class="row q-col-gutter-md">
        <div v-for="n in 6" :key="n" class="col-12 col-sm-6 col-md-4">
          <q-card flat class="floating-surface shadow-1">
            <q-card-section>
              <q-skeleton type="text" width="55%" />
              <q-skeleton type="text" width="40%" class="q-mt-sm" />
              <q-skeleton type="text" width="80%" class="q-mt-sm" />
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div
        v-else-if="!items.length"
        class="q-pa-xl text-center text-grey-6 bg-grey-1 rounded-borders"
      >
        {{ search.trim() ? 'No customers match your search.' : 'No customers yet.' }}
      </div>

      <template v-else>
        <div class="row q-col-gutter-md">
          <div
            v-for="row in items"
            :key="row.id"
            class="col-12 col-sm-6 col-md-4"
          >
            <q-card flat class="floating-surface shadow-1 customer-card full-height">
              <q-card-section class="q-pb-none">
                <div class="text-subtitle1 text-weight-bold ellipsis">{{ row.name || '—' }}</div>
                <div class="text-body2 text-grey-8 q-mt-xs">
                  <q-icon name="ph ph-phone" size="14px" class="q-mr-xs" />
                  {{ row.phone || '—' }}
                </div>
                <div v-if="row.secondaryPhone" class="text-caption text-grey-7 q-mt-xs">
                  Alt: {{ row.secondaryPhone }}
                </div>
              </q-card-section>

              <q-card-section v-if="addressLine(row)" class="q-pt-sm text-body2 text-grey-8">
                <div class="row no-wrap items-start">
                  <q-icon name="ph ph-map-pin" size="14px" class="q-mr-xs q-mt-xs" />
                  <span>{{ addressLine(row) }}</span>
                </div>
              </q-card-section>

              <q-card-section v-if="row.notes" class="q-pt-none text-caption text-grey-7 notes">
                {{ row.notes }}
              </q-card-section>

              <q-card-section class="q-pt-none text-caption text-grey-6">
                Updated {{ formatDate(row.updatedAt) }}
              </q-card-section>
            </q-card>
          </div>
        </div>

        <div class="row justify-center q-mt-md" v-if="totalPages > 1">
          <q-pagination
            v-model="page"
            :max="totalPages"
            :max-pages="7"
            boundary-numbers
            direction-links
            color="primary"
          />
        </div>
        <div class="text-center text-caption text-grey-6">
          {{ total }} customer{{ total === 1 ? '' : 's' }}
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { date } from 'quasar';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftCustomersQuery } from '../composables/useThriftCustomersQuery';
import type { ThriftCustomerListItem } from '../repositories/thriftCustomersRepository';

const PAGE_SIZE = 24;

const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);

const searchInput = ref('');
const search = ref('');
const page = ref(1);

watch(searchInput, (value) => {
  search.value = value ?? '';
  page.value = 1;
});

const listParams = computed(() => ({
  tenantId: Number(tenantId.value ?? 0),
  search: search.value,
  page: page.value,
  pageSize: PAGE_SIZE,
}));

const { data, isLoading, isError, error } = useThriftCustomersQuery(listParams);

const items = computed(() => data.value?.items ?? []);
const total = computed(() => data.value?.total ?? 0);
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));
const errorMessage = computed(() =>
  error.value instanceof Error ? error.value.message : 'Failed to load customers',
);

const addressLine = (row: ThriftCustomerListItem) => {
  const parts = [
    row.addressParts.district,
    row.addressParts.thana,
    row.addressParts.post_code,
  ].filter(Boolean);
  const geo = parts.join(', ');
  if (row.address && geo) return `${row.address} · ${geo}`;
  return row.address || geo || '';
};

const formatDate = (value: string) => {
  if (!value) return '—';
  return date.formatDate(value, 'DD MMM YYYY');
};
</script>

<style scoped>
.customer-card {
  border-radius: 12px;
}

.notes {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
