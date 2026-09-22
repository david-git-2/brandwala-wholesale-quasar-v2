<template>
  <q-page class="q-pa-sm">
    <div v-if="redirecting" class="row justify-center items-center q-pa-xl">
      <q-spinner color="primary" size="3em" />
    </div>
    <q-banner v-else-if="pageError" class="bw-status-banner bg-negative text-white q-ma-xs">
      {{ pageError }}
    </q-banner>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { batchCodeRepository } from '../repositories/batchCodeRepository';

const route = useRoute();
const router = useRouter();

const listId = Number(route.params.listId);
const redirecting = ref(true);
const pageError = ref<string | null>(null);

onMounted(async () => {
  try {
    const row = await batchCodeRepository.getById(listId);
    if (!row) {
      pageError.value = 'Batch file not found.';
      redirecting.value = false;
      return;
    }
    const tenantSlug = route.params.tenantSlug;
    if (tenantSlug) {
      await router.replace({
        name: 'app-procurement-shipment-batch-code',
        params: { tenantSlug, id: row.shipment_id },
      });
      return;
    }
    await router.replace({
      name: 'app-procurement-shipment-batch-code',
      params: { id: row.shipment_id },
    });
  } catch (err: unknown) {
    pageError.value = (err as Error).message || 'Failed to open batch file.';
    redirecting.value = false;
  }
});
</script>
