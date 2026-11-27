<template>
  <div class="catalog-header-shop">
    <q-btn-dropdown
      v-if="shops.length > 1"
      flat
      no-caps
      dense
      unelevated
      :ripple="false"
      class="catalog-header-shop__trigger"
      dropdown-icon="ph ph-caret-down"
      content-class="catalog-shop-switcher__menu"
      data-test="catalog-shop-switcher"
      :aria-label="$t('shop.switch_shop')"
    >
      <template #label>
        <span class="catalog-header-shop__label">
          <q-icon name="ph ph-storefront" size="15px" class="catalog-header-shop__icon" />
          <span class="catalog-header-shop__name">{{ shopName }}</span>
        </span>
      </template>

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

    <div v-else class="catalog-header-shop__static">
      <q-icon name="ph ph-storefront" size="15px" class="catalog-header-shop__icon" />
      <span class="catalog-header-shop__name">{{ shopName }}</span>
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
  align-items: center;
  min-width: 0;
  max-width: 100%;
}

.catalog-header-shop__static,
.catalog-header-shop__trigger {
  display: inline-flex;
  align-items: center;
  min-height: 32px;
  max-width: 100%;
  padding: 0.25rem 0.55rem;
  border-radius: var(--tf-radius-md, 8px);
  border: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-canvas);
  color: var(--tf-neutral-ink);
  font-size: 0.8125rem;
  font-weight: 600;
  line-height: 1.2;
}

.catalog-header-shop__trigger {
  transition: border-color 0.15s ease, background-color 0.15s ease;
}

.catalog-header-shop__trigger:hover,
.catalog-header-shop__trigger:focus-visible {
  border-color: var(--tf-neutral-border-strong);
  background: var(--tf-neutral-surface);
}

.catalog-header-shop__static {
  gap: 0.35rem;
}

.catalog-header-shop__label {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-width: 0;
  max-width: 100%;
}

.catalog-header-shop__icon {
  color: var(--tf-neutral-muted);
  flex-shrink: 0;
}

.catalog-header-shop__name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.catalog-header-shop__trigger :deep(.q-btn__content) {
  gap: 0.25rem;
  flex-wrap: nowrap;
  max-width: 100%;
}

.catalog-header-shop__trigger :deep(.q-btn-dropdown__arrow) {
  font-size: 0.78rem;
  margin-left: 0.1rem;
  color: var(--tf-neutral-muted);
  flex-shrink: 0;
}
</style>
