import { computed, ref, type ComputedRef, type Ref } from 'vue';
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { moneyKernelRepository } from 'src/modules/bills_pays/repositories/moneyKernelRepository';
import { createPayIdempotencyKey } from 'src/modules/bills_pays/repositories/paysRepository';
import { cashbookQueryKeys } from 'src/modules/bills_pays/services/cashbookQueryKeys';
import type { MoneyPayKind, MoneyPaySubmitPayload } from 'src/modules/bills_pays/types/moneyPayDialog';
import { applyDepositCacheUpdate } from 'src/modules/bills_pays/composables/applyDepositCacheUpdate';
import { isProfileCashbookEnabled } from '../utils/profileCashbookEnabled';

async function resolveMoneyProfileId(
  booksTenantId: number,
  entityType: string,
  entityId: number,
): Promise<number> {
  if (entityType === 'customer') return entityId;

  if (entityType === 'tenant') {
    const { data, error } = await supabase
      .from('profiles')
      .select('id')
      .eq('tenant_id', booksTenantId)
      .eq('profile_type', 'tenant')
      .eq('subject_id', booksTenantId)
      .maybeSingle();
    if (error) throw error;
    if (!data?.id) throw new Error('Tenant cash profile not found.');
    return data.id;
  }

  if (entityType === 'investor') {
    const { data, error } = await supabase
      .from('profiles')
      .select('id')
      .eq('tenant_id', booksTenantId)
      .eq('profile_type', 'investor')
      .eq('subject_id', entityId)
      .maybeSingle();
    if (error) throw error;
    if (!data?.id) throw new Error('Investor cash profile not found.');
    return data.id;
  }

  throw new Error('Cashbook is not enabled for this party.');
}

export function useProfileCashMovementDialog(options: {
  tenantId: ComputedRef<number>;
  booksTenantId: ComputedRef<number>;
  entityType: ComputedRef<string>;
  entityId: ComputedRef<number>;
  partyName: ComputedRef<string>;
  tenantSlug: ComputedRef<string | undefined>;
  active: Ref<boolean>;
}) {
  const queryClient = useQueryClient();

  const dialogOpen = ref(false);
  const locationsPanelOpen = ref(false);
  const dialogKind = ref<MoneyPayKind>('deposit');
  const profileId = ref<number | null>(null);

  const cashbookEnabled = computed(() =>
    isProfileCashbookEnabled(options.entityType.value),
  );

  const ensureProfileId = async () => {
    if (!cashbookEnabled.value || options.entityId.value <= 0) {
      profileId.value = null;
      return;
    }
    try {
      profileId.value = await resolveMoneyProfileId(
        options.booksTenantId.value,
        options.entityType.value,
        options.entityId.value,
      );
    } catch (error: unknown) {
      profileId.value = null;
      showErrorNotification(error instanceof Error ? error.message : 'Could not resolve cash profile.');
    }
  };

  const openDeposit = async () => {
    await ensureProfileId();
    if (profileId.value == null) return;
    dialogKind.value = 'deposit';
    dialogOpen.value = true;
  };

  const openWithdraw = async () => {
    await ensureProfileId();
    if (profileId.value == null) return;
    dialogKind.value = 'withdrawal';
    dialogOpen.value = true;
  };

  const openLocations = async () => {
    await ensureProfileId();
    if (profileId.value == null) return;
    locationsPanelOpen.value = true;
  };

  const movementMutation = useMutation({
    mutationFn: async (payload: MoneyPaySubmitPayload) => {
      const pid = profileId.value;
      if (pid == null) throw new Error('Cash profile not ready.');
      const amount = payload.amount;
      if (amount <= 0) throw new Error('Enter an amount greater than zero.');
      const currency =
        payload.legCurrencyCode?.trim().toUpperCase()
        || payload.sourceCurrencyCode?.trim().toUpperCase()
        || 'BDT';
      const key = createPayIdempotencyKey();
      const meta = {
        source: 'people_cash_movement',
        method_code: payload.methodCode,
        reference: payload.reference,
        note: payload.note,
      };

      if (dialogKind.value === 'deposit') {
        if (payload.legLocationPointId == null) throw new Error('Choose a deposit location.');
        const selectedPotId = payload.toPotId;
        if (selectedPotId != null && selectedPotId <= 0) {
          throw new Error('Choose a bundle.');
        }
        const locationCode = payload.legLocationCode?.trim() || undefined;
        const deposit = await moneyKernelRepository.deposit({
          tenantId: options.booksTenantId.value,
          profileId: pid,
          amount,
          currencyCode: currency,
          potId: selectedPotId != null && selectedPotId > 0 ? selectedPotId : null,
          locationCode: selectedPotId != null && selectedPotId > 0 ? null : locationCode,
          booksRate: payload.legBooksRate ?? null,
          meta,
          idempotencyKey: key,
        });
        return {
          kind: 'deposit' as const,
          deposit,
          booksTenantId: options.booksTenantId.value,
          profileId: pid,
          locationCode: locationCode ?? null,
          legLocationPointId: payload.legLocationPointId,
          legBooksRate: payload.legBooksRate ?? null,
        };
      }

      const potId = payload.fromPotId;
      if (potId == null) throw new Error('Choose which bundle to withdraw from.');
      await moneyKernelRepository.withdraw({
        tenantId: options.booksTenantId.value,
        profileId: pid,
        amount,
        currencyCode: currency,
        potId,
        meta,
        idempotencyKey: key,
      });
    },
    onSuccess: (result) => {
      showSuccessNotification(dialogKind.value === 'deposit' ? 'Deposit posted.' : 'Withdrawal posted.');
      dialogOpen.value = false;
      if (result && typeof result === 'object' && 'kind' in result && result.kind === 'deposit') {
        applyDepositCacheUpdate(queryClient, {
          booksTenantId: result.booksTenantId,
          profileId: result.profileId,
          locationCode: result.locationCode,
          legLocationPointId: result.legLocationPointId,
          legBooksRate: result.legBooksRate,
          deposit: result.deposit,
        });
      } else {
        void queryClient.invalidateQueries({ queryKey: cashbookQueryKeys.root });
      }
    },
    onError: (error: unknown) => {
      showErrorNotification(error instanceof Error ? error.message : 'Could not post cash movement.');
    },
  });

  const onMoneyPaySubmit = (payload: MoneyPaySubmitPayload) => {
    void movementMutation.mutateAsync(payload);
  };

  const resolvedProfileId = computed(() => profileId.value);

  return {
    cashbookEnabled,
    dialogOpen,
    dialogKind,
    locationsPanelOpen,
    resolvedProfileId,
    openDeposit,
    openWithdraw,
    openLocations,
    onMoneyPaySubmit,
    movementMutation,
    partyName: options.partyName,
    operatingTenantId: options.tenantId,
    booksTenantId: options.booksTenantId,
  };
}
