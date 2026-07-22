# Dropship Order Flow — Product Manager Review & Implementation Plan

## 1. Flow Verification: User (Middle Man) to Admin (Staff)

After auditing the actual frontend implementation (`DropshipOrderDetailPage.vue`, `ShopCheckoutPage.vue`) and backend migrations (`courier_services`), I can confirm that the foundation of the Dropship flow is already heavily implemented. The current system operates logically but contains a few critical friction points regarding financial consistency that exist in the codebase today:
1. **User Checkout**: Middle man provides full recipient details. A *provisional* COD fee is shown.
2. **Staff Processing**: Staff picks up the order in `DropshipOrderDetailPage.vue`, selects the actual courier, which triggers a reactive recalculation of `cod_charge` locking in the *exact* COD fee. Staff prints the customer invoice.
3. **Staff Dispatch**: Order is marked `ready_for_pickup`. The formal dual invoice is created, locking the books and calculating middle-man payout.
4. **Settlement**: After delivery, courier remits net amount to seller, and seller settles payout with middle man.
5. **Returns**: Failed deliveries incur return fees based on courier policy, which are debited from the middle man's ledger.

---

## 2. Identified Lackings & Breaking Points (Confirmed in Codebase)

### A. Provisional vs. Exact COD Discrepancy
**The Breaking Point**: At checkout, the middle man sees a provisional COD fee. During "Process Order", staff selects a courier (e.g., Pathao vs. Steadfast), which may change the COD fee.
**The Risk**: If the final `cod_collect_amount` printed on the customer invoice is higher than what the middle man communicated to the recipient, the recipient might refuse the parcel, causing a return and costing the middle man a return fee.
**Suggestion**: Allow the middle man to select their preferred courier during checkout so the COD fee is exact. Alternatively, if staff must pick the courier for ops reasons, the shop should charge a flat generic COD rate to the recipient, and the seller absorbs any minor variance against the actual courier's COD fee. 
*Why it's good*: Prevents recipient friction at the door and unfair return fees to the middle man.

### B. Partial Advance Payments
**The Breaking Point**: The document states: `If prepaid (cod_collect_amount = 0): skip courier COD fee`. It doesn't explicitly address *partial* prepaid orders (e.g., middle man pays 150 Tk advance delivery fee, rest is COD).
**The Risk**: The system might miscalculate the COD fee by applying the percentage against the *total* face value instead of the remaining *collectable* amount.
**Suggestion**: Explicitly define `cod_collect_amount = Total Face - Advance Payment`. The courier COD fee percentage MUST only apply to this remaining `cod_collect_amount`.

### C. Negative Ledger Risk on Returns
**The Breaking Point**: The document says negative middle-man balances are allowed and net against future payouts. 
**The Risk**: A malicious or struggling middle man could place fake/failed orders, rack up high `return_fee_uninvoiced` debits, and abandon the platform, leaving the seller to absorb the courier return costs.
**Suggestion**: Implement a credit limit or require a security deposit/wallet balance for dropship middle men before they can place COD orders.
*Why it's good*: Protects the platform from bad actors and cash flow loss.

### D. Invoice Print vs. Accounting Sync
**The Breaking Point**: Staff prints the Customer Invoice at `processing`, but the Accounting Invoice is created later at `ready_for_pickup`. 
**The Risk**: If staff edits the `cod_collect_amount` after printing the physical customer invoice but before hitting "Create Accounting Invoice", the books will mismatch the paper given to the courier.
**Suggestion**: Lock the consignment financial fields once the Customer Invoice is printed. If changes are needed, the staff must explicitly click "Void and Reprint".

---

## 3. What Needs to be Fixed to Ship ASAP (MVP Checklist)

Since the foundation is already implemented, the MVP effort should focus purely on fixing the financial integrity bugs identified above.

### Backend / RPCs (Bug Fixes)
- [ ] `update_dropship_consignment`: Update the COD calculation logic to subtract any partial advance payments from the `collectBase` before applying the COD percentage (fixes Breaking Point B).
- [ ] `submit_shop_order_from_cart`: Add a balance check or implement a dropship credit limit to prevent negative balance accumulation on returns (fixes Breaking Point C).

### Frontend UI (Bug Fixes)
- [ ] **Dropship Checkout (`ShopCheckoutPage.vue`)**: Show a prominent warning that the COD fee is a provisional estimate and may change based on the final courier selection, OR add a courier selector dropdown so the user can lock the COD fee upfront (fixes Breaking Point A).
- [ ] **Dropship Ops Desk (`DropshipOrderDetailPage.vue`)**: Lock the consignment financial inputs (like `cod_charge`) after the "Customer Invoice" is printed. Add a "Void & Reprint" action to unlock them (fixes Breaking Point D).
- [ ] **Dropship Ops Desk (`DropshipOrderDetailPage.vue`)**: Ensure `calculateCodCharge` correctly handles partial prepaid orders by factoring in `order.is_prepaid_snapshot` and advance amounts.

---

## 4. End-to-End Test Flow (Change Validation)

Execute this flow to verify the entire system change:

1. **Checkout**: As a middle man, place a dropship order. Ensure recipient name, phone, address, and district are mandatory.
2. **Process Desk**: As staff, open the order (`processing` status). 
3. **Courier Select**: Select *Pathao*. Verify the `cod_collect_amount` updates automatically based on Pathao's COD fee.
4. **Print**: Click "Download Customer Invoice". Verify the printed PDF matches the exact face amount + COD fee.
5. **Books Handoff**: Mark `ready_for_pickup`. Click "Create Accounting Invoice". 
6. **Verify Books**: Check `global_invoices` for dual amounts. Ensure seller accounting is correct (face - margin).
7. **Success Route**: Mark `shipped` -> `delivered`. Go to Ledger. Record courier remittance. Settle middle-man payout. Verify balances = 0.
8. **Failure Route**: Create a second order. Follow steps 1-5. Mark `returned`. Select "Pathao Outside Dhaka" (50% return fee). Verify the exact return fee is debited from the middle man's ledger as `return_fee_uninvoiced`.
