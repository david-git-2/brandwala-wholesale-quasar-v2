<template>
  <AuthLoginPanel
    scope="shop"
    eyebrow="Customer Entry"
    title="Open the ordering portal"
    description="Sign in with the Google account that belongs to your customer organization to build carts, confirm orders, and handle negotiation."
    cta-label="Sign in to shop"
    support-text="Customer access is validated through customer-group membership for the shop scope."
    :notes="notes"
    tone="shop"
  />
</template>

<script setup lang="ts">
import AuthLoginPanel from '../components/AuthLoginPanel.vue'

const notes = [
  'Customer staff can build carts and prepare orders.',
  'Negotiators and customer admins confirm the next step.',
  'Internal tenant users need customer-group membership to enter the shop area.',
]
</script>
