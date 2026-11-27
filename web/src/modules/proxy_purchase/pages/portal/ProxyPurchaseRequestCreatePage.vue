<template>
  <q-page class="tf-page-fill theme-shop pp-request-create-page">
    <div class="pp-request-create-page__inner">
      <div v-if="isSupplierRole">
        <TfEmptyState title="Not available" message="Suppliers cannot open purchase requests here." />
      </div>

      <template v-else>
        <header class="tf-page-toolbar pp-request-create-page__toolbar">
          <div class="tf-page-toolbar__left">
            <TfBtn
              variant="icon"
              icon="ph ph-arrow-left"
              aria-label="Back"
              @click="goDashboard"
            />
            <div class="col min-width-0">
              <div class="tf-page-toolbar__title ellipsis">{{ requestHeadline }}</div>
              <div v-if="requestStatus" class="pp-request-create-page__meta ellipsis">
                {{ isDraft ? 'Draft' : 'Posted' }}
              </div>
            </div>
          </div>
          <div class="tf-page-toolbar__actions">
            <TfBtn
              v-if="isDraft"
              variant="secondary"
              size="md"
              label="Add item"
              icon="ph ph-plus"
              @click="openAddLine"
            />
            <TfBtn
              v-if="isDraft"
              variant="tertiary"
              size="md"
              label="Instructions"
              icon="ph ph-note-pencil"
              @click="showInstructions = true"
            />
            <TfBtn
              v-if="isDraft"
              variant="primary"
              size="md"
              label="Post"
              icon="ph ph-paper-plane-tilt"
              :loading="postRequest.isPending.value"
              :disable="!canPost"
              @click="confirmPost"
            />
            <TfBtn
              v-if="isDraft && isCustomerRole"
              variant="icon"
              icon="ph ph-trash"
              color="negative"
              aria-label="Delete draft request"
              :loading="deleteDraft.isPending.value"
              @click="confirmDelete"
            />
          </div>
        </header>

        <PpRequestOrderLinesSection
          :view-key="orderLinesViewKey"
          :lines="lines"
          :loading="requestQuery.isPending.value || linesQuery.isPending.value"
          :deleting-line-id="deletingLineId"
          @add-item="openAddLine"
          @edit-line="startEditLine"
          @delete-line="confirmDeleteLine"
        />

      <section
        v-if="requestQuery.data.value?.bucket_description"
        class="q-mt-md q-pa-md pp-request-create-page__instructions"
      >
        <div class="text-caption text-weight-bold text-uppercase q-mb-xs">Instructions</div>
        <div class="text-body2">{{ requestQuery.data.value.bucket_description }}</div>
      </section>
      </template>
    </div>

    <PpAddOrderLineDialog
      v-model="showLineDialog"
      :edit-line="editingLine"
      :loading="lineDialogLoading"
      @submit="onLineDialogSubmit"
    />
    <PpRequestInstructionsDialog
      v-model="showInstructions"
      :initial-text="requestQuery.data.value?.bucket_description"
      :loading="saveInstructions.isPending.value"
      @submit="onSaveInstructions"
    />

    <TfConfirmDialog
      v-model="showPostConfirm"
      title="Post to admin?"
      message="You will not be able to edit items or instructions after posting."
      confirm-label="Post"
      :confirm-loading="postRequest.isPending.value"
      @confirm="onConfirmPost"
    />
    <TfConfirmDialog
      v-model="showDeleteRequestConfirm"
      title="Delete draft request?"
      message="This cannot be undone. The request and its items will be removed."
      confirm-label="Delete"
      destructive
      :confirm-loading="deleteDraft.isPending.value"
      @confirm="onConfirmDeleteRequest"
    />
    <TfConfirmDialog
      v-model="showDeleteLineConfirm"
      title="Remove item?"
      message="This line will be removed from the draft request."
      confirm-label="Remove"
      destructive
      :confirm-loading="deleteLine.isPending.value"
      @confirm="onConfirmDeleteLine"
      @cancel="linePendingDelete = null"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfConfirmDialog from 'src/components/ui/TfConfirmDialog.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { getProxyDashboardRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';
import PpAddOrderLineDialog from '../../components/portal/PpAddOrderLineDialog.vue';
import PpRequestInstructionsDialog from '../../components/portal/PpRequestInstructionsDialog.vue';
import PpRequestOrderLinesSection from '../../components/portal/request-order-lines/PpRequestOrderLinesSection.vue';
import type { PpOrderLine } from '../../types/ppPurchaseRequest';
import { usePpPurchaseRequestPageQuery } from '../../composables/usePpPurchaseRequestPageQuery';
import { usePpPurchaseRequestMutations } from '../../composables/usePpPurchaseRequestMutations';
import { usePpRequestOrderLinesView } from '../../composables/usePpRequestOrderLinesView';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const requestId = computed(() => {
  const raw = route.params.requestId;
  const id = typeof raw === 'string' ? Number.parseInt(raw, 10) : Number(raw);
  return Number.isFinite(id) && id > 0 ? id : null;
});

const isSupplierRole = computed(() => {
  const role = authStore.matchedRole;
  return role === 'proxy_supplier_admin' || role === 'proxy_supplier_staff';
});

const { requestQuery, linesQuery } = usePpPurchaseRequestPageQuery(requestId);
const { addLine, updateLine, deleteLine, saveInstructions, postRequest, deleteDraft } =
  usePpPurchaseRequestMutations(requestId);

const isCustomerRole = computed(() => {
  const role = authStore.matchedRole;
  return role === 'proxy_customer_admin' || role === 'proxy_customer_staff';
});

const lines = computed(() => linesQuery.data.value ?? []);
const requestStatus = computed(() => requestQuery.data.value?.status ?? null);
const { viewKey: orderLinesViewKey } = usePpRequestOrderLinesView(requestStatus);
const isDraft = computed(() => requestStatus.value === 'draft');
const canPost = computed(() => isDraft.value && lines.value.length > 0 && !postRequest.isPending.value);

const requestHeadline = computed(() => {
  const req = requestQuery.data.value;
  if (!req) return '…';
  const num = req.request_number?.trim();
  if (num) return num;
  return '…';
});

const showLineDialog = ref(false);
const editingLine = ref<PpOrderLine | null>(null);
const deletingLineId = ref<number | null>(null);
const showInstructions = ref(false);
const showPostConfirm = ref(false);
const showDeleteRequestConfirm = ref(false);
const showDeleteLineConfirm = ref(false);
const linePendingDelete = ref<PpOrderLine | null>(null);

const lineDialogLoading = computed(
  () => addLine.isPending.value || updateLine.isPending.value,
);

const openAddLine = () => {
  editingLine.value = null;
  showLineDialog.value = true;
};

const startEditLine = (line: PpOrderLine) => {
  editingLine.value = line;
  showLineDialog.value = true;
};

onMounted(() => {
  if (isSupplierRole.value) {
    void router.replace(getProxyDashboardRouteLocation(route));
  }
});

watch(
  () => requestQuery.error.value,
  (err) => {
    if (err) {
      void router.replace(getProxyDashboardRouteLocation(route));
    }
  },
);

const goDashboard = () => {
  void router.push(getProxyDashboardRouteLocation(route));
};

const onLineDialogSubmit = async (payload: {
  url: string;
  needed_qty: number;
  description?: string;
  lineId?: number;
}) => {
  if (payload.lineId != null) {
    await updateLine.mutateAsync({
      lineId: payload.lineId,
      url: payload.url,
      needed_qty: payload.needed_qty,
      description: payload.description,
    });
  } else {
    await addLine.mutateAsync(payload);
  }
  showLineDialog.value = false;
  editingLine.value = null;
};

const confirmDeleteLine = (line: PpOrderLine) => {
  linePendingDelete.value = line;
  showDeleteLineConfirm.value = true;
};

const onConfirmDeleteLine = async () => {
  const line = linePendingDelete.value;
  if (!line) return;
  deletingLineId.value = line.id;
  try {
    await deleteLine.mutateAsync(line.id);
    showDeleteLineConfirm.value = false;
    linePendingDelete.value = null;
  } finally {
    deletingLineId.value = null;
  }
};

const onSaveInstructions = async (text: string) => {
  await saveInstructions.mutateAsync(text);
  showInstructions.value = false;
};

const confirmPost = () => {
  showPostConfirm.value = true;
};

const onConfirmPost = async () => {
  showLineDialog.value = false;
  showInstructions.value = false;
  editingLine.value = null;
  try {
    await postRequest.mutateAsync();
    showPostConfirm.value = false;
  } catch {
    /* error toast handled in mutation */
  }
};

const confirmDelete = () => {
  showDeleteRequestConfirm.value = true;
};

const onConfirmDeleteRequest = async () => {
  try {
    await deleteDraft.mutateAsync();
    showDeleteRequestConfirm.value = false;
    goDashboard();
  } catch {
    /* error toast handled in mutation */
  }
};
</script>

<style scoped>
.pp-request-create-page__inner {
  width: 100%;
  max-width: 1200px;
  margin-inline: auto;
  padding: 0 0.25rem 1rem;
}

.pp-request-create-page__toolbar {
  position: static;
  top: auto;
  margin-bottom: 12px;
}

.pp-request-create-page__meta {
  font-size: 12px;
  font-weight: 500;
  color: var(--tf-neutral-muted);
  line-height: 1.2;
}

.pp-request-create-page__instructions {
  border: 1px solid var(--tf-neutral-border);
  border-radius: 8px;
  background: var(--tf-neutral-surface);
}
</style>