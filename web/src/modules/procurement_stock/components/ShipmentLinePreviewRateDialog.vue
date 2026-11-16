<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card flat bordered class="line-preview-rate-dialog">
      <q-card-section class="row items-center no-wrap q-pb-sm">
        <q-icon name="ph ph-info" size="20px" class="text-primary q-mr-sm" aria-hidden="true" />
        <div class="col text-subtitle2 text-weight-bold">Line preview rate</div>
        <TfBtn variant="icon" icon="ph ph-x" aria-label="Close" @click="emit('update:modelValue', false)" />
      </q-card-section>

      <q-card-section v-if="breakdown" class="q-pt-none column q-gutter-y-md">
        <p class="text-body2 text-grey-8 q-mb-none">
          Shown on the Summary hero and in line landed-cost hints. It is always a
          <strong>money-weighted</strong> blend (Σ foreign × rate ÷ Σ foreign), never an average of two FX
          quotes.
        </p>

        <template v-if="breakdown.kind === 'ap_payments'">
          <div class="line-preview-rate-dialog__panel column q-gutter-y-xs">
            <div class="text-caption text-weight-bold text-grey-6 uppercase">Source</div>
            <p class="text-body2 text-grey-8 q-mb-none">
              From AP bills paid on this shipment. The engine stores this pay-weighted rate on the shipment
              header and uses it ahead of the line-list preview blend (same idea as <strong>Txn blend</strong>
              on this tab).
            </p>
          </div>

          <div class="line-preview-rate-dialog__panel column q-gutter-y-sm">
            <div class="text-caption text-weight-bold text-grey-6 uppercase">Payment-weighted blend</div>
            <div class="line-preview-rate-dialog__formula font-mono text-body2 text-grey-9">
              (Material BDT paid + Freight BDT paid) ÷ (Material {{ breakdown.purchaseSymbol }} paid + Freight
              {{ breakdown.purchaseSymbol }} paid)
            </div>
            <div class="column q-gutter-y-xs text-body2">
              <div
                v-for="leg in [breakdown.material, breakdown.freight]"
                :key="leg.label"
                class="column q-gutter-y-xs"
              >
                <div class="row justify-between">
                  <span class="text-grey-7">{{ leg.label }} paid</span>
                  <span v-if="leg.active && leg.foreign > 0" class="font-mono">
                    {{ breakdown.costSymbol }}{{ fmt(leg.bdt) }} /
                    {{ breakdown.purchaseSymbol }}{{ fmt(leg.foreign) }}
                  </span>
                  <span v-else class="text-grey-6">—</span>
                </div>
                <div v-if="leg.active && leg.rate != null" class="row justify-between">
                  <span class="text-grey-7">→ {{ leg.label }} pay rate</span>
                  <span class="font-mono">
                    {{ breakdown.costSymbol }}{{ rateFmt(leg.rate) }} / {{ breakdown.purchaseSymbol }}
                  </span>
                </div>
                <q-separator v-if="leg.label === 'Material'" class="q-my-xs" />
              </div>
              <div class="row justify-between text-weight-medium q-pt-xs">
                <span>Txn blend (line preview rate)</span>
                <span class="font-mono">
                  {{ breakdown.costSymbol }}{{ fmt(breakdown.blendBdt) }} ÷
                  {{ breakdown.purchaseSymbol }}{{ fmt(breakdown.blendForeign) }}
                  = {{ breakdown.costSymbol }}{{ rateFmt(breakdown.blendRate) }} / {{ breakdown.purchaseSymbol }}
                </span>
              </div>
            </div>
          </div>
        </template>

        <template v-else>
          <div class="line-preview-rate-dialog__panel column q-gutter-y-xs">
            <div class="text-caption text-weight-bold text-grey-6 uppercase">Source</div>
            <p class="text-body2 text-grey-8 q-mb-none">
              No pay-weighted shipment rate yet — blended from the line list purchase total and freight share
              × the material / freight FX on the Costs preview.
            </p>
          </div>

          <div class="line-preview-rate-dialog__panel column q-gutter-y-sm">
            <div class="text-caption text-weight-bold text-grey-6 uppercase">Line-list preview blend</div>
            <div class="line-preview-rate-dialog__formula font-mono text-body2 text-grey-9">
              (Material {{ breakdown.purchaseSymbol }} × Material FX + Freight {{ breakdown.purchaseSymbol }} ×
              Freight FX) ÷ (Material {{ breakdown.purchaseSymbol }} + Freight {{ breakdown.purchaseSymbol }})
            </div>
            <div class="column q-gutter-y-xs text-body2">
              <div class="row justify-between">
                <span class="text-grey-7">Material (line list)</span>
                <span class="font-mono">{{ breakdown.purchaseSymbol }}{{ fmt(breakdown.goodsPurchase) }}</span>
              </div>
              <div class="row justify-between">
                <span class="text-grey-7">× Material FX</span>
                <span class="font-mono">
                  {{ breakdown.costSymbol }}{{ rateFmt(breakdown.productRate) }} / {{ breakdown.purchaseSymbol }}
                </span>
              </div>
              <div class="row justify-between">
                <span class="text-grey-7">BDT leg</span>
                <span class="font-mono">{{ breakdown.costSymbol }}{{ fmt(breakdown.bdtOnMaterial) }}</span>
              </div>
              <q-separator class="q-my-xs" />
              <div class="row justify-between">
                <span class="text-grey-7">
                  Freight ({{ breakdown.cargoWeightKg.toFixed(2) }} kg ×
                  {{ rateFmt(breakdown.cargoRatePerKg) }}/kg)
                </span>
                <span class="font-mono">{{ breakdown.purchaseSymbol }}{{ fmt(breakdown.cargoPurchase) }}</span>
              </div>
              <div class="row justify-between">
                <span class="text-grey-7">× Freight FX</span>
                <span class="font-mono">
                  {{ breakdown.costSymbol }}{{ rateFmt(breakdown.cargoRate) }} / {{ breakdown.purchaseSymbol }}
                </span>
              </div>
              <div class="row justify-between">
                <span class="text-grey-7">BDT leg</span>
                <span class="font-mono">{{ breakdown.costSymbol }}{{ fmt(breakdown.bdtOnFreight) }}</span>
              </div>
              <q-separator class="q-my-xs" />
              <div class="row justify-between text-weight-medium">
                <span>Blend</span>
                <span class="font-mono">
                  {{ breakdown.costSymbol }}{{ fmt(breakdown.totalBdt) }} ÷
                  {{ breakdown.purchaseSymbol }}{{ fmt(breakdown.totalForeign) }}
                  = {{ breakdown.costSymbol }}{{ rateFmt(breakdown.blendRate) }} / {{ breakdown.purchaseSymbol }}
                </span>
              </div>
            </div>
            <p v-if="breakdown.weightNote" class="text-caption text-grey-7 q-mb-none">
              {{ breakdown.weightNote }}
            </p>
          </div>
        </template>

        <p class="text-caption text-grey-7 q-mb-none">
          Per-line landed cost still uses <strong>split</strong> material and freight FX on each line’s product
          and cargo share — not this single rate on the whole base.
        </p>
      </q-card-section>

      <q-card-actions align="right" class="q-pt-none">
        <TfBtn variant="secondary" label="Close" @click="emit('update:modelValue', false)" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { LinePreviewRateBreakdown } from '../utils/linePreviewRateBreakdown';

defineProps<{
  modelValue: boolean;
  breakdown: LinePreviewRateBreakdown | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const fmt = (n: number) =>
  (Math.round(n * 100) / 100).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
const rateFmt = (n: number) => (Math.round(n * 10_000) / 10_000).toFixed(4);
</script>

<style scoped lang="scss">
.line-preview-rate-dialog {
  width: 520px;
  max-width: 95vw;
  border-radius: var(--tf-radius-sm);
}

.line-preview-rate-dialog__panel {
  padding: 12px;
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
  background: var(--tf-neutral-surface-muted, #f8fafc);
}

.line-preview-rate-dialog__formula {
  line-height: 1.45;
}
</style>