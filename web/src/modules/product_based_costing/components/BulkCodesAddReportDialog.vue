<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card class="q-dialog-plugin column no-wrap" style="width: 520px; max-width: 95vw; max-height: 85vh">
      <q-card-section class="row items-center q-pb-none col-auto">
        <div class="text-h6 text-weight-bold">
          {{ $t('product_based_costing.bulk_codes_report_title') }}
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-sm col scroll">
        <div class="row q-col-gutter-sm q-mb-md">
          <div class="col-6 col-sm-3">
            <div class="summary-tile">
              <div class="summary-tile__value">{{ report.totalParsed }}</div>
              <div class="summary-tile__label">{{ $t('product_based_costing.bulk_codes_report_parsed') }}</div>
            </div>
          </div>
          <div class="col-6 col-sm-3">
            <div class="summary-tile summary-tile--positive">
              <div class="summary-tile__value">{{ report.added }}</div>
              <div class="summary-tile__label">{{ $t('product_based_costing.bulk_codes_report_added') }}</div>
            </div>
          </div>
          <div class="col-6 col-sm-3">
            <div class="summary-tile summary-tile--warning">
              <div class="summary-tile__value">{{ report.duplicateCodes.length }}</div>
              <div class="summary-tile__label">{{ $t('product_based_costing.bulk_codes_report_duplicates') }}</div>
            </div>
          </div>
          <div class="col-6 col-sm-3">
            <div class="summary-tile summary-tile--muted">
              <div class="summary-tile__value">{{ report.alreadyOnFile.length }}</div>
              <div class="summary-tile__label">{{ $t('product_based_costing.bulk_codes_report_on_file') }}</div>
            </div>
          </div>
        </div>

        <div v-if="report.missing.length > 0" class="report-section q-mb-md">
          <div class="text-subtitle2 text-negative q-mb-xs">
            {{ $t('product_based_costing.bulk_codes_report_not_found', { count: report.missing.length }) }}
          </div>
          <q-list dense bordered separator class="rounded-borders report-list">
            <q-item v-for="code in report.missing" :key="`missing-${code}`" dense>
              <q-item-section class="bw-tabular">{{ code }}</q-item-section>
            </q-item>
          </q-list>
        </div>

        <div v-if="report.duplicateCodes.length > 0" class="report-section q-mb-md">
          <div class="text-subtitle2 text-warning q-mb-xs">
            {{ $t('product_based_costing.bulk_codes_report_duplicate_list', { count: report.duplicateCodes.length }) }}
          </div>
          <q-banner dense class="bg-amber-1 text-amber-10 rounded-borders q-mb-sm">
            {{ $t('product_based_costing.bulk_codes_report_duplicate_hint') }}
          </q-banner>
          <q-list dense bordered separator class="rounded-borders report-list">
            <q-item v-for="entry in report.duplicateCodes" :key="`dup-${entry.code}`" dense>
              <q-item-section class="bw-tabular">{{ entry.code }}</q-item-section>
              <q-item-section side>
                <q-badge color="amber-8" :label="`×${entry.count}`" />
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <div v-if="report.alreadyOnFile.length > 0" class="report-section q-mb-md">
          <div class="text-subtitle2 text-grey-8 q-mb-xs">
            {{ $t('product_based_costing.bulk_codes_report_on_file_list', { count: report.alreadyOnFile.length }) }}
          </div>
          <q-list dense bordered separator class="rounded-borders report-list">
            <q-item v-for="code in report.alreadyOnFile" :key="`onfile-${code}`" dense>
              <q-item-section class="bw-tabular">{{ code }}</q-item-section>
            </q-item>
          </q-list>
        </div>

        <div
          v-if="
            report.added === 0 &&
            report.duplicateCodes.length === 0 &&
            report.alreadyOnFile.length === 0 &&
            report.missing.length === 0
          "
          class="text-body2 text-grey-7 text-center q-py-md"
        >
          {{ $t('product_based_costing.bulk_codes_report_nothing_done') }}
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1 col-auto">
        <q-btn
          unelevated
          color="primary"
          no-caps
          :label="$t('product_based_costing.done')"
          v-close-popup
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { useDialogPluginComponent } from 'quasar';

export interface BulkCodesAddReport {
  totalParsed: number;
  added: number;
  duplicateCodes: Array<{ code: string; count: number }>;
  alreadyOnFile: string[];
  missing: string[];
}

defineProps<{
  report: BulkCodesAddReport;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide } = useDialogPluginComponent();
</script>

<style scoped>
.summary-tile {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 10px 8px;
  text-align: center;
}

.summary-tile--positive .summary-tile__value {
  color: #15803d;
}

.summary-tile--warning .summary-tile__value {
  color: #b45309;
}

.summary-tile--muted .summary-tile__value {
  color: #64748b;
}

.summary-tile__value {
  font-size: 1.25rem;
  font-weight: 700;
  line-height: 1.2;
  color: #0f172a;
}

.summary-tile__label {
  font-size: 11px;
  color: #64748b;
  margin-top: 2px;
}

.report-list {
  max-height: 160px;
  overflow-y: auto;
}
</style>
