<template>
  <div class="catalog-header-shop">
    <q-btn-dropdown
      v-if="shops.length > 1"
      flat
      no-caps
      unelevated
      class="catalog-header-shop__trigger shop-banner-font"
      dropdown-icon="ph ph-caret-down"
      :label="shopName"
      content-class="catalog-shop-switcher__menu"
      data-test="catalog-shop-switcher"
      :aria-label="$t('shop.switch_shop')"
    >
      <q-list>
        <q-item
          v-for="shop in shops"
          :key="shop.id"
          v-close-popup
          clickable
          :active="shop.slug === currentSlug"
          @click="$emit('switch-shop', shop)"
        >
          <q-item-section avatar>
            <q-icon name="ph ph-storefront" size="18px" color="grey-7" />
          </q-item-section>
          <q-item-section>{{ shop.name }}</q-item-section>
        </q-item>
      </q-list>
    </q-btn-dropdown>

    <div v-else class="catalog-header-shop__static shop-banner-font ellipsis">
      {{ shopName }}
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  shopName: string;
  currentSlug: string;
  shops: Array<{ id: number; slug: string; name: string }>;
}>();

defineEmits<{
  (e: 'switch-shop', shop: { id: number; slug: string; name: string }): void;
}>();
</script>

<style scoped>
.catalog-header-shop {
  display: flex;
  justify-content: center;
  min-width: 0;
  max-width: 100%;
}

.catalog-header-shop__static,
.catalog-header-shop__trigger {
  font-size: clamp(0.95rem, 3.2vw, 1.45rem);
  line-height: 1.1;
  max-width: 100%;
}

.catalog-header-shop__static {
  text-align: center;
}

.catalog-header-shop__trigger {
  border-radius: 8px;
  padding: 0.1rem 0.25rem;
  max-width: 100%;
}

.catalog-header-shop__trigger :deep(.q-btn__content) {
  gap: 0.25rem;
  max-width: 100%;
}

.catalog-header-shop__trigger :deep(.q-btn__content .block) {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.catalog-header-shop__trigger :deep(.q-btn-dropdown__arrow) {
  font-size: 0.85rem;
  margin-left: 0.05rem;
  opacity: 0.72;
  flex-shrink: 0;
}
</style>
