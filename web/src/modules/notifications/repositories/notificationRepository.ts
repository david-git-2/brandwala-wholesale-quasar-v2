import { supabase } from 'src/boot/supabase';

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

export const notificationRepository = {
  async listMyNotificationsPaginated(params: {
    tenantId: number;
    page?: number;
    pageSize?: number;
    unreadOnly?: boolean;
    eventType?: string | null;
  }): Promise<NotificationListResult> {
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
    const { data, error } = await supabase.rpc('mark_notification_read', {
      p_notification_id: notificationId,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<MarkNotificationReadResult>(data);
  },

  async markAllMyNotificationsRead(tenantId: number): Promise<MarkAllNotificationsReadResult> {
    const { data, error } = await supabase.rpc('mark_all_my_notifications_read', {
      p_tenant_id: tenantId,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<MarkAllNotificationsReadResult>(data);
  },

  async getMyNotificationPreferences(): Promise<NotificationPreferences> {
    const { data, error } = await supabase.rpc('get_my_notification_preferences');

    if (error) {
      throw error;
    }

    return parseJsonResult<NotificationPreferences>(data);
  },

  async upsertMyNotificationPreferences(channelPush: boolean): Promise<NotificationPreferenceMutationResult> {
    const { data, error } = await supabase.rpc('upsert_my_notification_preferences', {
      p_channel_push: channelPush,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<NotificationPreferenceMutationResult>(data);
  },

  async saveMyPushSubscription(fcmToken: string, platform = 'web'): Promise<PushSubscriptionMutationResult> {
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
    const { data, error } = await supabase.rpc('delete_my_push_subscription', {
      p_fcm_token: fcmToken,
    });

    if (error) {
      throw error;
    }

    return parseJsonResult<PushSubscriptionMutationResult>(data);
  },
};
