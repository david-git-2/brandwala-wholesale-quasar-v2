<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Title & Subtitle Card -->
      <q-card flat bordered class="q-pa-md">
        <AppPageHeader :title="title" :subtitle="subtitle || ''">
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
}>();
</script>
