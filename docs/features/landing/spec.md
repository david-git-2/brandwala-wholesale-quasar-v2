# Landing — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/landing/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/landing/` |
| Copy | `web/src/modules/landing/content.ts` |
| SQL | n/a |
| State | static copy only |
| Access | public; no auth |

## Where to look

| Need | Path |
| :--- | :--- |
| Page / sections | `web/src/modules/landing/pages/LandingPage.vue`, `components/` |
| Route | `web/src/modules/landing/routes/index.ts` |
| Layout | `web/src/layouts/ExternalLayout.vue` |
| Login | `/app/login` (`admin-login-page`) |
| Contact CTA | `CONTACT_HREF` in `content.ts` (`TODO_CONTACT_LINK`) |
| How-to detail | `/help` (not on this page) |

## Scope

| | |
| :--- | :--- |
| Surfaces | Public web only |
| In | `/` hero, 5-step flow, who uses it, Sign in, Request access, links to `/help` |
| Out | Feature manuals, company modes table, help articles, OAuth, signup, platform login |

## What / who

Visitors who are not logged in. Page answers: shipment → warehouse → sell → cash, then Sign in or Request access. How-to lives in Help.

## Rules

- No backend. Copy lives in `content.ts`.
- Do not duplicate Help topics (landed cost lock, bins, PBC, remittance, modes).
- Colors from app theme tokens. One illustrative UI fragment in the hero.

## Stories

### US-1 Understand the product
- Visitor sees hero, flow, who uses it.
  - [x] Sections render on `/`

### US-2 Sign in
- Visitor clicks Sign in → `/app/login`.
  - [x] `admin-login-page`

### US-3 Help
- Visitor opens help from header, flow hint, CTA, or footer → `/help`.
  - [x] `help-home` route loads
