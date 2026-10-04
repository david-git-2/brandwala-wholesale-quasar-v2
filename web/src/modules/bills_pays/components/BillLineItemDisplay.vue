<template>
  <div class="bill-line-item">
    <SmartImage
      :src="imageUrl"
      :alt="name"
      img-class="bill-line-item__thumb"
      fallback-class="bill-line-item__thumb bill-line-item__thumb--fallback"
      :enable-lightbox="false"
      :enable-edit="false"
    />
    <span class="bill-line-item__name">{{ name }}</span>
  </div>
</template>

<script setup lang="ts">
import SmartImage from 'src/components/SmartImage.vue';

defineProps<{
  name: string;
  imageUrl?: string | null;
}>();
</script>

<style scoped lang="scss">
.bill-line-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  min-width: 0;
  max-width: 280px;
}

.bill-line-item__name {
  white-space: normal;
  word-break: break-word;
  overflow-wrap: anywhere;
  line-height: 1.35;
  font-size: inherit;
}

:deep(.bill-line-item__thumb) {
  width: 48px;
  height: 48px;
  min-width: 48px;
  object-fit: contain;
  border-radius: 4px;
  background: #f1f5f9;
}

:deep(.bill-line-item__thumb--fallback) {
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 9px;
  color: #94a3b8;
  text-align: center;
}
</style>
