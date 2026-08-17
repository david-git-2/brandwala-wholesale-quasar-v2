<template>
  <section class="row items-center justify-between q-col-gutter-md">
    <div class="col">
      <div class="row items-center q-gutter-x-sm no-wrap">
        <q-btn
          flat
          dense
          icon="ph ph-arrow-left"
          color="grey-7"
          :aria-label="$t('navigation.home')"
          data-test="catalog-back-home"
          @click="$emit('back')"
        />
        <div class="col">
          <div class="text-overline text-primary">{{ $t('navigation.catalog') }}</div>
          <q-btn-dropdown
            v-if="shops.length > 1"
            flat
            no-caps
            dense
            unelevated
            dropdown-icon="ph ph-caret-down"
            :label="shopName"
            class="catalog-shop-switcher q-px-none text-h5 text-weight-bold"
            content-class="catalog-shop-switcher__menu"
            data-test="catalog-shop-switcher"
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
                <q-item-section>{{ shop.name }}</q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
          <h1 v-else class="text-h5 text-weight-bold q-my-none">{{ shopName }}</h1>
        </div>
      </div>
    </div>
    <div v-if="$q.screen.xs" class="col-auto row items-center q-gutter-sm">
      <q-btn
        flat
        round
        dense
        color="primary"
        icon="ph ph-funnel-simple"
        :aria-label="$t('shop.filters')"
        @click="$emit('open-filter')"
      >
        <q-badge v-if="activeFilterCount > 0" color="primary" floating rounded>
          {{ activeFilterCount }}
        </q-badge>
        <q-tooltip>{{ $t('shop.filters') }}</q-tooltip>
      </q-btn>
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  shopName: string;
  currentSlug: string;
  shops: Array<{ id: number; slug: string; name: string }>;
  activeFilterCount: number;
}>();

defineEmits<{
  (e: 'back'): void;
  (e: 'open-filter'): void;
  (e: 'switch-shop', shop: { id: number; slug: string; name: string }): void;
}>();
</script>

<style scoped>
.catalog-shop-switcher {
  min-height: auto;
  border-radius: 8px;
}

.catalog-shop-switcher :deep(.q-btn__content) {
  justify-content: flex-start;
}
</style>
