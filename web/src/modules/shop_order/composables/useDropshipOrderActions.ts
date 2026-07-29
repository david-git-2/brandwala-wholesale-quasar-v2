import { ref, reactive, computed, watch, type Ref } from 'vue';
import { useRouter } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { shopOrderQueryKeys } from '../services/shopOrderQueryKeys';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { resolveDeliveryZone } from '../services/courierChargeEstimate';
import type { ShopOrder } from '../types';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

export function useDropshipOrderActions(
  tenantSlug: Ref<string | null>,
  order: Ref<ShopOrder | null>,
  form: any,
  selectedCourier: Ref<CourierServiceRow | undefined>,
  refetchOrderDetail: () => Promise<void>,
) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const orderStore = useShopOrderStore();

  const saving = ref(false);
  const handingOff = ref(false);
  const updatingStatus = ref(false);
  const targetUpdatingStatus = ref<string | null>(null);

  const dualInvoiceDialogOpen = ref(false);
  const creatingInvoice = ref(false);

  const remittanceDialogOpen = ref(false);
  const savingRemittance = ref(false);

  const confirmB2bInvoiceDialogOpen = ref(false);
  const confirmDeleteInvoiceDialogOpen = ref(false);

  const invoicePayout = ref<{
    id: number;
    billing_profile_id: number | null;
  } | null>(null);

  const remittanceForm = reactive({
    remittance_ref: '',
    net_amount: 0,
    bank_trx_id: '',
    note: '',
  });

  const loadInvoicePayoutContext = async () => {
    const invoiceId = order.value?.global_invoice_id;
    if (!invoiceId) {
      invoicePayout.value = null;
      return;
    }
    try {
      const { data } = await supabase
        .from('global_invoices')
        .select('id, billing_profile_id')
        .eq('id', invoiceId)
        .maybeSingle();
      invoicePayout.value = data ?? null;
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
      !order.value?.courier_remittance_ref,
  );

  const canSaveOrderRemittance = computed(
    () =>
      remittanceForm.remittance_ref.trim().length > 0 &&
      Number(remittanceForm.net_amount) > 0,
  );

  const openOrderRemittanceDialog = () => {
    remittanceForm.remittance_ref = '';
    remittanceForm.net_amount = Number(
      order.value?.cod_collect_amount ?? form.cod_collect_amount ?? 0,
    );
    remittanceForm.bank_trx_id = '';
    remittanceForm.note = '';
    remittanceDialogOpen.value = true;
  };

  const saveOrderRemittance = async () => {
    if (!order.value || !canSaveOrderRemittance.value) return;
    savingRemittance.value = true;
    try {
      const { error } = await supabase.rpc('record_dropship_courier_remittance', {
        p_order_id: order.value.id,
        p_net_amount: Number(remittanceForm.net_amount),
        p_remittance_ref: remittanceForm.remittance_ref.trim(),
        p_bank_trx_id: remittanceForm.bank_trx_id.trim() || null,
        p_note: remittanceForm.note.trim() || null,
      });
      if (error) throw error;
      showSuccessNotification('Courier remittance recorded.');
      remittanceDialogOpen.value = false;
      await refetchOrderDetail();
      await loadInvoicePayoutContext();
      await queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.ledger(tenantSlug.value),
      });
      await queryClient.invalidateQueries({
        queryKey: shopOrderQueryKeys.ledgerPendingCod(tenantSlug.value),
      });
    } catch (err: any) {
      showErrorNotification(err?.message || 'Failed to record remittance');
    } finally {
      savingRemittance.value = false;
    }
  };

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
        action: openOrderRemittanceDialog,
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

  const executeStatusUpdate = async (status: string) => {
    if (!order.value) return;

    updatingStatus.value = true;
    targetUpdatingStatus.value = status;

    try {
      let resData: any = null;
      if (status === 'returned') {
        const { data, error } = await supabase.rpc('mark_dropship_order_returned', {
          p_order_id: order.value.id,
          p_actual_return_charge: selectedCourier.value?.inside_dhaka_return_fee ?? 30,
          p_deduct_from_middle_man: true,
          p_reason: 'Refused on delivery',
        });
        if (error) throw error;
        resData = data;
      } else {
        const { data, error } = await supabase.rpc('advance_dropship_order_status', {
          p_order_id: order.value.id,
          p_target_status: status,
        });
        if (error) throw error;
        resData = data;
      }

      if (resData && typeof resData === 'object' && resData.success === false) {
        throw new Error(resData.error || 'Failed to update status');
      }

      showSuccessNotification(`Status updated to ${status.replace(/_/g, ' ')}`);
      await refetchOrderDetail();
    } catch (err: any) {
      showErrorNotification(err.message || 'Failed to update status');
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

    if (status === 'processing' && order.value.global_invoice_id) {
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
    canSaveOrderRemittance,
    remittanceDialogOpen,
    savingRemittance,
    remittanceForm,
    dualInvoiceDialogOpen,
    creatingInvoice,
    confirmB2bInvoiceDialogOpen,
    confirmDeleteInvoiceDialogOpen,
    saveChanges,
    onUpdateStatus,
    executeStatusUpdate,
    performHandoff,
    openOrderRemittanceDialog,
    saveOrderRemittance,
    openRecipientInvoicePreview,
    openDualInvoiceDialog,
    confirmDualInvoice,
  };
}
