<template>
  <div class="column no-wrap col overflow-hidden">
    <q-input
      v-model="search"
      dense
      outlined
      clearable
      :placeholder="`Search ${entityLabel}…`"
      class="q-mb-sm"
    />
    <q-list v-if="rows.length" bordered separator class="col overflow-auto">
      <q-item
        v-for="row in rows"
        :key="row.id"
        clickable
        v-ripple
        @click="openRow(row)"
      >
        <q-item-section>
          <q-item-label>{{ row.name }}</q-item-label>
          <q-item-label v-if="row.subtitle" caption>{{ row.subtitle }}</q-item-label>
        </q-item-section>
        <q-item-section v-if="row.balance != null" side>
          <q-item-label class="tf-num">{{ formatAmountBdt(row.balance) }}</q-item-label>
        </q-item-section>
      </q-item>
    </q-list>
    <div v-else-if="!loading" class="text-caption text-grey-6 text-center q-pa-lg">
      No {{ entityLabel }} found.
    </div>
    <div v-else class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="2em" />
    </div>

    <q-dialog v-model="drawerOpen" maximized transition-show="slide-up" transition-hide="slide-down">
      <q-card class="column no-wrap">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 col">{{ selected?.name }}</div>
          <q-btn flat round dense icon="close" @click="drawerOpen = false" />
        </q-card-section>
        <q-card-section class="col overflow-auto">
          <ProfileOperatingAccountPanel
            v-if="selected"
            :tenant-id="tenantId"
            :books-tenant-id="booksTenantId"
            :entity-type="entityType"
            :entity-id="selected.id"
            :party-name="selected.name"
            :tenant-name="tenantName"
            :tenant-slug="tenantSlug"
            :active="drawerOpen"
          />
        </q-card-section>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { cashbookRepository } from 'src/modules/bills_pays/repositories/cashbookRepository';
import ProfileOperatingAccountPanel from 'src/modules/bills_pays/components/ProfileOperatingAccountPanel.vue';
import { formatAmountBdt } from 'src/utils/currency';
import type { PayTransferEntityType } from 'src/modules/bills_pays/types/payTransferParty';

const props = defineProps<{
  entityType: PayTransferEntityType | 'investor' | 'cargo_company';
  entityLabel: string;
}>();

const authStore = useAuthStore();
const route = useRoute();
const search = ref('');
const rows = ref<Array<{ id: number; name: string; subtitle?: string; balance?: number }>>([]);
const loading = ref(false);
const drawerOpen = ref(false);
const selected = ref<{ id: number; name: string } | null>(null);

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});
const tenantName = computed(() => authStore.selectedTenant?.name ?? 'Company');
const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined,
);

const load = async () => {
  if (!tenantId.value) return;
  loading.value = true;
  try {
    const list = await cashbookRepository.listEntities({
      tenantId: tenantId.value,
      entityType: props.entityType,
      search: search.value || undefined,
      limit: 100,
    });
    rows.value = list.map((r) => ({
      id: r.entity_id,
      name: r.name,
      subtitle: r.entity_type,
      balance: r.available_balance,
    }));
  } finally {
    loading.value = false;
  }
};

watch([() => props.entityType, search, tenantId], () => void load(), { immediate: true });

const openRow = (row: { id: number; name: string }) => {
  selected.value = row;
  drawerOpen.value = true;
};
</script>
