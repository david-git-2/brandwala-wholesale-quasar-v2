# Operating manual (repo index)

Staff procedures: what to do in the app, step by step. Not build specs.

| | |
| :--- | :--- |
| **Live UI** | `/operating-manual` — markdown in `web/src/modules/operating_manual/content/md/` |
| **Platform concepts** | `/docs` — kernels, modules, scopes |
| **Agent specs** | `docs/features/<module>/spec.md` — do not paste procedures here |

Add new manual chapters: new `.md` under `web/src/modules/operating_manual/content/md/`, route in `web/src/modules/operating_manual/routes/index.ts`, row in `content/nav.ts`.

**Agents:** skip this tree unless the user explicitly asks for operating-manual work (see `.cursor/rules/docs-first.mdc` §3).
