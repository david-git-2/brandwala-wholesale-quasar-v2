export interface DropshipCartDeliveryDetails {
  recipient_name?: string;
  recipient_phone?: string;
  secondary_phone?: string;
  district?: string;
  thana?: string;
  post_code?: string;
  shipping_address?: string;
  delivery_instructions?: string;
  recipient_pays_delivery?: boolean;
  recipient_pays_cod?: boolean;
  terms_accepted?: boolean;
  terms_accepted_at?: string;
}

export type DropshipCustomerDeliveryForm = {
  recipientName: string;
  recipientPhone: string;
  secondaryPhone: string;
  district: string;
  thana: string;
  postCode: string;
  shippingAddress: string;
  deliveryInstructions: string;
};

const str = (value: unknown) => (typeof value === 'string' ? value : '');

export function deliveryDetailsToForm(
  details: DropshipCartDeliveryDetails | null | undefined,
): Partial<DropshipCustomerDeliveryForm> & {
  recipientPaysDelivery?: boolean;
  recipientPaysCod?: boolean;
  termsAccepted?: boolean;
} {
  if (!details || typeof details !== 'object') {
    return {};
  }
  return {
    recipientName: str(details.recipient_name),
    recipientPhone: str(details.recipient_phone),
    secondaryPhone: str(details.secondary_phone),
    district: str(details.district),
    thana: str(details.thana),
    postCode: str(details.post_code),
    shippingAddress: str(details.shipping_address),
    deliveryInstructions: str(details.delivery_instructions),
    recipientPaysDelivery:
      details.recipient_pays_delivery === undefined
        ? undefined
        : Boolean(details.recipient_pays_delivery),
    recipientPaysCod:
      details.recipient_pays_cod === undefined ? undefined : Boolean(details.recipient_pays_cod),
    termsAccepted:
      details.terms_accepted === undefined ? undefined : Boolean(details.terms_accepted),
  };
}

export function formToDeliveryDetails(
  form: DropshipCustomerDeliveryForm,
  recipientPaysDelivery: boolean,
  recipientPaysCod: boolean,
  termsAccepted: boolean,
): DropshipCartDeliveryDetails {
  return {
    recipient_name: form.recipientName.trim(),
    recipient_phone: form.recipientPhone.trim(),
    secondary_phone: form.secondaryPhone.trim(),
    district: form.district.trim(),
    thana: form.thana.trim(),
    post_code: form.postCode.trim(),
    shipping_address: form.shippingAddress.trim(),
    delivery_instructions: form.deliveryInstructions.trim(),
    recipient_pays_delivery: recipientPaysDelivery,
    recipient_pays_cod: recipientPaysCod,
    terms_accepted: termsAccepted,
    terms_accepted_at: termsAccepted ? new Date().toISOString() : undefined,
  };
}

export function hasStoredDeliveryDetails(
  details: DropshipCartDeliveryDetails | null | undefined,
): boolean {
  if (!details || typeof details !== 'object') return false;
  return Boolean(
    str(details.recipient_name) ||
      str(details.recipient_phone) ||
      str(details.shipping_address) ||
      str(details.district) ||
      str(details.thana),
  );
}