# Cloudflare Pages — `frontend:prod`

Deploy the Quasar SPA from the repo root:

```bash
pnpm run frontend:prod
```

Runs `scripts/deploy-frontend.sh`: switches to prod env (`web/.env` ← `web/.env.profile.prod`), installs, builds `web/dist/spa`, uploads with Wrangler.

## Env (`web/.env.profile.prod`, gitignored)

| Variable | Role |
| :--- | :--- |
| `CF_PAGES_PROJECT_NAME` | Cloudflare Pages project name (or pass as arg: `pnpm run frontend:prod -- my-project`). |
| `CLOUDFLARE_API_TOKEN` | **Required** in Cursor, CI, and other **non-TTY** shells. Wrangler cannot use OAuth-only auth there. [Create token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) — template or custom with **Cloudflare Pages → Edit** (scoped to the right account). |
| `CLOUDFLARE_ACCOUNT_ID` | **Often required** if the token is Pages-only: `wrangler whoami` / account listing can fail with “retrieve account IDs”. Dashboard → **Workers & Pages** → select account → **Account ID** (sidebar). |
| `CF_API_TOKEN` | Wrangler accepts this name too; same value as `CLOUDFLARE_API_TOKEN`. |

Optional: `CF_PAGES_DEPLOY_RETRIES`, `CF_PAGES_SKIP_CACHING`, `CF_WRANGLER_WHOAMI_TIMEOUT_SECONDS` — see `scripts/deploy-frontend.sh`.

## Auth choices

| Situation | What to do |
| :--- | :--- |
| Normal macOS Terminal, interactive | `wrangler login` once may work; token still recommended for repeatability. |
| Cursor / IDE integrated terminal | Set **`CLOUDFLARE_API_TOKEN`** (and usually **`CLOUDFLARE_ACCOUNT_ID`**) in `web/.env.profile.prod`. |
| Token + “account IDs” / whoami errors | Add **`CLOUDFLARE_ACCOUNT_ID`**, or broaden the token with **Account → Account Settings → Read**. |

After deploy, switch back to local Supabase with `pnpm run env:local` before `pnpm run dev`.
