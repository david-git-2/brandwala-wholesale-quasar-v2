<template>
  <div class="ops-blank-section">
    <div class="ops-blank-section__image-placeholder" aria-hidden="true">
      <q-icon name="ph ph-image" size="48px" color="grey-5" />
    </div>
  </div>
</template>

<style scoped>
.ops-blank-section {
  border: 1px dashed var(--bw-theme-border, rgba(0, 0, 0, 0.12));
  border-radius: 14px;
  background: var(--bw-theme-surface, #fff);
  overflow: hidden;
}

.ops-blank-section__image-placeholder {
  min-height: 240px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.02);
}
</style>
