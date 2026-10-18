<template>
  <q-dialog
    v-model="open"
    position="right"
    full-height
    :persistent="persistent"
    transition-show="slide-left"
    transition-hide="slide-right"
    transition-duration="180"
  >
    <q-card flat bordered class="tf-side-sheet column no-wrap" :style="{ width: width + 'px' }">
      <header class="tf-side-sheet__head row items-center no-wrap">
        <div class="col ellipsis">
          <div class="tf-side-sheet__title ellipsis">{{ title }}</div>
          <div v-if="subtitle" class="tf-side-sheet__sub ellipsis">{{ subtitle }}</div>
        </div>
        <slot name="header-actions" />
        <TfBtn variant="icon" icon="ph ph-x" aria-label="Close" @click="open = false" />
      </header>
      <div class="tf-side-sheet__body col scroll q-pa-md">
        <slot />
      </div>
      <footer v-if="$slots.footer" class="tf-side-sheet__foot row items-center justify-end q-gutter-sm">
        <slot name="footer" />
      </footer>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';

withDefaults(
  defineProps<{
    title: string;
    subtitle?: string;
    width?: 420 | 560 | 720;
    persistent?: boolean;
  }>(),
  { width: 560, persistent: false },
);

const open = defineModel<boolean>({ required: true });
</script>

<style scoped>
.tf-side-sheet {
  max-width: 100vw;
  height: 100%;
  border-radius: 0;
  border-top: 0;
  border-bottom: 0;
  border-right: 0;
}
.tf-side-sheet__head {
  padding: 8px 12px 8px 16px;
  border-bottom: 1px solid var(--tf-neutral-border);
}
.tf-side-sheet__title {
  font-size: 15px;
  font-weight: 600;
  color: var(--tf-neutral-ink);
}
.tf-side-sheet__sub {
  font-size: 12px;
  color: var(--tf-neutral-muted);
}
.tf-side-sheet__foot {
  padding: 8px 16px;
  border-top: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-surface);
}
</style>
