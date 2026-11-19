<template>
  <div class="profile-deposit-lines">
    <div class="profile-deposit-lines__label text-caption text-weight-bold text-uppercase text-grey-7">
      Payments to post
    </div>

    <div
      class="profile-deposit-lines__table-wrap"
      :class="{
        'profile-deposit-lines__table-wrap--scroll': lines.length > 8,
        'profile-deposit-lines__table-wrap--page': isPageLayout,
      }"
    >
      <table
        class="profile-deposit-lines__table"
        :class="{ 'profile-deposit-lines__table--page': isPageLayout }"
        data-test="profile-deposit-table"
      >
        <thead>
          <tr>
            <th scope="col" class="profile-deposit-lines__th profile-deposit-lines__th--num">#</th>
            <th scope="col" class="profile-deposit-lines__th profile-deposit-lines__th--amount">Amount</th>
            <th scope="col" class="profile-deposit-lines__th">Method</th>
            <th
              v-if="isPageLayout"
              scope="col"
              class="profile-deposit-lines__th profile-deposit-lines__th--bank"
            >
              Bank
            </th>
            <th
              v-if="isPageLayout"
              scope="col"
              class="profile-deposit-lines__th profile-deposit-lines__th--inst-date"
            >
              Instrument date
            </th>
            <th scope="col" class="profile-deposit-lines__th">Reference</th>
            <th scope="col" class="profile-deposit-lines__th">Note</th>
            <th
              scope="col"
              class="profile-deposit-lines__th profile-deposit-lines__th--action"
              aria-label="Actions"
            />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(line, index) in lines"
            :key="line.id"
            :data-test="`profile-deposit-line-${index}`"
          >
            <td class="profile-deposit-lines__td profile-deposit-lines__td--num text-grey-7">
              {{ index + 1 }}
            </td>
            <td class="profile-deposit-lines__td profile-deposit-lines__td--amount">
              <q-input
                :model-value="line.amount"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                hide-bottom-space
                class="profile-deposit-lines__field profile-deposit-lines__field--amount"
                :prefix="amountPrefix"
                :error="showAmountError(line)"
                @update:model-value="(v) => updateLine(line.id, { amount: parseAmount(v) })"
              />
            </td>
            <td class="profile-deposit-lines__td">
              <div class="row items-center no-wrap q-gutter-xs">
                <q-select
                  :model-value="line.methodCode"
                  :options="methodOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  hide-bottom-space
                  class="profile-deposit-lines__field profile-deposit-lines__field--method col"
                  :loading="loadingPaymentMeta"
                  @update:model-value="(v) => onMethodChange(line.id, String(v ?? ''))"
                />
                <TfBtn
                  v-if="!isPageLayout && lineNeedsInstrumentPanel(line)"
                  variant="icon"
                  size="sm"
                  :icon="instrumentPanelComplete(line) ? 'ph ph-check-circle' : 'ph ph-list-dashes'"
                  :aria-label="instrumentPanelComplete(line) ? 'Instrument details set' : 'Instrument details'"
                  :class="{
                    'text-positive': instrumentPanelComplete(line),
                    'text-grey-7': !instrumentPanelComplete(line),
                  }"
                  @click="toggleInstrumentPanel(line.id)"
                />
              </div>
              <div
                v-if="!isPageLayout && openInstrumentPanelId === line.id"
                class="profile-deposit-lines__instrument profile-deposit-lines__instrument--stacked q-mt-xs"
              >
                <BdBankSelect
                  v-if="methodFlags(line).showBank"
                  :model-value="line.bdBankId"
                  :options="bdBankOptions"
                  :clearable="!methodFlags(line).bankRequired"
                  :loading="loadingPaymentMeta"
                  label="Bank"
                  class="profile-deposit-lines__field q-mb-xs"
                  @update:model-value="(v) => updateLine(line.id, { bdBankId: v })"
                />
                <q-input
                  v-if="methodFlags(line).showInstrumentDate"
                  :model-value="line.instrumentDate"
                  outlined
                  dense
                  hide-bottom-space
                  readonly
                  label="Instrument date"
                  class="profile-deposit-lines__field"
                  :error="showInstrumentDateError(line)"
                >
                  <template #append>
                    <q-icon name="ph ph-calendar" class="cursor-pointer text-grey-7" size="16px">
                      <q-popup-proxy transition-show="scale" transition-hide="scale">
                        <q-date
                          :model-value="line.instrumentDate"
                          mask="YYYY-MM-DD"
                          @update:model-value="(v) => updateLine(line.id, { instrumentDate: String(v ?? '') })"
                        >
                          <div class="row items-center justify-end">
                            <TfBtn v-close-popup variant="link" size="sm" label="Done" />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
              </div>
            </td>
            <td v-if="isPageLayout" class="profile-deposit-lines__td profile-deposit-lines__td--bank">
              <BdBankSelect
                v-if="methodFlags(line).showBank"
                :model-value="line.bdBankId"
                :options="bdBankOptions"
                :clearable="!methodFlags(line).bankRequired"
                :loading="loadingPaymentMeta"
                class="profile-deposit-lines__field"
                @update:model-value="(v) => updateLine(line.id, { bdBankId: v })"
              />
              <span v-else class="text-caption text-grey-5">—</span>
            </td>
            <td v-if="isPageLayout" class="profile-deposit-lines__td profile-deposit-lines__td--inst-date">
              <q-input
                v-if="methodFlags(line).showInstrumentDate"
                :model-value="line.instrumentDate"
                outlined
                dense
                hide-bottom-space
                readonly
                placeholder="YYYY-MM-DD"
                class="profile-deposit-lines__field"
                :error="showInstrumentDateError(line)"
              >
                <template #append>
                  <q-icon name="ph ph-calendar" class="cursor-pointer text-grey-7" size="16px">
                    <q-popup-proxy transition-show="scale" transition-hide="scale">
                      <q-date
                        :model-value="line.instrumentDate"
                        mask="YYYY-MM-DD"
                        @update:model-value="(v) => updateLine(line.id, { instrumentDate: String(v ?? '') })"
                      >
                        <div class="row items-center justify-end">
                          <TfBtn v-close-popup variant="link" size="sm" label="Done" />
                        </div>
                      </q-date>
                    </q-popup-proxy>
                  </q-icon>
                </template>
              </q-input>
              <span v-else class="text-caption text-grey-5">—</span>
            </td>
            <td class="profile-deposit-lines__td">
              <q-input
                :model-value="referenceDisplay(line)"
                outlined
                dense
                hide-bottom-space
                clearable
                class="profile-deposit-lines__field"
                :placeholder="referencePlaceholder(line)"
                :error="showReferenceError(line)"
                @update:model-value="(v) => setReference(line.id, line, String(v ?? ''))"
              />
            </td>
            <td class="profile-deposit-lines__td">
              <q-input
                :model-value="line.note"
                outlined
                dense
                hide-bottom-space
                clearable
                placeholder="Optional"
                class="profile-deposit-lines__field"
                @update:model-value="(v) => updateLine(line.id, { note: String(v ?? '') })"
              />
            </td>
            <td class="profile-deposit-lines__td profile-deposit-lines__td--action">
              <TfBtn
                v-if="lines.length > 1"
                variant="icon"
                size="sm"
                icon="ph ph-trash"
                aria-label="Remove row"
                @click="emit('remove-line', line.id)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="profile-deposit-lines__add row items-center wrap q-gutter-xs q-mt-sm">
      <button
        type="button"
        class="profile-deposit-lines__pill"
        :disabled="!canAddLine"
        data-test="profile-deposit-add-line"
        @click="emit('add-line')"
      >
        + Add payment line
      </button>
      <button
        type="button"
        class="profile-deposit-lines__pill profile-deposit-lines__pill--soft"
        :disabled="!canAddLine"
        @click="emit('add-line', 'cheque')"
      >
        Cheque
      </button>
      <button
        type="button"
        class="profile-deposit-lines__pill profile-deposit-lines__pill--soft"
        :disabled="!canAddLine"
        @click="emit('add-line', 'cash')"
      >
        Cash
      </button>
      <button
        type="button"
        class="profile-deposit-lines__pill profile-deposit-lines__pill--soft"
        :disabled="!canAddLine"
        @click="emit('add-line', 'bank_transfer')"
      >
        Transfer
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import BdBankSelect from './BdBankSelect.vue';
import { paymentMethodFieldFlags } from '../utils/paymentInstrumentFields';
import type { ProfileDepositLineDraft } from '../composables/useProfileDepositLines';
import type { WholesaleMethodOption } from '../composables/useWholesalePaymentMethodMeta';

const lines = defineModel<ProfileDepositLineDraft[]>('lines', { required: true });

const props = withDefaults(
  defineProps<{
    currencyCode: string;
    methodOptions: WholesaleMethodOption[];
    bdBankOptions: { label: string; value: number }[];
    loadingPaymentMeta?: boolean;
    showErrors?: boolean;
    totalAmount: number;
    canAddLine: boolean;
    layout?: 'dialog' | 'page';
  }>(),
  {
    loadingPaymentMeta: false,
    showErrors: false,
    layout: 'dialog',
  },
);

const isPageLayout = computed(() => props.layout === 'page');

const emit = defineEmits<{
  'add-line': [methodCode?: string];
  'remove-line': [id: string];
}>();

const openInstrumentPanelId = ref<string | null>(null);

const amountPrefix = computed(() => {
  const c = props.currencyCode.trim().toUpperCase();
  if (c === 'BDT') return '৳';
  return c;
});

const methodFlags = (line: ProfileDepositLineDraft) => {
  const code = line.methodCode?.toLowerCase();
  const opt = props.methodOptions.find((m) => m.value === code);
  const meta = opt
    ? { code: opt.code, category: opt.category }
    : { code: line.methodCode, category: '' };
  return paymentMethodFieldFlags(meta);
};

const lineNeedsInstrumentPanel = (line: ProfileDepositLineDraft) => {
  const f = methodFlags(line);
  return f.showBank || f.showInstrumentDate;
};

const instrumentPanelComplete = (line: ProfileDepositLineDraft) => {
  const f = methodFlags(line);
  if (f.bankRequired && line.bdBankId == null) return false;
  if (f.instrumentDateRequired && !line.instrumentDate.trim()) return false;
  return true;
};

const toggleInstrumentPanel = (lineId: string) => {
  openInstrumentPanelId.value = openInstrumentPanelId.value === lineId ? null : lineId;
};

const referencePlaceholder = (line: ProfileDepositLineDraft) => {
  const f = methodFlags(line);
  if (f.showChequeNumber) return 'Cheque #';
  if (f.showInstrumentReference) return 'Trx ref';
  return 'Optional';
};

const referenceDisplay = (line: ProfileDepositLineDraft) => {
  const f = methodFlags(line);
  if (f.showChequeNumber) return line.chequeNumber;
  if (f.showInstrumentReference) return line.instrumentReference;
  return line.reference;
};

const setReference = (id: string, line: ProfileDepositLineDraft, value: string) => {
  const f = methodFlags(line);
  if (f.showChequeNumber) updateLine(id, { chequeNumber: value });
  else if (f.showInstrumentReference) updateLine(id, { instrumentReference: value });
  else updateLine(id, { reference: value });
};

const showAmountError = (line: ProfileDepositLineDraft) => {
  if (!props.showErrors) return false;
  const n = Number(line.amount);
  return !Number.isFinite(n) || n <= 0;
};

const showReferenceError = (line: ProfileDepositLineDraft) => {
  if (!props.showErrors) return false;
  const f = methodFlags(line);
  const val = referenceDisplay(line).trim();
  if (f.chequeNumberRequired && !val) return true;
  return false;
};

const showInstrumentDateError = (line: ProfileDepositLineDraft) => {
  if (!props.showErrors) return false;
  const f = methodFlags(line);
  return f.instrumentDateRequired && !line.instrumentDate.trim();
};

type LinePatch = Partial<ProfileDepositLineDraft>;

const updateLine = (id: string, patch: LinePatch) => {
  lines.value = lines.value.map((line) =>
    line.id === id ? { ...line, ...patch } : line,
  );
};

const parseAmount = (v: string | number | null): number | null => {
  if (v === '' || v === null) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

const onMethodChange = (id: string, methodCode: string) => {
  updateLine(id, {
    methodCode,
    bdBankId: null,
    chequeNumber: '',
    instrumentDate: '',
    instrumentReference: '',
  });
  if (!isPageLayout.value) {
    openInstrumentPanelId.value = id;
  }
};
</script>

<style scoped lang="scss">
.profile-deposit-lines__label {
  margin-bottom: 6px;
}

.profile-deposit-lines__table-wrap {
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
  border-radius: var(--tf-radius-sm, 8px);
  overflow: hidden;
  background: var(--tf-neutral-surface, #fff);
}

.profile-deposit-lines__table-wrap--scroll {
  max-height: 280px;
  overflow: auto;
}

.profile-deposit-lines__table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
  background: var(--tf-neutral-surface, #fff);
}

.profile-deposit-lines__table-wrap--page {
  max-width: 100%;
  overflow-x: auto;
}

.profile-deposit-lines__table--page {
  table-layout: auto;
  width: 100%;
  min-width: 0;
}

.profile-deposit-lines__th--bank,
.profile-deposit-lines__td--bank {
  min-width: 140px;
}

.profile-deposit-lines__th--inst-date,
.profile-deposit-lines__td--inst-date {
  min-width: 130px;
}

.profile-deposit-lines__table thead th {
  position: sticky;
  top: 0;
  z-index: 1;
  height: 28px;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  text-align: left;
  color: var(--tf-neutral-chrome-text, #64748b);
  padding: 4px 6px;
  background: var(--tf-neutral-canvas, #f8fafc);
  border-bottom: 1px solid var(--tf-neutral-border, #e2e8f0);
  white-space: nowrap;
}

.profile-deposit-lines__table tbody td {
  vertical-align: middle;
  padding: 4px 6px;
  border-bottom: 1px solid var(--tf-neutral-border, #e2e8f0);
  background: var(--tf-neutral-surface, #fff);
}

.profile-deposit-lines__table tbody tr:last-child td {
  border-bottom: none;
}

body.body--dark .profile-deposit-lines__table thead th {
  background: var(--tf-neutral-chrome, #1e1e23);
  color: var(--tf-neutral-chrome-text, #b4b4bd);
  border-bottom-color: var(--tf-neutral-border, #34343b);
}

body.body--dark .profile-deposit-lines__table tbody td {
  background: var(--tf-neutral-surface, #141416);
  border-bottom-color: var(--tf-neutral-border, #34343b);
}

body.body--dark .profile-deposit-lines__table-wrap {
  background: var(--tf-neutral-surface, #141416);
  border-color: var(--tf-neutral-border, #34343b);
}

.profile-deposit-lines__th--num,
.profile-deposit-lines__td--num {
  width: 28px;
  text-align: center;
}

.profile-deposit-lines__th--amount,
.profile-deposit-lines__td--amount {
  width: 130px;
}

.profile-deposit-lines__field--amount {
  :deep(.q-field__control) {
    align-items: center;
  }

  :deep(.q-field__prefix) {
    align-self: center;
    height: auto;
    line-height: 1;
    padding-right: 4px;
    font-size: 13px;
    font-weight: 500;
    color: var(--tf-neutral-muted, #64748b);
  }

  :deep(.q-field__native),
  :deep(.q-field__input) {
    text-align: right;
    font-variant-numeric: tabular-nums;
    font-family: var(--tf-font-mono);
  }
}

.profile-deposit-lines__th--action,
.profile-deposit-lines__td--action {
  width: 36px;
  text-align: center;
}

.profile-deposit-lines__field {
  :deep(.q-field__control) {
    min-height: 30px;
    height: 30px;
  }

  :deep(.q-field__native),
  :deep(.q-field__input) {
    min-height: 28px;
    padding-top: 0;
    padding-bottom: 0;
    font-size: 13px;
  }

  :deep(.q-field__marginal) {
    height: 30px;
  }
}

.profile-deposit-lines__field--method {
  min-width: 108px;
}

.profile-deposit-lines__instrument {
  display: block;
  padding: 4px 0 2px;
  border-top: 1px dashed var(--tf-neutral-border, #e2e8f0);
}

.profile-deposit-lines__pill {
  appearance: none;
  border: 1px solid var(--tf-neutral-border-strong, #cbd5e1);
  border-radius: 999px;
  background: var(--tf-neutral-surface, #fff);
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 500;
  color: var(--tf-neutral-ink, #0f172a);
  cursor: pointer;
  line-height: 1.3;

  &:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  &:not(:disabled):hover {
    border-color: var(--tf-theme-primary, #334155);
  }

  &--soft {
    font-weight: 400;
    color: var(--tf-neutral-muted, #64748b);
    background: var(--tf-neutral-canvas, #f8fafc);
  }
}
</style>