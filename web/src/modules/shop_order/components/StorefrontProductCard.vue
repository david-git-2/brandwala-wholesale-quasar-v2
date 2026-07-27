<template>
  <q-card flat bordered class="product-card">
    <div class="product-image-wrapper cursor-pointer" @click="$emit('quick-view', item)">
      <img
        v-if="item.product_image_url && !isImageBroken"
        :src="item.product_image_url"
        :alt="item.product_name || 'Product'"
        class="product-image"
        loading="lazy"
        @error="$emit('image-error')"
      />
      <div v-else class="product-image-fallback">
        <q-icon name="ph ph-image-square" size="28px" color="grey-5" />
      </div>
    </div>

    <div class="product-body">
      <div class="product-meta text-caption text-uppercase tracking-wider">
        {{ item.product_brand || 'Generic' }}
      </div>
      <div
        class="product-name text-subtitle2 text-weight-bold cursor-pointer"
        @click="$emit('quick-view', item)"
      >
        {{ item.product_name }}
      </div>

      <!-- Available Quantity -->
      <div
        v-if="
          permissions?.can_view_quantity &&
          item.available_units !== null &&
          item.available_units !== undefined
        "
        class="text-caption q-mt-xs"
        :class="
          item.available_units > 0
            ? 'text-positive'
            : item.available_units === 0
              ? 'text-negative'
              : 'text-grey-6'
        "
      >
        {{ item.available_units }} {{ $t('shop.avail') }}
      </div>

      <!-- Pricing Section -->
      <div class="product-pricing q-mt-sm">
        <template v-if="permissions?.see_price">
          <div class="text-subtitle1 text-weight-bold text-primary">
            <span
              v-if="shopType === 'dropship'"
              class="text-caption text-grey-6 block text-weight-medium"
            >
              {{ $t('shop.wholesale_price') }}
            </span>
            {{ formatMoney(item.unit_price_amount, item.unit_price_currency_symbol) }}
          </div>
          <div
            v-if="item.minimum_sell_price_amount != null"
            class="text-body2 text-grey-9 text-weight-medium q-mt-xs"
          >
            <template v-if="shopType === 'dropship'">
              {{ $t('shop.min_sell_price') }}:
              <span class="text-secondary text-weight-bold">
                {{
                  formatMoney(
                    item.minimum_sell_price_amount,
                    item.minimum_sell_price_currency_symbol,
                  )
                }}
              </span>
            </template>
            <template v-else>
              {{
                $t('shop.min_price_hint', {
                  amount: formatMoney(
                    item.minimum_sell_price_amount,
                    item.minimum_sell_price_currency_symbol,
                  ),
                })
              }}
            </template>
          </div>
        </template>
      </div>

      <!-- Separate Actions Row below everything -->
      <div class="product-actions q-mt-auto q-pt-sm">
        <div class="row items-center no-wrap justify-between q-gutter-x-xs">
          <!-- Qty adjuster shown only when NOT in cart -->
          <div
            v-if="!inCart"
            class="row items-center no-wrap quantity-controls col-auto"
            style="
              border: 1.5px solid var(--bw-theme-border, rgba(34, 56, 101, 0.15));
              border-radius: 8px;
              padding: 2px;
              background: rgba(0, 0, 0, 0.02);
            "
          >
            <q-btn
              flat
              round
              dense
              size="xs"
              icon="ph ph-minus"
              color="grey-8"
              style="min-width: 28px; min-height: 28px"
              @click="$emit('decrement', item)"
            />
            <div
              class="text-weight-bold text-center text-grey-9"
              style="width: 28px; font-size: 13px; user-select: none"
            >
              {{ selectedQty || minQty }}
            </div>
            <q-btn
              flat
              round
              dense
              size="xs"
              icon="ph ph-plus"
              color="grey-8"
              style="min-width: 28px; min-height: 28px"
              @click="$emit('increment', item)"
            />
          </div>
          <div v-else class="col-auto"></div>

          <q-btn
            v-if="!inCart"
            color="primary"
            unelevated
            no-caps
            dense
            icon="ph ph-shopping-cart"
            :label="$q.screen.lt.sm ? undefined : $t('shop.add')"
            class="add-cart-btn"
            :disabled="
              !permissions?.can_add_to_cart ||
              (item.available_units !== null && item.available_units <= 0)
            "
            @click="$emit('add-to-cart', item)"
          />
          <q-btn
            v-else
            color="negative"
            unelevated
            no-caps
            dense
            icon="ph ph-shopping-cart"
            :label="$q.screen.lt.sm ? undefined : $t('shop.remove')"
            class="add-cart-btn"
            :disabled="!permissions?.can_add_to_cart"
            @click="$emit('remove-from-cart', item)"
          />
        </div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  item: any;
  permissions?: any;
  shopType?: string | null;
  selectedQty?: number | undefined;
  inCart?: boolean | undefined;
  isImageBroken?: boolean | undefined;
  formatMoney: (amount: unknown, symbol?: string | null) => string;
}>();

defineEmits<{
  (e: 'quick-view', item: any): void;
  (e: 'image-error'): void;
  (e: 'increment', item: any): void;
  (e: 'decrement', item: any): void;
  (e: 'add-to-cart', item: any): void;
  (e: 'remove-from-cart', item: any): void;
}>();

const minQty = computed(() => {
  if (props.shopType === 'dropship') return 1;
  return props.item.minimum_order_quantity || 1;
});
</script>

<style scoped>
.product-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  border-radius: 16px;
  background: var(--bw-theme-surface, #ffffff);
  border-color: var(--bw-theme-border, rgba(34, 56, 101, 0.12));
  color: var(--bw-theme-ink, #1f2937);
  overflow: hidden;
  transition:
    transform 0.25s ease,
    box-shadow 0.25s ease;
}
.product-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--bw-theme-shadow, 0 10px 20px rgba(34, 56, 101, 0.06));
}
.product-image-wrapper {
  position: relative;
  height: 160px;
  flex: 0 0 160px;
  background: color-mix(
    in srgb,
    var(--bw-theme-base, #fafafa) 90%,
    var(--bw-theme-surface, #fff) 10%
  );
  border-bottom: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.05));
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px;
}
.product-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
  border-radius: 8px;
}
.product-image-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: color-mix(
    in srgb,
    var(--bw-theme-base, #eef2f6) 88%,
    var(--bw-theme-surface, #fff) 12%
  );
  border-radius: 8px;
}
.product-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 10px 12px 12px;
}
.product-meta {
  letter-spacing: 0.05em;
  margin-bottom: 2px;
  color: var(--bw-theme-muted, #6b7280);
}
.product-name {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.35;
  min-height: 4.05em;
  margin-bottom: 4px;
  color: var(--bw-theme-ink, #1f2937);
}
.product-actions {
  margin-top: auto;
  padding-top: 8px;
  border-top: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.06));
}
.product-pricing {
  min-width: 0;
}
.add-cart-btn {
  flex: 1 1 auto;
  border-radius: 8px;
}

@media (max-width: 599px) {
  .product-card {
    flex-direction: row;
    align-items: stretch;
    height: auto;
    border-radius: 0;
    border: none !important;
    border-bottom: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08)) !important;
    box-shadow: none;
  }
  .product-card:hover {
    transform: none;
    box-shadow: none;
  }
  .product-image-wrapper {
    width: 96px;
    height: 96px;
    flex: 0 0 96px;
    align-self: center;
    margin: 10px 0 10px 10px;
    padding: 4px;
    border-bottom: none;
    border-radius: 8px;
    overflow: hidden;
  }
  .product-image,
  .product-image-fallback {
    border-radius: 6px;
  }
  .product-body {
    padding: 10px 12px 10px 10px;
  }
  .product-name {
    min-height: unset;
    -webkit-line-clamp: 3;
    line-clamp: 3;
    font-size: 14px;
  }
  .product-actions {
    border-top: none;
    padding-top: 4px;
  }
  .add-cart-btn {
    min-width: 36px;
    padding-left: 4px;
    padding-right: 4px;
  }
}
</style>
