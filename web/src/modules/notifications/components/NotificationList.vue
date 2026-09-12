<template>
  <div class="notification-list">
    <template v-if="loading">
      <q-item v-for="index in skeletonCount" :key="index" dense>
        <q-item-section avatar>
          <q-skeleton type="QAvatar" size="36px" />
        </q-item-section>
        <q-item-section>
          <q-skeleton type="text" width="70%" />
          <q-skeleton type="text" width="45%" class="q-mt-xs" />
        </q-item-section>
      </q-item>
    </template>

    <div
      v-else-if="!items.length"
      class="notification-list__empty column items-center justify-center q-pa-lg text-center"
      data-test="notification-list-empty"
    >
      <q-icon name="ph ph-bell-slash" size="28px" color="grey-5" />
      <div class="text-caption text-grey-6 q-mt-sm">{{ emptyMessage }}</div>
    </div>

    <q-list
      v-else
      dense
      separator
      class="notification-list__items"
      :class="{ 'notification-list__items--constrained': constrained }"
    >
      <NotificationListItem
        v-for="item in items"
        :key="item.recipient_id"
        :item="item"
        :close-popup="closePopupOnSelect"
        @select="emit('select', $event)"
      />
    </q-list>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import NotificationListItem from './NotificationListItem.vue';
import type { NotificationItem } from '../types';

const props = withDefaults(
  defineProps<{
    items: NotificationItem[];
    loading?: boolean;
    skeletonCount?: number;
    constrained?: boolean;
    unreadOnly?: boolean;
    closePopupOnSelect?: boolean;
  }>(),
  {
    constrained: true,
    skeletonCount: 4,
    unreadOnly: false,
    closePopupOnSelect: false,
  },
);

const emit = defineEmits<{
  select: [item: NotificationItem];
}>();

const emptyMessage = computed(() =>
  props.unreadOnly ? 'You are caught up' : 'No notifications yet',
);
</script>

<style scoped>
.notification-list__empty {
  min-height: 120px;
}

.notification-list__items--constrained {
  max-height: 360px;
  overflow-y: auto;
}
</style>
