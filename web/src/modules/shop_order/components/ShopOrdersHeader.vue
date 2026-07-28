<template>
  <section class="row items-center justify-between q-col-gutter-md">
    <div class="col">
      <div class="text-overline text-primary">{{ $t('shop_admin.shop_and_order') }}</div>
      <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('shop_admin.shop_orders_title') }}</h1>
      <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
        {{ $t('shop_admin.shop_orders_subtitle') }}
      </p>
    </div>
    <div class="col-auto row q-gutter-sm">
      <q-btn
        outline
        color="primary"
        icon="ph ph-truck"
        label="Dropship Ops Desk"
        no-caps
        :to="{ name: 'app-shop-dropship-orders-page' }"
      />
    </div>
  </section>
</template>

<script setup lang="ts">
// Header component for Shop Orders page
</script>
