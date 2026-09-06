<template>
  <div class="dropship-action-bar" :class="{ 'dropship-action-bar--fixed': fixed }">
    <q-card flat bordered class="dropship-action-bar__card">
      <q-card-section class="dropship-action-bar__inner q-pa-md">
        <div class="dropship-action-bar__copy column col">
          <span class="text-subtitle2 text-weight-bold text-grey-9">
            {{ $t('shop_admin.counter_offer_required') }}
          </span>
          <span class="text-caption text-grey-7">
            {{ $t('shop_admin.counter_offer_hint') }}
          </span>
        </div>
        <q-btn
          color="primary"
          unelevated
          no-caps
          class="action-btn text-weight-bold"
          :label="$t('shop_admin.submit_counter_offer')"
          :loading="isSendingCounter"
          @click="emit('submit-counter-offer')"
        />
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuasar } from 'quasar';

defineProps<{
  isSendingCounter: boolean;
}>();

const emit = defineEmits<{
  (e: 'submit-counter-offer'): void;
}>();

const $q = useQuasar();
const fixed = computed(() => $q.screen.lt.md);
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderDropshipActionBar',
};
</script>

<style scoped>
.dropship-action-bar {
  width: 100%;
}

.dropship-action-bar__card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #fff);
}

.dropship-action-bar__inner {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.action-btn {
  border-radius: 8px;
  min-height: 48px;
  width: 100%;
}

@media (min-width: 600px) {
  .dropship-action-bar__inner {
    flex-direction: row;
    align-items: center;
    gap: 16px;
    padding: 12px 16px !important;
  }

  .dropship-action-bar__copy {
    flex: 1 1 auto;
    min-width: 0;
  }

  .action-btn {
    flex: 0 0 auto;
    width: auto;
    min-width: 200px;
    min-height: 40px;
  }
}

@media (max-width: 599px) {
  .dropship-action-bar--fixed {
    position: fixed;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 200;
    padding: 0 12px calc(12px + env(safe-area-inset-bottom, 0px));
    background: linear-gradient(
      to top,
      rgba(255, 255, 255, 0.98) 70%,
      rgba(255, 255, 255, 0)
    );
  }

  .dropship-action-bar--fixed .dropship-action-bar__card {
    border-radius: 12px 12px 0 0;
    box-shadow: 0 -4px 24px rgba(34, 56, 101, 0.08);
  }
}
</style>
