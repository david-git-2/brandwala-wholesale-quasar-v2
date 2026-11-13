<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card class="profile-cash-location-form-dialog">
      <q-card-section class="row items-center q-pb-none">
        <div class="col">
          <div class="text-subtitle1 text-weight-bold">Add bundle</div>
          <div v-if="point" class="text-caption text-grey-7 ellipsis">{{ point.name }}</div>
        </div>
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          aria-label="Close"
          :disable="saving"
          @click="close"
        />
      </q-card-section>
      <q-card-section class="column q-gutter-y-sm">
        <q-select
          v-model="currency"
          outlined
          dense
          emit-value
          map-options
          label="Currency"
          :options="currencyOptions"
          :disable="saving || lockCurrency"
        />
        <q-input
          v-model.number="booksRate"
          outlined
          dense
          type="number"
          step="0.000001"
          :min="0"
          label="Books rate (BDT per 1 unit)"
          hint="Required. Use 1 for BDT."
          :disable="saving || currency === 'BDT'"
        />
        <q-input
          v-model.number="openingAmount"
          outlined
          dense
          type="number"
          step="0.01"
          :min="0"
          label="Opening amount (optional)"
          clearable
          :disable="saving"
        />
      </q-card-section>
      <q-card-actions align="right" class="q-px-md q-pb-md">
        <TfBtn variant="tertiary" label="Cancel" :disable="saving" @click="close" />
        <TfBtn
          variant="primary"
          label="Add bundle"
          :loading="saving"
          :disable="!canSubmit"
          @click="submit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { CashbookPointRow } from 'src/modules/bills_pays/repositories/cashbookRepository';
import { cashbookRepository } from 'src/modules/bills_pays/repositories/cashbookRepository';
import { moneyKernelRepository } from 'src/modules/bills_pays/repositories/moneyKernelRepository';
import { createPayIdempotencyKey } from 'src/modules/bills_pays/repositories/paysRepository';
import { useBooksExchangeRateQuery } from 'src/modules/bills_pays/composables/useBooksExchangeRateQuery';
import { useMoneyKernelCurrenciesQuery } from 'src/modules/bills_pays/composables/useMoneyKernelCurrenciesQuery';
import { useQueryClient } from '@tanstack/vue-query';
import { cashbookQueryKeys } from 'src/modules/bills_pays/services/cashbookQueryKeys';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  booksTenantId: number;
  operatingTenantId: number;
  profileId: number | null;
  point: CashbookPointRow | null;
  initialCurrency?: string;
  lockCurrency?: boolean;
  bundlesAtPoint?: Array<{ currencyCode: string }>;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  created: [payload: { bundleId: number | null }];
}>();

const queryClient = useQueryClient();

const currency = ref('BDT');
const booksRate = ref(1);
const openingAmount = ref<number | null>(null);
const saving = ref(false);

const { data: moneyCurrencies } = useMoneyKernelCurrenciesQuery();

const currencyOptions = computed(() =>
  (moneyCurrencies.value ?? [])
    .map((c) => ({
      label: `${c.code} (${c.symbol || c.code})`,
      value: c.code.toUpperCase(),
    }))
    .sort((a, b) => a.value.localeCompare(b.value)),
);

const booksTenantIdRef = computed(() => props.booksTenantId);
const booksRateQueryEnabled = computed(() => props.modelValue && currency.value !== 'BDT');
const booksRateQuery = useBooksExchangeRateQuery(
  booksTenantIdRef,
  computed(() => currency.value),
  booksRateQueryEnabled,
);

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return;
    const init = (props.initialCurrency ?? 'BDT').trim().toUpperCase() || 'BDT';
    currency.value = init;
    booksRate.value = init === 'BDT' ? 1 : booksRate.value;
    openingAmount.value = null;
  },
);

watch(currency, (ccy) => {
  if (ccy === 'BDT') {
    booksRate.value = 1;
    return;
  }
  const fetched = booksRateQuery.data.value;
  if (fetched != null && fetched > 0) {
    booksRate.value = fetched;
  }
});

watch(
  () => booksRateQuery.data.value,
  (rate) => {
    if (currency.value !== 'BDT' && rate != null && rate > 0) {
      booksRate.value = rate;
    }
  },
);

const canSubmit = computed(() => {
  if (!props.point || props.profileId == null) return false;
  if (!currency.value.trim()) return false;
  const rate = Number(booksRate.value);
  if (!Number.isFinite(rate) || rate <= 0) return false;
  const amt = openingAmount.value;
  if (amt != null && (!Number.isFinite(amt) || amt < 0)) return false;
  return currencyOptions.value.some((o) => o.value === currency.value);
});

const close = () => {
  if (saving.value) return;
  emit('update:modelValue', false);
};

const submit = async () => {
  const point = props.point;
  const profileId = props.profileId;
  if (!point || profileId == null || !canSubmit.value || saving.value) return;

  const currencyCode = currency.value.trim().toUpperCase();
  const rate = Number(booksRate.value);
  const amount =
    openingAmount.value != null && openingAmount.value > 0
      ? Number(openingAmount.value)
      : null;

  saving.value = true;
  try {
    const pointCode = point.code?.trim() || 'main';
    const existing = props.bundlesAtPoint ?? [];
    const currenciesAtPoint = [
      ...new Set(
        existing.map((b) => b.currencyCode.toUpperCase()).concat(currencyCode),
      ),
    ];
    const prov = await moneyKernelRepository.provisionCashbookCurrency(
      props.booksTenantId,
      profileId,
      currencyCode,
      pointCode,
      rate,
    );

    await cashbookRepository.syncCashbookPointPots(
      props.booksTenantId,
      point.id,
      currenciesAtPoint,
    );

    let bundleId: number | null =
      typeof prov.pot_id === 'number' ? prov.pot_id : null;

    if (amount != null) {
      const potId = bundleId;
      if (potId == null) throw new Error('Bundle not ready for deposit.');
      await moneyKernelRepository.deposit({
        tenantId: props.booksTenantId,
        profileId,
        amount,
        currencyCode,
        potId,
        meta: {
          source: 'people_add_bundle',
          requested_books_rate: rate,
        },
        idempotencyKey: createPayIdempotencyKey(),
      });
    }

    showSuccessNotification(
      amount != null ? 'Bundle added with opening balance.' : 'Bundle added.',
    );
    await queryClient.invalidateQueries({ queryKey: cashbookQueryKeys.root });
    emit('created', { bundleId });
    emit('update:modelValue', false);
  } catch (error: unknown) {
    showErrorNotification(error instanceof Error ? error.message : 'Could not add bundle.');
  } finally {
    saving.value = false;
  }
};
</script>
