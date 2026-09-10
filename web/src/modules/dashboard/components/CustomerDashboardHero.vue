<template>
  <section class="shop-home-banner" aria-label="Shop home">
    <h1 class="shop-home-banner__tenant q-my-none">{{ tenantName }}</h1>

    <div class="shop-home-banner__stats row justify-center q-col-gutter-lg q-mt-md">
      <div class="col-auto text-center">
        <div class="shop-home-banner__stat-value">{{ formatCount(totalProducts) }}</div>
        <div class="shop-home-banner__stat-label">{{ $t('customer_dashboard.total_products') }}+</div>
      </div>
      <div class="col-auto text-center">
        <div class="shop-home-banner__stat-value">{{ formatCount(totalBrands) }}</div>
        <div class="shop-home-banner__stat-label">{{ $t('customer_dashboard.total_brands') }}+</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  tenantName: string;
  totalProducts?: number | null;
  totalBrands?: number | null;
}>();

const formatCount = (value?: number | null) => {
  if (value == null) return '—';
  return value.toLocaleString();
};
</script>

<style scoped>
.shop-home-banner {
  padding: 0.5rem 0 1rem;
  text-align: center;
}

.shop-home-banner__stat-value {
  font-size: clamp(1.75rem, 5vw, 2.25rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--bw-shop-charcoal);
}

.shop-home-banner__stat-label {
  margin-top: 0.2rem;
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--bw-shop-plum);
  text-transform: capitalize;
}
</style>
