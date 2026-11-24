<template>
  <div class="q-gutter-y-md">
    <q-skeleton type="rect" height="128px" class="shop-home-skeleton-card" />

    <div class="row q-col-gutter-md">
      <div v-for="n in 3" :key="`kpi-${n}`" class="col-12 col-sm-4">
        <q-skeleton type="rect" height="84px" class="shop-home-skeleton-card" />
      </div>
    </div>

    <div class="row q-col-gutter-md">
      <div class="col-12 col-lg-7 q-gutter-y-sm">
        <q-skeleton type="rect" height="104px" class="shop-home-skeleton-card" />
        <q-skeleton type="rect" height="104px" class="shop-home-skeleton-card" />
      </div>
      <div class="col-12 col-lg-5">
        <q-skeleton type="rect" height="296px" class="shop-home-skeleton-card" />
      </div>
    </div>
  </div>
</template>

<style scoped>
.shop-home-skeleton-card {
  border-radius: 14px;
}
</style>
