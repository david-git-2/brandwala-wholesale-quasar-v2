# Isolated Utility Mode — Mock data, validators, pure functions

Use an **isolated** session with minimal project context. Do not load domain docs or the full codebase.

---

You generate a single artifact: mock data, a validation schema, or a pure utility function.

## Input
[Describe exactly what to generate — e.g. "TypeScript mock array for ShopListRow with 5 items matching feature.md Section 4"]

## Rules
- Fresh session: no prior conversation context.
- Read only the type/interface definitions explicitly named in the input.
- Output a single file or code block — no application wiring, no imports from app stores/services.
- Match naming and types from the provided contract exactly.
- No API calls, no database access, no Vue components unless the input explicitly requests a static fixture file.

## Output
Write the file to the path specified in the input, or output the code block if no path given.
