# Money spine v2 — tests

Golden SQL later: `supabase/tests/golden_money_spine_v2_*.sql`.

| Id | Given | Action | Expect |
| :--- | :--- | :--- | :--- |
| **Cash** | | | |
| TC-CASH-01 | Profile BDT pot 1000 | `rpc_deposit` 500 | Pot 1500; pays `deposit`/`posted` |
| TC-CASH-02 | Pot 100 | `rpc_withdraw` 200 | `insufficient_balance` |
| TC-CASH-03 | Prior deposit with key K | `rpc_deposit` same params + K | `idempotent: true`; pot unchanged |
| TC-CASH-03b | Deposit K voided | `rpc_deposit` same K | `idempotent: true`; voided pays returned; pot unchanged |
| TC-CASH-04 | Key K used for 500 | `rpc_deposit` 600 + K | `idempotency_conflict` |
| TC-CASH-05 | Same-profile BDT pots | `rpc_transfer_same_profile` 100 | From −100; to +100 |
| TC-CASH-06 | BDT→USD, rate 120 | `rpc_transfer_same_profile` | To += amount×120 (server rate) |
| TC-CASH-07 | Same currency, rate 1.5 | transfer | `invalid_rate` / reject override |
| TC-CASH-08 | Different profiles | `rpc_transfer_p2p` | From down; to up |
| **Pay** | | | |
| TC-PAY-01 | Issued AR due 1000; customer pot 1000 | `rpc_pay_bill` 1000 | Bill `paid`; customer pot 0; payee pot +1000 |
| TC-PAY-02 | AP due 500; tenant from-pot; vendor payee pot | `rpc_pay_bill` 200 | Bill `partial`; vendor pot +200 |
| TC-PAY-03 | AP due; `p_to_pot_id` = vendor pot | `rpc_pay_bill` | Vendor pot += amount |
| TC-PAY-03b | AP due; omit `p_to_pot_id` | `rpc_pay_bill` | Derived vendor pot (Option C); reject if no payee pot |
| TC-PAY-04 | Bills due 300 + 200; pot 600 | `rpc_pay_bills` both | One pays; two `settlement_kind=pay` rows |
| TC-PAY-05 | Due 300 | alloc 400 | `invalid_amount` |
| TC-PAY-06 | Pays amount 500; alloc 300+100 | `rpc_pay_bills` | Commit OK; 100 unapplied (Σ books ≤ pays.books) |
| TC-PAY-07 | Pays 500; alloc 300+250 | `rpc_pay_bills` | `invalid_amount` (sum alloc > amount) |
| TC-PAY-08 | Draft or voided bill | `rpc_pay_bill` | `invalid_state` |
| TC-PAY-09 | From pot USD, bill BDT | `rpc_pay_bill` | `invalid_arguments` (I7b) |
| TC-PAY-10 | Posted pay + pay settlement | `rpc_void_pays` | Pots restored; bill due restored; document settlements untouched |
| TC-PAY-10b | Paid bill; void its only pay settle | `rpc_void_pays` | Bill status back to `issued` (T4 allows paid→issued) |
| TC-PAY-10c | Payment credited to pot; pot later emptied | `rpc_void_pays` | `insufficient_balance` (I20) |
| TC-PAY-11 | Bill kind = credit_note | `rpc_pay_bill` | `invalid_arguments` (document apply only) |
| TC-PAY-12 | Payer profile ≠ bill.from_profile_id | `rpc_pay_bill` | `invalid_arguments` |
| TC-PAY-13 | Multi-bill posted pays | `rpc_update_pays` | `invalid_arguments` (void + pay_bills) |
| TC-PAY-14 | Pays 100; two allocs; books rounding | `rpc_pay_bills` | Σ settlement books = settle-budget; D1 passes |
| TC-PAY-15 | Two allocs same bill_id | `rpc_pay_bills` | `invalid_arguments` duplicate bill_id |
| TC-PAY-16 | Posted pay key K amount 500 alloc A; retry K amount 500 alloc B≠A | `rpc_pay_bills` | `idempotency_conflict` (allocations must match) |
| TC-PAY-16b | Posted pay key K; retry same amount+pots+allocs+books_rate | `rpc_pay_bills` | `idempotent: true`; pots/bills unchanged |
| TC-PAY-17 | `to_pot` not payee's pot | `rpc_pay_bill` | `invalid_arguments` |
| TC-PAY-18 | Multi-bill; bills different `to_profile_id` | `rpc_pay_bills` | `invalid_arguments` (I32) |
| TC-PAY-19 | `from_pot_id = to_pot_id` | `rpc_pay_bill` | `invalid_arguments` (I30) |
| TC-PAY-20 | Settlement references voided pays | pay path | S5 / RPC reject |
| TC-PAY-21 | Retry with allocations reordered | `rpc_pay_bills` same key | `idempotent: true` (normalized order) |
| TC-CASH-09 | FX transfer posted | `rpc_void_pays` | to-pot reverse uses same server rate as post |
| **Document (CN)** | | | |
| TC-DOC-01 | Parent due 10k; issued CN due 2k | (no apply) | Parent due still 10k |
| TC-DOC-02 | Same | `rpc_apply_document_settlement` 2k | Parent due 8k; CN due 0; `settlement_kind=document`; pots unchanged |
| TC-DOC-02b | CN due 2k; parent due 10k | apply 500 then 500 | Two document rows; parent due 9k; CN due 1k |
| TC-DOC-03 | Parent due 1k | apply 2k | `invalid_amount` |
| TC-DOC-04 | CN due 500 | apply 800 | `invalid_amount` |
| TC-DOC-05 | Source kind = debit_note | apply | `invalid_arguments` (credit_note only) |
| TC-DOC-05b | Target kind = credit_note | apply | `invalid_arguments` |
| TC-DOC-06 | Document settlement | `rpc_void_document_settlement` | Parent + CN dues restored |
| TC-DOC-07 | Document settlement | UPDATE settlement amount | S1 rejects |
| TC-DOC-08 | Apply CN | (events) | `payment_applied` on target **and** on CN |
| TC-DOC-09 | Apply with key K twice | same params + K | Second `idempotent: true` |
| TC-DOC-09b | Key K used for 500 | apply 600 + K | `idempotency_conflict` |
| TC-DOC-10 | CN is source of document settle | `rpc_void_bill` CN reverse=true | Document deleted; target due restored; CN voided |
| TC-DOC-11 | CN partially applied | UPDATE CN `total_amount` | T4 reject (source counts as settled) |
| TC-DOC-12 | CN parties A↔B; target bill parties C↔D | `rpc_apply_document_settlement` | `invalid_arguments` (I29) |
| TC-DOC-13 | CN from parent AR; second AR same from/to with due | apply onto second AR | Allowed; parent due unchanged |
| **Bills** | | | |
| TC-BILL-01 | Payload with from/to + lines | create + `auto_issue` | Events `created` then `issued` |
| TC-BILL-02 | Draft with from/to set | `rpc_issue_bill` | `issued` |
| TC-BILL-02b | Draft missing from/to | `rpc_issue_bill` | `invalid_arguments` |
| TC-BILL-03 | Issued + any settlement | `rpc_void_bill` reverse=false | `invalid_arguments` |
| TC-BILL-04 | Issued + pay settlement | `rpc_void_bill` reverse=true | Pays voided; bill voided |
| TC-BILL-04b | Bill on multi-bill pays | `rpc_void_bill` reverse=true | `invalid_arguments` (void pays first) |
| TC-BILL-05 | Issued + document settle | `rpc_void_bill` reverse=true | Document voided; bill voided |
| TC-BILL-06 | Due 100; paid 0 | `rpc_write_off_bill` 100 | Due 0; status `written_off` |
| TC-BILL-06b | Due 100; paid 0 | write-off 40 | Due 60; status `partial`; `paid+due+written=total` |
| TC-BILL-06c | Credit note with due | `rpc_write_off_bill` | `invalid_arguments` |
| TC-BILL-06d | Paid 400 then write-off remaining 600 | `rpc_write_off_bill` | Status `paid` (derive); one `written_off` event |
| TC-BILL-07 | Same create idempotency key | `rpc_create_bill` ×2 | One bill |
| TC-BILL-07b | Concurrent create same idempotency key | two `rpc_create_bill` | One winner; loser returns `idempotent: true` (unique_violation path) |
| TC-BILL-08 | Create credit_note without `parent_bill_id` | `rpc_create_bill` | `invalid_arguments` |
| TC-BILL-08b | Create credit_note; parent missing/voided/draft | `rpc_create_bill` | `not_found` / `invalid_state` |
| TC-BILL-08c | CN from/to not swap of parent | `rpc_create_bill` | `invalid_arguments` |
| TC-BILL-08d | CN omit from/to | `rpc_create_bill` | Inherits parent.to → from, parent.from → to |
| TC-BILL-08e | Parent currency USD; CN omits currency | `rpc_create_bill` | CN currency USD (not forced BDT reject) |
| TC-BILL-09 | Draft bill | `rpc_void_bill` | Status `voided` |
| TC-BILL-10 | Voided bill held key K | create again with K | `idempotency_conflict` or return voided bill id (permanent key) |
| TC-BILL-11 | Issued bill | INSERT line | T8 reject |
| TC-BILL-12 | CN total > parent total | `rpc_create_bill` | `invalid_arguments` (I33) |
| TC-BILL-13 | Parent with live CNs | `rpc_void_bill` | refuse or cascade per RPC |
| TC-BILL-14 | Issue with Σ lines ≠ total | `rpc_issue_bill` | `invalid_amount` |
| **Guards** | | | |
| TC-G-01 | Posted pays | UPDATE amount | T2 reject |
| TC-G-02 | — | UPDATE pot.amount | T3 reject |
| TC-G-03 | Issued bill | UPDATE total_amount | T4 reject |
| TC-G-04 | — | UPDATE bill_events | T5 reject |
| TC-G-05 | One pay settle → bill `partial` | (events) | One `payment_applied` only (no extra status event) |
| TC-G-06 | Voided bill | UPDATE any column | T4 reject (`voided bill cannot be updated`) |
| TC-G-07 | Draft bill | UPDATE status=`paid` | T4 reject (draft → issued/voided only) |
| TC-G-08 | Written-off bill | `rpc_void_bill` (clears due + written_off) | One `voided` event (not `written_off`) |
| TC-G-09 | Pay settle | (T7) | One bills UPDATE (paid+due+status); one `payment_applied` |
| **Reads** | | | |
| TC-R-01 | Many bills | `rpc_query_bills` limit 2 then `next_cursor` | Page 2 continues; no `total_pages` / `total_count` |
| TC-R-02 | List + lines include, limit 100 | `rpc_query_bills` | `invalid_arguments` (heavy includes ≤ 50) |
| TC-R-03 | Profile ledger | `rpc_profile_transactions` + cursor | `has_more` / `next_cursor`; snapshot balances |
| TC-R-04 | Bills with NULL `due_date` | `rpc_query_bills` cursor | No skipped rows |
| TC-R-05 | Ledger + date filter | `rpc_profile_transactions` | `balance_after` matches snapshot cols |
| TC-R-06 | Group mode two currencies | `rpc_query_bills` | Split by currency or error |
| **TC-SEC** | | | |
| TC-SEC-01 | Role `anon` | each public write RPC | `permission denied` |
| TC-SEC-02 | Tenant B session | RPC with tenant A id | `access_denied` (uniform) |
| TC-SEC-03 | Caller | `rpc_apply_document_settlement` cross-tenant bills | reject |
| TC-SEC-04 | Spoof `issued_by_tenant_id` | `rpc_create_bill` | reject |
| TC-SEC-05 | Foreign profile ids | create/issue | reject |
| TC-SEC-06 | Rate override | transfer without `fx_override` | reject |
| TC-SEC-07 | Inflated books rate param (legacy) | deposit | ignored; server rate used |
| TC-SEC-08 | — | INSERT pot amount ≠ 0 | T3 reject |
| TC-SEC-09 | — | DELETE pays/bills/settlements | G1 reject |
| **TC-IDEM** | | | |
| TC-IDEM-01 | Voided pays key K | deposit same K | no new money |
| TC-IDEM-02 | Transfer K different rate | retry | `idempotency_conflict` |
| TC-IDEM-03 | Create bill K different payload | retry | `idempotency_conflict` |
| TC-IDEM-04 | Write-off retry same due | twice | no double write-off |
| **TC-NUM** | | | |
| TC-NUM-01 | 4-dp bill amounts | settle | exact close |
| TC-NUM-02 | Excess precision input | pay | rejected at RPC |
| TC-NUM-03 | JPY 0 dp / KWD 3 dp | create + pay | currency scale |
| TC-NUM-04 | Payment at Dhaka midnight | deposit date | tenant TZ date |
| **TC-CONC** | | | |
| TC-CONC-01 | Two pays one bill | concurrent | one wins; other invalid_amount or partial |
| TC-CONC-02 | Void bill + pay same bill | concurrent | safe ordering |
| TC-CONC-03 | Void bill + document settle | load | no deadlock |
| TC-CONC-04 | Same idempotency key | concurrent insert | one row |
| **TC-INV** | | | |
| TC-INV-01 | Posted pays | pot = Σ deltas | recon pass |
| TC-INV-02 | Each bill | paid = Σ settlements | exact |
| TC-INV-03 | Multi-bill pays | Σ alloc ≤ pays.amount | pass |
| TC-INV-04 | Tenant | money conservation per currency | pass |
| **TC-PERF** | | | |
| TC-PERF-01 | 10k bills tenant | `rpc_query_bills` p99 | within budget |
| TC-PERF-02 | 200 allocations | `rpc_pay_bills` | completes |
| TC-PERF-03 | Hot collection pot | concurrent deposits | throughput baseline |
