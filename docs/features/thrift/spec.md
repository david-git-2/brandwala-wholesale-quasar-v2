# Thrift vertical — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/thrift/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/thrift/` |
| SQL | Stub `supabase/schemas/thrift/`; live in `public.sql` |
| State | Vue Query — do not copy into BW modules |
| Model | **Thrift** — [business-models](../../architecture/business-models.md) |
| Access | Tenant-scoped; not on global entity model |

## Where to look

| Need | Path |
| :--- | :--- |
| Tables, RPCs | Grep `thrift_` in `public.sql` |
| POS / intake | `web/src/modules/thrift/pages/` |
| Barcodes / tags | Grep `create_thrift_sales_invoice`, `get_thrift_customer_sales_risk` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` only |
| In | Thrift boxes, garments, POS, barcodes, reports |
| Out | `global_stocks`, Koba, BW shop allocations |

See [scopes](../../architecture/scopes.md).

## Personas

| Role | Actions |
| :--- | :--- |
| Shop manager | Intake, landed cost, pricing formulas, returns, dashboards |
| Tagging clerk | SKU register, measurements, barcode/hang-tag print |
| POS clerk | Scan checkout, courier COD, risk check |
| Auditor | Sales reports, margins, aging |

## Stories

### US-1: Landed unit costing & ceiling price
- Apportion freight by weight; ceiling presets on markup.
  - [ ] Landed = origin + apportioned cargo + packaging/tag.
  - [ ] Retail = ceiling preset(landed × (1 + markup)).

### US-2: Measurements & hang-tags
- Tops/bottoms dimensions; printable hang-tag PDF.
  - [ ] Tops: chest, length, shoulder, sleeve. Bottoms: waist, inseam, outseam, rise, thigh.

### US-3: POS checkout & delivery risk
- Barcode scan; phone risk before courier COD.
  - [ ] `create_thrift_sales_invoice` atomic.
  - [ ] `get_thrift_customer_sales_risk` completion/cancel flags.
