<template>
  <div class="marketing-tag-card">
    <div v-if="showHeader" class="marketing-tag-card__header">
      <img v-if="tagConfig.show_logo" :src="basLogo" class="marketing-tag-card__logo" alt="BAS" />
      <div v-if="tagConfig.show_brand_name && displayBrandName" class="marketing-tag-card__brand">
        {{ displayBrandName }}
      </div>
    </div>

    <div class="marketing-tag-card__body">
      <div v-if="tagConfig.show_core_sizes && coreSizesLine" class="marketing-tag-card__size-line">
        <span class="marketing-tag-card__label">Size</span>
        <span class="marketing-tag-card__size-value">{{ coreSizesLine }}</span>
      </div>

      <div
        v-if="tagConfig.show_additional_sizes && additionalSizesLine"
        class="marketing-tag-card__additional-line"
      >
        <span class="marketing-tag-card__label">Add</span>
        <span class="marketing-tag-card__additional-value">{{ additionalSizesLine }}</span>
      </div>

      <div v-if="tagConfig.show_listed_sell" class="marketing-tag-card__price">
        {{ listedSellFormatted }}
      </div>
    </div>

    <div class="marketing-tag-card__barcode-wrap">
      <div class="marketing-tag-card__barcode">
        <BarcodeRenderer
          :value="stock.barcode || ''"
          :height="24"
          :width="1.15"
          :display-value="false"
        />
      </div>
      <div v-if="tagConfig.show_barcode_text" class="marketing-tag-card__barcode-text">
        {{ stock.barcode }}
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ThriftStock } from '../types';
import type { ThriftMarketingTagConfig } from '../../shipment/types/marketingTag';
import BarcodeRenderer from '../../barcode/components/BarcodeRenderer.vue';
import {
  formatCoreSizes,
  formatAdditionalSizes,
} from '../../shared/utils/formatThriftStockTagSizes';
import basLogo from 'src/assets/bas-logo.png';

const props = defineProps<{
  stock: ThriftStock;
  tagConfig: ThriftMarketingTagConfig;
  listedSellFormatted: string;
}>();

const coreSizesLine = computed(() => formatCoreSizes(props.stock));
const additionalSizesLine = computed(() => formatAdditionalSizes(props.stock));

const displayBrandName = computed(() => {
  const shopBrand = props.tagConfig.brand_name?.trim();
  const itemBrand = props.stock.brand_name?.trim();
  return shopBrand || itemBrand || '';
});

const showHeader = computed(() => {
  return props.tagConfig.show_logo || (props.tagConfig.show_brand_name && !!displayBrandName.value);
});
</script>

<style scoped>
.marketing-tag-card {
  --tag-accent: #1565c0;
  border: 1.5px solid #1a1a1a;
  padding: 2mm 3mm;
  background: #fff;
  display: grid;
  grid-template-rows: auto minmax(0, 1fr) auto;
  gap: 1mm;
  box-sizing: border-box;
  height: 42mm;
  width: 100%;
  border-radius: 4px;
  overflow: hidden;
  font-family: 'Segoe UI', system-ui, sans-serif;
  color: #111;
}

.marketing-tag-card__header {
  display: flex;
  align-items: flex-start;
  gap: 2mm;
  min-height: 0;
  flex-shrink: 0;
  padding-bottom: 1mm;
  border-bottom: 1px solid #e0e0e0;
}

.marketing-tag-card__logo {
  height: 6.5mm;
  width: auto;
  max-width: 14mm;
  object-fit: contain;
  flex-shrink: 0;
  display: block;
}

.marketing-tag-card__brand {
  flex: 1;
  min-width: 0;
  font-size: 11px;
  font-weight: 800;
  line-height: 1.15;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: #111;
  overflow-wrap: anywhere;
}

.marketing-tag-card__body {
  min-height: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 1mm;
}

.marketing-tag-card__price {
  font-size: 17px;
  font-weight: 800;
  line-height: 1;
  text-align: center;
  color: var(--tag-accent);
  letter-spacing: -0.01em;
  flex-shrink: 0;
}

.marketing-tag-card__label {
  font-size: 8px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #666;
  flex-shrink: 0;
  min-width: 7mm;
}

.marketing-tag-card__size-line,
.marketing-tag-card__additional-line {
  display: flex;
  align-items: baseline;
  gap: 1.5mm;
  min-width: 0;
  flex-shrink: 1;
}

.marketing-tag-card__size-value {
  font-size: 12px;
  font-weight: 800;
  line-height: 1.15;
  color: #111;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 0;
  flex: 1;
}

.marketing-tag-card__additional-value {
  font-size: 9px;
  font-weight: 600;
  line-height: 1.15;
  color: #333;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 0;
  flex: 1;
}

.marketing-tag-card__barcode-wrap {
  flex-shrink: 0;
  width: 100%;
  padding-top: 1mm;
  border-top: 1px dashed #ccc;
}

.marketing-tag-card__barcode {
  width: 100%;
  height: 7.5mm;
  display: flex;
  justify-content: center;
  align-items: center;
}

.marketing-tag-card__barcode-text {
  font-size: 8px;
  font-family: ui-monospace, monospace;
  font-weight: 700;
  letter-spacing: 0.06em;
  line-height: 1;
  text-align: center;
  color: #222;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}
</style>
