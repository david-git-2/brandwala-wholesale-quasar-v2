<template>
  <q-btn
    v-if="generalText"
    flat
    dense
    no-caps
    size="sm"
    color="primary"
    icon="ph ph-note"
    label="General"
    class="pp-general-instruction-btn"
    :aria-label="ariaLabel"
    @click.stop
  >
    <q-menu
      ref="menuRef"
      anchor="bottom right"
      self="top right"
      :offset="[0, 4]"
      content-class="pp-app-order-line-row__instructions-menu-panel"
      @click.stop
    >
      <div class="pp-general-instruction-menu column">
        <div class="pp-general-instruction-menu__head row items-center justify-between no-wrap">
          <span class="pp-general-instruction-menu__title">General instructions</span>
          <TfBtn
            variant="icon"
            size="sm"
            icon="ph ph-x"
            aria-label="Close general instructions"
            @click="closeMenu"
          />
        </div>
        <p class="pp-general-instruction-menu__text q-mb-none">{{ generalText }}</p>
      </div>
    </q-menu>
  </q-btn>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { PpBucketInstruction } from '../types/ppPurchaseRequest';
import { ppBucketGeneralInstructionText } from '../utils/ppBucketInstructions';

const props = defineProps<{
  instructions?: PpBucketInstruction[];
  requestLabel?: string;
}>();

const menuRef = ref<{ hide: () => void } | null>(null);

const generalText = computed(() => ppBucketGeneralInstructionText(props.instructions));

const ariaLabel = computed(() =>
  props.requestLabel
    ? `General instructions for ${props.requestLabel}`
    : 'General instructions',
);

const closeMenu = () => {
  menuRef.value?.hide();
};
</script>

<style scoped>
.pp-general-instruction-btn {
  min-height: 0;
  padding: 0 6px;
  font-size: 11px;
}

.pp-general-instruction-menu {
  max-width: min(22rem, 80vw);
  padding: 0.5rem 0.65rem 0.65rem;
  font-size: 11px;
  line-height: 1.4;
  color: var(--tf-neutral-ink);
}

.pp-general-instruction-menu__head {
  gap: 0.5rem;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid var(--tf-neutral-border);
  margin-bottom: 0.35rem;
}

.pp-general-instruction-menu__title {
  font-size: 11px;
  font-weight: 600;
}

.pp-general-instruction-menu__text {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  word-break: break-word;
}
</style>