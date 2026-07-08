<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide">
    <q-card style="width: 580px; max-width: 95vw" class="floating-surface shadow-2">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div>
          <div class="text-h6 text-weight-bold">Landed cost breakdown</div>
          <div class="text-caption text-grey-8">
            {{ stockLabel }}
          </div>
        </div>
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-none">
        <q-list dense separator class="rounded-borders">
          <!-- Product cost -->
          <q-item>
            <q-item-section>
              <q-item-label class="text-weight-medium">Product cost</q-item-label>
              <q-item-label caption class="breakdown-detail">
                Origin {{ formatMoney(d.origin_unit_price) }}
                <template v-if="d.extra_origin_unit_price > 0">
                  + extra origin {{ formatMoney(d.extra_origin_unit_price) }}
                </template>
                = {{ formatMoney(originTotal) }}
              </q-item-label>
              <q-item-label caption class="breakdown-detail">
                × product conversion {{ d.product_conversion_rate }} =
                {{ formatMoney(breakdown.product_unit_cost) }}
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-item-label class="text-weight-bold">{{
                formatMoney(breakdown.product_unit_cost)
              }}</q-item-label>
            </q-item-section>
          </q-item>

          <!-- Cargo share -->
          <q-item>
            <q-item-section>
              <q-item-label class="text-weight-medium">Cargo share (per unit)</q-item-label>

              <q-item-label caption class="text-weight-medium text-grey-8 q-mt-xs">
                Cargo bill (shipment)
              </q-item-label>
              <q-item-label caption class="breakdown-detail">
                Invoice weight {{ formatKg(d.total_cargo_weight_kg) }} × cargo rate
                {{ formatMoney(d.cargo_rate) }}/kg × cargo conv. {{ d.cargo_conversion_rate }}
              </q-item-label>
              <q-item-label caption class="breakdown-detail">
                = cargo total {{ formatMoney(breakdown.shipment_cargo_cost) }}
              </q-item-label>

              <q-item-label caption class="text-weight-medium text-grey-8 q-mt-xs">
                This item (weight allocation)
              </q-item-label>
              <template v-if="breakdown.uses_weight_based_cargo">
                <q-item-label caption class="breakdown-detail">
                  Product weight {{ formatGrams(d.product_weight_g) }}
                  <template v-if="d.extra_weight_g > 0"
                    >+ extra {{ formatGrams(d.extra_weight_g) }}</template
                  >
                  = {{ formatGrams(d.product_weight_g + d.extra_weight_g) }} per unit
                </q-item-label>
                <q-item-label caption class="breakdown-detail">
                  {{ formatKg(d.unit_weight_kg) }} × qty {{ d.quantity }} = line weight
                  {{ formatKg(breakdown.line_weight_kg) }}
                </q-item-label>
                <q-item-label caption class="breakdown-detail">
                  {{ formatKg(breakdown.line_weight_kg) }} of
                  {{ formatKg(breakdown.shipment_total_weight_kg) }} item weights ({{
                    formatPct(d.cargo_weight_share_pct)
                  }})
                </q-item-label>
                <q-item-label caption class="breakdown-detail">
                  × cargo total {{ formatMoney(breakdown.shipment_cargo_cost) }} = line allocation
                  {{ formatMoney(d.cargo_line_allocation) }}
                </q-item-label>
                <q-item-label caption class="breakdown-detail">
                  ÷ qty {{ d.quantity || 1 }} =
                  {{ formatMoney(breakdown.cargo_share_per_unit) }} per unit
                </q-item-label>
              </template>
              <template v-else>
                <q-item-label caption class="breakdown-detail text-grey-7">
                  No item weights — equal split: cargo total ÷ U ({{
                    breakdown.shipment_unit_count
                  }})
                </q-item-label>
                <q-item-label caption class="breakdown-detail">
                  {{ formatMoney(breakdown.shipment_cargo_cost) }} ÷
                  {{ breakdown.shipment_unit_count }} =
                  {{ formatMoney(breakdown.cargo_share_per_unit) }} per unit
                </q-item-label>
              </template>
            </q-item-section>
            <q-item-section side>
              <q-item-label class="text-weight-bold">{{
                formatMoney(breakdown.cargo_share_per_unit)
              }}</q-item-label>
            </q-item-section>
          </q-item>

          <!-- Ops share -->
          <q-item>
            <q-item-section>
              <q-item-label class="text-weight-medium">Ops share (per unit)</q-item-label>
              <q-item-label caption class="breakdown-detail">
                Hand tags {{ formatMoney(d.hand_tag_unit_cost) }} × U ({{
                  breakdown.shipment_unit_count
                }}) = {{ formatMoney(d.hand_tags_total) }}
              </q-item-label>
              <q-item-label caption class="breakdown-detail">
                Stickers {{ formatMoney(d.sticker_unit_cost) }} × U ({{
                  breakdown.shipment_unit_count
                }}) = {{ formatMoney(d.stickers_total) }}
              </q-item-label>
              <q-item-label caption class="breakdown-detail">
                Labor {{ formatMoney(d.labor_total_cost) }} + transport
                {{ formatMoney(d.transportation_total_cost) }} + washing
                {{ formatMoney(d.washing_total_cost) }}
              </q-item-label>
              <q-item-label caption class="breakdown-detail">
                = ops total {{ formatMoney(breakdown.shipment_ops_cost) }} ÷ U ({{
                  breakdown.shipment_unit_count
                }}) = {{ formatMoney(breakdown.ops_share_per_unit) }} per unit
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-item-label class="text-weight-bold">{{
                formatMoney(breakdown.ops_share_per_unit)
              }}</q-item-label>
            </q-item-section>
          </q-item>

          <!-- Additional charges -->
          <q-item>
            <q-item-section>
              <q-item-label class="text-weight-medium">Additional charges</q-item-label>
              <q-item-label caption class="breakdown-detail"
                >Per-item extra cost (cost currency)</q-item-label
              >
            </q-item-section>
            <q-item-section side>
              <q-item-label class="text-weight-bold">{{
                formatMoney(breakdown.additional_charges_cost)
              }}</q-item-label>
            </q-item-section>
          </q-item>

          <!-- Landed total -->
          <q-item class="bg-teal-1">
            <q-item-section>
              <q-item-label class="text-weight-bold text-teal-10">Landed unit cost</q-item-label>
              <q-item-label caption class="breakdown-detail text-teal-9">
                {{ formatMoney(breakdown.product_unit_cost) }}
                + {{ formatMoney(breakdown.cargo_share_per_unit) }} +
                {{ formatMoney(breakdown.ops_share_per_unit) }} +
                {{ formatMoney(breakdown.additional_charges_cost) }} =
                {{ formatMoney(breakdown.landed_unit_cost) }}
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-item-label class="text-h6 text-weight-bold text-teal-10">
                {{ formatMoney(breakdown.landed_unit_cost) }}
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-list>

        <div v-if="shipmentName" class="text-caption text-grey-6 q-mt-md">
          Shipment: {{ shipmentName }}
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Close" color="primary" v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script lang="ts">
import { defineComponent, computed, type PropType } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import type { ThriftUnitCostBreakdown } from '../../shared/utils/computeThriftUnitCosts';

export type LandedBreakdownStockInfo = {
  name?: string;
  barcode?: string;
};

export default defineComponent({
  name: 'ThriftLandedCostBreakdownDialog',
  props: {
    stock: {
      type: Object as PropType<LandedBreakdownStockInfo>,
      required: true,
    },
    breakdown: {
      type: Object as PropType<ThriftUnitCostBreakdown>,
      required: true,
    },
    shipmentName: {
      type: String,
      default: '',
    },
    formatCost: {
      type: Function as PropType<(amount: number) => string>,
      required: true,
    },
  },
  emits: [...useDialogPluginComponent.emits],
  setup(props) {
    const { dialogRef, onDialogHide } = useDialogPluginComponent();

    const d = computed(() => props.breakdown.details);

    const stockLabel = computed(() => {
      const name = props.stock.name || 'Item';
      const barcode = props.stock.barcode ? ` (${props.stock.barcode})` : '';
      return `${name}${barcode}`;
    });

    const originTotal = computed(() => {
      return d.value.origin_unit_price + d.value.extra_origin_unit_price;
    });

    function formatMoney(amount: number): string {
      return props.formatCost(amount);
    }

    function formatKg(kg: number): string {
      return `${kg.toFixed(3)} kg`;
    }

    function formatGrams(g: number): string {
      return `${g} g`;
    }

    function formatPct(pct: number | null): string {
      if (pct == null) return '—';
      return `${pct.toFixed(2)}%`;
    }

    return {
      dialogRef,
      onDialogHide,
      d,
      stockLabel,
      originTotal,
      formatMoney,
      formatKg,
      formatGrams,
      formatPct,
    };
  },
});
</script>

<style scoped>
.breakdown-detail {
  line-height: 1.45;
  white-space: normal;
}
</style>
