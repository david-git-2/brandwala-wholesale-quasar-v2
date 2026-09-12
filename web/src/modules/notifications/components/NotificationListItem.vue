<template>
  <q-item
    clickable
    v-ripple
    class="notification-list-item"
    :class="{ 'notification-list-item--unread': item.is_unread }"
    data-test="notification-list-item"
    @click="emit('select', item)"
  >
    <q-item-section>
      <q-item-label class="notification-list-item__title text-weight-medium">
        {{ item.title }}
      </q-item-label>
      <q-item-label v-if="item.body" caption lines="1" class="notification-list-item__body">
        {{ item.body }}
      </q-item-label>
      <q-item-label caption class="notification-list-item__time">
        {{ relativeTime }}
      </q-item-label>
    </q-item-section>
  </q-item>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import { formatRelativeTime } from '../utils/formatRelativeTime';
import type { NotificationItem } from '../types';

const props = defineProps<{
  item: NotificationItem;
}>();

const emit = defineEmits<{
  select: [item: NotificationItem];
}>();

const relativeTime = computed(() => formatRelativeTime(props.item.created_at));
</script>

<style scoped>
.notification-list-item {
  border-left: 3px solid transparent;
  padding-left: 10px;
}

.notification-list-item--unread {
  border-left-color: var(--bw-theme-primary, var(--q-primary));
  background: color-mix(in srgb, var(--bw-theme-primary, var(--q-primary)) 8%, transparent);
}

.notification-list-item__title {
  color: var(--bw-theme-ink, #0f172a);
}

.notification-list-item__body,
.notification-list-item__time {
  color: var(--bw-theme-muted, #64748b);
}
</style>
