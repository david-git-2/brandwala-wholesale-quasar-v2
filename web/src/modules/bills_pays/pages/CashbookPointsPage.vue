<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="!isTenantContext" class="col flex flex-center text-grey-7 q-pa-lg">
      Cash points are only for company cash.
    </div>

    <div v-else-if="pointsQuery.isPending.value" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="pointsQuery.isError.value" class="col flex flex-center text-negative q-pa-lg">
      {{ pointsError }}
    </div>

    <div v-else class="col column no-wrap overflow-hidden q-gutter-y-sm">
      <div class="points-toolbar row items-center justify-between q-px-xs shrink-0">
        <div class="text-body2 text-grey-7">
          {{ activeCount }} active · {{ points.length }} total
        </div>
        <q-btn
          color="primary"
          unelevated
          dense
          no-caps
          icon="ph ph-plus"
          label="Add location"
          style="border-radius: 8px"
          @click="openAddPoint"
        />
      </div>

      <div class="col overflow-auto">
        <div v-if="!points.length" class="column items-center justify-center q-pa-xl text-grey-6 points-empty">
          <q-icon name="ph ph-map-pin" size="48px" class="q-mb-sm text-grey-4" />
          <div class="text-subtitle2">No cash locations yet</div>
          <div class="text-caption q-mt-xs">Add a till, safe, or bank counter to tag payments.</div>
        </div>

        <div v-else class="tf-entity-grid q-pa-xs">
          <q-card
            v-for="point in points"
            :key="point.id"
            flat
            bordered
            class="cash-point-card cursor-pointer"
            :class="{ 'cash-point-card--inactive': !point.is_active }"
            @click="openEditPoint(point)"
          >
            <q-card-section>
              <div class="row items-start no-wrap q-gutter-sm">
                <q-icon name="ph ph-wallet" size="28px" class="text-primary q-mt-xs" />
                <div class="col min-width-0">
                  <div class="text-subtitle1 text-weight-medium ellipsis">{{ point.name }}</div>
                  <div class="text-caption text-grey-7">{{ cashbookPointKindLabel(point.kind) }}</div>
                  <div v-if="point.code" class="text-caption text-grey-6 q-mt-xs">Code {{ point.code }}</div>
                  <div v-if="potCodesForPoint(point.id).length" class="row q-gutter-xs q-mt-sm flex-wrap">
                    <q-badge
                      v-for="code in potCodesForPoint(point.id)"
                      :key="code"
                      dense
                      outline
                      color="grey-7"
                      :label="code"
                    />
                  </div>
                </div>
                <q-badge
                  v-if="!point.is_active"
                  dense
                  color="grey-3"
                  text-color="grey-8"
                  label="Inactive"
                />
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>

    <CashbookPointFormDialog
      v-model="pointFormOpen"
      :mode="pointFormMode"
      :point="editingPoint"
      :cashbook-account-id="cashbookAccountId"
      :parent-tenant-id="booksTenantId"
      :operating-tenant-id="operatingTenantId"
      @saved="onPointSaved"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import CashbookPointFormDialog from '../components/CashbookPointFormDialog.vue';
import { useCashbookPointPotsBatchQuery } from '../composables/useCashbookPointPotsQuery';
import { useCashbookPointsQuery } from '../composables/useCashbookPointsQuery';
import { cashbookPointKindLabel } from '../constants/cashbookPointKinds';
import type { CashbookPointRow } from '../repositories/cashbookRepository';

const ALLOWED_TYPES = new Set(['tenant', 'customer', 'courier', 'vendor']);

const authStore = useAuthStore();
const route = useRoute();

const operatingTenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const booksTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return 0;
  return t.parent_id ?? t.id;
});

const entityType = computed(() => {
  const raw = route.params.entityType;
  const t = typeof raw === 'string' ? raw : '';
  return ALLOWED_TYPES.has(t) ? t : 'customer';
});

const entityId = computed(() => {
  const raw = route.params.entityId;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : 0;
});

const isTenantContext = computed(() => entityType.value === 'tenant' && entityId.value > 0);

const pointsContext = computed(() => ({
  booksTenantId: booksTenantId.value,
  entityType: entityType.value,
  entityId: entityId.value,
  enabled: isTenantContext.value,
}));

const { pointsQuery, cashbookAccountId } = useCashbookPointsQuery(pointsContext);

const points = computed(() => {
  const list = pointsQuery.data.value ?? [];
  return [...list].sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name));
});

const pointIds = computed(() => points.value.map((p) => p.id));
const potsBatchEnabled = computed(() => isTenantContext.value && pointIds.value.length > 0);
const potsBatchQuery = useCashbookPointPotsBatchQuery(pointIds, potsBatchEnabled);

const potsByPointId = computed(() => {
  const map = new Map<number, string[]>();
  for (const pot of potsBatchQuery.data.value ?? []) {
    const list = map.get(pot.cashbook_point_id) ?? [];
    list.push(pot.currency_code);
    map.set(pot.cashbook_point_id, list);
  }
  return map;
});

const potCodesForPoint = (pointId: number) => potsByPointId.value.get(pointId) ?? [];

const activeCount = computed(() => points.value.filter((p) => p.is_active).length);

const pointsError = computed(() => {
  const err = pointsQuery.error.value;
  return err instanceof Error ? err.message : 'Could not load cash points.';
});

const pointFormOpen = ref(false);
const pointFormMode = ref<'add' | 'edit'>('add');
const editingPoint = ref<CashbookPointRow | null>(null);

const onPointSaved = () => {
  void pointsQuery.refetch();
  void potsBatchQuery.refetch();
};

const openAddPoint = () => {
  pointFormMode.value = 'add';
  editingPoint.value = null;
  pointFormOpen.value = true;
};

const openEditPoint = (point: CashbookPointRow) => {
  pointFormMode.value = 'edit';
  editingPoint.value = point;
  pointFormOpen.value = true;
};
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.points-toolbar {
  max-width: 960px;
  margin: 0 auto;
  width: 100%;
}
.points-empty,
.tf-entity-grid {
  max-width: 960px;
  margin: 0 auto;
  width: 100%;
}
.cash-point-card {
  border-radius: var(--tf-radius-md, 12px);
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.cash-point-card:hover {
  border-color: var(--tf-theme-primary, #0d6b5c);
  box-shadow: var(--tf-theme-shadow, 0 2px 8px rgba(0, 0, 0, 0.06));
}
.cash-point-card--inactive {
  opacity: 0.72;
}
.min-width-0 {
  min-width: 0;
}
</style>
