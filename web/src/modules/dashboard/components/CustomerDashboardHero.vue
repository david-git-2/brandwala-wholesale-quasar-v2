<template>
  <section class="shop-home-banner" aria-label="Shop home">
    <h1 class="shop-home-banner__tenant q-my-none">{{ tenantName }}</h1>

    <div class="shop-home-banner__stats row justify-center q-col-gutter-md q-mt-md">
      <div class="col-auto">
        <q-card flat bordered class="shop-home-stat-card q-pa-md text-center">
          <div class="shop-home-banner__stat-value">{{ formatCountWithPlus(totalProducts) }}</div>
          <div class="shop-home-banner__stat-label">{{ $t('customer_dashboard.total_products') }}</div>
        </q-card>
      </div>
      <div class="col-auto">
        <q-card flat bordered class="shop-home-stat-card q-pa-md text-center">
          <div class="shop-home-banner__stat-value">{{ formatCountWithPlus(totalBrands) }}</div>
          <div class="shop-home-banner__stat-label">{{ $t('customer_dashboard.total_brands') }}</div>
        </q-card>
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

const formatCountWithPlus = (value?: number | null) => {
  const formatted = formatCount(value);
  return formatted === '—' ? formatted : `${formatted}+`;
};
</script>

<style scoped>
.shop-home-banner {
  padding: 0.5rem 0 1rem;
  text-align: center;
}

.shop-home-stat-card {
  min-width: 8.5rem;
  background: var(--tf-theme-surface);
}

.shop-home-banner__stat-value {
  font-size: clamp(1.75rem, 5vw, 2.25rem);
  font-weight: 700;
  line-height: 1.1;
  color: var(--tf-shop-charcoal);
}

.shop-home-banner__stat-label {
  margin-top: 0.35rem;
  font-size: 1rem;
  font-weight: 600;
  color: var(--tf-theme-muted);
  text-transform: capitalize;
}
</style>
