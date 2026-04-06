# Costing File Documentation

This folder explains the costing file feature in a human-readable way.
It is meant to help developers, reviewers, and AI assistants understand the data model, workflow, and access rules without reading every migration file.

## Files

- `costing-file-structure.md`: tables, fields, statuses, and frontend flow
- `costing-file-rls.md`: row-level security rules, RPC access rules, and actor permissions

## Quick mental model

1. A `costing_file` is the parent record.
2. A `costing_file_item` belongs to one costing file.
3. Customers can create draft files and, when allowed, add/remove their own draft items.
4. Staff and admins can enrich pricing fields and move files through the review flow.
5. Once a file reaches `offered`, customers can review the offer and make decisions on items.
