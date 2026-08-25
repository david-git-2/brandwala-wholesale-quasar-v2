<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import { date } from 'quasar';

const props = defineProps<{
  order: any;
  orderItems: any[];
  currencySymbol: string;
  isUpdatingCharges: boolean;
}>();

const emit = defineEmits<{
  (e: 'update-charges', payload: any): void;
}>();

const route = useRoute();

const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

// Financial calculations
const recipientSubtotal = computed(() => {
  return props.orderItems.reduce((sum, item) => sum + (item.customer_sell_price_amount ?? 0) * item.quantity, 0);
});

const accountingSubtotal = computed(() => {
  return props.orderItems.reduce((sum, item) => {
    const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
    return sum + price * item.quantity;
  }, 0);
});

const codChargeVal = computed(() => Number(props.order?.cod_charge_amount || 0));
const deliveryChargeVal = computed(() => Number(props.order?.delivery_charge_amount || 0));
const printChargeVal = computed(() => Number(props.order?.print_charge_amount || 0));
const packingChargeVal = computed(() => Number(props.order?.packing_charge_amount || 0));
const discountVal = computed(() => Number(props.order?.discount_amount || 0));
const deductCodFromMargin = computed(() => !!props.order?.deduct_cod_from_margin);
const deductDeliveryFromMargin = computed(() => !!props.order?.deduct_delivery_from_margin);
const deductPrintFromMargin = computed(() => !!props.order?.deduct_print_from_margin);
const deductPackingFromMargin = computed(() => !!props.order?.deduct_packing_from_margin);

const codFeePctLabel = computed(() => {
  const sub = recipientSubtotal.value;
  if (!sub) return 0;
  return Number(((codChargeVal.value / sub) * 100).toFixed(1));
});

const recipientGrandTotal = computed(() => {
  return recipientSubtotal.value
    + (deductDeliveryFromMargin.value ? 0 : deliveryChargeVal.value)
    + (deductPrintFromMargin.value ? 0 : printChargeVal.value)
    + (deductPackingFromMargin.value ? 0 : packingChargeVal.value)
    + (deductCodFromMargin.value ? 0 : codChargeVal.value)
    - discountVal.value;
});

const middlemanTotalCost = computed(() => {
  return accountingSubtotal.value
    + (deductPrintFromMargin.value ? printChargeVal.value : 0)
    + (deductPackingFromMargin.value ? packingChargeVal.value : 0)
    + (deductDeliveryFromMargin.value ? deliveryChargeVal.value : 0)
    + (deductCodFromMargin.value ? codChargeVal.value : 0);
});

const estimatedProfit = computed(() => {
  return recipientSubtotal.value - discountVal.value - middlemanTotalCost.value;
});

// Edit charges dialog
const chargesDialogOpen = ref(false);
const chargesForm = ref({
  delivery_charge_amount: 0,
  deduct_delivery_from_margin: false,
  cod_charge_amount: 0,
  deduct_cod_from_margin: false,
  print_charge_amount: 0,
  deduct_print_from_margin: false,
  packing_charge_amount: 0,
  deduct_packing_from_margin: false,
});

const openChargesDialog = () => {
  const o = props.order;
  if (o) {
    chargesForm.value = {
      delivery_charge_amount: Number(o.delivery_charge_amount || 0),
      deduct_delivery_from_margin: !!o.deduct_delivery_from_margin,
      cod_charge_amount: Number(o.cod_charge_amount || 0),
      deduct_cod_from_margin: !!o.deduct_cod_from_margin,
      print_charge_amount: Number(o.print_charge_amount || 0),
      deduct_print_from_margin: !!o.deduct_print_from_margin,
      packing_charge_amount: Number(o.packing_charge_amount || 0),
      deduct_packing_from_margin: !!o.deduct_packing_from_margin,
    };
    chargesDialogOpen.value = true;
  }
};

const saveCharges = () => {
  emit('update-charges', {
    payload: chargesForm.value,
    closeDialog: () => {
      chargesDialogOpen.value = false;
    },
  });
};
</script>

<template>
  <div>
    <!-- Summary Card -->
    <q-card flat bordered class="details-card">
      <q-card-section class="q-px-lg q-py-md border-bottom">
        <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.order_context') }}</div>
      </q-card-section>

      <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
        <div class="row justify-between">
          <span class="text-grey-6">{{ $t('shop_admin.order_no') }}</span>
          <span class="text-weight-bold text-grey-8">{{ order.order_no }}</span>
        </div>
        <div class="row justify-between">
          <span class="text-grey-6">{{ $t('shop_admin.date') }}</span>
          <span class="text-grey-8">{{ formatDate(order.created_at) }}</span>
        </div>
        <div class="row justify-between">
          <span class="text-grey-6">{{ $t('shop_admin.shop_type_label') }}</span>
          <span class="text-grey-8 text-capitalize">{{ order.shop_type_snapshot }}</span>
        </div>
        <div class="row justify-between" v-if="order.shop_type_snapshot !== 'dropship'">
          <span class="text-grey-6">{{ $t('shop_admin.order_mode_label') }}</span>
          <span class="text-grey-8 text-capitalize">{{ order.order_mode_snapshot }}</span>
        </div>
        <div class="row justify-between">
          <span class="text-grey-6">{{ $t('shop_admin.negotiable') }}</span>
          <span class="text-grey-8">{{
            order.is_negotiable_snapshot ? $t('shop_admin.yes') : $t('shop_admin.no')
          }}</span>
        </div>
        <div class="row justify-between" v-if="order.global_invoice_id">
          <span class="text-grey-6">Invoice:</span>
          <router-link
            :to="{
              name: 'app-global-invoice-details-page',
              params: {
                tenantSlug: route.params.tenantSlug || '',
                id: order.global_invoice_id,
              },
            }"
            class="text-weight-bold text-primary"
          >
            View Invoice
          </router-link>
        </div>
        <div class="row justify-between" v-if="order.status === 'placed'">
          <span class="text-grey-6">Procurement:</span>
          <span class="text-weight-bold text-indigo-7">Placed (Shipment Pull)</span>
        </div>

        <q-separator class="q-my-sm" />

        <!-- Dropship detailed context preview -->
        <template v-if="order.shop_type_snapshot === 'dropship'">
          <div class="row justify-between text-body2 text-grey-7 q-mb-xs">
            <span>Seller (Middle-man):</span>
            <span class="text-weight-bold text-grey-8">{{ order.customer_group_name }}</span>
          </div>

          <div class="row justify-between text-body2 text-grey-7 q-mb-xs">
            <span>{{ $t('shop_admin.payment_mode') }}</span>
            <q-badge
              :color="order.is_prepaid_snapshot ? 'positive' : 'warning'"
              text-color="white"
              class="q-py-xs q-px-sm"
            >
              {{
                order.is_prepaid_snapshot
                  ? $t('shop_admin.payment_prepaid')
                  : $t('shop_admin.payment_cod')
              }}
            </q-badge>
          </div>

          <q-separator class="q-my-xs" />

          <div class="row justify-between text-body2 text-grey-7">
            <span>{{ $t('shop.items_subtotal') }}</span>
            <span>{{ currencySymbol }}{{ recipientSubtotal.toFixed(2) }}</span>
          </div>

          <div class="row justify-between text-body2 text-grey-7" v-if="deliveryChargeVal > 0">
            <span>
              {{ $t('shop.delivery_charge') }}
              <span class="text-grey-5">({{ deductDeliveryFromMargin ? 'deducted from profit' : 'customer pays' }})</span>
            </span>
            <span>{{ currencySymbol }}{{ deliveryChargeVal.toFixed(2) }}</span>
          </div>

          <div class="row justify-between text-body2 text-grey-7" v-if="codChargeVal > 0">
            <span>
              {{ $t('shop.cod_fee', { pct: codFeePctLabel }) }}
              <span class="text-grey-5">({{ deductCodFromMargin ? 'deducted from profit' : 'customer pays' }})</span>
            </span>
            <span>{{ currencySymbol }}{{ codChargeVal.toFixed(2) }}</span>
          </div>

          <div class="row justify-between text-body2 text-grey-7" v-if="printChargeVal > 0">
            <span>
              {{ $t('shop.print_charge') }}
              <span class="text-grey-5">(deducted from profit)</span>
            </span>
            <span>{{ currencySymbol }}{{ printChargeVal.toFixed(2) }}</span>
          </div>

          <div class="row justify-between text-body2 text-grey-7" v-if="packingChargeVal > 0">
            <span>
              {{ $t('shop.packing_charge') }}
              <span class="text-grey-5">(deducted from profit)</span>
            </span>
            <span>{{ currencySymbol }}{{ packingChargeVal.toFixed(2) }}</span>
          </div>

          <div class="row justify-between text-body2 text-negative" v-if="discountVal > 0">
            <span>{{ $t('shop_admin.discount') }}</span>
            <span>-{{ currencySymbol }}{{ discountVal.toFixed(2) }}</span>
          </div>

          <q-separator class="q-my-sm" />

          <div class="row justify-between text-body1 text-weight-bold text-grey-9 q-mb-sm">
            <span>Recipient Grand Total:</span>
            <span>{{ currencySymbol }}{{ recipientGrandTotal.toFixed(2) }}</span>
          </div>

          <div class="bg-blue-50 q-pa-sm rounded-borders text-caption text-grey-8 q-mb-sm" style="border: 1px solid #bfdbfe;">
            <div class="row justify-between">
              <span>Wholesale Base Cost:</span>
              <span class="text-weight-bold">{{ currencySymbol }}{{ accountingSubtotal.toFixed(2) }}</span>
            </div>
            <div class="row justify-between">
              <span>Middle-man Total Cost:</span>
              <span class="text-weight-bold text-grey-9">{{ currencySymbol }}{{ middlemanTotalCost.toFixed(2) }}</span>
            </div>
            <q-separator class="q-my-xs" />
            <div class="row justify-between text-subtitle2 text-weight-bold text-primary">
              <span>Estimated Margin / Profit:</span>
              <span>{{ currencySymbol }}{{ estimatedProfit.toFixed(2) }}</span>
            </div>
          </div>

          <q-btn
            outline
            dense
            color="primary"
            icon="ph ph-pencil-simple"
            label="Edit Charges"
            class="full-width q-mt-xs pill-btn"
            @click="openChargesDialog"
          />
        </template>
      </q-card-section>
    </q-card>

    <!-- Edit Charges Dialog -->
    <q-dialog v-model="chargesDialogOpen" persistent>
      <q-card style="min-width: 350px; border-radius: 14px;">
        <q-card-section class="row items-center border-bottom q-py-md">
          <div class="text-h6 text-weight-bold">Edit Charges</div>
          <q-space />
          <q-btn icon="ph ph-x" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-lg q-gutter-y-md">
          <!-- Delivery -->
          <div class="row items-center q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="chargesForm.delivery_charge_amount"
                type="number"
                label="Delivery Charge"
                outlined
                dense
                :prefix="currencySymbol"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-toggle
                v-model="chargesForm.deduct_delivery_from_margin"
                label="Deduct from Profit"
                dense
              />
            </div>
          </div>

          <!-- COD -->
          <div class="row items-center q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="chargesForm.cod_charge_amount"
                type="number"
                label="COD Charge"
                outlined
                dense
                :prefix="currencySymbol"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-toggle
                v-model="chargesForm.deduct_cod_from_margin"
                label="Deduct from Profit"
                dense
              />
            </div>
          </div>

          <!-- Print -->
          <div class="row items-center q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="chargesForm.print_charge_amount"
                type="number"
                label="Print Charge"
                outlined
                dense
                :prefix="currencySymbol"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-toggle
                v-model="chargesForm.deduct_print_from_margin"
                label="Deduct from Profit"
                dense
              />
            </div>
          </div>

          <!-- Packing -->
          <div class="row items-center q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="chargesForm.packing_charge_amount"
                type="number"
                label="Packaging Charge"
                outlined
                dense
                :prefix="currencySymbol"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-toggle
                v-model="chargesForm.deduct_packing_from_margin"
                label="Deduct from Profit"
                dense
              />
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-px-lg q-pb-md">
          <q-btn flat label="Cancel" color="grey-7" v-close-popup />
          <q-btn
            unelevated
            label="Save"
            color="primary"
            :loading="isUpdatingCharges"
            @click="saveCharges"
            class="pill-btn q-px-md"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<style scoped>
.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.pill-btn {
  border-radius: 8px;
}
</style>
