<template>
  <div class="profile-cash-leg-picker column q-gutter-y-md">
    <BillDialogField label="Currency">
      <q-select
        v-model="currencyModel"
        outlined
        dense
        emit-value
        map-options
        :options="legData.currencyOptions.value"
        :loading="legData.loading.value"
        :disable="lockCurrency"
        hide-bottom-space
        data-test="profile-cash-currency"
      />
    </BillDialogField>

    <MoneyPayDialogAmountBlock
      :amount="amountModel"
      :currency-code="currencyModel"
      :show-error="amountShowError"
      @update:amount="(v) => (amountModel = v)"
      @blur="amountTouched = true"
    />

    <BillDialogField :label="locationLabel">
      <q-select
        v-model="locationPointIdModel"
        outlined
        dense
        emit-value
        map-options
        clearable
        :options="locationSelectOptions"
        :display-value="locationPointDisplayValue"
        :loading="legData.loading.value"
        hide-bottom-space
        data-test="profile-cash-location"
      />
    </BillDialogField>

    <BillDialogField
      v-if="showFxBooksRateField"
      label="Books rate (BDT per 1 unit)"
    >
      <q-input
        v-model.number="booksRateModel"
        outlined
        dense
        type="number"
        step="0.000001"
        :min="0"
        hide-bottom-space
        hint="A new bundle opens at this rate when you post."
        data-test="profile-cash-books-rate"
      />
    </BillDialogField>

    <div
      v-if="depositBdtAutoHint"
      class="text-caption text-grey-7"
    >
      A BDT bundle will be created when you post.
    </div>

    <div
      v-if="depositFxAutoHint"
      class="text-caption text-grey-7"
    >
      A new {{ currencyModel }} bundle opens at your books rate when you post.
    </div>

    <div
      v-if="showWithdrawNoBundleHint"
      class="text-caption text-grey-7"
    >
      No {{ currencyModel }} bundle at this location.
    </div>

    <div v-if="showBundleSection && locationPointIdModel != null" class="profile-cash-leg-picker__bundles">
      <div
        v-if="showBundlePickerHeader"
        class="row items-center justify-between q-mb-sm"
      >
        <span class="text-caption text-weight-bold text-uppercase text-grey-7">Bundle</span>
        <TfBtn
          v-if="showBdtCreateBundle"
          variant="link"
          size="sm"
          icon="ph ph-plus"
          label="Create bundle"
          :disable="legData.loading.value"
          @click="openBundleDialog"
        />
      </div>

      <div v-if="legData.loading.value" class="row justify-center q-py-md">
        <q-spinner color="primary" size="24px" />
      </div>
      <div
        v-else-if="!filteredBundles.length && kind === 'deposit'"
        class="text-caption text-grey-7 q-py-sm"
      >
        No {{ currencyModel }} bundle at this location yet.
      </div>
      <div v-else class="row q-gutter-sm flex-wrap">
        <button
          v-for="bundle in filteredBundles"
          :key="bundle.bundleId"
          type="button"
          class="profile-cash-leg-picker__bundle"
          :class="{ 'profile-cash-leg-picker__bundle--selected': bundleIdModel === bundle.bundleId }"
          @click="bundleIdModel = bundle.bundleId"
        >
          <span class="text-caption text-weight-bold text-grey-8">{{ bundle.currencyCode }}</span>
          <span class="text-body2 text-weight-medium text-grey-9 q-mt-xs">
            {{ formatAmountBdt(bundle.amount) }}
          </span>
          <span
            v-if="showBooksRate(bundle)"
            class="text-caption text-grey-7 q-mt-xs"
          >
            @ {{ bundle.booksRate }}
          </span>
        </button>
      </div>
    </div>

    <div v-if="legData.loadError.value" class="text-negative text-caption">
      {{ legData.loadError.value }}
    </div>

    <ProfileCashbookBundleCreateDialog
      v-if="kind === 'deposit'"
      v-model="bundleDialogOpen"
      :books-tenant-id="booksTenantId"
      :operating-tenant-id="operatingTenantId"
      :profile-id="profileId"
      :point="legData.pointById(locationPointIdModel)"
      :initial-currency="currencyModel"
      :lock-currency="true"
      :bundles-at-point="bundlesAtSelectedPoint"
      @created="onBundleCreated"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import BillDialogField from 'src/modules/bills_pays/components/BillDialogField.vue';
import MoneyPayDialogAmountBlock from 'src/modules/bills_pays/components/MoneyPayDialogAmountBlock.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import { formatAmountBdt } from 'src/utils/currency';
import { useBooksExchangeRateQuery } from 'src/modules/bills_pays/composables/useBooksExchangeRateQuery';
import { useProfileCashMovementLegData } from '../composables/useProfileCashMovementLegData';
import ProfileCashbookBundleCreateDialog from './ProfileCashbookBundleCreateDialog.vue';
import type { MoneyPayKind } from 'src/modules/bills_pays/types/moneyPayDialog';
import type { ProfileCashbookBundleRow } from '../types/profileCashbookBundle';

const props = defineProps<{
  booksTenantId: number;
  operatingTenantId: number;
  profileId: number | null;
  kind: MoneyPayKind;
  enabled: boolean;
  amountShowError?: boolean;
  lockCurrency?: boolean;
  /** Label for pre-selected location before profile points load. */
  prefillLocationLabel?: string | null;
}>();

const currencyModel = defineModel<string>('currencyCode', { default: 'BDT' });
const amountModel = defineModel<number | null>('amount', { default: null });
const locationPointIdModel = defineModel<number | null>('locationPointId', { default: null });
const bundleIdModel = defineModel<number | null>('bundleId', { default: null });
const booksRateModel = defineModel<number | null>('booksRate', { default: null });
const depositRequiresBundlePickModel = defineModel<boolean>('depositRequiresBundlePick', {
  default: false,
});

const amountTouched = ref(false);
const bundleDialogOpen = ref(false);

const enabledRef = computed(() => props.enabled && props.profileId != null);
const profileIdRef = computed(() => props.profileId);
const booksTenantIdRef = computed(() => props.booksTenantId);

const legData = useProfileCashMovementLegData(booksTenantIdRef, profileIdRef, enabledRef);

const isBdt = computed(() => currencyModel.value.trim().toUpperCase() === 'BDT');

const locationLabel = computed(() =>
  props.kind === 'deposit' ? 'Deposit to location' : 'Withdraw from location',
);

function resolveLocationPointLabel(pointId: number): string | null {
  const fromOptions = legData.locationOptions.value.find((o) => o.value === pointId);
  if (fromOptions?.label) return fromOptions.label;
  const point = legData.pointById(pointId);
  if (point) {
    return point.name?.trim() || point.code?.trim() || null;
  }
  const prefill = props.prefillLocationLabel?.trim();
  if (prefill && locationPointIdModel.value === pointId) return prefill;
  return null;
}

const locationSelectOptions = computed(() => {
  const opts = [...legData.locationOptions.value];
  const id = locationPointIdModel.value;
  if (id == null) return opts;
  if (opts.some((o) => o.value === id)) return opts;
  const label = resolveLocationPointLabel(id);
  if (!label) return opts;
  return [...opts, { label, value: id }].sort((a, b) => a.label.localeCompare(b.label));
});

const locationPointDisplayValue = computed(() => {
  const id = locationPointIdModel.value;
  if (id == null) return undefined;
  const label = resolveLocationPointLabel(id);
  if (label) return label;
  return legData.loading.value ? '' : undefined;
});

const filteredBundles = computed(() =>
  legData.bundlesForPointAndCurrency(locationPointIdModel.value, currencyModel.value),
);

const showBundleSection = computed(() => {
  if (props.kind === 'withdrawal') {
    return filteredBundles.value.length > 1;
  }
  if (props.kind === 'deposit') {
    return isBdt.value && filteredBundles.value.length > 0;
  }
  return false;
});

const showWithdrawNoBundleHint = computed(
  () =>
    props.kind === 'withdrawal'
    && locationPointIdModel.value != null
    && !legData.loading.value
    && filteredBundles.value.length === 0,
);

const showBundlePickerHeader = computed(
  () => props.kind === 'deposit' && locationPointIdModel.value != null,
);

const showBdtCreateBundle = computed(
  () =>
    props.kind === 'deposit'
    && isBdt.value
    && locationPointIdModel.value != null
    && filteredBundles.value.length > 0,
);

const showFxBooksRateField = computed(
  () =>
    props.kind === 'deposit'
    && !isBdt.value
    && locationPointIdModel.value != null,
);

const depositFxAutoHint = computed(
  () =>
    props.kind === 'deposit'
    && !isBdt.value
    && locationPointIdModel.value != null,
);

const depositBdtAutoHint = computed(
  () =>
    props.kind === 'deposit'
    && isBdt.value
    && locationPointIdModel.value != null
    && filteredBundles.value.length === 0,
);

const booksRateQueryEnabled = computed(
  () => props.enabled && !isBdt.value && props.kind === 'deposit',
);
const booksRateQuery = useBooksExchangeRateQuery(
  booksTenantIdRef,
  currencyModel,
  booksRateQueryEnabled,
);

const bundlesAtSelectedPoint = computed(() => {
  const pointId = locationPointIdModel.value;
  if (pointId == null) return [];
  const point = legData.pointById(pointId);
  if (!point) return [];
  const codes = new Set<string>();
  for (const b of legData.bundles.value) {
    if (
      (b.deskPointId != null && b.deskPointId === point.id)
      || (point.code?.trim() && b.locationCode.toLowerCase() === point.code.trim().toLowerCase())
    ) {
      codes.add(b.currencyCode);
    }
  }
  return [...codes].map((currencyCode) => ({ currencyCode }));
});

const showBooksRate = (bundle: ProfileCashbookBundleRow) =>
  bundle.currencyCode !== 'BDT' || Math.abs(bundle.booksRate - 1) > 0.000001;

watch(
  [() => props.kind, currencyModel, filteredBundles],
  () => {
    depositRequiresBundlePickModel.value =
      props.kind === 'deposit'
      && isBdt.value
      && filteredBundles.value.length > 0;
  },
  { immediate: true },
);

watch(currencyModel, (ccy) => {
  locationPointIdModel.value = null;
  bundleIdModel.value = null;
  if (ccy.trim().toUpperCase() === 'BDT') {
    booksRateModel.value = 1;
  } else {
    booksRateModel.value = null;
  }
});

watch(locationPointIdModel, () => {
  bundleIdModel.value = null;
});

watch(
  () => props.enabled,
  (open) => {
    if (open) {
      amountTouched.value = false;
      if (!currencyModel.value) currencyModel.value = 'BDT';
    }
  },
);

watch(
  () => booksRateQuery.data.value,
  (rate) => {
    if (
      !isBdt.value
      && rate != null
      && rate > 0
      && props.kind === 'deposit'
    ) {
      booksRateModel.value = rate;
    }
  },
);

watch(bundleIdModel, (id) => {
  if (id == null) return;
  const bundle = filteredBundles.value.find((b) => b.bundleId === id);
  if (bundle != null && bundle.booksRate > 0) {
    booksRateModel.value = bundle.booksRate;
  }
});

watch(filteredBundles, (list) => {
  if (bundleIdModel.value != null && !list.some((b) => b.bundleId === bundleIdModel.value)) {
    bundleIdModel.value = null;
  }
  if (props.kind === 'withdrawal' || (props.kind === 'deposit' && list.length === 1)) {
    if (list.length === 1) {
      bundleIdModel.value = list[0].bundleId;
    } else if (props.kind === 'withdrawal' && list.length !== 1) {
      bundleIdModel.value =
        bundleIdModel.value != null && list.some((b) => b.bundleId === bundleIdModel.value)
          ? bundleIdModel.value
          : null;
    }
  }
});

const openBundleDialog = () => {
  if (locationPointIdModel.value == null) return;
  bundleDialogOpen.value = true;
};

const onBundleCreated = async (payload: { bundleId: number | null }) => {
  await legData.refetch();
  if (payload.bundleId != null) {
    bundleIdModel.value = payload.bundleId;
  }
};

defineExpose({ refetch: legData.refetch });
</script>

<style scoped lang="scss">
.profile-cash-leg-picker__bundle {
  min-width: 6.5rem;
  padding: 8px 10px;
  text-align: left;
  border: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.1));
  border-radius: 8px;
  background: #fff;
  cursor: pointer;

  &--selected {
    border-color: var(--tf-primary, #1976d2);
    box-shadow: 0 0 0 1px var(--tf-primary, #1976d2);
  }
}
</style>
