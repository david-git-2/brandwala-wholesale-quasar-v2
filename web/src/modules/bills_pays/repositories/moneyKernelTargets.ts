/**
 * v2 money kernel RPC names (spec-only in DB today).
 * Swap call sites here when `public.rpc_*` bodies ship — see docs/features/money_bill_bridge/spec.md.
 */
export const MONEY_KERNEL_WRITE_RPC = {
  deposit: 'rpc_deposit',
  withdraw: 'rpc_withdraw',
  transferSameProfile: 'rpc_transfer_same_profile',
  transferP2p: 'rpc_transfer_p2p',
  payBills: 'rpc_pay_bills',
  payBill: 'rpc_pay_bill',
  applyDocumentSettlement: 'rpc_apply_document_settlement',
  voidDocumentSettlement: 'rpc_void_document_settlement',
  voidPays: 'rpc_void_pays',
  updatePays: 'rpc_update_pays',
  createBill: 'rpc_create_bill',
  issueBill: 'rpc_issue_bill',
  voidBill: 'rpc_void_bill',
  writeOffBill: 'rpc_write_off_bill',
} as const;
