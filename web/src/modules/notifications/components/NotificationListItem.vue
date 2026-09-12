<template>
  <q-item
    v-ripple
    v-close-popup="closePopup"
    clickable
    class="notification-list-item"
    :class="{
      'notification-list-item--unread': item.is_unread,
      'notification-list-item--no-link': !hasLink,
    }"
    data-test="notification-list-item"
    @click="emit('select', item)"
  >
    <q-item-section avatar class="notification-list-item__avatar">
      <q-avatar
        size="36px"
        font-size="16px"
        :color="item.is_unread ? 'primary' : 'grey-3'"
        :text-color="item.is_unread ? 'white' : 'grey-8'"
      >
        <q-icon :name="presentation.icon" />
      </q-avatar>
    </q-item-section>

    <q-item-section>
      <div class="row items-start no-wrap q-gutter-x-xs">
        <q-item-label
          class="notification-list-item__title col"
          :class="{ 'text-weight-bold': item.is_unread, 'text-weight-medium': !item.is_unread }"
          lines="2"
        >
          {{ item.title }}
        </q-item-label>
        <span
          v-if="item.is_unread"
          class="notification-list-item__dot"
          aria-hidden="true"
          data-test="notification-unread-dot"
        />
      </div>

      <q-item-label caption lines="1" class="notification-list-item__kind">
        {{ presentation.kindLabel }}
      </q-item-label>

      <q-item-label caption lines="2" class="notification-list-item__body">
        {{ actionLine }}
      </q-item-label>

      <q-item-label
        v-if="showTenantName"
        caption
        lines="1"
        class="notification-list-item__tenant"
      >
        From {{ item.operating_tenant_name }}
      </q-item-label>
    </q-item-section>

    <q-item-section side top class="notification-list-item__time-col">
      <q-item-label caption class="notification-list-item__time">
        {{ relativeTime }}
      </q-item-label>
    </q-item-section>
  </q-item>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';

import { formatRelativeTime } from '../utils/formatRelativeTime';
import { getNotificationPresentation } from '../utils/notificationPresentation';
import type { NotificationItem } from '../types';

const props = withDefaults(
  defineProps<{
    item: NotificationItem;
    closePopup?: boolean;
  }>(),
  {
    closePopup: false,
  },
);

const emit = defineEmits<{
  select: [item: NotificationItem];
}>();

const route = useRoute();
const presentation = computed(() => getNotificationPresentation(props.item.event_type));
const hasLink = computed(() => Boolean(props.item.link_path?.trim()));
const actionLine = computed(() => props.item.body?.trim() || presentation.value.fallbackAction);
const showTenantName = computed(
  () =>
    route.path.includes('/app/') && Boolean(props.item.operating_tenant_name?.trim()),
);
const relativeTime = computed(() => formatRelativeTime(props.item.created_at));
</script>

<style scoped>
.notification-list-item {
  border-left: 3px solid transparent;
  padding-left: 6px;
}

.notification-list-item--unread {
  border-left-color: var(--bw-theme-primary, var(--q-primary));
  background: color-mix(in srgb, var(--bw-theme-primary, var(--q-primary)) 8%, transparent);
}

.notification-list-item--no-link {
  cursor: default;
}

.notification-list-item__avatar {
  min-width: 44px;
}

.notification-list-item__dot {
  flex-shrink: 0;
  width: 8px;
  height: 8px;
  margin-top: 6px;
  border-radius: 50%;
  background: var(--bw-theme-primary, var(--q-primary));
}

.notification-list-item__title {
  color: var(--bw-theme-ink, #0f172a);
}

.notification-list-item__kind,
.notification-list-item__body,
.notification-list-item__tenant,
.notification-list-item__time {
  color: var(--bw-theme-muted, #64748b);
}

.notification-list-item__time-col {
  min-width: 44px;
  padding-left: 4px;
}

.notification-list-item__time {
  white-space: nowrap;
}
</style>
