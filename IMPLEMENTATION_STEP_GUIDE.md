# Costing File Implementation Steps

This guide is now focused only on the first functional version of the `Costing File` module.

Use this file as the execution checklist for the mock-first build.

Use [COSTING_FILE_MODULE_SPEC.md](/Users/david/Desktop/projects/group/brandwala-wholesale-quasar-v2/COSTING_FILE_MODULE_SPEC.md) as the feature source of truth.

## Goal

Build a first mock but functional version of the module with three role views:

- admin page
- staff page
- customer page

This first version should focus on flow and usability first.

The UI does not need final polish yet.

## Working Rule

Do the work in small passes:

1. build one step
2. verify the step works
3. move to the next step

## Step 1. Define The Three Pages

Goal:

Set the initial page structure for the three role experiences.

Scope:

- define one admin page
- define one staff page
- define one customer page
- map the main actions each page needs
- keep the layout simple and functional

Expected result:

- admin page clearly supports file setup, pricing, and offer actions
- staff page clearly supports enrichment actions only
- customer page clearly supports request submission and buyer profit usage

## Step 2. Build A Mock Functional Flow

Goal:

Create a first working UI flow without worrying about final design polish.

Scope:

- show costing file header and status
- show costing file items list
- allow customer-side request entry:
  - website URL
  - quantity
- allow staff-side enrichment entry:
  - name
  - image URL
  - product weight
  - package weight
  - web price GBP
  - delivery price GBP
- allow admin-side pricing controls:
  - conversion rate
  - cargo rate 1 KG
  - cargo rate 2 KG
  - admin profit rate
  - offer price override
- show calculated values in the UI

Expected result:

- all three pages can be used to walk through the full costing-file flow
- the interface is usable even if visual design is still basic

## Step 3. Add Role Behavior Rules

Goal:

Make each page behave according to the confirmed permission rules.

Scope:

- customer can create item request rows
- customer cannot edit submitted link and quantity later
- customer can edit buyer profit rate later
- staff can edit only enrichment fields
- admin can edit all fields and workflow state
- item status supports:
  - pending
  - accepted
  - rejected

Expected result:

- each page exposes only the actions that role should have
- workflow feels correct even in the first mock

## Step 4. Plug In Centralized Calculations

Goal:

Use one separate JavaScript calculation file for all pricing logic.

Scope:

- calculate total weight dynamically
- calculate auxiliary price GBP
- calculate item price GBP
- select cargo rate dynamically
- calculate costing price GBP
- calculate costing price BDT
- calculate offer price BDT
- calculate buyer sell price
- apply GBP decimal rules
- apply BDT round-up-to-0-or-5 rules

Expected result:

- pricing stays consistent across admin, staff, and customer pages
- UI does not duplicate formula logic

## Step 5. Verify The End-To-End Mock

Goal:

Confirm the first mock version supports the full intended flow.

Verify:

- admin can create a costing file
- customer can add item requests
- staff can enrich item data
- admin can enter pricing inputs and finalize offer
- customer can enter buyer profit rate later
- calculated fields update correctly
- role restrictions behave correctly

Expected result:

- the module is ready for UI refinement and adjustment
- next pass can focus on layout, styling, and UX improvements
