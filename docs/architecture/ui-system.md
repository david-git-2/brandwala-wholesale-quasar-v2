# Architecture: UI Layout & Table Design System

This specification enforces visual and operational consistency across all administrative, operational, and financial dashboards in TradeFlow BD.

---

## 🎨 Core Layout Rules

### 1. Zero In-Page Headers
- Never render redundant in-page `<h1>` or `text-overline` header banners.
- Global breadcrumbs in the top navigation bar communicate the page title and hierarchy.
- Move primary action buttons (e.g. `+ New Invoice`, `Export CSV`) directly into the compact table toolbar.

### 2. Locked Height Container
- Lock `q-page` height to `calc(100vh - 55px)` with `overflow: hidden`.
- No page-level body scrollbars.

### 3. Internal Table Scroll
- Use sticky headers on tables (`thead tr th`).
- Scroll internally within `.q-table__middle { overflow-y: auto }`.

### 4. Status Row Hues & Borders
- Apply soft background tints for status states (`bg-amber-1`, `bg-emerald-1`, `bg-rose-1`).
- Inset left accent border on rows: `box-shadow: inset 3px 0 0 <color>`.

### 5. Controls & Styling Tokens
- **Buttons**: Rounded square corners (`border-radius: 8px`), NEVER pill shapes.
- **Search Inputs**: Outlined, rounded, dense (`outlined rounded dense`).
- **Entity Avatars**: Neutral grey tones (`color="grey-3" text-color="grey-9"`).
- **Surfaces**: Flat table surfaces without stacked heavy elevation cards.
