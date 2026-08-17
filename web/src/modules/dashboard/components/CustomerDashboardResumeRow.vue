<template>
  <div class="row q-col-gutter-md">
    <div v-if="continueShop" class="col-12 col-md-5">
      <q-card flat bordered class="resume-card q-pa-md">
        <div class="text-caption text-grey-6 text-weight-bold text-uppercase q-mb-sm">
          {{ $t('customer_dashboard.resume_title') }}
        </div>
        <div class="row items-center no-wrap q-gutter-sm">
          <q-avatar size="44px" class="shop-avatar text-weight-bold">
            {{ shopInitial(continueShop.name) }}
          </q-avatar>
          <div class="col">
            <div class="text-subtitle1 text-weight-bold">{{ continueShop.name }}</div>
            <q-btn
              v-if="cartItemCount > 0"
              flat
              dense
              no-caps
              color="primary"
              class="q-pa-none"
              :label="cartLabel"
              data-test="resume-cart"
              @click="$emit('go-cart')"
            />
          </div>
          <q-btn
            color="primary"
            unelevated
            no-caps
            :label="$t('customer_dashboard.open_shop')"
            icon-right="ph ph-caret-right"
            data-test="continue-shop-btn"
            @click="$emit('continue')"
          />
        </div>
      </q-card>
    </div>

    <div v-if="showSearch" class="col-12" :class="continueShop ? 'col-md-7' : 'col-md-12'">
      <div class="text-caption text-grey-6 text-weight-bold text-uppercase q-mb-sm">
        {{ $t('customer_dashboard.find_product') }}
      </div>
      <q-input
        v-model="searchModel"
        outlined
        dense
        :placeholder="$t('customer_dashboard.search_placeholder')"
        class="soft-input"
        data-test="dashboard-search"
        @keydown.enter="$emit('search')"
      >
        <template #prepend>
          <q-icon name="ph ph-magnifying-glass" color="grey-6" />
        </template>
        <template #append>
          <q-btn
            color="primary"
            flat
            no-caps
            dense
            :label="$t('customer_dashboard.search_btn')"
            class="q-px-md"
            @click="$emit('search')"
          />
        </template>
      </q-input>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';

const props = defineProps<{
  continueShop: CustomerAccessibleShop | null;
  cartItemCount: number;
  searchQuery: string;
  showSearch: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:searchQuery', value: string): void;
  (e: 'search'): void;
  (e: 'continue'): void;
  (e: 'go-cart'): void;
}>();

const { t } = useI18n();

const searchModel = computed({
  get: () => props.searchQuery,
  set: (val: string) => emit('update:searchQuery', val),
});

const cartLabel = computed(() =>
  props.cartItemCount === 1
    ? t('customer_dashboard.cart_item_one')
    : t('customer_dashboard.cart_items', { count: props.cartItemCount }),
);

const shopInitial = (name: string) => (name.trim().charAt(0) || 'S').toUpperCase();
</script>

<style scoped>
.resume-card {
  border-radius: 14px;
  background: var(--bw-theme-surface);
  min-height: 100%;
}

.shop-avatar {
  background: var(--bw-theme-primary-soft);
  color: var(--q-primary);
}
</style>
