# Design colors

> **Source of truth:** `web/src/css/app.scss`; do not hand-edit this file. Regenerate from tokens when `app.scss` changes.

## Global rules

- Never use color alone for state: pair success/warning/error/info with an icon and text.
- Primary color = actions only. It is never a state color.
- `--tf-neutral-chrome` is decorative only (borders, icons). Use `--tf-neutral-chrome-text` for overlines and headers.
- Components use tokens or Quasar color names (`primary`, `positive`, `negative`, `warning`, `info`, `neutral`), never raw hex.

## Quasar brand mapping (every scope, light + dark)

| Quasar var | Maps to |
|------------|---------|
| `--q-primary` | `--tf-theme-primary` |
| `--q-primary-text-on` | `--tf-theme-on-primary` |
| `--q-secondary` | `--tf-neutral-muted` |
| `--q-accent` | scope decorative accent |
| `--q-positive` | `--tf-success` |
| `--q-negative` | `--tf-error` |
| `--q-warning` | `--tf-warning` |
| `--q-info` | `--tf-info` |
| `--q-neutral` | `--tf-neutral-ink` |
| `--q-dark` | `#18181b` |
| `--q-dark-page` | `#09090b` |

Scope accents: platform → mint; app → tide; shop → sky; investor → coral.

## Neutrals

| Token | Light | Dark |
|-------|-------|------|
| `--tf-neutral-canvas` | `#f4f6f8` | `#09090b` |
| `--tf-neutral-surface` | `#ffffff` | `#18181b` |
| `--tf-neutral-border` | `#e2e8f0` | `#27272a` |
| `--tf-neutral-border-strong` | `#cbd5e1` | `#3f3f46` |
| `--tf-neutral-ink` | `#0f172a` | `#f4f4f5` |
| `--tf-neutral-muted` | `#475569` | `#a1a1aa` |
| `--tf-neutral-chrome` | `#94a3b8` | `#71717a` |
| `--tf-neutral-chrome-text` | `#5b6b80` | `#8b8b94` |
| `--tf-disabled-bg` | `#eef1f5` | `#1f1f23` |
| `--tf-disabled-ink` | `#94a3b8` | `#71717a` |

## Semantic

| Token | Light | Dark |
|-------|-------|------|
| `--tf-success` | `#15803d` | `#4ade80` |
| `--tf-warning` | `#b45309` | `#fbbf24` |
| `--tf-error` | `#b91c1c` | `#f87171` |
| `--tf-info` | `#0e7490` | `#22d3ee` |

Soft tints: light 12% / dark 18% `color-mix` on surface. Badges, banners, and toasts use tint + icon + text only (no side accent bar).

## Focus

`--tf-focus-ring: 0 0 0 3px rgb(var(--tf-theme-primary-rgb) / 0.35)` on `:focus-visible` (2px offset).

## Radius

| Token | Value | Use |
|-------|-------|-----|
| `--tf-radius-sm` | 8px | buttons, inputs, chips |
| `--tf-radius-md` | 12px | cards, dialogs |
| `--tf-radius-pill` | 999px | shop CTAs only |

## `.theme-platform`

| Token | Light | Dark |
|-------|-------|------|
| primary | `#464b71` | `#9aa0d6` |
| primary-hover | `#3a3f5f` | `#b3b8e6` |
| primary-active | `#30344f` | `#c8ccf0` |
| on-primary | `#ffffff` | `#0f1020` |
| primary-soft | color-mix mint 40% / 16% | surface |
| paper | `#f2f2ed` | canvas |
| accent-mint | `#7cd5c7` | `#5fb8aa` |
| accent-blue | `#0b7a9e` | `#38bdf8` |

## `.theme-app`

| Token | Light | Dark |
|-------|-------|------|
| primary | `#0d6b5c` | `#4db8a4` |
| primary-hover | `#0a574b` | `#6cc9b6` |
| primary-active | `#084539` | `#8bd8c8` |
| on-primary | `#ffffff` | `#04211c` |
| primary-soft | rgb teal 8% / 16% | |
| paper | `#faf9f9` | canvas |
| wash | `#add2c9` | `#1c3a35` |
| tide (accent) | `#5ea3a3` | `#4c8a8a` |
| lagoon | `#488b8f` | `#5aa3a8` |

## `.theme-shop`

| Token | Light | Dark |
|-------|-------|------|
| primary | `#3368a0` | `#7fb0e0` |
| primary-hover | `#2a5887` | `#9bc2ea` |
| primary-active | `#224a73` | `#b5d2f0` |
| on-primary | `#ffffff` | `#0b1b2e` |
| primary-soft | color-mix mint 60% / blue 16% | surface |
| paper / clay | `#f2efe7` | canvas |
| mint / mauve | `#c8dfdb` | `#223a36` |
| sky (accent) | `#66a3bf` | `#5a93ae` |

## `.theme-investor`

| Token | Light | Dark |
|-------|-------|------|
| primary | `#9a3b2a` | `#f0917d` |
| primary-hover | `#82301f` | `#f4a897` |
| primary-active | `#6c2619` | `#f7bdb0` |
| on-primary | `#ffffff` | `#2a0f0a` |
| primary-soft | color-mix paper 72% / coral 16% | surface |
| paper | `#f5ebdd` | canvas |
| umber | `#413333` | `#e8dcd6` |
| coral (accent) | `#f2765e` | `#f0917d` |
| navy | `#315b8c` | `#8fb4e3` |

## Ops table column hues (ops only)

| Column | Fill L | Accent L | Fill D | Accent D |
|--------|--------|----------|--------|----------|
| Weight | `#e8d7f7` | `#9333ea` | `#2e1f45` | `#c084fc` |
| Price | `#daf3e4` | `#047857` | `#123524` | `#34d399` |
| Cost | `#ffe8d1` | `#c2410c` | `#3d2412` | `#fb923c` |
| Qty | `#d0e6ff` | `#2563eb` | `#12284a` | `#60a5fa` |

Ink on fills: `--tf-neutral-ink`.

## Data viz (`--tf-viz-1` … `--tf-viz-6`)

| # | Light | Dark |
|---|-------|------|
| 1 | `#0072B2` | `#56B4E9` |
| 2 | `#E69F00` | `#F5B63A` |
| 3 | `#009E73` | `#2FC79A` |
| 4 | `#CC79A7` | `#DB92BC` |
| 5 | `#56B4E9` | `#8FCBF0` |
| 6 | `#D55E00` | `#F08440` |

Charts only — not success/warning/error.

## Wrappers

| Component | Path |
|-----------|------|
| Buttons | `web/src/components/ui/TfBtn.vue` |
| Status | `web/src/components/ui/TfStatusBadge.vue` |
| Confirm | `web/src/components/ui/TfConfirmDialog.vue` |
| Notify | `web/src/composables/useNotify.ts` |

## Checks

- `pnpm --filter web check:contrast` — WCAG text pairs (build gate).
- `pnpm --filter web check:ui-colors` — hex / palette / button hygiene (report).
