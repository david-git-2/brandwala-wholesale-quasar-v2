import { computed, ref, watch, type Ref } from 'vue';
import type {
  MoneyPayDepositLine,
  MoneyPayInstrumentFields,
} from '../types/moneyPayDialog';
import {
  paymentInstrumentExtrasBlockReason,
  paymentMethodFieldFlags,
} from '../utils/paymentInstrumentFields';
import type { WholesaleMethodOption } from './useWholesalePaymentMethodMeta';

export const PROFILE_DEPOSIT_LINES_MAX = 25;

export type ProfileDepositLineDraft = {
  id: string;
  amount: number | null;
  methodCode: string;
  reference: string;
  note: string;
  bdBankId: number | null;
  chequeNumber: string;
  instrumentDate: string;
  instrumentReference: string;
};

const emptyInstrumentFields = (): MoneyPayInstrumentFields => ({
  bdBankId: null,
  chequeNumber: '',
  instrumentDate: '',
  instrumentReference: '',
});

function newLine(defaultMethodCode: string): ProfileDepositLineDraft {
  return {
    id: crypto.randomUUID(),
    amount: null,
    methodCode: defaultMethodCode,
    reference: '',
    note: '',
    ...emptyInstrumentFields(),
  };
}

function methodMeta(
  methodCode: string,
  methodOptions: WholesaleMethodOption[],
): { code: string; category: string } {
  const code = methodCode?.toLowerCase();
  const opt = methodOptions.find((m) => m.value === code);
  if (!opt) return { code: methodCode, category: '' };
  return { code: opt.code, category: opt.category };
}

function lineInstrumentFields(line: ProfileDepositLineDraft): MoneyPayInstrumentFields {
  return {
    bdBankId: line.bdBankId,
    chequeNumber: line.chequeNumber,
    instrumentDate: line.instrumentDate,
    instrumentReference: line.instrumentReference,
  };
}

export function useProfileDepositLines(options: {
  dialogOpen: Ref<boolean>;
  methodOptions: Ref<WholesaleMethodOption[]>;
  defaultMethodCode: string;
}) {
  const lines = ref<ProfileDepositLineDraft[]>([newLine(options.defaultMethodCode)]);

  const resetLines = () => {
    lines.value = [newLine(options.defaultMethodCode)];
  };

  watch(
    () => options.dialogOpen.value,
    (open) => {
      if (open) resetLines();
    },
  );

  const addLine = (methodCode?: string) => {
    if (lines.value.length >= PROFILE_DEPOSIT_LINES_MAX) return;
    const code = methodCode?.trim() || options.defaultMethodCode;
    lines.value.push(newLine(code));
  };

  const removeLine = (id: string) => {
    if (lines.value.length <= 1) return;
    lines.value = lines.value.filter((l) => l.id !== id);
  };

  const trimPostedLines = (postedCount: number) => {
    if (postedCount <= 0) return;
    lines.value = lines.value.slice(postedCount);
    if (lines.value.length === 0) {
      resetLines();
    }
  };

  const totalAmount = computed(() =>
    lines.value.reduce((sum, line) => {
      const n = Number(line.amount);
      return sum + (Number.isFinite(n) && n > 0 ? n : 0);
    }, 0),
  );

  const buildDepositLines = (): MoneyPayDepositLine[] =>
    lines.value.map((line) => ({
      amount: Number(line.amount) || 0,
      methodCode: line.methodCode,
      reference: line.reference.trim() || null,
      note: line.note.trim() || null,
      instrumentFields: lineInstrumentFields(line),
    }));

  const submitDisabledReason = computed((): string | null => {
    if (!lines.value.length) return 'Add at least one deposit line.';
    for (let i = 0; i < lines.value.length; i += 1) {
      const line = lines.value[i];
      const amt = Number(line.amount);
      if (!Number.isFinite(amt) || amt <= 0) {
        return `Line ${i + 1}: enter an amount greater than zero.`;
      }
      const flags = paymentMethodFieldFlags(
        methodMeta(line.methodCode, options.methodOptions.value),
      );
      const extrasReason = paymentInstrumentExtrasBlockReason(
        flags,
        lineInstrumentFields(line),
      );
      if (extrasReason) {
        const plain = extrasReason.replace(/^Next: /, '');
        return `Line ${i + 1}: ${plain.charAt(0).toLowerCase()}${plain.slice(1)}`;
      }
    }
    return null;
  });

  return {
    lines,
    addLine,
    removeLine,
    trimPostedLines,
    resetLines,
    totalAmount,
    buildDepositLines,
    submitDisabledReason,
    canAddLine: computed(() => lines.value.length < PROFILE_DEPOSIT_LINES_MAX),
  };
}