# Tasks & Notifications — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/notifications/` and `web/src/modules/tasks/`  
> **Stores Target**: `web/src/modules/notifications/stores/notificationStore.ts` and `web/src/modules/tasks/stores/`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/notifications/
├── components/
│   ├── NotificationBell.vue              # Top header bell with animated badge
│   ├── NotificationDrawer.vue            # Real-time notification inbox drawer
│   └── NotificationSettingsDialog.vue    # FCM web push & Telegram opt-in modal
├── stores/
│   └── notificationStore.ts              # Realtime subscription & unread state
└── utils/
    └── firebaseMessaging.ts              # Service worker & FCM push client

web/src/modules/tasks/
├── pages/
│   └── TasksPage.vue                     # Operational task management desk
└── components/
    ├── TaskCreateDialog.vue              # Task assignment modal
    └── TaskPriorityChip.vue              # Priority color indicator
```

---

## 2. Server State Management & Realtime Protocol

```typescript
// notificationStore.ts (Pinia)
export const useNotificationStore = defineStore('notifications', {
  state: () => ({
    unreadCount: 0,
    items: [] as NotificationItem[],
    isSubscribed: false,
  }),
  actions: {
    subscribeToRealtime(userId: string) {
      if (this.isSubscribed) return;
      supabase
        .channel(`user-notifications:${userId}`)
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notification_recipients' }, (payload) => {
          this.unreadCount++;
          this.fetchLatestNotifications();
        })
        .subscribe();
      this.isSubscribed = true;
    },
  },
});
```

---

## 3. UI Implementation Patterns & Best Practices

1. **Optimistic Unread Badge Decrement**: Clicking a notification marks it read locally and decrements `unreadCount` immediately before awaiting network response.
2. **Browser Push Permissions**: Never prompt for push permissions on initial page load; show an explicit toggle switch in Settings.
3. **Graceful Browser Fallbacks**: If the browser blocks push (e.g. Brave or Safari non-PWA), display an informative guidance message.
