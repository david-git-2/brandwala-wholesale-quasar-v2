# Customer hub — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/customer/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/customer/` |
| SQL | `public.sql` (customer stub not split) |
| State | Pinia — copy module |
| Access | `app` + `shop`. Grants: `customer` and child `recipient_profile` |

## Where to look

| Need | Path |
| :--- | :--- |
| Tables, RPCs | Grep `customer_groups`, `create_customer_account` in `public.sql` |
| Money party | [bills_pays spec](../bills_pays/spec.md) — `profiles` / `billing_profiles` |
| Pages | `web/src/modules/customer/pages/` |
| Recipient profiles | Same hub; `parentModuleKey: customer` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` hub; `shop` as **group members** (not recipients) |
| In | Customer group (who pays), **profile** (bill-to), members, dues. **Recipient profiles** (parcel) in same hub |
| Out | Shop orders; ledger posting ([bills_pays](../bills_pays/spec.md)); no separate `recipient/` pack |

Customer ≠ recipient: group/wallet vs delivery name/phone/address. Invoice/dropship dialogs pick a recipient.

See [scopes](../../architecture/scopes.md).

## Personas

| Role | Actions |
| :--- | :--- |
| Sales ops admin | Groups, credit limits, members, billing |
| Desk staff | Search, dues, collect payment, store credit |
| Shop customer admin | Members, order history, checkout |
| Auditor | Credit ledger read-only |

## Stories

### US-1: Atomic customer provisioning
- One modal → group + profile + wallet account.
  - [ ] `create_customer_account`: `customer_groups`, profile (`billing_profiles` until [BP3](../bills_pays/00-gaps.md)), `wallet_accounts`.
  - [ ] Phone unique per books parent tenant.
  - [ ] Member login optional on create.

### US-2: Four-tab detail drawer
- General, Members, Account, Wallet Ledger.
  - [ ] General: company, accent, phone, email, billing address.
  - [ ] Members: storefront users (`admin`, `manager`, `staff`).
  - [ ] Account: dues vs store credit, open invoices, record payment.
  - [ ] Wallet Ledger: immutable transaction list.
