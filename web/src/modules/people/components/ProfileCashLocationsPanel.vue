<template>
  <AppResizableOverlayPanel
    v-model="open"
    storage-key="people.cash-locations-drawer-width"
    :default-width="520"
    :min-width="400"
    :max-width="720"
    aria-label="Cash locations"
  >
    <div class="cash-locations-drawer column no-wrap full-height">
      <div class="cash-locations-drawer__header row items-center no-wrap q-pa-md shrink-0">
        <div class="col min-width-0">
          <div class="text-overline text-primary">Locations</div>
          <div v-if="partyName" class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
            {{ partyName }}
          </div>
        </div>
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          color="grey-7"
          aria-label="Close"
          class="shrink-0"
          @click="open = false"
        />
      </div>

      <q-separator />

      <div class="cash-locations-drawer__body col scroll q-pa-md">
        <div class="row justify-end q-mb-md">
          <TfBtn
            variant="primary"
            size="sm"
            icon="ph ph-plus"
            label="Add location"
            data-test="profile-cash-locations-add"
            @click="openAddDialog"
          />
        </div>

        <div v-if="loading" class="row justify-center q-pa-lg">
          <q-spinner color="primary" size="28px" />
        </div>
        <div v-else-if="loadError" class="text-negative text-body2">
          {{ loadError }}
        </div>
        <TfEmptyState
          v-else-if="!points.length"
          icon="ph ph-map-pin"
          title="No locations yet"
          message="Add a till, safe, or bank counter."
        />
        <div v-else class="tf-entity-grid">
          <q-card
            v-for="point in points"
            :key="point.id"
            flat
            bordered
            class="cash-location-card"
            :class="{ 'cash-location-card--inactive': !point.is_active }"
          >
            <q-card-section class="column q-gutter-y-sm">
              <div class="row items-center no-wrap q-gutter-x-sm">
                <q-icon name="ph ph-map-pin" size="20px" class="text-primary shrink-0" />
                <div class="col min-width-0 row items-center q-gutter-x-xs no-wrap">
                  <span class="text-subtitle2 text-weight-medium ellipsis">{{ point.name }}</span>
                  <q-badge
                    v-if="!point.is_active"
                    dense
                    color="grey-3"
                    text-color="grey-8"
                    label="Inactive"
                  />
                </div>
                <div class="row no-wrap q-gutter-xs shrink-0">
                  <TfBtn
                    variant="icon"
                    icon="ph ph-stack-plus"
                    aria-label="Add bundle"
                    @click="openBundleDialog(point)"
                  />
                  <TfBtn
                    variant="icon"
                    icon="ph ph-pencil-simple"
                    aria-label="Edit location"
                    @click="openEditDialog(point)"
                  />
                  <TfBtn
                    v-if="canDeletePoint(point)"
                    variant="icon"
                    icon="ph ph-trash"
                    color="negative"
                    aria-label="Delete location"
                    :loading="deletingPointId === point.id"
                    @click="confirmDeletePoint(point)"
                  />
                </div>
              </div>
              <div
                v-if="bundlesForPoint(point).length"
                class="row q-gutter-sm flex-wrap"
              >
                <ProfileLocationBundleBox
                  v-for="bundle in bundlesForPoint(point)"
                  :key="bundle.bundleId"
                  :bundle="bundle"
                  :deleting="deletingBundleId === bundle.bundleId"
                  @delete="confirmDeleteBundle(bundle)"
                />
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </AppResizableOverlayPanel>

  <q-dialog v-model="formDialogOpen" persistent>
    <q-card class="profile-cash-location-form-dialog">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-subtitle1 text-weight-bold">
          {{ formMode === 'add' ? 'Add location' : 'Edit location' }}
        </div>
        <q-space />
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          aria-label="Close"
          :disable="formSaving"
          @click="closeFormDialog"
        />
      </q-card-section>
      <q-card-section>
        <q-input
          ref="nameInputRef"
          v-model="formName"
          outlined
          dense
          label="Location name"
          autofocus
          :disable="formSaving"
          @keyup.enter="submitForm"
        />
      </q-card-section>
      <q-card-actions align="right" class="q-px-md q-pb-md">
        <TfBtn variant="tertiary" label="Cancel" :disable="formSaving" @click="closeFormDialog" />
        <TfBtn
          variant="primary"
          :label="formMode === 'add' ? 'Add' : 'Save'"
          :loading="formSaving"
          :disable="!formName.trim()"
          @click="submitForm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>

  <ProfileCashbookBundleCreateDialog
    v-model="bundleDialogOpen"
    :books-tenant-id="booksTenantId"
    :operating-tenant-id="operatingTenantId"
    :profile-id="profileId"
    :point="bundlePoint"
    :bundles-at-point="bundlePoint ? bundlesForPoint(bundlePoint).map((b) => ({ currencyCode: b.currencyCode })) : []"
    @created="onBundleCreated"
  />
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';
import type { QInput } from 'quasar';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import ProfileLocationBundleBox from './ProfileLocationBundleBox.vue';
import ProfileCashbookBundleCreateDialog from './ProfileCashbookBundleCreateDialog.vue';
import type { CashbookPointRow } from 'src/modules/bills_pays/repositories/cashbookRepository';
import { cashbookRepository } from 'src/modules/bills_pays/repositories/cashbookRepository';
import { moneyKernelRepository } from 'src/modules/bills_pays/repositories/moneyKernelRepository';
import { createPayIdempotencyKey } from 'src/modules/bills_pays/repositories/paysRepository';
import { cashbookQueryKeys } from 'src/modules/bills_pays/services/cashbookQueryKeys';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import { useCashbookPointsForProfileQuery } from '../composables/useCashbookPointsForProfileQuery';
import { useProfileCashbookBundlesQuery } from '../composables/useProfileCashbookBundlesQuery';
import type { ProfileCashbookBundleRow } from '../types/profileCashbookBundle';

const props = defineProps<{
  booksTenantId: number;
  operatingTenantId: number;
  profileId: number | null;
  partyName?: string;
}>();

const open = defineModel<boolean>({ required: true });

const queryClient = useQueryClient();
const formName = ref('');
const formDialogOpen = ref(false);
const formMode = ref<'add' | 'edit'>('add');
const editingPoint = ref<CashbookPointRow | null>(null);
const nameInputRef = ref<QInput | null>(null);
const deletingPointId = ref<number | null>(null);
const deletingBundleId = ref<number | null>(null);
const bundleDialogOpen = ref(false);
const bundlePoint = ref<CashbookPointRow | null>(null);

const enabled = computed(() => open.value && props.profileId != null);
const profileIdRef = computed(() => props.profileId);
const booksTenantIdRef = computed(() => props.booksTenantId);

const { pointsQuery, cashbookAccountId } = useCashbookPointsForProfileQuery(
  booksTenantIdRef,
  profileIdRef,
  enabled,
);

const points = computed(() => {
  const list = pointsQuery.data.value ?? [];
  return [...list].sort((a, b) => a.name.localeCompare(b.name));
});

const bundlesQuery = useProfileCashbookBundlesQuery(booksTenantIdRef, profileIdRef, enabled);

const bundlesForPoint = (point: CashbookPointRow) => {
  const code = point.code?.trim().toLowerCase() ?? '';
  return (bundlesQuery.data.value ?? []).filter((bundle) => {
    if (bundle.deskPointId != null && bundle.deskPointId === point.id) return true;
    return bundle.locationCode.toLowerCase() === code;
  });
};

const canDeletePoint = (point: CashbookPointRow) => bundlesForPoint(point).length === 0;

const loading = computed(
  () =>
    pointsQuery.isPending.value
    || pointsQuery.isFetching.value
    || bundlesQuery.isPending.value
    || bundlesQuery.isFetching.value,
);

const loadError = computed(() => {
  const err = pointsQuery.error.value ?? bundlesQuery.error.value;
  return err instanceof Error ? err.message : null;
});

const invalidateAll = async () => {
  await Promise.all([pointsQuery.refetch(), bundlesQuery.refetch()]);
  await queryClient.invalidateQueries({ queryKey: cashbookQueryKeys.root });
};

const addMutation = useMutation({
  mutationFn: async (name: string) => {
    const accountId = cashbookAccountId.value;
    if (accountId == null) throw new Error('Cashbook not ready.');
    await cashbookRepository.createCashbookPoint({
      parentTenantId: props.booksTenantId,
      cashbookAccountId: accountId,
      name: name.trim(),
      currencyCodes: ['BDT'],
    });
  },
  onSuccess: async () => {
    showSuccessNotification('Location added.');
    closeFormDialog(true);
    await invalidateAll();
  },
  onError: (error: unknown) => {
    showErrorNotification(error instanceof Error ? error.message : 'Could not add location.');
  },
});

const editMutation = useMutation({
  mutationFn: async ({ pointId, name }: { pointId: number; name: string }) => {
    const accountId = cashbookAccountId.value;
    if (accountId == null) throw new Error('Cashbook not ready.');
    await cashbookRepository.updateCashbookPoint(pointId, accountId, { name: name.trim() });
  },
  onSuccess: async () => {
    showSuccessNotification('Location updated.');
    closeFormDialog(true);
    await invalidateAll();
  },
  onError: (error: unknown) => {
    showErrorNotification(error instanceof Error ? error.message : 'Could not update location.');
  },
});

const formSaving = computed(
  () => addMutation.isPending.value || editMutation.isPending.value,
);

const openAddDialog = () => {
  formMode.value = 'add';
  editingPoint.value = null;
  formName.value = '';
  formDialogOpen.value = true;
  void nextTick(() => nameInputRef.value?.focus());
};

const openEditDialog = (point: CashbookPointRow) => {
  formMode.value = 'edit';
  editingPoint.value = point;
  formName.value = point.name;
  formDialogOpen.value = true;
  void nextTick(() => nameInputRef.value?.focus());
};

const closeFormDialog = (force?: boolean) => {
  if (force !== true && formSaving.value) return;
  formDialogOpen.value = false;
  formName.value = '';
  editingPoint.value = null;
};

const submitForm = () => {
  const name = formName.value.trim();
  if (!name || formSaving.value) return;
  if (formMode.value === 'add') {
    void addMutation.mutateAsync(name);
    return;
  }
  const point = editingPoint.value;
  if (!point) return;
  void editMutation.mutateAsync({ pointId: point.id, name });
};

const confirmDeleteBundle = async (bundle: ProfileCashbookBundleRow) => {
  const profileId = props.profileId;
  if (profileId == null) return;
  const balanceLabel = bundle.amount > 0 ? ' Remaining cash will be withdrawn.' : '';
  const ok = await requestConfirmation(
    `This closes the bundle and removes it from this location.${balanceLabel}`,
    `Remove ${bundle.currencyCode} bundle?`,
    'Remove',
  );
  if (!ok) return;
  deletingBundleId.value = bundle.bundleId;
  try {
    await moneyKernelRepository.closeCashBundle({
      tenantId: props.booksTenantId,
      profileId,
      bundleId: bundle.bundleId,
      meta: { source: 'people_close_bundle' },
      idempotencyKey: createPayIdempotencyKey(),
    });
    showSuccessNotification(
      bundle.amount > 0 ? 'Bundle withdrawn and removed.' : 'Bundle removed.',
    );
    await invalidateAll();
  } catch (error: unknown) {
    showErrorNotification(error instanceof Error ? error.message : 'Could not remove bundle.');
  } finally {
    deletingBundleId.value = null;
  }
};

const confirmDeletePoint = async (point: CashbookPointRow) => {
  if (!canDeletePoint(point)) {
    showErrorNotification('Remove all bundles before deleting this location.');
    return;
  }
  const ok = await requestConfirmation(
    'This cannot be undone.',
    `Delete “${point.name}”?`,
    'Delete',
  );
  if (!ok) return;
  deletingPointId.value = point.id;
  try {
    await cashbookRepository.deleteCashbookPoint(props.operatingTenantId, point.id);
    showSuccessNotification('Location deleted.');
    await invalidateAll();
  } catch (error: unknown) {
    showErrorNotification(error instanceof Error ? error.message : 'Could not delete location.');
  } finally {
    deletingPointId.value = null;
  }
};

const openBundleDialog = (point: CashbookPointRow) => {
  bundlePoint.value = point;
  bundleDialogOpen.value = true;
};

const onBundleCreated = async () => {
  bundlePoint.value = null;
  await invalidateAll();
};

watch(open, (isOpen) => {
  if (!isOpen) {
    closeFormDialog();
    bundleDialogOpen.value = false;
    bundlePoint.value = null;
  }
});
</script>

<style scoped>
.cash-locations-drawer {
  background: #fff;
  min-height: 0;
}

.cash-locations-drawer__header {
  border-bottom: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.08));
}

.min-width-0 {
  min-width: 0;
}

.cash-location-card {
  border-radius: var(--tf-radius-md, 12px);
}

.cash-location-card--inactive {
  opacity: 0.72;
}

.profile-cash-location-form-dialog {
  width: min(400px, 92vw);
}
</style>
