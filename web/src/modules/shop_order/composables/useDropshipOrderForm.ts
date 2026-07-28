import { ref, reactive, computed, watch, type Ref } from 'vue';
import { copyToClipboard } from 'quasar';
import { supabase } from 'src/boot/supabase';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import type { MerchantProfileRow } from '../repositories/dropshipMerchantRepository';
import type { ShopOrder, ShopOrderItem } from '../types';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import { useRecipientProfileStore } from 'src/modules/sales_invoice/stores/recipientProfileStore';
import { resolveDeliveryZone, suggestDeliveryFee, type DeliveryZone } from '../services/courierChargeEstimate';

export function useDropshipOrderForm(
  order: Ref<ShopOrder | null>,
  orderItems: Ref<ShopOrderItem[]>,
  couriers: Ref<CourierServiceRow[]>,
  merchants: Ref<MerchantProfileRow[]>,
  updateThanaList: (distName: string, currentPostCode?: string) => Promise<void>,
  updatePostcodeList: (distName: string, thanaName: string, currentPostCode?: string) => Promise<void>,
) {
  const recipientProfileStore = useRecipientProfileStore();
  const hydratingForm = ref(false);
  const selectedMerchantId = ref<string | null>(null);
  const blockCExpanded = ref(true);
  const lastLookupPhone = ref('');

  const form = reactive({
    recipient_name: '',
    recipient_phone: '',
    secondary_phone: '',
    district: 'Dhaka',
    thana: '',
    post_code: '',
    shipping_address: '',
    cod_collect_amount: 0,
    delivery_charge: 0,
    cod_charge: 0,
    cod_fee_percent: 0,
    package_weight_band: 'under_1kg',
    sender_name: '',
    pickup_phone: '',
    pickup_address: '',
    allow_open_box: false,
    delivery_instruction_notes: '',
    courier_service_id: null as string | null,
    courier_awb_number: '',
    tracking_url: '',
    deduct_delivery_from_margin: false,
    deduct_cod_from_margin: false,
    deduct_print_from_margin: false,
    deduct_packing_from_margin: false,
  });

  const originalBlockA = reactive({
    recipient_name: '',
    recipient_phone: '',
    secondary_phone: '',
    district: '',
    thana: '',
    post_code: '',
    shipping_address: '',
  });

  const originalBlockB = reactive({
    delivery_charge: 0,
    package_weight_band: 'under_1kg',
    cod_fee_percent: 0,
    cod_charge: 0,
  });

  const originalBlockC = reactive({
    sender_name: '',
    pickup_phone: '',
    pickup_address: '',
    merchant_id: null as string | null,
  });

  const originalBlockD = reactive({
    allow_open_box: false,
    delivery_instruction_notes: '',
  });

  const originalBlockE = reactive({
    courier_service_id: null as string | null,
    courier_awb_number: '',
    tracking_url: '',
  });

  const isBlockADirty = computed(() => {
    return form.recipient_name !== originalBlockA.recipient_name ||
           form.recipient_phone !== originalBlockA.recipient_phone ||
           form.secondary_phone !== originalBlockA.secondary_phone ||
           form.district !== originalBlockA.district ||
           form.thana !== originalBlockA.thana ||
           form.post_code !== originalBlockA.post_code ||
           form.shipping_address !== originalBlockA.shipping_address;
  });

  const isBlockBDirty = computed(() => {
    return form.delivery_charge !== originalBlockB.delivery_charge ||
           form.package_weight_band !== originalBlockB.package_weight_band ||
           form.cod_fee_percent !== originalBlockB.cod_fee_percent ||
           form.cod_charge !== originalBlockB.cod_charge;
  });

  const isBlockCDirty = computed(() => {
    return form.sender_name !== originalBlockC.sender_name ||
           form.pickup_phone !== originalBlockC.pickup_phone ||
           form.pickup_address !== originalBlockC.pickup_address ||
           selectedMerchantId.value !== originalBlockC.merchant_id;
  });

  const isBlockDDirty = computed(() => {
    return form.allow_open_box !== originalBlockD.allow_open_box ||
           form.delivery_instruction_notes !== originalBlockD.delivery_instruction_notes;
  });

  const isBlockEDirty = computed(() => {
    return form.courier_service_id !== originalBlockE.courier_service_id ||
           form.courier_awb_number !== originalBlockE.courier_awb_number ||
           form.tracking_url !== originalBlockE.tracking_url;
  });

  const isFormDirty = computed(() => {
    return isBlockADirty.value ||
           isBlockBDirty.value ||
           isBlockCDirty.value ||
           isBlockDDirty.value ||
           isBlockEDirty.value;
  });

  const discardChanges = () => {
    form.recipient_name = originalBlockA.recipient_name;
    form.recipient_phone = originalBlockA.recipient_phone;
    form.secondary_phone = originalBlockA.secondary_phone;
    form.district = originalBlockA.district;
    form.thana = originalBlockA.thana;
    form.post_code = originalBlockA.post_code;
    form.shipping_address = originalBlockA.shipping_address;

    form.delivery_charge = originalBlockB.delivery_charge;
    form.package_weight_band = originalBlockB.package_weight_band;
    form.cod_fee_percent = originalBlockB.cod_fee_percent;
    form.cod_charge = originalBlockB.cod_charge;

    selectedMerchantId.value = originalBlockC.merchant_id;
    form.sender_name = originalBlockC.sender_name;
    form.pickup_phone = originalBlockC.pickup_phone;
    form.pickup_address = originalBlockC.pickup_address;

    form.allow_open_box = originalBlockD.allow_open_box;
    form.delivery_instruction_notes = originalBlockD.delivery_instruction_notes;

    form.courier_service_id = originalBlockE.courier_service_id;
    form.courier_awb_number = originalBlockE.courier_awb_number;
    form.tracking_url = originalBlockE.tracking_url;
  };

  const deliveryZone = computed<DeliveryZone>(() => resolveDeliveryZone(form.district));
  const deliveryZoneLabel = computed(() =>
    deliveryZone.value === 'inside_dhaka' ? 'Inside Dhaka' : 'Outside Dhaka',
  );

  const selectedCourier = computed(() =>
    couriers.value.find((c) => c.id === form.courier_service_id),
  );

  const suggestedDeliveryFee = computed(() => {
    if (!selectedCourier.value) return 0;
    return suggestDeliveryFee(selectedCourier.value, deliveryZone.value);
  });

  const codRateLabel = computed(() => {
    const courier = selectedCourier.value;
    if (!courier) return '—';
    if (courier.cod_fee_mode === 'percent_of_collect') return `${courier.cod_fee_percent}% of collect`;
    if (courier.cod_fee_mode === 'flat') return `${courier.cod_fee_flat_amount} BDT flat`;
    if (courier.cod_fee_mode === 'tiered_manual') return 'Tiered / manual';
    return 'None';
  });

  const formatBdt = (amount: number) => `${Number(amount || 0).toFixed(2)} BDT`;

  const recipientSubtotal = computed(() =>
    orderItems.value.reduce(
      (sum, item) => sum + (item.customer_sell_price_amount ?? 0) * item.quantity,
      0,
    ),
  );

  const accountingSubtotal = computed(() =>
    orderItems.value.reduce((sum, item) => {
      const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
      return sum + price * item.quantity;
    }, 0),
  );

  const deliveryChargeVal = computed(() => Number(form.delivery_charge || 0));
  const codChargeVal = computed(() => Number(form.cod_charge || 0));
  const printChargeVal = computed(() => Number(order.value?.print_charge_amount || 0));
  const packingChargeVal = computed(() => Number(order.value?.packing_charge_amount || 0));
  const discountVal = computed(() => Number(order.value?.discount_amount || 0));

  const deductCodFromMargin = computed(() => !!form.deduct_cod_from_margin);
  const deductDeliveryFromMargin = computed(() => !!form.deduct_delivery_from_margin);
  const deductPrintFromMargin = computed(() => !!form.deduct_print_from_margin);
  const deductPackingFromMargin = computed(() => !!form.deduct_packing_from_margin);

  const recipientGrandTotal = computed(() =>
    recipientSubtotal.value
      + (deductDeliveryFromMargin.value ? 0 : deliveryChargeVal.value)
      + (deductPrintFromMargin.value ? 0 : printChargeVal.value)
      + (deductPackingFromMargin.value ? 0 : packingChargeVal.value)
      + (deductCodFromMargin.value ? 0 : codChargeVal.value)
      - discountVal.value,
  );

  const middlemanTotalCost = computed(() =>
    accountingSubtotal.value
      + (deductPrintFromMargin.value ? printChargeVal.value : 0)
      + (deductPackingFromMargin.value ? packingChargeVal.value : 0)
      + (deductDeliveryFromMargin.value ? deliveryChargeVal.value : 0)
      + (deductCodFromMargin.value ? codChargeVal.value : 0),
  );

  const estimatedProfit = computed(() => recipientSubtotal.value - discountVal.value - middlemanTotalCost.value);

  const recalculateCollectAmount = () => {
    form.cod_collect_amount = recipientSubtotal.value
      + (deductDeliveryFromMargin.value ? 0 : form.delivery_charge)
      + (deductPrintFromMargin.value ? 0 : printChargeVal.value)
      + (deductPackingFromMargin.value ? 0 : packingChargeVal.value)
      + (deductCodFromMargin.value ? 0 : form.cod_charge)
      - discountVal.value;
  };

  const calculateCodCharge = () => {
    if (order.value?.is_prepaid_snapshot) {
      form.cod_charge = 0;
      return;
    }
    const courier = selectedCourier.value;
    if (!courier) return;

    if (courier.cod_fee_mode === 'percent_of_collect') {
      const collectBase = recipientSubtotal.value
        + (deductDeliveryFromMargin.value ? 0 : Number(form.delivery_charge || 0))
        + (deductPrintFromMargin.value ? 0 : printChargeVal.value)
        + (deductPackingFromMargin.value ? 0 : packingChargeVal.value);
      if (collectBase <= 0) {
        form.cod_charge = 0;
      } else {
        form.cod_charge = Math.round(collectBase * Number(form.cod_fee_percent || 0) / 100 * 100) / 100;
      }
    } else if (courier.cod_fee_mode === 'flat') {
      form.cod_charge = Number(courier.cod_fee_flat_amount || 0);
    } else {
      form.cod_charge = 0;
    }

    recalculateCollectAmount();
  };

  const onToggleDeduct = async () => {
    if (!order.value) return;
    try {
      calculateCodCharge();

      const { error } = await supabase
        .from('shop_orders')
        .update({
          deduct_delivery_from_margin: form.deduct_delivery_from_margin,
          deduct_cod_from_margin: form.deduct_cod_from_margin,
          deduct_print_from_margin: form.deduct_print_from_margin,
          deduct_packing_from_margin: form.deduct_packing_from_margin,
          cod_collect_amount: form.cod_collect_amount,
        })
        .eq('id', order.value.id);

      if (error) throw error;
      showSuccessNotification('Order charge preferences updated');
    } catch (err: any) {
      showErrorNotification(err.message || 'Failed to update charge preferences');
    }
  };

  const applySuggestedCharges = () => {
    const courier = selectedCourier.value;
    if (!courier) return;

    const zone = deliveryZone.value;
    form.delivery_charge = suggestDeliveryFee(courier, zone);
    form.cod_fee_percent = Number(courier.cod_fee_percent || 0);

    calculateCodCharge();
  };

  const onDeliveryChargeManualEdit = () => {
    calculateCodCharge();
  };

  const courierOptions = computed(() =>
    couriers.value.map((c) => ({ label: c.name, value: c.id }))
  );

  const merchantOptions = computed(() =>
    merchants.value.map((m) => ({
      label: `${m.merchant_name}${m.store_name ? ' (' + m.store_name + ')' : ''} - ${m.phone_primary}`,
      value: m.id,
    }))
  );

  const onMerchantSelect = (merchantId: string | null) => {
    if (!merchantId) return;
    const merchant = merchants.value.find((m) => m.id === merchantId);
    if (merchant) {
      form.sender_name = merchant.merchant_name;
      form.pickup_phone = merchant.phone_primary;
      form.pickup_address = merchant.pickup_address;
    }
  };

  const handleCopy = (text: string | null | undefined, label: string) => {
    if (!text || !text.trim()) {
      showErrorNotification(`No ${label.toLowerCase()} available to copy`);
      return;
    }
    copyToClipboard(text.trim())
      .then(() => {
        showSuccessNotification(`${label} copied`);
      })
      .catch(() => {
        showErrorNotification(`Failed to copy ${label.toLowerCase()}`);
      });
  };

  const onRecipientPhoneBlur = async () => {
    const phone = form.recipient_phone.replace(/\D/g, '');
    const tenantId = order.value?.tenant_id;
    if (!tenantId || !/^01\d{9}$/.test(phone)) return;
    if (phone === lastLookupPhone.value) return;
    lastLookupPhone.value = phone;

    const profile = await recipientProfileStore.getByPhone(tenantId, phone);
    if (!profile) return;

    if (!form.recipient_name.trim()) form.recipient_name = profile.name || '';
    if (!form.secondary_phone.trim() && profile.secondary_phone) {
      form.secondary_phone = profile.secondary_phone;
    }

    let baseAddress = profile.address || '';
    let extractedPostcode = '';
    const pcMatch = baseAddress.match(/Post\s*Code:\s*([^\n,]+)/i);
    if (pcMatch) {
      extractedPostcode = pcMatch[1]?.trim() || '';
    }
    baseAddress = baseAddress.replace(/\n?(?:Thana|District|Post\s*Code):.*$/gi, '').trim();

    if (!form.shipping_address.trim() && baseAddress) {
      form.shipping_address = baseAddress;
    }
    if (profile.district) {
      form.district = profile.district;
      await updateThanaList(profile.district);
    }
    if (profile.thana) {
      form.thana = profile.thana;
      await updatePostcodeList(form.district, profile.thana);
    }
    if (extractedPostcode) {
      form.post_code = extractedPostcode;
      await updatePostcodeList(form.district, form.thana);
    }
  };

  const hydrateFormFromOrder = async (o: any) => {
    hydratingForm.value = true;
    try {
      form.recipient_name = o.recipient_name || '';
      form.recipient_phone = o.recipient_phone || '';
      form.secondary_phone = o.recipient_phone_secondary || '';
      form.district = o.shipping_district || 'Dhaka';
      form.thana = o.shipping_thana || '';

      let baseAddress = o.shipping_address || '';
      let extractedPostcode = '';
      const pcMatch = baseAddress.match(/Post\s*Code:\s*([^\n,]+)/i);
      if (pcMatch) {
        extractedPostcode = pcMatch[1].trim();
      }
      baseAddress = baseAddress.replace(/\n?(?:Thana|District|Post\s*Code):.*$/gi, '').trim();

      form.post_code = o.shipping_post_code || o.post_code || extractedPostcode || '';
      form.shipping_address = baseAddress;

      form.cod_collect_amount = o.cod_collect_amount ?? o.total_amount ?? 0;
      form.delivery_charge = o.delivery_charge_amount ?? o.courier_cost_amount ?? 0;
      form.cod_charge = o.cod_charge_amount ?? 0;
      form.package_weight_band = o.package_weight_band || 'under_1kg';

      const activeCourier = couriers.value.find((c: any) => c.id === o.courier_service_id) || null;
      form.cod_fee_percent = activeCourier ? Number(activeCourier.cod_fee_percent || 0) : 0;

      form.deduct_delivery_from_margin = !!o.deduct_delivery_from_margin;
      form.deduct_cod_from_margin = o.deduct_cod_from_margin !== undefined ? !!o.deduct_cod_from_margin : !!activeCourier?.deduct_cod_from_margin_default;
      form.deduct_print_from_margin = !!o.deduct_print_from_margin;
      form.deduct_packing_from_margin = !!o.deduct_packing_from_margin;

      originalBlockB.delivery_charge = form.delivery_charge;
      originalBlockB.package_weight_band = form.package_weight_band;
      originalBlockB.cod_fee_percent = form.cod_fee_percent;
      originalBlockB.cod_charge = form.cod_charge;
      form.sender_name = o.sender_name || o.default_sender_name || '';
      form.pickup_phone = o.pickup_phone || o.default_pickup_phone || '';
      form.pickup_address = o.pickup_address || o.default_pickup_address || '';
      form.allow_open_box = !!o.allow_open_box;
      form.delivery_instruction_notes = o.delivery_instruction_notes || o.driver_notes || '';
      form.courier_service_id = o.courier_service_id || null;
      form.courier_awb_number = o.courier_awb_number || '';
      form.tracking_url = o.tracking_url || '';

      await updateThanaList(form.district, form.post_code);

      const matchedMerchant = merchants.value.find(
        (m) => m.merchant_name === form.sender_name || m.phone_primary === form.pickup_phone
      );
      if (matchedMerchant) {
        selectedMerchantId.value = matchedMerchant.id;
      }

      blockCExpanded.value = !selectedMerchantId.value;

      originalBlockA.recipient_name = form.recipient_name;
      originalBlockA.recipient_phone = form.recipient_phone;
      originalBlockA.secondary_phone = form.secondary_phone;
      originalBlockA.district = form.district;
      originalBlockA.thana = form.thana;
      originalBlockA.post_code = form.post_code;
      originalBlockA.shipping_address = form.shipping_address;

      originalBlockC.sender_name = form.sender_name;
      originalBlockC.pickup_phone = form.pickup_phone;
      originalBlockC.pickup_address = form.pickup_address;
      originalBlockC.merchant_id = selectedMerchantId.value;

      originalBlockD.allow_open_box = form.allow_open_box;
      originalBlockD.delivery_instruction_notes = form.delivery_instruction_notes;

      originalBlockE.courier_service_id = form.courier_service_id;
      originalBlockE.courier_awb_number = form.courier_awb_number;
      originalBlockE.tracking_url = form.tracking_url;
    } finally {
      hydratingForm.value = false;
    }
  };

  watch(
    [() => form.courier_awb_number, () => form.courier_service_id],
    ([awbVal, courierIdVal]) => {
      if (hydratingForm.value) return;
      const courier = couriers.value.find((c) => c.id === courierIdVal) || selectedCourier.value;
      const template = courier?.tracking_url_template;
      if (!template) return;

      const trimmedAwb = (awbVal || '').trim();
      if (trimmedAwb) {
        form.tracking_url = template.replace(/\{awb\}/gi, trimmedAwb);
      }
    },
  );

  return {
    form,
    hydratingForm,
    selectedMerchantId,
    blockCExpanded,
    isFormDirty,
    deliveryZoneLabel,
    selectedCourier,
    suggestedDeliveryFee,
    codRateLabel,
    formatBdt,
    recipientSubtotal,
    accountingSubtotal,
    deliveryChargeVal,
    codChargeVal,
    printChargeVal,
    packingChargeVal,
    discountVal,
    recipientGrandTotal,
    middlemanTotalCost,
    estimatedProfit,
    courierOptions,
    merchantOptions,
    discardChanges,
    recalculateCollectAmount,
    calculateCodCharge,
    onToggleDeduct,
    applySuggestedCharges,
    onDeliveryChargeManualEdit,
    onMerchantSelect,
    handleCopy,
    onRecipientPhoneBlur,
    hydrateFormFromOrder,
  };
}
