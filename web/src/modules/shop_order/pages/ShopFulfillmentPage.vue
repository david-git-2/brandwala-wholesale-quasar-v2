<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">{{ $t('shop_admin.shop_and_order') }}</div>
          <h1 class="text-h5 q-my-none">{{ $t('navigation.fulfillment') }}</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            {{ $t('shop_admin.fulfillment_subtitle') }}
          </p>
        </div>
      </section>

      <q-card flat bordered>
        <q-card-section class="text-grey-7">
          {{ $t('shop_admin.fulfillment_coming_soon') }}
        </q-card-section>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
// shop_fulfillment — placeholder (P1). Full UI arrives in P8.
</script>
