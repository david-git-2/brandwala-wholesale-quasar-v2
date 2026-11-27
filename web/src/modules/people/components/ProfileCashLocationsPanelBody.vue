<template>
  <div class="cash-locations-drawer__body col scroll" :class="embedded ? '' : 'q-pa-md'">
    <div class="row justify-end q-mb-md">
      <TfBtn
        variant="primary"
        size="sm"
        icon="ph ph-plus"
        label="Add location"
        data-test="profile-cash-locations-add"
        @click="emit('add-location')"
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
                @click="emit('add-bundle', point)"
              />
              <TfBtn
                variant="icon"
                icon="ph ph-pencil-simple"
                aria-label="Edit location"
                @click="emit('edit-point', point)"
              />
              <TfBtn
                v-if="canDeletePoint(point)"
                variant="icon"
                icon="ph ph-trash"
                color="negative"
                aria-label="Delete location"
                :loading="deletingPointId === point.id"
                @click="emit('delete-point', point)"
              />
            </div>
          </div>
          <div v-if="bundlesForPoint(point).length" class="row q-gutter-sm flex-wrap">
            <ProfileLocationBundleBox
              v-for="bundle in bundlesForPoint(point)"
              :key="bundle.bundleId"
              :bundle="bundle"
              :deleting="deletingBundleId === bundle.bundleId"
              @delete="emit('delete-bundle', bundle)"
            />
          </div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import ProfileLocationBundleBox from './ProfileLocationBundleBox.vue';
import type { CashbookPointRow } from 'src/modules/finance/submodules/bills_pays/repositories/cashbookRepository';
import type { ProfileCashbookBundleRow } from '../types/profileCashbookBundle';

withDefaults(
  defineProps<{
    loading: boolean;
    loadError: string | null;
    points: CashbookPointRow[];
    deletingPointId: number | null;
    deletingBundleId: number | null;
    bundlesForPoint: (point: CashbookPointRow) => ProfileCashbookBundleRow[];
    canDeletePoint: (point: CashbookPointRow) => boolean;
    embedded?: boolean;
  }>(),
  { embedded: false },
);

const emit = defineEmits<{
  'add-location': [];
  'add-bundle': [point: CashbookPointRow];
  'edit-point': [point: CashbookPointRow];
  'delete-point': [point: CashbookPointRow];
  'delete-bundle': [bundle: ProfileCashbookBundleRow];
}>();
</script>