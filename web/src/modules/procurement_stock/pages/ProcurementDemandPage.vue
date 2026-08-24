<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-card flat class="floating-surface shadow-1 q-pa-xs flex-shrink-0">
        <div class="row items-center justify-between q-col-gutter-xs">
          <div class="col-12 col-md-auto">
            <div class="row items-center q-gutter-x-xs quick-filter-toggle">
              <q-btn
                v-for="tab in statusTabs"
                :key="tab.value"
                dense
                unelevated
                no-caps
                :color="procurementStatus === tab.value ? 'primary' : 'transparent'"
                :text-color="procurementStatus === tab.value ? 'white' : 'grey-8'"
                class="quick-filter-btn text-xs"
                @click="setProcurementStatus(tab.value)"
              >
                {{ tab.label }}
              </q-btn>
            </div>
          </div>

          <div class="col-12 col-md-grow row items-center justify-end q-gutter-x-xs">
            <q-input
              v-model="searchText"
              outlined
              rounded
              dense
              clearable
              style="min-width: 220px"
              class="col-grow col-sm-auto dense-search-input"
              placeholder="Search product or document..."
              @keyup.enter="applySearch"
              @clear="applySearch"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" />
              </template>
            </q-input>
            <q-btn flat round dense icon="ph ph-arrow-clockwise" :loading="isFetching" @click="refetch">
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>
          </div>
        </div>
      </q-card>

      <q-card flat bordered class="col column no-wrap overflow-hidden">
        <q-card-section v-if="meta?.sources_included?.length" class="q-pb-none">
          <div class="text-caption text-grey-7">
            Sources:
            <q-chip
              v-for="source in meta.sources_included"
              :key="source"
              dense
              square
              size="sm"
              class="q-ml-xs"
            >
              {{ sourceLabel(source) }}
            </q-chip>
          </div>
        </q-card-section>

        <q-card-section class="col scroll">
          <div v-if="isLoading" class="row justify-center q-pa-xl">
            <q-spinner color="primary" size="32px" />
          </div>

          <div v-else-if="isError" class="text-negative q-pa-md">
            {{ errorMessage }}
          </div>

          <div v-else-if="!groups.length" class="text-grey-7 q-pa-lg text-center">
            No procurement demand for this status.
          </div>

          <q-list v-else bordered separator class="rounded-borders">
            <q-expansion-item
              v-for="group in groups"
              :key="`${group.document_type}-${group.document_id}`"
              expand-separator
              header-class="bg-grey-1"
            >
              <template #header>
                <q-item-section avatar>
                  <q-icon :name="groupIcon(group.document_type)" color="primary" />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-weight-medium">
                    {{ groupTitle(group) }}
                  </q-item-label>
                  <q-item-label caption>
                    {{ group.document_status }}
                    <span v-if="group.vendor?.name || group.vendor?.code">
                      · {{ group.vendor?.name || group.vendor?.code }}
                    </span>
                  </q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-badge color="primary" :label="`${group.items.length} items`" />
                </q-item-section>
              </template>

              <q-markup-table flat dense separator="horizontal" class="q-mx-md q-mb-md">
                <thead>
                  <tr>
                    <th class="text-left">Product</th>
                    <th class="text-left">Code</th>
                    <th class="text-right">Qty</th>
                    <th class="text-right"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="item in group.items" :key="item.source_id">
                    <td>
                      <div class="row items-center no-wrap q-gutter-x-sm">
                        <q-avatar v-if="item.image_url" square size="32px">
                          <img :src="item.image_url" :alt="item.name" />
                        </q-avatar>
                        <q-avatar v-else square size="32px" color="grey-3" text-color="grey-7" icon="ph ph-package" />
                        <span>{{ item.name }}</span>
                      </div>
                    </td>
                    <td class="text-grey-8">
                      {{ item.product_code || item.barcode || '—' }}
                    </td>
                    <td class="text-right text-weight-medium">{{ item.quantity }}</td>
                    <td class="text-right">
                      <q-btn
                        flat
                        dense
                        no-caps
                        color="primary"
                        label="View doc"
                        @click="openDocument(group)"
                      />
                    </td>
                  </tr>
                </tbody>
              </q-markup-table>
            </q-expansion-item>
          </q-list>
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useProcurementDemandGroupsQuery } from '../composables/useProcurementDemandGroupsQuery';
import type {
  ProcurementDemandDocumentType,
  ProcurementDemandGroup,
  ProcurementDemandStatus,
} from '../repositories/procurementDemandRepository';

const authStore = useAuthStore();
const router = useRouter();

const procurementStatus = ref<ProcurementDemandStatus>('procuring');
const searchText = ref('');
const appliedSearch = ref<string | null>(null);
const pageSize = 50;

const statusTabs: Array<{ value: ProcurementDemandStatus; label: string }> = [
  { value: 'procuring', label: 'Procuring' },
  { value: 'ready_for_shipment', label: 'Ready for shipment' },
  { value: 'delivered', label: 'Delivered' },
];

const { data, isLoading, isFetching, isError, error, refetch } = useProcurementDemandGroupsQuery({
  tenantId: computed(() => authStore.tenantId),
  procurementStatus,
  search: appliedSearch,
  limit: pageSize,
});

const meta = computed(() => data.value?.meta ?? null);
const groups = computed(() => data.value?.groups ?? []);

const errorMessage = computed(() => {
  if (!isError.value) return '';
  const err = error.value;
  return err instanceof Error ? err.message : 'Failed to load procurement demand';
});

const setProcurementStatus = (status: ProcurementDemandStatus) => {
  procurementStatus.value = status;
};

const applySearch = () => {
  const trimmed = searchText.value.trim();
  appliedSearch.value = trimmed.length ? trimmed : null;
};

const sourceLabel = (source: string) => {
  if (source === 'shop_order') return 'Shop orders';
  if (source === 'pbc_costing') return 'Costing files';
  return source;
};

const groupIcon = (documentType: ProcurementDemandDocumentType) =>
  documentType === 'shop_order' ? 'ph ph-receipt' : 'ph ph-file-text';

const groupTitle = (group: ProcurementDemandGroup) => {
  if (group.document_type === 'shop_order') {
    return `Shop order #${group.document_id}`;
  }
  return `Costing file #${group.document_id}`;
};

const openDocument = (group: ProcurementDemandGroup) => {
  if (group.document_type === 'shop_order') {
    void router.push({
      name: 'app-shop-order-detail-page',
      params: { id: String(group.document_id) },
    });
    return;
  }
  void router.push({
    name: 'product-based-costing-file-details-page',
    params: { id: String(group.document_id) },
  });
};
</script>
