<template>
  <q-dialog ref="dialogRef" class="theme-app" @hide="onDialogHide" position="right" full-height persistent>
    <q-card class="drawer-card column no-wrap">
      <q-card-section class="row items-center q-py-sm q-px-md drawer-header no-wrap q-gutter-x-sm">
        <div class="col min-width-0">
          <div class="text-subtitle1 text-weight-bold drawer-header__title">
            {{ $t('product_based_costing.add_products') }}
          </div>
          <div class="text-caption ellipsis drawer-header__subtitle">
            {{ fileName }}
          </div>
        </div>
        <q-btn
          unelevated
          dense
          no-caps
          color="white"
          text-color="primary"
          size="sm"
          icon="ph ph-squares-four"
          :label="$t('product_based_costing.browse_catalog')"
          class="drawer-header__catalog-btn q-px-sm shrink-0"
          @click="openBrowseCatalog"
        />
        <q-btn
          icon="ph ph-x"
          flat
          round
          dense
          color="white"
          class="shrink-0"
          aria-label="Close"
          @click="onSaved"
        />
      </q-card-section>

      <AddCostingItemsPanel
        class="col"
        :file-id="fileId"
        layout="drawer"
        @saved="onSaved"
        @create-new-product="onCreateNewProduct"
      />
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useDialogPluginComponent } from 'quasar';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import AddCostingItemsPanel from './AddCostingItemsPanel.vue';

const props = defineProps<{
  fileId: number;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const route = useRoute();
const router = useRouter();
const tenantStore = useTenantStore();
const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const costingStore = useProductBasedCostingStore();

const fileName = computed(
  () => costingStore.item?.name ?? `Costing File #${props.fileId}`,
);

const onSaved = () => {
  onDialogOK();
};

const onCreateNewProduct = (name: string) => {
  onDialogOK({ createProductName: name });
};

const openBrowseCatalog = () => {
  onDialogOK();
  const tenantSlug = tenantStore.selectedTenant?.slug ?? route.params.tenantSlug;
  void router.push({
    name: 'product-based-costing-add-product-cart-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      id: String(props.fileId),
    },
  });
};
</script>

<style scoped>
.drawer-card {
  width: 640px;
  max-width: 95vw;
  height: calc(100vh - 24px) !important;
  margin: 12px;
  border-radius: 16px !important;
  background: var(--bw-theme-surface) !important;
  color: var(--bw-theme-ink);
  border: 1px solid var(--bw-theme-border);
  box-shadow: var(--bw-theme-shadow) !important;
  overflow: hidden;
}

.drawer-header {
  background: var(--bw-theme-primary) !important;
  border-bottom: 1px solid rgb(0 0 0 / 0.12);
  color: #fff;
}

.drawer-header__title {
  color: #fff;
}

.drawer-header__subtitle {
  color: rgb(255 255 255 / 0.92);
}

.drawer-header__catalog-btn {
  border-radius: 8px;
  font-weight: 700;
}
</style>
