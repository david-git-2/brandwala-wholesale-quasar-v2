<template>
  <q-page class="bw-page notification-inbox-page">
    <div class="bw-page__stack">
      <q-card flat bordered class="notification-inbox-page__card">
        <q-card-section class="row items-center q-col-gutter-sm q-pb-sm">
          <div class="col-auto">
            <q-toggle
              v-model="unreadOnly"
              dense
              label="Unread only"
              data-test="notification-unread-filter"
              @update:model-value="onUnreadFilterChange"
            />
          </div>
          <q-space />
          <div class="col-auto">
            <q-btn
              flat
              dense
              no-caps
              label="Mark all read"
              color="primary"
              :disable="notificationStore.unreadCount === 0"
              data-test="notification-inbox-mark-all-read"
              @click="onMarkAllRead"
            />
          </div>
        </q-card-section>

        <q-separator />

        <NotificationList
          :items="notificationStore.items"
          :loading="notificationStore.loading"
          :skeleton-count="6"
          :constrained="false"
          @select="onSelect"
        />

        <q-separator v-if="notificationStore.totalPages > 1" />

        <q-card-section
          v-if="notificationStore.totalPages > 1"
          class="row items-center justify-center q-pt-sm q-pb-md"
        >
          <q-pagination
            v-model="currentPage"
            :max="notificationStore.totalPages"
            :max-pages="7"
            direction-links
            boundary-links
            color="primary"
            data-test="notification-inbox-pagination"
            @update:model-value="onPageChange"
          />
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';

import NotificationList from '../components/NotificationList.vue';
import { useNotificationStore } from '../stores/notificationStore';
import { resolveNotificationLink } from '../utils/resolveNotificationLink';
import type { NotificationItem } from '../types';

const authStore = useAuthStore();
const notificationStore = useNotificationStore();
const router = useRouter();

const unreadOnly = ref(notificationStore.unreadOnly);
const currentPage = ref(notificationStore.page);

const loadInbox = async (page = currentPage.value) => {
  const tenantId = authStore.tenantId;
  if (!tenantId) {
    return;
  }

  currentPage.value = page;
  await notificationStore.loadPage(tenantId, page);
};

watch(
  () => authStore.tenantId,
  () => {
    currentPage.value = 1;
    void loadInbox(1);
  },
);

onMounted(() => {
  void loadInbox(1);
});

const onUnreadFilterChange = (value: boolean) => {
  notificationStore.setUnreadOnly(value);
  currentPage.value = 1;
  void loadInbox(1);
};

const onPageChange = (page: number) => {
  void loadInbox(page);
};

const onMarkAllRead = async () => {
  const tenantId = authStore.tenantId;
  if (!tenantId) {
    return;
  }
  await notificationStore.markAllRead(tenantId);
  await loadInbox(currentPage.value);
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
</script>

<style scoped>
.notification-inbox-page__card {
  border-radius: var(--bw-radius-md, 12px);
}
</style>
