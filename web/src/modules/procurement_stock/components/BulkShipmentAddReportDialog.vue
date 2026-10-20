<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card class="q-dialog-plugin column no-wrap" style="width: 520px; max-width: 95vw; max-height: 85vh">
      <q-card-section class="row items-center q-pb-none col-auto">
        <div class="text-subtitle1 text-weight-bold">Bulk Add Report</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup :ripple="false" />
      </q-card-section>

      <q-card-section class="q-pt-sm col scroll">
        <div class="row q-col-gutter-sm q-mb-md">
          <div class="col-6 col-sm-3">
            <div class="summary-tile">
              <div class="summary-tile__value">{{ report.totalParsed }}</div>
              <div class="summary-tile__label">Parsed</div>
            </div>
          </div>
          <div class="col-6 col-sm-3">
            <div class="summary-tile summary-tile--positive">
              <div class="summary-tile__value">{{ report.linesAdded }}</div>
              <div class="summary-tile__label">Lines added</div>
            </div>
          </div>
          <div class="col-6 col-sm-3">
            <div class="summary-tile summary-tile--positive">
              <div class="summary-tile__value">{{ report.totalUnitsAdded }}</div>
              <div class="summary-tile__label">Units inserted</div>
            </div>
          </div>
          <div class="col-6 col-sm-3">
            <div class="summary-tile summary-tile--warning">
              <div class="summary-tile__value">{{ notInsertedCount }}</div>
              <div class="summary-tile__label">Not inserted</div>
            </div>
          </div>
        </div>

        <div v-if="report.missing.length > 0" class="report-section q-mb-md">
          <div class="text-subtitle2 text-negative q-mb-xs">
            Not found in catalog ({{ report.missing.length }})
          </div>
          <q-list dense bordered separator class="report-list">
            <q-item v-for="code in report.missing" :key="`missing-${code}`" dense>
              <q-item-section class="tf-tabular">{{ code }}</q-item-section>
            </q-item>
          </q-list>
        </div>

        <div v-if="report.alreadyOnShipment.length > 0" class="report-section q-mb-md">
          <div class="text-subtitle2 q-mb-xs" style="color: var(--tf-neutral-muted)">
            Already on {{ shipmentTargetLabel }} ({{ report.alreadyOnShipment.length }})
          </div>
          <q-list dense bordered separator class="report-list">
            <q-item v-for="code in report.alreadyOnShipment" :key="`on-shipment-${code}`" dense>
              <q-item-section class="tf-tabular">{{ code }}</q-item-section>
            </q-item>
          </q-list>
        </div>

        <div v-if="report.duplicateCodes.length > 0" class="report-section q-mb-md">
          <div class="text-subtitle2 q-mb-xs" style="color: var(--tf-warning-ink, #b45309)">
            Duplicate codes in paste ({{ report.duplicateCodes.length }})
          </div>
          <div class="text-caption q-mb-sm" style="color: var(--tf-neutral-muted)">
            Only the first occurrence of each product was added.
          </div>
          <q-list dense bordered separator class="report-list">
            <q-item v-for="entry in report.duplicateCodes" :key="`dup-${entry.code}`" dense>
              <q-item-section class="tf-tabular">{{ entry.code }}</q-item-section>
              <q-item-section side>
                <q-badge :label="`×${entry.count}`" />
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div
          v-if="report.linesAdded === 0 && notInsertedCount === 0 && report.duplicateCodes.length === 0"
          class="text-body2 text-center q-py-md"
          style="color: var(--tf-neutral-muted)"
        >
          No items were added.
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md col-auto" style="border-top: 1px solid var(--tf-neutral-border)">
        <q-btn unelevated color="primary" no-caps label="Done" v-close-popup :ripple="false" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useDialogPluginComponent } from 'quasar';

export interface BulkShipmentAddReport {
  totalParsed: number;
  linesAdded: number;
  totalUnitsAdded: number;
  missing: string[];
  alreadyOnShipment: string[];
  duplicateCodes: Array<{ code: string; count: number }>;
}

const props = defineProps<{
  report: BulkShipmentAddReport;
  shipmentHasSections?: boolean;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide } = useDialogPluginComponent();

const notInsertedCount = computed(
  () => props.report.missing.length + props.report.alreadyOnShipment.length,
);

const shipmentTargetLabel = computed(() =>
  props.shipmentHasSections ? 'this section' : 'shipment',
);
</script>

<style scoped>
.summary-tile {
  background: color-mix(in srgb, var(--tf-neutral-surface) 96%, var(--tf-neutral-ink) 4%);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 4px);
  padding: 10px 8px;
  text-align: center;
}

.summary-tile--positive .summary-tile__value {
  color: var(--tf-success-ink, #15803d);
}

.summary-tile--warning .summary-tile__value {
  color: var(--tf-warning-ink, #b45309);
}

.summary-tile__value {
  font-size: 1.25rem;
  font-weight: 700;
  line-height: 1.2;
  color: var(--tf-neutral-ink);
}

.summary-tile__label {
  font-size: 11px;
  color: var(--tf-neutral-muted);
  margin-top: 2px;
}

.report-list {
  max-height: 160px;
  overflow-y: auto;
}
</style>
