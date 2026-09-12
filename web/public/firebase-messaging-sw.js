/* global firebase, importScripts, self, clients */

importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-messaging-compat.js');

let messagingInitialized = false;

const initFirebaseMessaging = (config) => {
  if (messagingInitialized || !config) {
    return;
  }

  firebase.initializeApp(config);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const title = payload.notification?.title || 'Notification';
    const body = payload.notification?.body || '';
    const linkPath = payload.data?.link_path || '/';

    self.registration.showNotification(title, {
      body,
      icon: '/favicon.ico',
      data: { link_path: linkPath },
    });
  });

  messagingInitialized = true;
};

self.addEventListener('message', (event) => {
  if (event.data?.type === 'INIT_FIREBASE') {
    initFirebaseMessaging(event.data.config);
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const linkPath = event.notification.data?.link_path || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(linkPath);
      }
      return undefined;
    }),
  );
});
