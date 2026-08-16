# Shop create — name + type, then setup page

Create Shop dumped type, order mode, currencies, vendors, markup, and charges in one dialog. Labels like Buy / Sell Currency looked like product prices. Presets duplicated type/mode fields.

## Locked UX

1. **Create dialog** — shop name + one of three types. Saves as **draft**. Slug from name. Type immutable.
2. **Setup page** — `/app/shop/shops/:id/setup`. **Make public** requires vendor (catalog) and currencies. Help ("I") lives here.
3. Letter scenarios A–F stay in Help / §3.6. They are not create chips.

## Currency labels

| Column | UI label | Role |
|--------|----------|------|
| `buy_currency_id` | Cost currency | Supplier origin cost (back office) |
| `sell_currency_id` | Checkout currency | Customer-facing list / cart / negotiate |

Create defaults to **draft**. Vendor is required only when making a catalog shop **public**.

## Files

- `ShopFormDialog.vue` — create only
- `ShopSettingsPage.vue` — setup
- Domain: [SHOP_ORDER.md](../shop_order/SHOP_ORDER.md) §3.0
