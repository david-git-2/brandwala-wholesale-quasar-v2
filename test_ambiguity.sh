#!/bin/bash
for file in supabase/migrations/*.sql; do
  awk '/returns table/,/^as \$\$/ {print}' "$file" | grep -q "tenant_id.*bigint"
  if [ $? -eq 0 ]; then
    grep -H -n -E "select tenant_id into v_tenant_id" "$file"
  fi
done
