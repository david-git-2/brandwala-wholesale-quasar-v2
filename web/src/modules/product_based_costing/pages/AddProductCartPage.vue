<template>
  <q-page class="add-product-cart-page column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <div class="add-product-cart-page__top bg-white border-bottom q-px-sm q-py-xs shrink-0">
      <div class="row items-center no-wrap q-col-gutter-x-xs q-mb-2xs">
        <q-btn
          flat
          round
          dense
          icon="ph ph-arrow-left"
          color="grey-8"
          size="sm"
          aria-label="Back"
          @click="goBackToFile"
        >
          <q-tooltip>{{ $t('product_based_costing.go_back') }}</q-tooltip>
        </q-btn>
        <div class="col min-width-0">
          <div class="add-product-cart-page__title ellipsis">
            PBC-{{ fileId }} · {{ fileName }}
          </div>
        </div>
      </div>
    </div>

    <AddProductCartPanel v-if="fileId > 0" class="col" :file-id="fileId" layout="page" />
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import AddProductCartPanel from '../components/AddProductCartPanel.vue';
import { useProductBasedCostingFileDetailQuery } from '../composables/useProductBasedCostingFileDetailQuery';

const props = defineProps<{
  id?: string | number;
}>();

const route = useRoute();
const router = useRouter();
const tenantStore = useTenantStore();

const fileId = computed(() => {
  const rawId = props.id ?? route.params.id;
  const parsed = Number(rawId);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
});

const { data: file } = useProductBasedCostingFileDetailQuery(fileId);

const fileName = computed(
  () => file.value?.name?.trim() || `Costing File #${fileId.value}`,
);

function goBackToFile() {
  const tenantSlug = tenantStore.selectedTenant?.slug ?? route.params.tenantSlug;
  void router.push({
    name: 'product-based-costing-file-details-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      id: String(fileId.value),
    },
  });
}
</script>

<style scoped>
.add-product-cart-page {
  background: var(--tf-theme-base, var(--tf-disabled-bg));
}

.border-bottom {
  border-bottom: 1px solid var(--tf-neutral-border);
}

.add-product-cart-page__title {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.2;
  color: var(--tf-theme-ink, #1e293b);
}
</style>
