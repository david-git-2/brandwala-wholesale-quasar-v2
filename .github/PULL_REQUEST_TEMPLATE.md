## Description
Please include a summary of the change and which issue is fixed. Please also include relevant motivation and context.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Code style update (formatting, local variables)
- [ ] Refactoring (no functional changes, no api changes)
- [ ] Performance improvements

## Performance Checklist
Before submitting this PR, please ensure the following performance guidelines are met:
- [ ] **No new `backdrop-filter` on static surfaces**: Do not use `backdrop-filter` on static headers, cards, toolbars, etc. Opaque surfaces should be preferred for rendering performance.
- [ ] **No `listShipmentItems` inside loops**: Use the batch shipment costing cache (`useShipmentItemsCostingCache` or `listShipmentItemsBatch`) instead of calling the single-item service in loops or lists.
- [ ] **Prefer `skip_count` on search/list pages**: Ensure pagination queries on large datasets (such as stock lists) pass `skip_count: true` to avoid duplicate count queries.
