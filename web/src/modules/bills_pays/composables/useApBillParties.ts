import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';

/** AP bills: vendor/cargo bill the tenant; local is tenant-only opex. profile_id = payee for payouts. */
export function useApBillParties(bill: Ref<GlobalInvoiceDetail | undefined>) {
  const authStore = useAuthStore();

  const tenantName = computed(() => authStore.selectedTenant?.name ?? '—');

  const counterpartyName = computed(
    () => bill.value?.profiles?.name || bill.value?.recipient_name || '—',
  );

  const counterpartyAddress = computed(() => bill.value?.profiles?.address ?? null);

  const counterpartyEmail = computed(() => bill.value?.profiles?.email ?? null);

  const showCounterparty = computed(() => {
    const kind = bill.value?.ap_kind;
    return (
      kind === 'vendor'
      || kind === 'material'
      || kind === 'cargo'
      || kind === 'freight'
      || kind === 'customs'
    );
  });

  const counterpartyLabel = computed(() => {
    const kind = bill.value?.ap_kind;
    if (kind === 'vendor' || kind === 'material') return 'From (vendor)';
    if (kind === 'cargo' || kind === 'freight' || kind === 'customs') return 'From (cargo)';
    return 'From';
  });

  const tenantLabel = computed(() => {
    const kind = bill.value?.ap_kind;
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
