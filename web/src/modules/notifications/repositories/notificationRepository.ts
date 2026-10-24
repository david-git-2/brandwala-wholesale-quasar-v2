import { supabase } from 'src/boot/supabase';

import { NOTIFICATIONS_ENABLED } from '../notificationsFeature';
import type {
  MarkAllNotificationsReadResult,
  MarkNotificationReadResult,
  NotificationListResult,
  NotificationPreferenceMutationResult,
  NotificationPreferences,
  NotificationUnreadCountResult,
  PushSubscriptionMutationResult,
} from '../types';

const parseJsonResult = <T>(value: unknown): T => value as T;

const emptyListResult = (page = 1, pageSize = 20): NotificationListResult => ({
  data: [],
  meta: {
    total_count: 0,
    page,
    page_size: pageSize,
    total_pages: 0,
    unread_count: 0,
  },
});

export const notificationRepository = {
  async listMyNotificationsPaginated(params: {
    tenantId: number;
    page?: number;
    pageSize?: number;
    unreadOnly?: boolean;
    eventType?: string | null;
  }): Promise<NotificationListResult> {
    if (!NOTIFICATIONS_ENABLED) {
      return emptyListResult(params.page ?? 1, params.pageSize ?? 20);
    }

    const { data, error } = await supabase.rpc('list_my_notifications_paginated', {
      p_tenant_id: params.tenantId,
      p_page: params.page ?? 1,
      p_page_size: params.pageSize ?? 20,
      p_unread_only: params.unreadOnly ?? false,
      p_event_type: params.eventType ?? null,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<NotificationListResult>(data);
  },

  async getMyUnreadCount(tenantId: number): Promise<number> {
    if (!NOTIFICATIONS_ENABLED) {
      return 0;
    }

    const { data, error } = await supabase.rpc('get_my_notification_unread_count', {
      p_tenant_id: tenantId,
    });

    if (error) {
      throw error;
    }

    const result = parseJsonResult<NotificationUnreadCountResult>(data);
    return Number(result.unread_count ?? 0);
  },

  async markNotificationRead(notificationId: string): Promise<MarkNotificationReadResult> {
    if (!NOTIFICATIONS_ENABLED) {
      return { success: true, notification_id: notificationId };
    }

    const { data, error } = await supabase.rpc('mark_notification_read', {
      p_notification_id: notificationId,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<MarkNotificationReadResult>(data);
  },

  async markAllMyNotificationsRead(tenantId: number): Promise<MarkAllNotificationsReadResult> {
    if (!NOTIFICATIONS_ENABLED) {
      return { success: true, updated_count: 0 };
    }

    const { data, error } = await supabase.rpc('mark_all_my_notifications_read', {
      p_tenant_id: tenantId,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<MarkAllNotificationsReadResult>(data);
  },

  async getMyNotificationPreferences(): Promise<NotificationPreferences> {
    if (!NOTIFICATIONS_ENABLED) {
      return {
        user_id: '',
        channel_telegram: false,
        channel_push: false,
        channel_email: false,
        event_preferences: {},
        updated_at: null,
      };
    }

    const { data, error } = await supabase.rpc('get_my_notification_preferences');

    if (error) {
      throw error;
    }

    return parseJsonResult<NotificationPreferences>(data);
  },

  async upsertMyNotificationPreferences(channelPush: boolean): Promise<NotificationPreferenceMutationResult> {
    if (!NOTIFICATIONS_ENABLED) {
      return { success: true, channel_push: channelPush };
    }

    const { data, error } = await supabase.rpc('upsert_my_notification_preferences', {
      p_channel_push: channelPush,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<NotificationPreferenceMutationResult>(data);
  },

  async saveMyPushSubscription(fcmToken: string, platform = 'web'): Promise<PushSubscriptionMutationResult> {
    if (!NOTIFICATIONS_ENABLED) {
      return { success: true };
    }

    const { data, error } = await supabase.rpc('save_my_push_subscription', {
      p_fcm_token: fcmToken,
      p_platform: platform,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<PushSubscriptionMutationResult>(data);
  },

  async deleteMyPushSubscription(fcmToken: string): Promise<PushSubscriptionMutationResult> {
    if (!NOTIFICATIONS_ENABLED) {
      return { success: true };
    }

    const { data, error } = await supabase.rpc('delete_my_push_subscription', {
      p_fcm_token: fcmToken,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<PushSubscriptionMutationResult>(data);
  },
};
