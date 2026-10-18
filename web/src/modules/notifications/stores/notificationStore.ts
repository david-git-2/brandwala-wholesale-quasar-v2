import { defineStore } from 'pinia';
import type { RealtimeChannel } from '@supabase/supabase-js';

import { supabase } from 'src/boot/supabase';
import { showErrorNotification } from 'src/utils/appFeedback';

import { notificationRepository } from '../repositories/notificationRepository';
import type { NotificationItem } from '../types';

const PREVIEW_PAGE_SIZE = 8;

type VisibilityHandler = () => void;

const REFRESH_DEBOUNCE_MS = 2000;
const STALE_ON_FOCUS_MS = 60_000;
let refreshTimer: ReturnType<typeof setTimeout> | null = null;
let refreshInFlight = false;
let dirty = false;
let lastRefreshAt = 0;

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

    scheduleRefresh(tenantId: number) {
      if (document.visibilityState !== 'visible') {
        dirty = true;
        return;
      }
      if (refreshTimer) return;
      refreshTimer = setTimeout(() => {
        refreshTimer = null;
        void this.refreshActive(tenantId);
      }, REFRESH_DEBOUNCE_MS);
    },

    async refreshActive(tenantId: number) {
      if (refreshInFlight) {
        dirty = true;
        return;
      }
      refreshInFlight = true;
      dirty = false;
      lastRefreshAt = Date.now();
      try {
        await this.refreshActiveInner(tenantId);
      } finally {
        refreshInFlight = false;
        if (dirty && document.visibilityState === 'visible') this.scheduleRefresh(tenantId);
      }
    },

    async refreshActiveInner(tenantId: number) {
      const listActive =
        this.viewMode === 'page' || this.previewMenuOpen || this.previewLoaded;
      // List queries already return unread_count; skip the extra count call.
      if (!listActive) {
        await this.loadUnreadCount(tenantId);
        return;
      }

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
            this.scheduleRefresh(tenantId);
          },
        )
        .subscribe() as RealtimeChannel;

      this.visibilityHandler = () => {
        if (document.visibilityState !== 'visible') return;
        if (dirty || Date.now() - lastRefreshAt > STALE_ON_FOCUS_MS) {
          this.scheduleRefresh(tenantId);
        }
      };
      document.addEventListener('visibilitychange', this.visibilityHandler);
    },

    unsubscribe() {
      if (refreshTimer) {
        clearTimeout(refreshTimer);
        refreshTimer = null;
      }
      if (this.channel) {
        void supabase.removeChannel(this.channel as unknown as RealtimeChannel);
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
