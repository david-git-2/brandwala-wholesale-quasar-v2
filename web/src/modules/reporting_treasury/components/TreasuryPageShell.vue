<template>
  <q-page
    :class="dense ? 'q-pa-sm q-sm-pa-md' : 'bw-page'"
    :style="dense ? 'max-width: 100% !important;' : ''"
  >
    <div :class="dense ? 'q-gutter-y-sm' : 'bw-page__stack'">
      <!-- Title & Subtitle Card -->
      <q-card flat bordered :class="dense ? 'q-py-none q-px-sm' : 'q-pa-md'">
        <AppPageHeader :title="title" :subtitle="subtitle || ''" :dense="dense">
          <template v-if="$slots.action" #action>
            <slot name="action" />
          </template>
        </AppPageHeader>
      </q-card>

      <!-- Status Banner / Error Slot -->
      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>
      <slot name="error-banner" />

      <!-- Main Body Slot -->
      <slot />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';

defineProps<{
  title: string;
  subtitle?: string;
  error?: string | null;
  dense?: boolean;
}>();
</script>
