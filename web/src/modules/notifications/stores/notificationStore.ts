import { defineStore } from 'pinia';
import type { RealtimeChannel } from '@supabase/supabase-js';

import { supabase } from 'src/boot/supabase';
import { showErrorNotification } from 'src/utils/appFeedback';

import { notificationRepository } from '../repositories/notificationRepository';
import type { NotificationItem } from '../types';

const PREVIEW_PAGE_SIZE = 8;

type VisibilityHandler = () => void;

const mapReadState = (items: NotificationItem[], notificationId: string, now: string) =>
  items.map((item) =>
    item.notification_id === notificationId
      ? { ...item, read_at: now, is_unread: false }
      : item,
  );

const mapAllReadState = (items: NotificationItem[], now: string) =>
  items.map((item) => ({
    ...item,
    read_at: item.read_at ?? now,
    is_unread: false,
  }));

export const useNotificationStore = defineStore('notifications', {
  state: () => ({
    previewItems: [] as NotificationItem[],
    inboxItems: [] as NotificationItem[],
    unreadCount: 0,
    previewLoading: false,
    inboxLoading: false,
    previewLoaded: false,
    inboxLoaded: false,
    previewMenuOpen: false,
    page: 1,
    pageSize: 20,
    totalPages: 0,
    totalCount: 0,
    unreadOnly: false,
    viewMode: 'preview' as 'preview' | 'page',
    channel: null as RealtimeChannel | null,
    subscribedUserId: null as string | null,
    subscribedTenantId: null as number | null,
    visibilityHandler: null as VisibilityHandler | null,
  }),

  actions: {
    async loadUnreadCount(tenantId: number) {
      this.unreadCount = await notificationRepository.getMyUnreadCount(tenantId);
    },

    async loadPreview(tenantId: number, options?: { silent?: boolean }) {
      const silent = options?.silent === true;
      if (!silent || !this.previewLoaded) {
        this.previewLoading = true;
      }

      this.viewMode = 'preview';

      try {
        const result = await notificationRepository.listMyNotificationsPaginated({
          tenantId,
          page: 1,
          pageSize: PREVIEW_PAGE_SIZE,
          unreadOnly: false,
        });
        this.previewItems = result.data;
        this.unreadCount = result.meta.unread_count;
        this.previewLoaded = true;
      } catch (error: unknown) {
        showErrorNotification((error as Error).message || 'Failed to load notifications');
      } finally {
        this.previewLoading = false;
      }
    },

    async loadPage(tenantId: number, page = 1, options?: { silent?: boolean }) {
      const silent = options?.silent === true;
      if (!silent || !this.inboxLoaded) {
        this.inboxLoading = true;
      }

      this.viewMode = 'page';

      try {
        const result = await notificationRepository.listMyNotificationsPaginated({
          tenantId,
          page,
          pageSize: this.pageSize,
          unreadOnly: this.unreadOnly,
        });
        this.inboxItems = result.data;
        this.page = result.meta.page;
        this.totalPages = result.meta.total_pages;
        this.totalCount = result.meta.total_count;
        this.unreadCount = result.meta.unread_count;
        this.inboxLoaded = true;
      } catch (error: unknown) {
        showErrorNotification((error as Error).message || 'Failed to load notifications');
      } finally {
        this.inboxLoading = false;
      }
    },

    setPreviewMenuOpen(open: boolean) {
      this.previewMenuOpen = open;
    },

    async refreshActive(tenantId: number) {
      await this.loadUnreadCount(tenantId);

      if (this.viewMode === 'page') {
        await this.loadPage(tenantId, this.page, {
          silent: this.inboxLoaded && this.inboxItems.length > 0,
        });
        return;
      }

      if (this.previewMenuOpen || this.previewLoaded) {
        await this.loadPreview(tenantId, {
          silent: this.previewLoaded && this.previewItems.length > 0,
        });
      }
    },

    async markRead(notificationId: string) {
      const previousPreviewItems = this.previewItems.map((item) => ({ ...item }));
      const previousInboxItems = this.inboxItems.map((item) => ({ ...item }));
      const previousUnreadCount = this.unreadCount;
      const now = new Date().toISOString();

      const wasUnread =
        previousPreviewItems.some(
          (item) => item.notification_id === notificationId && item.is_unread,
        ) ||
        previousInboxItems.some(
          (item) => item.notification_id === notificationId && item.is_unread,
        );

      this.previewItems = mapReadState(this.previewItems, notificationId, now);
      this.inboxItems = mapReadState(this.inboxItems, notificationId, now);

      if (wasUnread) {
        this.unreadCount = Math.max(0, this.unreadCount - 1);
      }

      try {
        const result = await notificationRepository.markNotificationRead(notificationId);
        if (!result.success) {
          throw new Error(result.error || 'Failed to mark notification as read');
        }
      } catch (error: unknown) {
        this.previewItems = previousPreviewItems;
        this.inboxItems = previousInboxItems;
        this.unreadCount = previousUnreadCount;
        showErrorNotification((error as Error).message || 'Failed to mark notification as read');
      }
    },

    async markAllRead(tenantId: number) {
      const previousPreviewItems = this.previewItems.map((item) => ({ ...item }));
      const previousInboxItems = this.inboxItems.map((item) => ({ ...item }));
      const previousUnreadCount = this.unreadCount;
      const now = new Date().toISOString();

      this.previewItems = mapAllReadState(this.previewItems, now);
      this.inboxItems = mapAllReadState(this.inboxItems, now);
      this.unreadCount = 0;

      try {
        const result = await notificationRepository.markAllMyNotificationsRead(tenantId);
        if (!result.success) {
          throw new Error(result.error || 'Failed to mark all notifications as read');
        }
      } catch (error: unknown) {
        this.previewItems = previousPreviewItems;
        this.inboxItems = previousInboxItems;
        this.unreadCount = previousUnreadCount;
        showErrorNotification((error as Error).message || 'Failed to mark all notifications as read');
      }
    },

    setUnreadOnly(value: boolean) {
      this.unreadOnly = value;
      this.page = 1;
    },

    subscribe(userId: string, tenantId: number) {
      if (
        this.subscribedUserId === userId &&
        this.subscribedTenantId === tenantId &&
        this.channel
      ) {
        return;
      }

      this.unsubscribe();

      this.subscribedUserId = userId;
      this.subscribedTenantId = tenantId;

      this.channel = supabase
        .channel(`notification-recipients:${userId}:${tenantId}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'notification_recipients',
            filter: `user_id=eq.${userId}`,
          },
          () => {
            void this.refreshActive(tenantId);
          },
        )
        .subscribe();

      this.visibilityHandler = () => {
        if (document.visibilityState === 'visible') {
          void this.refreshActive(tenantId);
        }
      };
      document.addEventListener('visibilitychange', this.visibilityHandler);
    },

    unsubscribe() {
      if (this.channel) {
        void supabase.removeChannel(this.channel);
        this.channel = null;
      }

      if (this.visibilityHandler) {
        document.removeEventListener('visibilitychange', this.visibilityHandler);
        this.visibilityHandler = null;
      }

      this.subscribedUserId = null;
      this.subscribedTenantId = null;
    },

    reset() {
      this.unsubscribe();
      this.previewItems = [];
      this.inboxItems = [];
      this.unreadCount = 0;
      this.previewLoading = false;
      this.inboxLoading = false;
      this.previewLoaded = false;
      this.inboxLoaded = false;
      this.previewMenuOpen = false;
      this.page = 1;
      this.totalPages = 0;
      this.totalCount = 0;
      this.unreadOnly = false;
      this.viewMode = 'preview';
    },
  },
});
