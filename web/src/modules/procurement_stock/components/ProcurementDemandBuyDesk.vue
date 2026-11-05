<template>
  <q-page class="q-px-xs q-py-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-card flat bordered class="flex-shrink-0 q-pa-sm">
        <header class="q-mb-sm">
          <h1 class="text-subtitle1 text-weight-bold q-my-none">Demand paper</h1>
          <p class="text-caption text-grey-7 q-mb-none">
            Procuring orders and costing files. Open a document to record vendor orders.
          </p>
        </header>
        <q-input
          v-model="searchText"
          outlined
          dense
          hide-bottom-space
          clearable
          debounce="300"
          placeholder="Search product, order, customer…"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>
      </q-card>

      <div class="col scroll-y-min">
        <div
          v-if="listQuery.isLoading.value && documents.length === 0"
          class="row justify-center q-py-xl"
        >
          <q-spinner-dots size="32px" color="primary" />
        </div>
        <TfEmptyState
          v-else-if="documents.length === 0"
          icon="ph ph-clipboard-text"
          title="No procuring documents"
          message="Nothing is waiting for vendor orders right now."
        />
        <div v-else class="column q-gutter-y-xs">
          <article
            v-for="doc in documents"
            :key="documentKey(doc)"
            class="demand-buy-doc flat bordered"
          >
            <div
              class="demand-buy-doc__head row no-wrap items-center q-gutter-sm cursor-pointer q-pa-sm"
              role="button"
              tabindex="0"
              @click="openDemandDocument(doc)"
              @keydown.enter="openDemandDocument(doc)"
              @keydown.space.prevent="openDemandDocument(doc)"
            >
              <q-icon name="ph ph-caret-right" size="18px" color="grey-8" />
              <div class="col min-width-0">
                <div class="row items-center q-gutter-x-sm no-wrap">
                  <span class="text-weight-bold ellipsis">{{ documentLabel(doc) }}</span>
                  <TfStatusBadge
                    v-if="doc.has_under_ordered_lines"
                    status="attention"
                    label="Vendor order incomplete"
                  />
                  <span class="text-caption text-grey-7">
                    {{ doc.under_ordered_line_count }}/{{ doc.line_count }} lines short
                  </span>
                </div>
                <div class="text-caption text-grey-7 ellipsis">
                  {{ doc.profile_name || '—' }}
                  <span v-if="doc.customer_group_name"> · {{ doc.customer_group_name }}</span>
                </div>
              </div>
              <q-btn
                flat
                dense
                no-caps
                color="grey-8"
                label="Order"
                class="col-shrink"
                @click.stop="openDocumentSource(doc)"
              />
            </div>
          </article>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useProcurementDemandBuyDocumentsQuery } from '../composables/useProcurementDemandBuyDocumentsQuery';
import type { ProcurementDemandBuyDocument } from '../repositories/procurementDemandRepository';

const authStore = useAuthStore();
const router = useRouter();

const searchText = ref('');
const debouncedSearch = ref('');
let searchDebounceTimer: ReturnType<typeof setTimeout> | undefined;
watch(searchText, (v) => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(() => {
    debouncedSearch.value = v.trim();
  }, 300);
});

const parentTenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId ?? null,
);

const listQuery = useProcurementDemandBuyDocumentsQuery({
  tenantId: parentTenantId,
  search: debouncedSearch,
});

const documents = computed(() => listQuery.data.value?.documents ?? []);

const documentKey = (doc: ProcurementDemandBuyDocument) =>
  `${doc.document_type}-${doc.document_id}`;

const documentLabel = (doc: ProcurementDemandBuyDocument) =>
  doc.shop_order_no?.trim() ||
  doc.document_name?.trim() ||
  `#${doc.document_id}`;

const openDemandDocument = (doc: ProcurementDemandBuyDocument) => {
  const tenantSlug = authStore.tenantSlug || undefined;
  void router.push({
    name: 'app-procurement-demand-document',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      documentType: doc.document_type,
      documentId: String(doc.document_id),
    },
    query: {
      documentName: documentLabel(doc),
    },
  });
};

const openDocumentSource = (doc: ProcurementDemandBuyDocument) => {
  const tenantSlug = authStore.tenantSlug || '';
  if (doc.document_type === 'shop_order') {
    void router.push({
      name: 'app-shop-order-detail-page',
      params: { tenantSlug, id: String(doc.document_id) },
    });
    return;
  }
  void router.push({
    name: 'product-based-costing-file-details-page',
    params: { tenantSlug, id: String(doc.document_id) },
  });
};
</script>

<style scoped lang="scss">
.demand-buy-doc {
  background: var(--tf-neutral-surface);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 4px);
}
.demand-buy-doc__head:focus-visible {
  outline: 2px solid var(--tf-focus-ring, #0d6b5c);
  outline-offset: 2px;
}
</style>
