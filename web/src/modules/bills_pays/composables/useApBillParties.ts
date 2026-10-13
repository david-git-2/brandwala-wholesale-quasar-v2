import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import { shipmentApKindFromBill } from '../utils/shipmentApBillSource';

/** AP bills: vendor/cargo bill the tenant; local is tenant-only opex. profile_id = payee for payouts. */
export function useApBillParties(bill: Ref<GlobalInvoiceDetail | undefined>) {
  const authStore = useAuthStore();

  const apKind = computed(() => shipmentApKindFromBill(bill.value));

  const tenantName = computed(
    () => bill.value?.to_profile?.name || authStore.selectedTenant?.name || '—',
  );

  const counterpartyName = computed(
    () =>
      bill.value?.from_profile?.name
      || bill.value?.profiles?.name
      || bill.value?.recipient_name
      || '—',
  );

  const counterpartyAddress = computed(
    () => bill.value?.from_profile?.address ?? bill.value?.profiles?.address ?? null,
  );

  const counterpartyEmail = computed(
    () => bill.value?.from_profile?.email ?? bill.value?.profiles?.email ?? null,
  );

  const showCounterparty = computed(() => {
    const kind = apKind.value;
    return (
      kind === 'vendor'
      || kind === 'material'
      || kind === 'cargo'
      || kind === 'freight'
      || kind === 'customs'
    );
  });

  const counterpartyLabel = computed(() => {
    const kind = apKind.value;
    if (kind === 'vendor' || kind === 'material') return 'From (vendor)';
    if (kind === 'cargo' || kind === 'freight' || kind === 'customs') return 'From (cargo)';
    return 'From';
  });

  const tenantLabel = computed(() => {
    const kind = apKind.value;
    if (kind === 'local' || kind === 'handling' || kind === 'finance' || kind === 'other') {
      return 'Payable by (tenant)';
    }
    return 'To (tenant)';
  });

  return {
    tenantName,
    counterpartyName,
    counterpartyAddress,
    counterpartyEmail,
    showCounterparty,
    counterpartyLabel,
    tenantLabel,
  };
}
