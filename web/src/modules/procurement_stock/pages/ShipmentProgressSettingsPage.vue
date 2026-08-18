<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between">
        <div>
          <div class="text-overline text-primary">Procurement & Stock</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Shipment Progress</h1>
          <div class="text-body2 text-grey-7 q-mt-xs">
            Create multiple shipment journeys, pick a default flow, and manage stages inside each flow.
          </div>
        </div>
        <q-btn color="primary" unelevated no-caps icon="ph ph-plus" label="Add flow" @click="openFlowDialog()" />
      </section>

      <q-banner v-if="shipmentStore.error" class="bg-negative text-white" rounded dense>
        <div class="row items-center justify-between q-gutter-sm">
          <div>{{ shipmentStore.error }}</div>
          <q-btn flat dense color="white" no-caps label="Dismiss" @click="shipmentStore.error = null" />
        </div>
      </q-banner>

      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-4">
          <q-card flat bordered>
            <q-card-section class="row items-center justify-between q-pb-sm">
              <div class="text-subtitle2 text-weight-medium">Flows</div>
              <q-toggle v-model="showArchivedFlows" label="Show archived" dense />
            </q-card-section>
            <q-separator />
            <q-list v-if="visibleFlows.length" separator>
              <q-item
                v-for="flow in visibleFlows"
                :key="flow.id"
                clickable
                :active="selectedFlowId === flow.id"
                active-class="selected-flow-row"
                @click="selectFlow(flow.id)"
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
                  <div class="row items-center q-gutter-x-xs">
                    <q-btn flat round dense size="sm" icon="ph ph-pencil-simple" color="primary" @click.stop="openFlowDialog(flow)" />
                    <q-btn
                      flat
                      round
                      dense
                      size="sm"
                      icon="ph ph-star"
                      color="amber-8"
                      :disable="flow.is_default"
                      @click.stop="markDefault(flow.id)"
                    />
                    <q-btn
                      v-if="flow.is_active"
                      flat round dense size="sm" icon="ph ph-archive" color="grey-7"
                      @click.stop="toggleFlowArchive(flow.id, true)"
                    />
                    <q-btn
                      v-else
                      flat round dense size="sm" icon="ph ph-arrow-counter-clockwise" color="positive"
                      @click.stop="toggleFlowArchive(flow.id, false)"
                    />
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
            <div v-else class="q-pa-lg text-center text-grey-6">
              <q-icon name="ph ph-git-branch" size="40px" class="q-mb-sm text-grey-4" />
              <div class="text-subtitle2 q-mb-xs">No flows yet</div>
              <q-btn color="primary" unelevated no-caps label="Create first flow" @click="openFlowDialog()" />
            </div>
          </q-card>
        </div>

        <div class="col-12 col-md-8">
          <q-card flat bordered>
            <q-card-section class="row items-center justify-between q-pb-sm">
              <div>
                <div class="text-subtitle2 text-weight-medium">
                  {{ selectedFlow?.name || 'Select a flow' }}
                </div>
                <div class="text-caption text-grey-6">
                  Only stages from the selected flow appear in shipment progress and public tracking.
                </div>
              </div>
              <div class="row items-center q-gutter-sm">
                <q-toggle v-model="showArchivedStages" label="Show archived" dense />
                <q-btn
                  color="primary"
                  unelevated
                  no-caps
                  icon="ph ph-plus"
                  label="Add stage"
                  :disable="!selectedFlow"
                  @click="openStageDialog()"
                />
              </div>
            </q-card-section>
            <q-separator />

            <q-list v-if="visibleStages.length" separator>
              <q-item v-for="(stage, idx) in visibleStages" :key="stage.flow_stage_id" :class="{ 'archived-row': !stage.is_active }">
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
                    <q-btn flat round dense size="sm" icon="ph ph-arrow-up" color="grey-6" :disable="idx === 0 || !stage.is_active" @click="moveStage(idx, -1)" />
                    <q-btn flat round dense size="sm" icon="ph ph-arrow-down" color="grey-6" :disable="idx === activeStages.length - 1 || !stage.is_active" @click="moveStage(idx, 1)" />
                    <q-btn flat round dense size="sm" icon="ph ph-pencil-simple" color="primary" @click="openStageDialog(stage)" />
                    <q-btn
                      v-if="stage.is_active"
                      flat round dense size="sm" icon="ph ph-archive" color="grey-7"
                      @click="toggleStageArchive(stage.flow_stage_id, true)"
                    />
                    <q-btn
                      v-else
                      flat round dense size="sm" icon="ph ph-arrow-counter-clockwise" color="positive"
                      @click="toggleStageArchive(stage.flow_stage_id, false)"
                    />
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
            <div v-else class="q-pa-xl text-center text-grey-6">
              <q-icon name="ph ph-map-trifold" size="40px" class="q-mb-sm text-grey-4" />
              <div class="text-subtitle2 q-mb-xs">
                {{ selectedFlow ? 'No stages in this flow yet' : 'Choose a flow to manage stages' }}
              </div>
            </div>
          </q-card>
        </div>
      </div>
    </div>

    <q-dialog v-model="flowDialogOpen" persistent>
      <q-card style="min-width: 360px">
        <q-card-section class="row items-center justify-between">
          <div class="text-h6">{{ editingFlow ? 'Edit flow' : 'Add flow' }}</div>
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
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
          <q-btn flat round dense icon="ph ph-x" v-close-popup />
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
import { computed, onMounted, ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { requestConfirmation, showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import type { ShipmentProgressFlow, ShipmentProgressFlowStage } from '../repositories/globalShipmentRepository';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();

const loading = ref(false);
const saving = ref(false);
const selectedFlowId = ref<number | null>(null);
const showArchivedFlows = ref(false);
const showArchivedStages = ref(false);

const flowDialogOpen = ref(false);
const editingFlow = ref<ShipmentProgressFlow | null>(null);
const flowForm = ref({ name: '' });

const stageDialogOpen = ref(false);
const editingStage = ref<ShipmentProgressFlowStage | null>(null);
const stageForm = ref({ name: '', color: '#64748b' });

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

async function loadFlows() {
  if (!authStore.tenantId) return;
  loading.value = true;
  try {
    await shipmentStore.loadProgressTagsForSettings(authStore.tenantId, true);
    if (!selectedFlowId.value) {
      selectedFlowId.value = shipmentStore.progressFlows.find((flow) => flow.is_default)?.id ?? shipmentStore.progressFlows[0]?.id ?? null;
    }
    if (selectedFlowId.value) {
      await shipmentStore.loadProgressFlowStages(selectedFlowId.value, true);
    }
  } finally {
    loading.value = false;
  }
}

async function selectFlow(flowId: number) {
  selectedFlowId.value = flowId;
  await shipmentStore.loadProgressFlowStages(flowId, true);
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
    } else {
      const flow = await shipmentStore.createProgressFlow(authStore.tenantId, flowForm.value.name.trim());
      selectedFlowId.value = flow.id;
      await shipmentStore.loadProgressFlowStages(flow.id, true);
      showSuccessNotification('Flow created');
    }
    flowDialogOpen.value = false;
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

onMounted(async () => {
  await loadFlows();
});
</script>

<style scoped lang="scss">
.selected-flow-row {
  background: rgba(59, 130, 246, 0.08);
}

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
  border: 1px solid rgba(0, 0, 0, 0.12);
}
</style>
