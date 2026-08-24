import { shopOrderRepository } from '../repositories/shopOrderRepository';
import type { ShopOrder, ShopOrderItem, ShopServiceResult, ShopCatalogBrowseResult, ShopCatalogSearchResult, ShopCatalogProductDetailResult, ShopCatalogRelatedResult, CustomerOrderListItem } from '../types';

const submitOrder = async (
  cartId: number,
  recipientName: string,
  recipientPhone: string,
  shippingAddress: string,
  billingProfileId: number | null,
  isPrepaid?: boolean,
  deliveryInstructions?: string | null,
  codChargeAmount?: number,
  deliveryChargeAmount?: number,
  printChargeAmount?: number,
  packingChargeAmount?: number,
  discountAmount?: number,
  recipientPhoneSecondary?: string | null,
  shippingDistrict?: string | null,
  shippingThana?: string | null,
): Promise<ShopServiceResult<{ order_id: number; order_no: string; status: string }>> => {
  try {
    const data = await shopOrderRepository.submitShopOrderFromCart(
      cartId,
      recipientName,
      recipientPhone,
      shippingAddress,
      billingProfileId,
      isPrepaid,
      deliveryInstructions,
      codChargeAmount,
      deliveryChargeAmount,
      printChargeAmount,
      packingChargeAmount,
      discountAmount,
      recipientPhoneSecondary,
      shippingDistrict,
      shippingThana,
    );
    return { success: true, data };
  } catch (error: any) {
    return {
      success: false,
      error: error?.message || (typeof error === 'string' ? error : 'Failed to submit order.'),
    };
  }
};

const staffPriceOrder = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number; weight_kg?: number | null }>,
  profitBasis?: string | null,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.staffPriceShopOrder(orderId, items, profitBasis);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to set pricing.',
    };
  }
};

const staffFinalizeCatalogPrices = async (
  orderId: number,
  items: Array<{ id: number; final_offer_amount: number; final_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.staffFinalizeCatalogPrices(orderId, items);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to finalize catalog prices.',
    };
  }
};

const customerCounter = async (
  orderId: number,
  items: Array<{ id: number; customer_offer_amount: number; customer_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.customerCounterOffer(orderId, items);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to place counter offer.',
    };
  }
};

const staffCounter = async (
  orderId: number,
  items: Array<{ id: number; staff_offer_amount: number; staff_offer_currency_id: number }>,
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.staffCounterOffer(orderId, items);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to counter offer.',
    };
  }
};

const confirmOrder = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.confirmShopOrder(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to confirm order.',
    };
  }
};

const customerConfirmCatalogOrder = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.customerConfirmShopOrder(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to confirm catalog order.',
    };
  }
};

const getOrderDetails = async (
  tenantId: number,
  orderId: number,
): Promise<ShopServiceResult<{ order: ShopOrder; items: ShopOrderItem[] }>> => {
  try {
    const data = await shopOrderRepository.getShopOrderById(tenantId, orderId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch order details.',
    };
  }
};

const fetchCustomerOrders = async (
  tenantId: number,
  opts?: { limit?: number; offset?: number; statusBucket?: string | null },
): Promise<ShopServiceResult<CustomerOrderListItem[]>> => {
  try {
    const data = await shopOrderRepository.listCustomerShopOrders(tenantId, opts);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list customer orders.',
    };
  }
};

const fetchStaffOrders = async (
  tenantId: number,
  opts?: { limit?: number; offset?: number; search?: string | null; status?: string | null; shopId?: number | null },
): Promise<ShopServiceResult<ShopOrder[]>> => {
  try {
    const data = await shopOrderRepository.listShopOrdersForStaff(tenantId, opts);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list staff orders.',
    };
  }
};

const fetchDropshipStaffOrders = async (
  tenantId: number,
  opts?: { limit?: number; offset?: number; search?: string | null; status?: string | null },
): Promise<ShopServiceResult<ShopOrder[]>> => {
  try {
    const data = await shopOrderRepository.listDropshipShopOrdersForStaff(tenantId, opts);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list dropship desk orders.',
    };
  }
};

const placeOrderForProcurement = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.placeShopOrderForProcurement(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to place order for procurement.',
    };
  }
};

const fulfillOrderToInvoice = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.fulfillShopOrderToInvoice(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fulfill order to invoice.',
    };
  }
};

const deleteOrder = async (orderId: number): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.deleteShopOrder(orderId);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete order.',
    };
  }
};

const browseShopCatalog = async (
  tenantId: number,
  shopSlug: string,
  opts?: {
    search?: string | null;
    category?: string | null;
    brand?: string | null;
    limit?: number;
    offset?: number;
  },
): Promise<ShopServiceResult<ShopCatalogBrowseResult>> => {
  try {
    const data = await shopOrderRepository.browseShopCatalog(tenantId, shopSlug, opts);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch catalog.',
    };
  }
};

const searchShopCatalog = async (
  tenantId: number,
  search: string,
  opts?: { limit?: number; offset?: number },
): Promise<ShopServiceResult<ShopCatalogSearchResult>> => {
  try {
    const data = await shopOrderRepository.searchShopCatalog(tenantId, search, opts);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to search catalog.',
    };
  }
};

const getShopCatalogProduct = async (
  tenantId: number,
  shopSlug: string,
  productId: number,
): Promise<ShopServiceResult<ShopCatalogProductDetailResult>> => {
  try {
    const data = await shopOrderRepository.getShopCatalogProduct(tenantId, shopSlug, productId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch product.',
    };
  }
};

const listRelatedShopCatalogProducts = async (
  tenantId: number,
  shopSlug: string,
  productId: number,
  limit = 4,
): Promise<ShopServiceResult<ShopCatalogRelatedResult>> => {
  try {
    const data = await shopOrderRepository.listRelatedShopCatalogProducts(
      tenantId,
      shopSlug,
      productId,
      limit,
    );
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch related products.',
    };
  }
};

const listCustomerShops = async (
  tenantId: number,
): Promise<
  ShopServiceResult<Awaited<ReturnType<typeof shopOrderRepository.listCustomerShops>>>
> => {
  try {
    const data = await shopOrderRepository.listCustomerShops(tenantId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list accessible shops.',
    };
  }
};

const updateOrderCharges = async (
  orderId: number,
  payload: {
    delivery_charge_amount: number;
    deduct_delivery_from_margin: boolean;
    cod_charge_amount: number;
    deduct_cod_from_margin: boolean;
    print_charge_amount: number;
    deduct_print_from_margin: boolean;
    packing_charge_amount: number;
    deduct_packing_from_margin: boolean;
  },
): Promise<ShopServiceResult<void>> => {
  try {
    await shopOrderRepository.updateOrderCharges(orderId, payload);
    return { success: true, data: undefined };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update order charges.',
    };
  }
};

const processDropshipOrder = async (
  orderId: number,
): Promise<ShopServiceResult<any>> => {
  try {
    const res = await shopOrderRepository.processDropshipShopOrder(orderId);
    if (!res.success) {
      return { success: false, error: res.error || 'Failed to process dropship order handoff.' };
    }
    return { success: true, data: res };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to process dropship order handoff.',
    };
  }
};

const resolveCategoryStyle = (
  categoryName: string,
): { icon: string; color: string; bgColor: string } => {
  const name = (categoryName || '').toLowerCase();

  if (/t-shirt|apparel|shirt/.test(name)) {
    return { icon: 'ph ph-t-shirt', color: 'blue-7', bgColor: 'blue-1' };
  }
  if (/hoodie|jacket|outerwear/.test(name)) {
    return { icon: 'ph ph-sneaker', color: 'deep-orange-7', bgColor: 'deep-orange-1' };
  }
  if (/activewear|sport/.test(name)) {
    return { icon: 'ph ph-person-simple-run', color: 'green-7', bgColor: 'green-1' };
  }
  if (/accessory|watch|jewel/.test(name)) {
    return { icon: 'ph ph-watch', color: 'purple-7', bgColor: 'purple-1' };
  }
  if (/footwear|shoe/.test(name)) {
    return { icon: 'ph ph-sneaker', color: 'indigo-7', bgColor: 'indigo-1' };
  }
  if (/pant|trouser|bottom/.test(name)) {
    return { icon: 'ph ph-stack', color: 'teal-7', bgColor: 'teal-1' };
  }

  return { icon: 'ph ph-squares-four', color: 'grey-7', bgColor: 'grey-2' };
};

const listCustomerShopCategories = async (
  tenantId: number,
): Promise<
  ShopServiceResult<
    { name: string; icon: string; bgColor: string; color: string; count: number }[]
  >
> => {
  try {
    const rawCategories = await shopOrderRepository.fetchCustomerShopCategories(tenantId);
    const data = rawCategories.map((cat) => {
      const style = resolveCategoryStyle(cat.name);
      return {
        name: cat.name,
        count: Number(cat.count || 0),
        ...style,
      };
    });
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch customer shop categories.',
    };
  }
};

export const shopOrderService = {
  submitOrder,
  staffPriceOrder,
  staffFinalizeCatalogPrices,
  customerCounter,
  staffCounter,
  confirmOrder,
  customerConfirmCatalogOrder,
  getOrderDetails,
  fetchCustomerOrders,
  fetchStaffOrders,
  fetchDropshipStaffOrders,
  placeOrderForProcurement,
  fulfillOrderToInvoice,
  deleteOrder,
  browseShopCatalog,
  searchShopCatalog,
  getShopCatalogProduct,
  listRelatedShopCatalogProducts,
  listCustomerShops,
  listCustomerShopCategories,
  updateOrderCharges,
  processDropshipOrder,
};

