<template>
  <q-page class="tracking-page flex flex-center">
    <!-- Loading -->
    <div v-if="loading" class="column items-center q-gutter-y-md">
      <q-spinner color="primary" size="3em" />
      <div class="text-grey-6">Loading shipment status…</div>
    </div>

    <!-- Not found -->
    <div v-else-if="!shipment" class="column items-center text-center q-pa-xl q-gutter-y-sm">
      <q-icon name="ph ph-link-break" size="64px" color="grey-4" />
      <div class="text-h6 text-grey-7">Link not found</div>
      <div class="text-body2 text-grey-5">
        This tracking link is invalid or has been removed by the sender.
      </div>
    </div>

    <!-- Shipment progress card -->
    <div v-else class="tracking-card-wrap">
      <q-card flat bordered class="tracking-card">

        <!-- Header -->
        <q-card-section class="tracking-header q-pb-sm">
          <div class="row items-center no-wrap q-gutter-x-sm q-mb-xs">
            <q-icon name="ph ph-package" size="20px" color="primary" />
            <span class="text-caption text-uppercase text-grey-6 tracking-label">Shipment Tracking</span>
          </div>
          <div class="text-h6 text-weight-bold text-grey-9">{{ shipment.name }}</div>
          <div v-if="shipment.progress_flow" class="text-body2 text-grey-7 q-mt-xs">
            Flow: {{ shipment.progress_flow.name }}
          </div>
          <div class="row items-center q-gutter-x-sm q-mt-xs">
            <q-chip
              dense
              square
              size="sm"
              :color="statusColor(shipment.status)"
              text-color="white"
              class="text-weight-bold text-uppercase text-xxs"
            >
              {{ formatStatus(shipment.status) }}
            </q-chip>
            <span class="text-caption text-grey-5">
              Updated {{ formatDate(shipment.updated_at) }}
            </span>
          </div>
        </q-card-section>

        <q-separator />

        <!-- Progress timeline -->
        <q-card-section class="q-pt-md">
          <div v-if="shipment.progress_tags.length" class="progress-timeline">
            <div
              v-for="(tag, idx) in shipment.progress_tags"
              :key="tag.id"
              class="timeline-step"
              :class="{
                'step-done': isStepDone(tag),
                'step-active': isStepActive(tag),
                'step-pending': !isStepDone(tag) && !isStepActive(tag),
              }"
            >
              <!-- Connector line -->
              <div v-if="idx < shipment.progress_tags.length - 1" class="timeline-line" />

              <!-- Dot -->
              <div class="timeline-dot-wrap">
                <div class="timeline-dot" :style="dotStyle(tag)">
                  <q-icon
                    v-if="isStepDone(tag)"
                    name="ph ph-check"
                    size="12px"
                    color="white"
                  />
                  <div v-else-if="isStepActive(tag)" class="active-pulse" />
                </div>
              </div>

              <!-- Label -->
              <div class="timeline-label">
                <div
                  class="text-weight-medium"
                  :class="isStepActive(tag) ? 'text-grey-9' : isStepDone(tag) ? 'text-grey-7' : 'text-grey-5'"
                >
                  {{ tag.name }}
                </div>
                <div v-if="isStepActive(tag)" class="text-caption text-primary text-weight-medium">
                  Current stage
                </div>
              </div>
            </div>
          </div>

          <!-- No progress tags configured -->
          <div v-else class="text-center text-grey-5 q-py-md">
            <q-icon name="ph ph-map-trifold" size="32px" class="q-mb-xs" />
            <div class="text-body2">Progress stages not configured yet.</div>
          </div>
        </q-card-section>

        <!-- Footer -->
        <q-separator />
        <q-card-section class="q-py-sm row items-center q-gutter-x-sm">
          <q-icon name="ph ph-shield-check" size="14px" color="grey-4" />
          <span class="text-caption text-grey-5">This is a read-only public tracking page.</span>
        </q-card-section>

      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import {
  publicShipmentTrackingRepository,
  type PublicShipmentStatus,
  type PublicProgressTag,
} from '../repositories/publicShipmentTrackingRepository';
import { date } from 'quasar';

const route = useRoute();

const loading = ref(true);
const shipment = ref<PublicShipmentStatus | null>(null);

function formatStatus(status: string): string {
  switch (status) {
    case 'draft':      return 'Draft';
    case 'in_transit': return 'In Transit';
    case 'received':   return 'Received';
    case 'cancelled':  return 'Cancelled';
    default:           return status;
  }
}

function statusColor(status: string): string {
  switch (status) {
    case 'draft':      return 'grey-6';
    case 'in_transit': return 'orange-8';
    case 'received':   return 'positive';
    case 'cancelled':  return 'negative';
    default:           return 'grey-6';
  }
}

function formatDate(ts: string): string {
  return date.formatDate(ts, 'D MMM YYYY, h:mm A');
}

function isStepActive(tag: PublicProgressTag): boolean {
  return shipment.value?.progress_tag?.id === tag.id;
}

function isStepDone(tag: PublicProgressTag): boolean {
  if (!shipment.value?.progress_tag) return false;
  const activeOrder = shipment.value.progress_tag.sort_order ?? 0;
  const tagOrder = tag.sort_order ?? 0;
  return tagOrder < activeOrder;
}

function dotStyle(tag: PublicProgressTag): Record<string, string> {
  if (isStepActive(tag)) return { background: tag.color || '#3b82f6', boxShadow: `0 0 0 4px ${(tag.color || '#3b82f6')}33` };
  if (isStepDone(tag))   return { background: '#6b7280' };
  return { background: '#e5e7eb', border: '2px solid #d1d5db' };
}

onMounted(async () => {
  const token = route.params.token as string;
  if (!token) { loading.value = false; return; }
  try {
    shipment.value = await publicShipmentTrackingRepository.getShipmentPublicStatus(token);
  } catch {
    shipment.value = null;
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped lang="scss">
.tracking-page {
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
  min-height: 100vh;
}

.tracking-card-wrap {
  width: 100%;
  max-width: 480px;
  padding: 24px 16px;
}

.tracking-card {
  border-radius: 12px;
}

.tracking-header {
  background: rgba(255, 255, 255, 0.6);
}

.tracking-label {
  letter-spacing: 0.08em;
  font-size: 10px;
}

/* Timeline */
.progress-timeline {
  display: flex;
  flex-direction: column;
  gap: 0;
}

.timeline-step {
  display: flex;
  align-items: flex-start;
  position: relative;
  padding-bottom: 20px;

  &:last-child {
    padding-bottom: 0;
  }
}

.timeline-line {
  position: absolute;
  left: 11px;
  top: 24px;
  bottom: 0;
  width: 2px;
  background: #e5e7eb;
  z-index: 0;
}

.step-done .timeline-line {
  background: #9ca3af;
}

.timeline-dot-wrap {
  flex-shrink: 0;
  width: 24px;
  display: flex;
  justify-content: center;
  margin-right: 12px;
  position: relative;
  z-index: 1;
}

.timeline-dot {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: box-shadow 0.2s;
}

.active-pulse {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: white;
}

.timeline-label {
  padding-top: 2px;
  min-width: 0;
}
</style>
