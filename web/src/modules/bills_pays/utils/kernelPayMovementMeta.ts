import type { MoneyPayInstrumentFields, MoneyPaySubmitPayload } from '../types/moneyPayDialog';

const emptyInstrumentFields = (): MoneyPayInstrumentFields => ({
  bdBankId: null,
  chequeNumber: '',
  instrumentDate: '',
  instrumentReference: '',
});

type KernelPayMetaInput = Pick<
  MoneyPaySubmitPayload,
  'methodCode' | 'reference' | 'note' | 'paymentDate' | 'instrumentFields'
>;

export function buildKernelPayMovementMeta(
  payload: KernelPayMetaInput,
  extra?: Record<string, unknown>,
): Record<string, unknown> {
  const inst = payload.instrumentFields ?? emptyInstrumentFields();
  const meta: Record<string, unknown> = {
    ...(extra ?? {}),
  };

  const methodCode = payload.methodCode?.trim();
  if (methodCode) meta.method_code = methodCode;

  const reference = payload.reference?.trim();
  if (reference) meta.reference = reference;

  const note = payload.note?.trim();
  if (note) meta.note = note;

  const paidOn = payload.paymentDate?.trim();
  if (paidOn) meta.paid_on = paidOn;

  if (inst.bdBankId != null && inst.bdBankId > 0) {
    meta.bd_bank_id = inst.bdBankId;
  }

  const chequeNumber = inst.chequeNumber?.trim();
  if (chequeNumber) meta.cheque_number = chequeNumber;

  const instrumentDate = inst.instrumentDate?.trim();
  if (instrumentDate) {
    meta.cheque_date = instrumentDate;
    meta.instrument_date = instrumentDate;
  }

  const instrumentReference = inst.instrumentReference?.trim();
  if (instrumentReference) meta.instrument_reference = instrumentReference;

  return meta;
}