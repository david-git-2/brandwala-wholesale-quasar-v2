# Tenant Module

This module follows the same page -> store -> service -> repository pattern as the example module.

## Folder Pattern

```text
src/modules/tenant/
  pages/
  repositories/
  routes/
  services/
  stores/
  types/
```

## Flow

1. Page calls the store action
2. Store calls the service
3. Service calls the repository
4. Repository performs the raw Supabase query
