<template>
  <div class="q-gutter-y-md">
    <q-skeleton type="rect" height="70px" class="shop-home-skeleton-card" />

    <div class="row q-col-gutter-sm">
      <div v-for="n in 3" :key="`kpi-${n}`" class="col-4">
        <q-skeleton type="rect" height="72px" class="shop-home-skeleton-card" />
      </div>
    </div>

    <div class="row q-col-gutter-sm">
      <div v-for="n in 2" :key="`shop-${n}`" class="col-12 col-sm-6">
        <q-skeleton type="rect" height="108px" class="shop-home-skeleton-card" />
      </div>
    </div>

    <q-skeleton type="rect" height="320px" class="shop-home-skeleton-card" />
  </div>
</template>

<style scoped>
.shop-home-skeleton-card {
  border-radius: 12px;
}
</style>
