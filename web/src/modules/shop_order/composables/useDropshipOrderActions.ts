import { ref, computed, watch, type Ref } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { resolveDeliveryZone } from '../services/courierChargeEstimate';
import type { ShopOrder, ShopOrderItem } from '../types';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import { showSuccessNotification, showErrorNotification, parseSupabaseError } from 'src/utils/appFeedback';
import {
  useDropshipReturnMutations,
  type ReturnCondition,
} from './useDropshipReturnMutations';

function returnableQty(item: ShopOrderItem): number {
  const delivered = Number(item.confirmed_quantity ?? item.quantity ?? 0);
  const returned = Number(item.returned_quantity ?? 0);
  return Math.max(0, delivered - returned);
}

function mapConditionQtysToItems(
  items: ShopOrderItem[],
  qtyNormal: number,
  qtyOpenBox: number,
  qtyDamaged: number,
): Array<{ order_item_id: number; returned_qty: number; condition: ReturnCondition }> {
  const totalReturnable = items.reduce((sum, item) => sum + returnableQty(item), 0);
  const requested = qtyNormal + qtyOpenBox + qtyDamaged;
  if (requested <= 0) {
    throw new Error('Return quantity must be greater than zero');
  }
  if (requested !== totalReturnable) {
    throw new Error(
      `Return quantities (${requested}) must equal returnable total (${totalReturnable})`,
    );
  }

  const remaining: Record<ReturnCondition, number> = {
    perfect: qtyNormal,
    open_box: qtyOpenBox,
    damaged: qtyDamaged,
  };
  const result: Array<{
    order_item_id: number;
    returned_qty: number;
    condition: ReturnCondition;
  }> = [];

  for (const item of items) {
    let need = returnableQty(item);
    for (const condition of ['perfect', 'open_box', 'damaged'] as const) {
      if (need <= 0) break;
      const take = Math.min(need, remaining[condition]);
      if (take > 0) {
        result.push({
          order_item_id: item.id,
          returned_qty: take,
          condition,
        });
        remaining[condition] -= take;
        need -= take;
      }
    }
  }

  return result;
}

export function useDropshipOrderActions(
  tenantSlug: Ref<string | null>,
  order: Ref<ShopOrder | null>,
  form: any,
  selectedCourier: Ref<CourierServiceRow | undefined>,
  refetchOrderDetail: () => Promise<void>,
  orderItems: Ref<ShopOrderItem[]>,
) {
  const router = useRouter();
  const orderStore = useShopOrderStore();

  const { finalizeReturnMutation } = useDropshipReturnMutations(tenantSlug);

  const saving = ref(false);
  const handingOff = ref(false);
  const updatingStatus = ref(false);
  const targetUpdatingStatus = ref<string | null>(null);

  const dualInvoiceDialogOpen = ref(false);
  const creatingInvoice = ref(false);

  const returnDialogOpen = ref(false);

  const confirmB2bInvoiceDialogOpen = ref(false);
  const confirmDeleteInvoiceDialogOpen = ref(false);

  const invoicePayout = ref<{
    id: number;
    billing_profile_id: number | null;
    collection_source: string | null;
  } | null>(null);

  const suggestedReturnFee = computed(
    () => Number(selectedCourier.value?.inside_dhaka_return_fee ?? 30),
  );

  const totalReturnableQty = computed(() =>
    orderItems.value.reduce((sum, item) => sum + returnableQty(item), 0),
  );

  const effectiveCollectionSource = computed(
    () =>
      order.value?.collection_source
      ?? invoicePayout.value?.collection_source
      ?? (order.value?.is_prepaid_snapshot ? 'billing_profile' : null),
  );

  const loadInvoicePayoutContext = async () => {
    const invoiceId = order.value?.global_invoice_id;
    if (!invoiceId) {
      invoicePayout.value = null;
      return;
    }
    try {
      const { data } = await supabase
        .from('sales_invoices')
        .select('id, billing_profile_id, collection_source')
        .eq('id', invoiceId)
        .maybeSingle();
      invoicePayout.value = data
        ? {
            id: data.id,
            billing_profile_id: data.billing_profile_id,
            collection_source: data.collection_source ?? null,
          }
        : null;
    } catch {
      invoicePayout.value = null;
    }
  };

  watch(
    () => [order.value?.global_invoice_id, order.value?.status] as const,
    () => {
      void loadInvoicePayoutContext();
    },
    { immediate: true },
  );

  const showSettlementCard = computed(
    () =>
      !!order.value?.global_invoice_id &&
      ['delivered', 'payment_received'].includes(order.value?.status ?? ''),
  );

  const canRecordRemittance = computed(
    () =>
      order.value?.status === 'delivered' &&
      !!order.value?.global_invoice_id &&
      !order.value?.courier_remittance_ref &&
      effectiveCollectionSource.value !== 'billing_profile',
  );

  const performHandoff = async () => {
    if (!order.value) return;
    handingOff.value = true;
    try {
      const res = await orderStore.processDropshipOrder(order.value.id);
      if (res.success) {
        await refetchOrderDetail();
      }
    } finally {
      handingOff.value = false;
    }
  };

  const primaryCta = computed(() => {
    if (!order.value) return null;
    const status = order.value.status;

    if (
      !order.value.global_invoice_id &&
      ['ready_for_pickup', 'shipped', 'delivered', 'payment_received'].includes(status ?? '')
    ) {
      return {
        label: 'Create Accounting Invoice',
        icon: 'ph ph-receipt',
        loading: false,
        action: openDualInvoiceDialog,
      };
    }

    if (canRecordRemittance.value) {
      return {
        label: 'Record Courier Remittance',
        icon: 'ph ph-bank',
        loading: false,
        action: () => {
          if (!order.value) return;
          void router.push({
            name: 'app-shop-dropship-finance-hub-page',
            query: {
              orderId: String(order.value.id),
              step: 'courier_remittance',
            },
          });
        },
      };
    }

    return null;
  });

  const openRecipientInvoicePreview = () => {
    if (!order.value) return;
    const routeData = router.resolve({
      name: 'app-shop-dropship-recipient-invoice-preview',
      params: {
        id: order.value.id,
        tenantSlug: tenantSlug.value || undefined,
      },
    });
    window.open(routeData.href, '_blank');
  };

  const openDualInvoiceDialog = () => {
    dualInvoiceDialogOpen.value = true;
  };

  const confirmDualInvoice = async () => {
    if (!order.value) return;

    creatingInvoice.value = true;
    try {
      const { data, error } = await supabase.rpc('create_dropship_invoice', {
        p_order_id: order.value.id,
        p_invoice_no: null,
        p_billing_profile_id: null,
        p_note: `Accounting invoice created from dropship order #${order.value.order_no}`,
      });

      if (error) throw error;

      const res = data as any;
      showSuccessNotification(`Accounting invoice #${res.invoice_no || ''} created successfully!`);
      dualInvoiceDialogOpen.value = false;
      await refetchOrderDetail();
    } catch (err: any) {
      showErrorNotification(err.message || 'Failed to create accounting invoice');
    } finally {
      creatingInvoice.value = false;
    }
  };

  const openReturnFinalizeDialog = () => {
    returnDialogOpen.value = true;
  };

  const submitReturnFinalize = async (payload: {
    qty_normal: number;
    qty_open_box: number;
    qty_damaged: number;
    actual_return_fee: number;
    deduct_from_middle_man: boolean;
    override_reason: string;
    note: string;
  }) => {
    if (!order.value) return;

    let items: Array<{
      order_item_id: number;
      returned_qty: number;
      condition: ReturnCondition;
    }>;
    try {
      items = mapConditionQtysToItems(
        orderItems.value,
        Number(payload.qty_normal) || 0,
        Number(payload.qty_open_box) || 0,
        Number(payload.qty_damaged) || 0,
      );
    } catch (err: unknown) {
      showErrorNotification(
        err instanceof Error ? err.message : 'Invalid return quantities',
      );
      return;
    }

    updatingStatus.value = true;
    targetUpdatingStatus.value = 'returned';
    try {
      await finalizeReturnMutation.mutateAsync({
        orderId: order.value.id,
        items,
        actualReturnCharge: Number(payload.actual_return_fee) || 0,
        deductFromMiddleman: payload.deduct_from_middle_man === true,
        overrideReason: payload.override_reason?.trim() || null,
        reason: payload.note?.trim() || 'Refused on delivery',
        returnRef: `RET-${order.value.id}-${Date.now()}`,
      });

      returnDialogOpen.value = false;
      await refetchOrderDetail();
    } finally {
      updatingStatus.value = false;
      targetUpdatingStatus.value = null;
    }
  };

  const executeStatusUpdate = async (status: string) => {
    if (!order.value) return;

    if (status === 'returned') {
      openReturnFinalizeDialog();
      return;
    }

    updatingStatus.value = true;
    targetUpdatingStatus.value = status;

    try {
      const { data, error } = await supabase.rpc('advance_dropship_order_status', {
        p_order_id: order.value.id,
        p_target_status: status,
      });
      if (error) throw error;
      if (data && typeof data === 'object' && (data as any).success === false) {
        throw new Error((data as any).error || 'Failed to update status');
      }
      showSuccessNotification(`Status updated to ${status.replace(/_/g, ' ')}`);

      await refetchOrderDetail();
    } catch (err: any) {
      showErrorNotification(parseSupabaseError(err, 'Failed to update status'));
    } finally {
      updatingStatus.value = false;
      targetUpdatingStatus.value = null;
    }
  };

  const onUpdateStatus = async (status: string) => {
    if (!order.value || order.value.status === status) return;

    if (order.value.status === 'processing' && status === 'ready_for_pickup') {
      confirmB2bInvoiceDialogOpen.value = true;
      return;
    }

    if ((status === 'processing' || status === 'confirmed') && order.value.global_invoice_id) {
      targetUpdatingStatus.value = status;
      confirmDeleteInvoiceDialogOpen.value = true;
      return;
    }

    await executeStatusUpdate(status);
  };

  const saveChanges = async () => {
    if (!order.value) return;

    saving.value = true;
    try {
      let finalAddress = form.shipping_address.trim();
      const parts = [
        form.thana ? `Thana: ${form.thana}` : '',
        form.district ? `District: ${form.district}` : '',
        form.post_code ? `Post Code: ${form.post_code}` : '',
      ].filter(Boolean);
      if (parts.length > 0) {
        finalAddress = `${finalAddress}\n${parts.join(', ')}`;
      }

      const { error: dbError } = await supabase.rpc('update_dropship_consignment', {
        p_order_id: order.value.id,
        p_cod_collect_amount: form.cod_collect_amount,
        p_package_weight_band: form.package_weight_band,
        p_item_category: null,
        p_parcel_description: null,
        p_courier_order_ref: order.value.order_no,
        p_delivery_zone: resolveDeliveryZone(form.district),
        p_sender_name: form.sender_name,
        p_pickup_phone: form.pickup_phone,
        p_pickup_address: form.pickup_address,
        p_payout_account_type: 'bank',
        p_payout_account_info: null,
        p_allow_open_box: form.allow_open_box,
        p_delivery_instruction_notes: form.delivery_instruction_notes,
        p_courier_service_id: form.courier_service_id,
        p_courier_tracking_number: form.courier_awb_number,
        p_courier_awb_number: form.courier_awb_number,
        p_courier_consignment_id: null,
        p_tracking_url: form.tracking_url,
        p_courier_cost_amount: form.delivery_charge,
        p_recipient_name: form.recipient_name,
        p_recipient_phone: form.recipient_phone,
        p_recipient_phone_secondary: form.secondary_phone || null,
        p_shipping_address: finalAddress,
        p_shipping_district: form.district || null,
        p_shipping_thana: form.thana || null,
        p_delivery_charge_amount: form.delivery_charge,
        p_cod_charge_amount: form.cod_charge,
      });

      if (dbError) throw dbError;

      const { error: chargesError } = await supabase
        .from('shop_orders')
        .update({
          deduct_delivery_from_margin: form.deduct_delivery_from_margin,
          deduct_cod_from_margin: form.deduct_cod_from_margin,
          deduct_print_from_margin: form.deduct_print_from_margin,
          deduct_packing_from_margin: form.deduct_packing_from_margin,
        })
        .eq('id', order.value.id);
      if (chargesError) throw chargesError;

      showSuccessNotification('Consignment details saved successfully!');
      await refetchOrderDetail();
    } catch (err: any) {
      showErrorNotification(err.message || 'Failed to save consignment');
    } finally {
      saving.value = false;
    }
  };

  return {
    saving,
    handingOff,
    updatingStatus,
    targetUpdatingStatus,
    primaryCta,
    showSettlementCard,
    canRecordRemittance,
    returnDialogOpen,
    suggestedReturnFee,
    totalReturnableQty,
    dualInvoiceDialogOpen,
    creatingInvoice,
    confirmB2bInvoiceDialogOpen,
    confirmDeleteInvoiceDialogOpen,
    saveChanges,
    onUpdateStatus,
    executeStatusUpdate,
    submitReturnFinalize,
    performHandoff,
    openRecipientInvoicePreview,
    openDualInvoiceDialog,
    confirmDualInvoice,
  };
}
