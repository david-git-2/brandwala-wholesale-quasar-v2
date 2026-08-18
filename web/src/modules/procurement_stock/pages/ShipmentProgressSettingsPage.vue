<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <div class="row items-start justify-between q-col-gutter-sm">
        <div class="col">
          <AppPageHeader
            eyebrow="Procurement & Stock"
            :title="selectedFlow ? selectedFlow.name : 'Shipment Progress'"
            :subtitle="selectedFlow
              ? 'Add stages in the order a shipment should move through.'
              : 'Create a flow, then open it to add stages.'"
          />
        </div>
        <div class="col-auto row items-center q-gutter-sm">
          <q-btn
            v-if="selectedFlow"
            flat
            no-caps
            color="primary"
            icon="ph ph-arrow-left"
            label="All flows"
            data-test="back-to-flows"
            @click="backToFlows"
          />
          <q-btn
            v-if="!selectedFlow && visibleFlows.length"
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Add flow"
            style="border-radius: 8px"
            data-test="add-flow"
            @click="openFlowDialog()"
          />
          <q-btn
            v-if="selectedFlow && visibleStages.length"
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Add stage"
            style="border-radius: 8px"
            data-test="add-stage"
            @click="openStageDialog()"
          />
        </div>
      </div>

      <q-banner v-if="shipmentStore.error" class="bg-negative text-white" rounded dense>
        <div class="row items-center justify-between q-gutter-sm">
          <div>{{ shipmentStore.error }}</div>
          <q-btn flat dense color="white" no-caps label="Dismiss" @click="shipmentStore.error = null" />
        </div>
      </q-banner>

      <q-card v-if="!selectedFlowId" flat bordered class="relative-position">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-subtitle2 text-weight-medium">Flows</div>
          <q-toggle v-model="showArchivedFlows" label="Show archived" dense />
        </q-card-section>
        <q-separator />

        <q-inner-loading :showing="loading" />

        <q-list v-if="visibleFlows.length" separator>
          <q-item
            v-for="flow in visibleFlows"
            :key="flow.id"
            clickable
            :class="{ 'archived-row': !flow.is_active }"
            :data-test="`flow-row-${flow.id}`"
            @click="openFlow(flow.id)"
          >
            <q-item-section>
              <div class="row items-center q-gutter-x-sm">
                <span class="text-weight-medium">{{ flow.name }}</span>
                <q-badge v-if="flow.is_default" color="primary" label="default" />
                <q-badge v-if="!flow.is_active" color="grey-5" text-color="white" label="archived" />
              </div>
              <div class="text-caption text-grey-6">{{ flow.stage_count ?? 0 }} stages</div>
            </q-item-section>
            <q-item-section side>
              <q-icon name="ph ph-caret-right" color="grey-5" />
            </q-item-section>
          </q-item>
        </q-list>

        <div v-else-if="!loading" class="q-pa-lg text-center text-grey-6">
          <q-icon name="ph ph-git-branch" size="40px" class="q-mb-sm text-grey-4" />
          <div class="text-subtitle2 q-mb-xs">No flows yet</div>
          <div class="text-caption q-mb-md">Create a flow first. You can add stages after that.</div>
          <q-btn
            color="primary"
            unelevated
            no-caps
            label="Create first flow"
            style="border-radius: 8px"
            data-test="create-first-flow"
            @click="openFlowDialog()"
          />
        </div>
      </q-card>

      <q-card v-else flat bordered class="relative-position">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div>
            <div class="row items-center q-gutter-x-sm">
              <div class="text-subtitle2 text-weight-medium">Stages</div>
              <q-badge v-if="selectedFlow?.is_default" color="primary" label="default flow" />
            </div>
            <div class="text-caption text-grey-6">Only these stages show on shipments using this flow.</div>
          </div>
          <div class="row items-center q-gutter-sm">
            <q-toggle v-model="showArchivedStages" label="Show archived" dense />
            <q-btn
              v-if="selectedFlow"
              flat round dense
              icon="ph ph-pencil-simple"
              color="primary"
              aria-label="Edit flow"
              @click="openFlowDialog(selectedFlow)"
            >
              <q-tooltip>Rename flow</q-tooltip>
            </q-btn>
            <q-btn
              v-if="selectedFlow"
              flat round dense
              icon="ph ph-star"
              color="amber-8"
              aria-label="Set as default"
              :disable="selectedFlow.is_default"
              @click="markDefault(selectedFlow.id)"
            >
              <q-tooltip>{{ selectedFlow.is_default ? 'Already default' : 'Set as default' }}</q-tooltip>
            </q-btn>
            <q-btn
              v-if="selectedFlow?.is_active"
              flat round dense
              icon="ph ph-archive"
              color="grey-7"
              aria-label="Archive flow"
              @click="toggleFlowArchive(selectedFlow.id, true)"
            >
              <q-tooltip>Archive flow</q-tooltip>
            </q-btn>
            <q-btn
              v-else-if="selectedFlow"
              flat round dense
              icon="ph ph-arrow-counter-clockwise"
              color="positive"
              aria-label="Restore flow"
              @click="toggleFlowArchive(selectedFlow.id, false)"
            >
              <q-tooltip>Restore flow</q-tooltip>
            </q-btn>
          </div>
        </q-card-section>
        <q-separator />

        <q-inner-loading :showing="loading" />

        <q-list v-if="visibleStages.length" separator>
          <q-item
            v-for="(stage, idx) in visibleStages"
            :key="stage.flow_stage_id"
            :class="{ 'archived-row': !stage.is_active }"
          >
            <q-item-section avatar>
              <div class="order-badge text-caption text-weight-bold text-grey-6">{{ idx + 1 }}</div>
            </q-item-section>
            <q-item-section>
              <div class="row items-center q-gutter-x-sm">
                <span class="color-dot" :style="{ background: stage.color || '#64748b' }" />
                <span class="text-weight-medium">{{ stage.name }}</span>
                <q-badge v-if="!stage.is_active" color="grey-5" text-color="white" label="archived" />
              </div>
            </q-item-section>
            <q-item-section side>
              <div class="row items-center q-gutter-x-xs">
                <q-btn
                  flat round dense size="sm"
                  icon="ph ph-arrow-up"
                  color="grey-6"
                  aria-label="Move stage up"
                  :disable="idx === 0 || !stage.is_active"
                  @click="moveStage(idx, -1)"
                >
                  <q-tooltip>Move up</q-tooltip>
                </q-btn>
                <q-btn
                  flat round dense size="sm"
                  icon="ph ph-arrow-down"
                  color="grey-6"
                  aria-label="Move stage down"
                  :disable="idx === activeStages.length - 1 || !stage.is_active"
                  @click="moveStage(idx, 1)"
                >
                  <q-tooltip>Move down</q-tooltip>
                </q-btn>
                <q-btn
                  flat round dense size="sm"
                  icon="ph ph-pencil-simple"
                  color="primary"
                  aria-label="Edit stage"
                  @click="openStageDialog(stage)"
                >
                  <q-tooltip>Edit</q-tooltip>
                </q-btn>
                <q-btn
                  v-if="stage.is_active"
                  flat round dense size="sm"
                  icon="ph ph-archive"
                  color="grey-7"
                  aria-label="Archive stage"
                  @click="toggleStageArchive(stage.flow_stage_id, true)"
                >
                  <q-tooltip>Archive</q-tooltip>
                </q-btn>
                <q-btn
                  v-else
                  flat round dense size="sm"
                  icon="ph ph-arrow-counter-clockwise"
                  color="positive"
                  aria-label="Restore stage"
                  @click="toggleStageArchive(stage.flow_stage_id, false)"
                >
                  <q-tooltip>Restore</q-tooltip>
                </q-btn>
              </div>
            </q-item-section>
          </q-item>
        </q-list>

        <div v-else-if="!loading" class="q-pa-xl text-center text-grey-6">
          <q-icon name="ph ph-map-trifold" size="40px" class="q-mb-sm text-grey-4" />
          <div class="text-subtitle2 q-mb-xs">No stages yet</div>
          <div class="text-caption q-mb-md">Add the first stage for this flow.</div>
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-plus"
            label="Add stage"
            style="border-radius: 8px"
            data-test="add-first-stage"
            @click="openStageDialog()"
          />
        </div>
      </q-card>
    </div>

    <q-dialog v-model="flowDialogOpen" persistent>
      <q-card style="min-width: 360px">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">{{ editingFlow ? 'Rename flow' : 'Add flow' }}</div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup aria-label="Close" />
        </q-card-section>
        <q-card-section>
          <q-input v-model="flowForm.name" label="Flow name" outlined dense autofocus />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" unelevated no-caps :loading="saving" :disable="!flowForm.name.trim()" label="Save" @click="saveFlow" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="stageDialogOpen" persistent>
      <q-card style="min-width: 380px">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">{{ editingStage ? 'Edit stage' : 'Add stage' }}</div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup aria-label="Close" />
        </q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <q-input v-model="stageForm.name" label="Stage name" outlined dense autofocus />
          <q-input v-model="stageForm.color" label="Color" outlined dense>
            <template #append>
              <span class="color-preview" :style="{ background: stageForm.color || '#64748b' }">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-color v-model="stageForm.color" no-header-tabs />
                </q-popup-proxy>
              </span>
            </template>
          </q-input>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn color="primary" unelevated no-caps :loading="saving" :disable="!stageForm.name.trim() || !selectedFlowId" label="Save" @click="saveStage" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { requestConfirmation, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { ShipmentProgressFlow, ShipmentProgressFlowStage } from '../repositories/globalShipmentRepository';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();

const loading = ref(false);
const saving = ref(false);
const showArchivedFlows = ref(false);
const showArchivedStages = ref(false);

const flowDialogOpen = ref(false);
const editingFlow = ref<ShipmentProgressFlow | null>(null);
const flowForm = ref({ name: '' });

const stageDialogOpen = ref(false);
const editingStage = ref<ShipmentProgressFlowStage | null>(null);
const stageForm = ref({ name: '', color: '#64748b' });

const selectedFlowId = computed(() => {
  const raw = route.params.flowId;
  const id = Number(raw);
  return Number.isFinite(id) && id > 0 ? id : null;
});

const flows = computed(() => shipmentStore.progressFlows);
const selectedFlow = computed(() => flows.value.find((flow) => flow.id === selectedFlowId.value) ?? null);
const visibleFlows = computed(() =>
  showArchivedFlows.value ? flows.value : flows.value.filter((flow) => flow.is_active !== false),
);
const stages = computed(() => (selectedFlowId.value ? shipmentStore.progressStagesByFlow[selectedFlowId.value] ?? [] : []));
const activeStages = computed(() => stages.value.filter((stage) => stage.is_active !== false));
const visibleStages = computed(() =>
  showArchivedStages.value ? stages.value : activeStages.value,
);

function listRoute() {
  return {
    name: 'app-procurement-shipment-progress-settings',
    params: { tenantSlug: route.params.tenantSlug },
  };
}

function flowRoute(flowId: number) {
  return {
    name: 'app-procurement-shipment-progress-flow',
    params: { tenantSlug: route.params.tenantSlug, flowId: String(flowId) },
  };
}

async function loadFlows() {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    await shipmentStore.loadProgressTagsForSettings(authStore.tenantId, true);
  } finally {
    loading.value = false;
  }
}

async function loadStages(flowId: number) {
  loading.value = true;
  try {
    await shipmentStore.loadProgressFlowStages(flowId, true);
  } finally {
    loading.value = false;
  }
}

function openFlow(flowId: number) {
  void router.push(flowRoute(flowId));
}

function backToFlows() {
  void router.push(listRoute());
}

function openFlowDialog(flow?: ShipmentProgressFlow) {
  editingFlow.value = flow ?? null;
  flowForm.value = { name: flow?.name ?? '' };
  flowDialogOpen.value = true;
}

function openStageDialog(stage?: ShipmentProgressFlowStage) {
  editingStage.value = stage ?? null;
  stageForm.value = { name: stage?.name ?? '', color: stage?.color ?? '#64748b' };
  stageDialogOpen.value = true;
}

async function saveFlow() {
  if (!authStore.tenantId || !flowForm.value.name.trim()) return;
  saving.value = true;
  try {
    if (editingFlow.value) {
      await shipmentStore.updateProgressFlow(editingFlow.value.id, flowForm.value.name.trim());
      showSuccessNotification('Flow updated');
      flowDialogOpen.value = false;
    } else {
      const flow = await shipmentStore.createProgressFlow(authStore.tenantId, flowForm.value.name.trim());
      showSuccessNotification('Flow created');
      flowDialogOpen.value = false;
      await router.push(flowRoute(flow.id));
    }
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to save flow');
  } finally {
    saving.value = false;
  }
}

async function saveStage() {
  if (!selectedFlowId.value || !stageForm.value.name.trim()) return;
  saving.value = true;
  try {
    if (editingStage.value) {
      await shipmentStore.updateProgressFlowStage(selectedFlowId.value, editingStage.value.flow_stage_id, {
        name: stageForm.value.name.trim(),
        color: stageForm.value.color,
      });
      showSuccessNotification('Stage updated');
    } else {
      await shipmentStore.createProgressFlowStage(selectedFlowId.value, stageForm.value.name.trim(), stageForm.value.color);
      showSuccessNotification('Stage added');
    }
    await shipmentStore.loadProgressFlowStages(selectedFlowId.value, true);
    stageDialogOpen.value = false;
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to save stage');
  } finally {
    saving.value = false;
  }
}

async function markDefault(flowId: number) {
  try {
    await shipmentStore.setDefaultProgressFlow(flowId);
    showSuccessNotification('Default flow updated');
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to set default flow');
  }
}

async function toggleFlowArchive(flowId: number, archive: boolean) {
  const ok = archive
    ? await requestConfirmation('Archive this flow? It must not be assigned to any shipment.', 'Archive flow', 'Archive')
    : true;
  if (!ok) return;
  try {
    await shipmentStore.archiveProgressFlow(flowId, archive);
    showSuccessNotification(archive ? 'Flow archived' : 'Flow restored');
    if (archive) backToFlows();
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to update flow');
  }
}

async function toggleStageArchive(flowStageId: number, archive: boolean) {
  if (!selectedFlowId.value) return;
  const ok = archive
    ? await requestConfirmation('Archive this stage? It must not be used by any shipment.', 'Archive stage', 'Archive')
    : true;
  if (!ok) return;
  try {
    await shipmentStore.archiveProgressFlowStage(selectedFlowId.value, flowStageId, archive);
    showSuccessNotification(archive ? 'Stage archived' : 'Stage restored');
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to update stage');
  }
}

async function moveStage(idx: number, direction: -1 | 1) {
  if (!selectedFlowId.value) return;
  const list = [...activeStages.value];
  const swapIdx = idx + direction;
  if (swapIdx < 0 || swapIdx >= list.length) return;
  [list[idx], list[swapIdx]] = [list[swapIdx]!, list[idx]!];
  try {
    await shipmentStore.reorderProgressFlowStages(
      selectedFlowId.value,
      list.map((stage) => stage.flow_stage_id),
    );
    await shipmentStore.loadProgressFlowStages(selectedFlowId.value, true);
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to reorder stages');
  }
}

watch(selectedFlowId, async (flowId) => {
  if (flowId) await loadStages(flowId);
});

onMounted(async () => {
  await loadFlows();
  if (selectedFlowId.value) await loadStages(selectedFlowId.value);
});
</script>

<style scoped lang="scss">
.archived-row {
  opacity: 0.6;
}

.order-badge {
  width: 20px;
  text-align: center;
}

.color-dot {
  display: inline-block;
  width: 12px;
  height: 12px;
  border-radius: 50%;
}

.color-preview {
  display: inline-block;
  width: 24px;
  height: 24px;
  border-radius: 4px;
  border: 1px solid var(--bw-theme-border);
}
</style>
