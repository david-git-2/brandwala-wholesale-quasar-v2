# Supabase Migration Workflow

This project is configured so backend schema changes can be deployed with:

```bash
npm run deploy:backend
```

## One-time setup

1. Login to Supabase CLI:

```bash
npm run backend:login
```

2. Link this project to your Supabase project:

```bash
export SUPABASE_PROJECT_REF=your_project_ref
npm run backend:link
```

Use the real Supabase **Project Reference ID** (20 lowercase chars), for example:

```bash
export SUPABASE_PROJECT_REF=pqlmomdpuiajhfwwfoqw
```

## Daily workflow

1. Add/update SQL migration files in `supabase/migrations`.
2. Run:

```bash
npm run deploy:backend
```

`deploy:backend` does:
- `backend:push` -> applies pending migrations to the linked remote project
- `backend:types` -> regenerates TypeScript DB types to `web/src/types/supabase.ts`

## Module Catalog Seed

The MVP module catalog is seeded through migrations, not through a separate script.

Current seeded keys:

- `order_management`
- `shipment`
- `inventory`
- `shop_costing_file`
- `costing_file`
- `accounting`
- `invoice`

The seed migration is idempotent, so rerunning migrations updates the canonical name/description/active state for those keys without creating duplicates.

## Extra scripts

- `npm run backend:push` (only apply migrations)
- `npm run backend:types` (only regenerate DB types)

## Troubleshooting

### Error: `Cannot find project ref. Have you run supabase link?`

Run:

```bash
npm run backend:login
export SUPABASE_PROJECT_REF=your_project_ref
npm run backend:link
```

Then run:

```bash
npm run deploy:backend
```

### Error: `Invalid project ref format. Must be like abcdefghijklmnopqrst`

You are using a placeholder (like `your_project_ref`) or a wrong value.
Use the real **Project Reference ID** from:

Supabase Dashboard -> Project Settings -> General -> Reference ID

### `.env` has `SUPABASE_PROJECT_REF` but script still fails

Shell variables from `.env` are not always auto-loaded for npm scripts.
Either export manually:

```bash
export SUPABASE_PROJECT_REF=your_project_ref
```

or load env first:

```bash
source .env
```

then run:

```bash
npm run backend:link
npm run deploy:backend
```

### `backend:types` seems stuck at `Initialising login role...`

Wait ~1 minute first. If needed, rerun with debug:

```bash
npx supabase gen types typescript --linked --schema public --debug > web/src/types/supabase.ts
```

Then verify file was generated:

```bash
ls -lah web/src/types/supabase.ts
```
