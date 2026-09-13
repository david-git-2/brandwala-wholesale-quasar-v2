<template>
  <q-card flat bordered class="add-product-cart-card">
    <div class="add-product-cart-card__image-wrap">
      <q-chip
        v-if="isOnFile"
        dense
        square
        color="green-1"
        text-color="green-9"
        size="xs"
        class="add-product-cart-card__badge add-product-cart-card__badge--on-file text-weight-bold q-ma-none"
      >
        {{ $t('product_based_costing.on_file') }}
      </q-chip>
      <SmartImage
        :src="product.image_url"
        :alt="product.name ?? 'Product'"
        class="add-product-cart-card__image"
        :enable-edit="false"
        :enable-lightbox="false"
      />
    </div>

    <q-card-section class="add-product-cart-card__body q-pt-sm q-pb-sm">
      <div class="add-product-cart-card__content">
        <div class="add-product-cart-card__primary">
          <div class="add-product-cart-card__name">{{ product.name ?? '—' }}</div>
          <div v-if="subtitleLine" class="add-product-cart-card__subtitle ellipsis">
            {{ subtitleLine }}
          </div>
        </div>

        <div class="add-product-cart-card__metrics">
          <div v-if="product.list_price_amount != null" class="add-product-cart-card__price">
            £{{ product.list_price_amount.toFixed(2) }}
          </div>
          <q-chip
            v-if="product.available_units != null"
            dense
            square
            size="sm"
            color="blue-grey-1"
            text-color="blue-grey-9"
            class="add-product-cart-card__units-chip q-ma-none text-weight-bold"
          >
            {{ product.available_units }} {{ $t('product_based_costing.card_units') }}
          </q-chip>
        </div>

        <div v-if="hasDetailRows" class="add-product-cart-card__details">
          <div v-if="product.product_code" class="add-product-cart-card__detail-row">
            <span class="add-product-cart-card__detail-label">{{ $t('product_based_costing.product_code') }}</span>
            <div class="add-product-cart-card__detail-value-row">
              <span class="add-product-cart-card__detail-value font-mono">{{ product.product_code }}</span>
              <q-btn
                flat
                round
                dense
                size="xs"
                icon="ph ph-copy"
                color="grey-6"
                class="add-product-cart-card__copy-btn"
                @click.stop="handleCopy(product.product_code, $t('product_based_costing.code'))"
              >
                <q-tooltip>{{ $t('product_based_costing.copy_code') }}</q-tooltip>
              </q-btn>
            </div>
          </div>
          <div v-if="product.barcode" class="add-product-cart-card__detail-row">
            <span class="add-product-cart-card__detail-label">{{ $t('product_based_costing.barcode') }}</span>
            <div class="add-product-cart-card__detail-value-row">
              <span class="add-product-cart-card__detail-value font-mono">{{ product.barcode }}</span>
              <q-btn
                flat
                round
                dense
                size="xs"
                icon="ph ph-copy"
                color="grey-6"
                class="add-product-cart-card__copy-btn"
                @click.stop="handleCopy(product.barcode, $t('product_based_costing.barcode'))"
              >
                <q-tooltip>{{ $t('product_based_costing.copy_barcode') }}</q-tooltip>
              </q-btn>
            </div>
          </div>
          <div v-if="product.vendor_code" class="add-product-cart-card__detail-row">
            <span class="add-product-cart-card__detail-label">{{ $t('product_based_costing.vendor') }}</span>
            <span class="add-product-cart-card__detail-value font-mono">{{ product.vendor_code }}</span>
          </div>
          <div v-if="categoryLabel" class="add-product-cart-card__detail-row">
            <span class="add-product-cart-card__detail-label">{{ $t('product_based_costing.category') }}</span>
            <span class="add-product-cart-card__detail-value">{{ categoryLabel }}</span>
          </div>
          <div v-if="batchLine" class="add-product-cart-card__detail-row">
            <span class="add-product-cart-card__detail-label">{{ $t('product_based_costing.card_batch') }}</span>
            <span class="add-product-cart-card__detail-value">{{ batchLine }}</span>
          </div>
          <div v-if="languageLabel" class="add-product-cart-card__detail-row">
            <span class="add-product-cart-card__detail-label">{{ $t('product_based_costing.card_language') }}</span>
            <span class="add-product-cart-card__detail-value">{{ languageLabel }}</span>
          </div>
          <div v-if="weightLine" class="add-product-cart-card__detail-row">
            <span class="add-product-cart-card__detail-label">{{ $t('product_based_costing.card_weight') }}</span>
            <span class="add-product-cart-card__detail-value">{{ weightLine }}</span>
          </div>
        </div>
      </div>

      <div class="add-product-cart-card__actions">
        <q-btn
          v-if="isOnFile"
          unelevated
          dense
          no-caps
          color="negative"
          icon="ph ph-trash"
          :label="$t('product_based_costing.remove')"
          class="full-width rounded-sq-btn text-weight-bold"
          style="border-radius: 8px"
          :loading="loading"
          :disable="disabled"
          data-test="remove-from-file-btn"
          @click="emit('remove', product)"
        />
        <q-btn
          v-else
          unelevated
          dense
          no-caps
          color="primary"
          icon="ph ph-shopping-cart"
          :label="$t('product_based_costing.add_to_cart')"
          class="full-width rounded-sq-btn text-weight-bold"
          style="border-radius: 8px"
          :loading="loading"
          :disable="disabled"
          data-test="add-to-cart-btn"
          @click="emit('add', product)"
        />
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useQuasar, copyToClipboard } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import type { Product } from 'src/modules/products/types';

const $q = useQuasar();
const { t } = useI18n();

const props = defineProps<{
  product: Product;
  isOnFile: boolean;
  loading?: boolean;
  disabled?: boolean;
}>();

const emit = defineEmits<{
  add: [product: Product];
  remove: [product: Product];
}>();

const languageLabel = computed(() => props.product.languages?.trim() || '');
const categoryLabel = computed(() => props.product.category?.trim() || '');
const batchLine = computed(() => props.product.batch_code_manufacture_date?.trim() || '');

const subtitleLine = computed(() => props.product.brand?.trim() || '');

const weightLine = computed(() => {
  const parts: string[] = [];
  if (props.product.product_weight != null) {
    parts.push(`${props.product.product_weight} kg`);
  }
  if (props.product.package_weight != null) {
    parts.push(`${props.product.package_weight} kg pkg`);
  }
  return parts.join(' · ');
});

const hasDetailRows = computed(
  () =>
    !!props.product.product_code?.trim() ||
    !!props.product.barcode?.trim() ||
    !!props.product.vendor_code?.trim() ||
    !!categoryLabel.value ||
    !!batchLine.value ||
    !!languageLabel.value ||
    !!weightLine.value,
);

const handleCopy = (text: string | null | undefined, label: string) => {
  if (!text?.trim()) return;
  copyToClipboard(text.trim())
    .then(() => {
      $q.notify({
        type: 'positive',
        message: t('product_based_costing.copied_to_clipboard', { label }),
        timeout: 1000,
      });
    })
    .catch(() => {
      $q.notify({
        type: 'negative',
        message: t('product_based_costing.failed_to_copy', { label }),
        timeout: 1000,
      });
    });
};
</script>

<style scoped>
.add-product-cart-card {
  border-radius: var(--bw-radius-md, 12px);
  overflow: hidden;
  height: 100%;
  display: flex;
  flex-direction: column;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.add-product-cart-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--bw-theme-shadow, 0 4px 12px rgba(0, 0, 0, 0.08));
}

.add-product-cart-card__image-wrap {
  position: relative;
  height: 160px;
  background: var(--bw-theme-base, #f8fafc);
  border-bottom: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
}

.add-product-cart-card__badge {
  position: absolute;
  top: 8px;
  z-index: 2;
}

.add-product-cart-card__badge--on-file {
  left: 8px;
}

.add-product-cart-card__image {
  width: 100%;
  height: 100%;
}

:deep(.add-product-cart-card__image .smart-image__img) {
  object-fit: contain;
}

.add-product-cart-card__body {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.add-product-cart-card__content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.add-product-cart-card__primary {
  min-width: 0;
}

.add-product-cart-card__name {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.3;
  color: var(--bw-theme-ink, #1e293b);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.add-product-cart-card__subtitle {
  margin-top: 2px;
  font-size: 11px;
  font-weight: 500;
  color: var(--bw-theme-muted, #64748b);
}

.add-product-cart-card__metrics {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  padding: 0.35rem 0.5rem;
  border-radius: var(--bw-radius-sm, 8px);
  background: color-mix(in srgb, var(--bw-theme-primary, #5ea3a3) 8%, var(--bw-theme-surface, #fff) 92%);
}

.add-product-cart-card__price {
  font-size: 15px;
  font-weight: 800;
  color: var(--q-primary);
  line-height: 1;
}

.add-product-cart-card__units-chip {
  font-size: 10px;
  height: 22px;
}

.add-product-cart-card__details {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding-top: 0.35rem;
  border-top: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
}

.add-product-cart-card__detail-row {
  display: grid;
  grid-template-columns: 4.5rem minmax(0, 1fr);
  gap: 0.35rem;
  align-items: baseline;
  font-size: 10px;
  line-height: 1.35;
}

.add-product-cart-card__detail-label {
  color: var(--bw-theme-muted, #64748b);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.add-product-cart-card__detail-value-row {
  display: flex;
  align-items: center;
  gap: 0.15rem;
  min-width: 0;
}

.add-product-cart-card__detail-value {
  color: var(--bw-theme-ink, #334155);
  word-break: break-word;
  min-width: 0;
}

.add-product-cart-card__copy-btn {
  flex-shrink: 0;
}

.add-product-cart-card__actions {
  margin-top: auto;
  padding-top: 0.65rem;
}

@media (max-width: 599px) {
  .add-product-cart-card {
    flex-direction: row;
    align-items: stretch;
  }

  .add-product-cart-card__image-wrap {
    width: 112px;
    min-width: 112px;
    height: auto;
    min-height: 112px;
    border-bottom: none;
    border-right: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
  }

  .add-product-cart-card__body {
    padding-left: 10px !important;
    justify-content: space-between;
  }

  .add-product-cart-card__detail-row {
    grid-template-columns: 4rem minmax(0, 1fr);
  }

  .add-product-cart-card:hover {
    transform: none;
  }
}
</style>
