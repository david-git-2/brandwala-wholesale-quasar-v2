# Dropship Wallet — Legacy drop plan

**Rule:** When a gap is closed, **drop or neutralize the conflicting legacy path in the same phase**. Do not leave two writers.

**Index:** [README_DROPSHIP_WALLET.md](./README_DROPSHIP_WALLET.md)

| ID | Conflicting legacy | Drop when | Action | Done |
|----|--------------------|-----------|--------|------|
| R1 | Independent `confirm_courier_remittance_to_tenant` UWL writer | P0B | Make thin wrapper to shared remittance routine; no second metadata/purpose branch | [ ] |
| R2 | `mark_dropship_order_returned` status-only path | P0C | Wrap to `finalize_dropship_return` or raise until finalize runs | [ ] |
| R3 | Reads of `billing_profile_wallet_ledger` | P1 | Delete queries; use UWL only | [ ] |
| R4 | Frontend calling finance-hub remittance RPC as parallel path | P1 | Call `record_dropship_courier_remittance` (or shared name) only | [ ] |
| R5 | UI offering recipient remittance for prepaid / billing_profile invoices | P2 | Hide CTA; rely on RPC reject as backstop | [ ] |
| R6 | EXECUTE grants on divergent remittance after cutover | P3 | Revoke public/authenticated execute on obsolete writers if still distinct; keep wrapper only | [ ] |

## How to mark done

After the owning phase migration/UI lands, check the box and note migration/commit in the PR description.

## Do not

- Leave “compat dual-write” for remittance
- Keep retired table reads “just in case”
- Defer R1–R2 to P3 — they are flow breakers
