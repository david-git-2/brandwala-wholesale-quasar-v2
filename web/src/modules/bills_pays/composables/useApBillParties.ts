import { computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';

/** AP bills: vendor/cargo bill the tenant; local is tenant-only opex. profile_id = payee for payouts. */
export function useApBillParties(bill: Ref<GlobalInvoiceDetail | undefined>) {
  const authStore = useAuthStore();

  const tenantName = computed(() => authStore.selectedTenant?.name ?? '—');

  const counterpartyName = computed(
    () => bill.value?.billing_profiles?.name || bill.value?.recipient_name || '—',
  );

  const counterpartyAddress = computed(() => bill.value?.billing_profiles?.address ?? null);

  const counterpartyEmail = computed(() => bill.value?.billing_profiles?.email ?? null);

  const showCounterparty = computed(() => {
    const kind = bill.value?.ap_kind;
    return kind === 'vendor' || kind === 'cargo';
  });

  const counterpartyLabel = computed(() => {
    if (bill.value?.ap_kind === 'vendor') return 'From (vendor)';
    if (bill.value?.ap_kind === 'cargo') return 'From (cargo)';
    return 'From';
  });

  const tenantLabel = computed(() =>
    bill.value?.ap_kind === 'local' ? 'Payable by (tenant)' : 'To (tenant)',
  );

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
