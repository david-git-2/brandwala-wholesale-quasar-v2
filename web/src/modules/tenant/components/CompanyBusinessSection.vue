<template>
  <div v-if="businesses.length" class="company-business-section q-mt-lg">
    <div class="text-overline text-grey-7 text-weight-bold q-mb-sm">Business</div>
    <q-btn-toggle
      :model-value="selectedBrandId"
      toggle-color="primary"
      color="grey-3"
      text-color="grey-8"
      dense
      no-caps
      unelevated
      class="company-business-section__toggle"
      :options="toggleOptions"
      @update:model-value="onSelectBrand"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';

import { useTenantStore } from '../stores/tenantStore';

const props = defineProps<{
  companyId: number;
  companySlug: string;
  selectedBrandId?: number | null;
}>();

const router = useRouter();
const tenantStore = useTenantStore();
const { items } = storeToRefs(tenantStore);

const businesses = computed(() =>
  items.value
    .filter((tenant) => tenant.parent_id === props.companyId)
    .sort((a, b) => a.name.localeCompare(b.name)),
);

const toggleOptions = computed(() =>
  businesses.value.map((tenant) => ({
    label: tenant.name,
    value: tenant.id,
  })),
);

const onSelectBrand = (brandId: number | null) => {
  if (!brandId || brandId === props.selectedBrandId) {
    return;
  }

  void router.push({
    name: 'admin-tenant-details',
    params: {
      tenantSlug: props.companySlug,
      id: brandId,
    },
  });
};
</script>

<style scoped>
.company-business-section__toggle {
  flex-wrap: wrap;
}

.company-business-section__toggle :deep(.q-btn) {
  border-radius: 8px;
  margin: 2px;
}
</style>
