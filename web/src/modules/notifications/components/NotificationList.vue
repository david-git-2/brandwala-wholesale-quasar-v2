<template>
  <div class="notification-list">
    <template v-if="loading">
      <q-item v-for="index in skeletonCount" :key="index" dense>
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
      <div class="text-caption text-grey-6 q-mt-sm">No notifications yet</div>
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
        @select="emit('select', $event)"
      />
    </q-list>
  </div>
</template>

<script setup lang="ts">
import NotificationListItem from './NotificationListItem.vue';
import type { NotificationItem } from '../types';

withDefaults(
  defineProps<{
    items: NotificationItem[];
    loading?: boolean;
    skeletonCount?: number;
    constrained?: boolean;
  }>(),
  {
    constrained: true,
    skeletonCount: 4,
  },
);

const emit = defineEmits<{
  select: [item: NotificationItem];
}>();
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
