import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import { shipmentApKindFromBill } from '../utils/shipmentApBillSource';

/** AP bills (money spine): from_profile = payer (tenant), to_profile = payee (vendor/cargo). profile_id = counterparty. */
export function useApBillParties(bill: Ref<GlobalInvoiceDetail | undefined>) {
  const authStore = useAuthStore();

  const apKind = computed(() => shipmentApKindFromBill(bill.value));

  const tenantName = computed(
    () => bill.value?.from_profile?.name || authStore.selectedTenant?.name || '—',
  );

  const counterpartyName = computed(
    () =>
      bill.value?.to_profile?.name
      || bill.value?.profiles?.name
      || bill.value?.recipient_name
      || '—',
  );

  const counterpartyAddress = computed(
    () => bill.value?.to_profile?.address ?? bill.value?.profiles?.address ?? null,
  );

  const counterpartyEmail = computed(
    () => bill.value?.to_profile?.email ?? bill.value?.profiles?.email ?? null,
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
    if (kind === 'vendor' || kind === 'material') return 'Payee (vendor)';
    if (kind === 'cargo' || kind === 'freight' || kind === 'customs') return 'Payee (cargo)';
    if (kind === 'local' || kind === 'handling' || kind === 'finance' || kind === 'other') {
      return 'Payee';
    }
    return 'Payee';
  });

  const tenantLabel = computed(() => 'Payer (tenant)');

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
