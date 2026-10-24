# Portfolio & naming (TradeFlow BD)

Showcase notes. Product truth for builders: `docs/README.md`.

**Line:** TradeFlow is sell modules on four kernels. Each module is a full job. Together they keep sales, cash, COD, and stock aligned.

---

## What to call what

| Say this | Means | Examples | Do not call it |
| :--- | :--- | :--- | :--- |
| **Platform** | Whole company system | TradeFlow BD | A kernel |
| **Kernel** | Shared engine others must call | Money, warehouse, landed cost, access | Dropship, dashboard |
| **Module** (sales: **product**) | Full job a tenant can turn on | Wholesale, dropship, PBC, thrift | Kernel |
| **Adapter / plug-in** | Module writing into a kernel | Shipment AP, dropship ship, Delivery close | Second invoice product |
| **Channel** | How BW sells the same warehouse | Walk-in, take/condition, dropship | A fourth company type |
| **Sales model** | Which stock world | BW, pre-order, K-beauty, thrift | Mix `global_stocks` with `koba_*` / `thrift_*` |
| **Desk** | Screen | Bills, Payments, Cashbook | The kernel |
| **Scope** | Login surface | platform, app, shop, investor | Job title |

**Kernels (exactly four)**

1. **Money** — profile, bill, pay, leftover cashbook  
2. **Warehouse** — parent lots, movements, ATP  
3. **Landed cost** — shipment buckets, lock, FX from pays  
4. **Access** — parent/child tenants, grants, four logins  

Do not call the whole catalogue “kernels.” Buyers hear plumbing. Do not call everything “feature.” Sounds like checkboxes.

**Not showcase products:** notifications, dashboard, landing, PC upload, trash, settings. Supporting services.

---

## Scopes (four logins)

Scopes are **login surfaces**, not job titles. They prove tenant + multi-shop: same company, different doors. Full matrix: `docs/architecture/scopes.md`.

| Scope | URL | Who | Does |
| :--- | :--- | :--- | :--- |
| `platform` | `/auth/platform/login` → `/platform/*` | Superadmin | Tenants, module catalog, global reference |
| `app` | `/:slug/app/*` | Tenant staff | ERP. Grants via `effectiveGrants` |
| `shop` | `/:slug/shop/*` or custom host | Buyer / reseller | Storefront, cart, own orders |
| `investor` | `/:slug/investor/*` | Capital partner | Read-only statements. No withdraw |

**Showcase × surface**

| Showcase | platform | app | shop | investor |
| :--- | :---: | :---: | :---: | :---: |
| Tenant-based | provision | staff, grants, child brands | login | login |
| Multi-shop | — | shop config, pricing, dropship desk | catalog, cart, orders | — |
| Wholesale | — | compose, issue, collect | — | — |
| Dropship | — | pick, ship, settlement | reseller cart + orders | — |
| Inbound shipment | — | shipments, bins, lock | — | — |
| Money | — | bills, payments, cashbook | merchant statement | — |
| Product-based costing | — | costing files, demand | — | — |

Shop and investor never get warehouse bins, landed-cost lock, or platform tenant provision.

On the hero: **four doors, one parent books.** That is the access kernel, not a fifth sell module.

---

## Showcase this set (all seven)

Length was the only reason to cut to three. Value-wise this is the catalogue.

| You named | Standalone job | Impact line |
| :--- | :--- | :--- |
| **Wholesale** | Sell goods in hand: take, condition, walk-in | Unpaid condition is not sales; leftover is not a fake invoice |
| **Dropship** | Reseller ships to a recipient | Merchant total is sales; COD face is not |
| **Inbound shipment** | Land a container onto lots | Unit cost from pays + lock; no mixed-currency AP |
| **Money** | One books for every channel | Modules do not own cash; notes after issue, not silent edits |
| **Tenant-based** | Parent company + child brands | Child cannot invent its own warehouse or books |
| **Multi-shop** | Several shops, several rules | One listing; price/visibility per shop and group |
| **Product-based costing** | Sell before goods land | Confirmed quote is demand, not on-hand stock |

**Layering**

- Platform: **tenant** + **multi-shop**  
- Sell / ops: **wholesale**, **dropship**, **PBC**, **inbound**  
- Glue: **money** (everything plugs in)

K-beauty and thrift are extra sell models (own stock tables). Optional fourth story if you want “many products, same login.” Skip in the main strip unless the audience cares.

---

## How to show it

**Hero (1 screen):** one company, several ways to sell, one books.

```text
Four logins: platform | app | shop | investor
Tenant company → many shops
  Wholesale / Dropship / Pre-order (PBC)
  Inbound fills the warehouse
  Everything posts to money
```

**Full VPC + impact + 1–2 screens (four):** Dropship, Wholesale, Inbound, then **Money** *or* **PBC** (money if finance/backend audience; PBC if product uniqueness).

**Short cards (the rest of the seven):** who / job / one pain. Tenant and multi-shop stay on the page as platform, not extra sell modes.

**Do not** put a VPC on dashboard, tags, or notifications.

### VPC boxes (same layout every time)

One canvas per full story. One extra canvas for the **whole platform**. One primary customer per canvas.

| Box | What to write |
| :--- | :--- |
| Customer | Who you chose |
| Jobs | Task they must finish |
| Pains | Error, bottleneck, money lie |
| Gains | Speed, visibility, trust |
| Pain relievers | Rule you enforced |
| Gain creators | Desk / flow |
| Products | Module **plugging** which kernel |

Max **3 bullets, ~8 words** per box.

**Platform canvas:** owner. Job = wholesale + dropship + pre-order without three books. Pain = COD as revenue; child oversells; cost edited after lock. Product = four kernels + modules on/off.

**Dropship example**

| Box | Content |
| :--- | :--- |
| Customer | Reseller (primary); picker secondary |
| Jobs | Sell parent stock to a recipient; take profit after courier pays |
| Pains | COD counted as their bill; packing slip as invoice; profit as a second invoice |
| Gains | B2B due vs leftover; ship without oversell |
| Relievers | Bill at ship = merchant total; remittance = net bank in; leftover = cashbook |
| Creators | Pick → ship+issue both papers; notes if amounts change |
| Product | Dropship shop + settlement desk → money kernel |

Worked numbers (from money-story): merchant **1,500**, COD **2,200**, courier **80**, bank **2,120**, leftover **620**.

### Impact without fake KPIs

Do not invent “cut close time 40%.” Use **risk removed**.

| Type | What to write |
| :--- | :--- |
| Error that used to happen | COD booked as sales |
| Rule that stops it | Sales = merchant bill at ship |
| Who is faster | One remittance writer |
| Break if this were a separate SaaS | Leftover ≠ invoice due |

---

## Other docs you can make (not this file)

Keep as-built specs in `docs/features/<module>/spec.md`. Do not clone them.

| Doc | Audience | Job |
| :--- | :--- | :--- |
| Platform one-pager | Owner / sales | Whole > parts |
| Module catalogue | Same | One card per module |
| VPC pack | Product / sales | Canvases above |
| Kernel brief (4 short pages) | Architect | Invariants |
| Money story | Finance / impl | Already: `docs/features/bills_pays/money-story.md` |
| Adapter map | Architect | `source_type` / from / to |
| Scopes matrix | Anyone | Already: `docs/architecture/scopes.md` |
| Sales-model sheet | Product | Already: `docs/architecture/business-models.md` |

If you only make three: one-pager, catalogue, VPC pack.

---

## Page order

1. Hero + four scopes + kernel diagram  
2. Dropship (VPC + money table + screens)  
3. Wholesale  
4. Inbound shipment  
5. Money or PBC (full)  
6. Strip of all seven  
7. Your role vs still-open gaps (credit-note desk, pay reverse) — honesty reads as seniority  
