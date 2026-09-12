<template>
  <q-page class="bw-page notification-preferences-page">
    <div class="bw-page__stack">
      <q-card flat bordered class="notification-preferences-page__card">
        <q-card-section>
          <div class="text-subtitle1 text-weight-bold q-mb-xs">Browser alerts</div>
          <div class="text-caption text-grey-7 q-mb-md">
            Get a desktop alert when this tab is closed. Chrome only. In-app alerts always stay on.
          </div>

          <q-banner v-if="!firebaseConfigured" dense rounded class="bg-grey-2 text-grey-9 q-mb-md">
            Browser alerts are not available in this environment yet. Ask your admin if you need them on production.
          </q-banner>

          <q-banner v-else-if="permissionDenied" dense rounded class="bg-grey-2 text-grey-9 q-mb-md">
            Your browser blocked alerts for this site. Allow them in site settings, then try again.
          </q-banner>

          <div class="row items-center justify-between q-gutter-sm">
            <div>
              <div class="text-body2 text-weight-medium">Enable browser alerts</div>
              <div class="text-caption text-grey-6">Optional desktop alerts outside the app</div>
            </div>
            <q-toggle
              v-model="pushEnabled"
              :disable="!firebaseConfigured || saving"
              :loading="saving"
              color="primary"
              data-test="notification-push-toggle"
              @update:model-value="onTogglePush"
            />
          </div>
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';

import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

import { notificationRepository } from '../repositories/notificationRepository';
import {
  getStoredPushToken,
  isFirebaseConfigured,
  requestWebPushToken,
  revokeWebPushToken,
} from '../utils/firebaseMessaging';

const pushEnabled = ref(false);
const saving = ref(false);
const firebaseConfigured = isFirebaseConfigured();
const permissionDenied = ref(false);

const loadPreferences = async () => {
  const prefs = await notificationRepository.getMyNotificationPreferences();
  pushEnabled.value = Boolean(prefs.channel_push);
  permissionDenied.value =
    typeof Notification !== 'undefined' && Notification.permission === 'denied';
};

onMounted(() => {
  void loadPreferences().catch((error: unknown) => {
    showErrorNotification((error as Error).message || 'Failed to load browser alert settings');
  });
});

const onTogglePush = async (enabled: boolean) => {
  saving.value = true;
  try {
    if (enabled) {
      const { token, permission, error } = await requestWebPushToken();
      permissionDenied.value = permission === 'denied';

      if (!token) {
        pushEnabled.value = false;
        if (permission === 'denied') {
          showErrorNotification('Allow alerts in your browser settings to enable browser alerts.');
        } else {
          showErrorNotification(error || 'Could not register browser alerts.');
        }
        return;
      }

      const result = await notificationRepository.saveMyPushSubscription(token);
      if (!result.success) {
        throw new Error(result.error || 'Failed to save push subscription');
      }

      showSuccessNotification('Browser alerts enabled');
      return;
    }

    const storedToken = getStoredPushToken();
    if (storedToken) {
      const result = await notificationRepository.deleteMyPushSubscription(storedToken);
      if (!result.success) {
        throw new Error(result.error || 'Failed to remove push subscription');
      }
    } else {
      await notificationRepository.upsertMyNotificationPreferences(false);
    }

    await revokeWebPushToken();
    showSuccessNotification('Browser alerts disabled');
  } catch (error: unknown) {
    pushEnabled.value = !enabled;
    showErrorNotification((error as Error).message || 'Failed to update browser alert settings');
  } finally {
    saving.value = false;
    await loadPreferences();
  }
};
</script>

<style scoped>
.notification-preferences-page__card {
  border-radius: var(--bw-radius-md, 12px);
}
</style>
