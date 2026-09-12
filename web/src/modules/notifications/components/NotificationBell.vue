<template>
  <q-btn
    flat
    round
    dense
    aria-label="Notifications"
    data-test="notification-bell"
    class="notification-bell"
  >
    <q-icon name="ph ph-bell" size="18px" class="notification-bell__icon" />
    <q-badge v-if="badgeLabel" color="negative" floating rounded>
      {{ badgeLabel }}
    </q-badge>

    <q-menu anchor="bottom end" self="top end" class="notification-bell__menu">
      <div class="notification-bell__header row items-center justify-between q-px-md q-pt-sm q-pb-xs">
        <div class="text-subtitle2 text-weight-bold">Notifications</div>
        <q-btn
          v-if="notificationStore.unreadCount > 0"
          flat
          dense
          no-caps
          size="sm"
          label="Mark all read"
          class="text-primary"
          data-test="notification-mark-all-read"
          @click.stop="onMarkAllRead"
        />
      </div>

      <NotificationList
        :items="notificationStore.items"
        :loading="notificationStore.loading"
        :skeleton-count="4"
        @select="onSelect"
      />

      <q-separator />

      <div class="notification-bell__footer q-pa-sm">
        <q-btn
          flat
          dense
          no-caps
          class="full-width text-primary"
          label="See all"
          data-test="notification-see-all"
          @click="onSeeAll"
        />
      </div>
    </q-menu>
  </q-btn>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, watch } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { getAppRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';

import NotificationList from './NotificationList.vue';
import { useNotificationStore } from '../stores/notificationStore';
import { resolveNotificationLink } from '../utils/resolveNotificationLink';
import type { NotificationItem } from '../types';

const authStore = useAuthStore();
const notificationStore = useNotificationStore();
const router = useRouter();

const badgeLabel = computed(() => {
  const count = notificationStore.unreadCount;
  if (count <= 0) {
    return null;
  }
  return count > 9 ? '9+' : String(count);
});

const syncNotifications = async () => {
  const tenantId = authStore.tenantId;
  const userId = authStore.user?.id;

  if (!tenantId || !userId) {
    notificationStore.reset();
    return;
  }

  notificationStore.subscribe(userId, tenantId);
  await notificationStore.loadPreview(tenantId);
};

watch(
  () => [authStore.tenantId, authStore.user?.id] as const,
  () => {
    void syncNotifications();
  },
  { immediate: true },
);

onBeforeUnmount(() => {
  notificationStore.unsubscribe();
});

const onMarkAllRead = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId) {
    return;
  }
  await notificationStore.markAllRead(tenantId);
};

const onSelect = async (item: NotificationItem) => {
  if (item.is_unread) {
    await notificationStore.markRead(item.notification_id);
  }

  const target = resolveNotificationLink(item.link_path, authStore.tenantSlug);
  if (target) {
    await router.push(target);
  }
};

const onSeeAll = () => {
  router.push(
    getAppRouteLocation(
      { name: 'notifications-inbox', params: {}, query: {} },
      authStore.tenantSlug,
    ),
  );
};
</script>

<style scoped>
.notification-bell {
  color: var(--shell-ink, var(--bw-theme-ink, #171412));
  background: var(--shell-accent-soft, color-mix(in srgb, var(--q-primary, #488b8f) 10%, transparent));
}

.notification-bell:hover {
  background: color-mix(in srgb, var(--q-primary, #488b8f) 16%, transparent);
}

.notification-bell :deep(.q-icon),
.notification-bell__icon {
  color: inherit;
}

.notification-bell__menu {
  width: min(360px, calc(100vw - 24px));
}

.notification-bell__header {
  border-bottom: 1px solid var(--bw-theme-border, #e2e8f0);
}
</style>
