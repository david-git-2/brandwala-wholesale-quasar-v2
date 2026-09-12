export type NotificationItem = {
  recipient_id: string;
  notification_id: string;
  read_at: string | null;
  is_unread: boolean;
  event_type: string;
  title: string;
  body: string | null;
  link_path: string | null;
  entity_type: string | null;
  entity_id: string | null;
  parent_tenant_id: number;
  operating_tenant_id: number | null;
  created_at: string;
};

export type NotificationListMeta = {
  total_count: number;
  page: number;
  page_size: number;
  total_pages: number;
  unread_count: number;
};

export type NotificationListResult = {
  data: NotificationItem[];
  meta: NotificationListMeta;
};

export type MarkNotificationReadResult = {
  success: boolean;
  notification_id?: string;
  read_at?: string;
  error?: string;
};

export type MarkAllNotificationsReadResult = {
  success: boolean;
  updated_count?: number;
  error?: string;
};

export type NotificationUnreadCountResult = {
  unread_count: number;
};

export type NotificationPreferences = {
  user_id: string;
  channel_telegram: boolean;
  channel_push: boolean;
  channel_email: boolean;
  event_preferences: Record<string, unknown>;
  updated_at: string | null;
};

export type NotificationPreferenceMutationResult = {
  success: boolean;
  channel_push?: boolean;
  updated_at?: string;
  error?: string;
};

export type PushSubscriptionMutationResult = {
  success: boolean;
  subscription_id?: string;
  channel_push?: boolean;
  remaining_subscriptions?: number;
  error?: string;
};
