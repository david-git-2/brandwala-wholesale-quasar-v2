# Customer Hub — Product Requirements Document (PRD)

> **Module**: Customer Groups, Billing Profiles & B2B Identity  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Account Managers, Sales Operations Staff, Desk Clerks, Customer Admins

---

## 1. Executive Summary

The **Customer Hub** module provides centralized identity, customer grouping, billing accounts, storefront buyer login management, and credit ledgers for B2B buyer organizations.

Customer accounts are consolidated under the **Parent Books Tenant** (`customer_groups.parent_tenant_id`). When a new customer account is created, the system executes an atomic transaction creating the customer group, linking a billing profile, and initializing a universal wallet account.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Sales Operations Admin** | Full Access | Create customer groups, assign credit limits, add/edit buyer members, configure billing details, soft-delete groups. |
| **Desk Sales Staff** | Operational | Search customer accounts by name/phone, view open dues, collect invoice payments, record store credit. |
| **Storefront Customer Admin** | External Buyer | Manage organization buyer members, view company order history, submit checkout orders. |
| **Auditor** | Read Only | View customer credit ledger history, inspect credit limits and overdue aging. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Atomic Customer Account Provisioning
- **As a** Sales Operations Clerk  
- **I want to** enter a customer company name and verified primary phone number in a quick modal dialog  
- **So that** a Customer Group, Billing Profile, and Customer Universal Wallet are provisioned in a single atomic transaction.

#### Acceptance Criteria
- [ ] Submitting the modal invokes `create_customer_account` creating `customer_groups`, `billing_profiles`, and `wallet_accounts`.
- [ ] Phone numbers are strictly unique per books parent tenant (`parent_tenant_id + phone_country_code + phone`).
- [ ] No initial member login row is required on create (added optionally via the Members drawer).

### US-2: 4-Tab Customer Detail Drawer
- **As an** Account Manager  
- **I want to** click a customer row in the hub table and open a right-side drawer with 4 dedicated tabs (`General`, `Members`, `Account`, `Wallet Ledger`)  
- **So that** I can manage company info, storefront logins, invoice dues, and store credit transactions in one place.

#### Acceptance Criteria
- [ ] **General Tab**: Edit company name, brand accent color, contact phone, email, and billing address.
- [ ] **Members Tab**: Manage storefront login users with roles (`admin`, `manager`, `staff`).
- [ ] **Account Tab**: View real-time Invoice Dues vs Customer Store Credit, open invoices table, and record payment.
- [ ] **Wallet Ledger Tab**: View full chronological, immutable transaction ledger.

---

## 4. UI Layout & Wireframe

### Customer Hub Directory Screen

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Customers > Directory Hub                                                       |
+----------------------------------------------------------------------------------------------------+
| [ Search company name, phone, email... ] [ Filter: Active v ]                [ + Create Customer ] |
+----------------------------------------------------------------------------------------------------+
| COMPANY / GROUP        | PHONE / CONTACT    | ACTIVE SHOPS | OPEN DUE (BDT)  | STORE CREDIT (BDT)  |
|------------------------+--------------------+--------------+-----------------+---------------------|
| Metro Mega Mart (Dhan) | +880 1711-223344   | 3 Shops      | 145,000.00 BDT  | 45,000.00 BDT       |
| Apex Retailers Ctg     | +880 1822-334455   | 1 Shop       | 38,500.00 BDT   | 0.00 BDT            |
| Sylhet Fashion House   | +880 1933-445566   | 2 Shops      | 0.00 BDT        | 12,400.00 BDT       |
+----------------------------------------------------------------------------------------------------+
| Pagination: 1 - 25 of 180 Customer Groups                                                          |
+----------------------------------------------------------------------------------------------------+
```
