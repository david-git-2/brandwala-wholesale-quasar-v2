import { getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import { deleteToken, getMessaging, getToken, isSupported, type Messaging } from 'firebase/messaging';

const PUSH_TOKEN_STORAGE_KEY = 'bw.fcm_token.v1';
const SW_READY_TIMEOUT_MS = 10_000;

export type FirebasePublicConfig = {
  apiKey: string;
  authDomain: string;
  projectId: string;
  messagingSenderId: string;
  appId: string;
};

export type WebPushTokenResult = {
  token: string | null;
  permission: NotificationPermission;
  error?: string;
};

export const getFirebasePublicConfig = (): FirebasePublicConfig | null => {
  const apiKey = import.meta.env.VITE_FIREBASE_API_KEY;
  const authDomain = import.meta.env.VITE_FIREBASE_AUTH_DOMAIN;
  const projectId = import.meta.env.VITE_FIREBASE_PROJECT_ID;
  const messagingSenderId = import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID;
  const appId = import.meta.env.VITE_FIREBASE_APP_ID;

  if (!apiKey || !authDomain || !projectId || !messagingSenderId || !appId) {
    return null;
  }

  return {
    apiKey,
    authDomain,
    projectId,
    messagingSenderId,
    appId,
  };
};

export const isFirebaseConfigured = (): boolean => getFirebasePublicConfig() !== null;

const getFirebaseApp = (config: FirebasePublicConfig): FirebaseApp => {
  const existing = getApps()[0];
  if (existing) {
    return existing;
  }
  return initializeApp(config);
};

const waitForServiceWorkerReady = (
  worker: ServiceWorker,
  config: FirebasePublicConfig,
): Promise<void> =>
  new Promise((resolve, reject) => {
    const timeoutId = window.setTimeout(() => {
      cleanup();
      reject(new Error('Firebase service worker did not respond in time. Try Chrome instead of Brave.'));
    }, SW_READY_TIMEOUT_MS);

    const onMessage = (event: MessageEvent) => {
      if (event.data?.type === 'FIREBASE_READY') {
        cleanup();
        resolve();
      }
    };

    const cleanup = () => {
      window.clearTimeout(timeoutId);
      navigator.serviceWorker.removeEventListener('message', onMessage);
    };

    navigator.serviceWorker.addEventListener('message', onMessage);
    worker.postMessage({ type: 'INIT_FIREBASE', config });
  });

const initServiceWorker = async (config: FirebasePublicConfig): Promise<ServiceWorkerRegistration> => {
  const registration = await navigator.serviceWorker.register('/firebase-messaging-sw.js');
  await navigator.serviceWorker.ready;

  const worker = registration.active ?? registration.waiting ?? registration.installing;
  if (!worker) {
    throw new Error('Firebase service worker is not active yet.');
  }

  await waitForServiceWorkerReady(worker, config);

  return registration;
};

let messagingInstance: Messaging | null = null;

const getMessagingInstance = async (): Promise<Messaging | null> => {
  if (!(await isSupported())) {
    return null;
  }

  const config = getFirebasePublicConfig();
  if (!config) {
    return null;
  }

  const app = getFirebaseApp(config);
  const registration = await initServiceWorker(config);

  if (!messagingInstance) {
    messagingInstance = getMessaging(app, { serviceWorkerRegistration: registration });
  }

  return messagingInstance;
};

export const getStoredPushToken = (): string | null => {
  return window.sessionStorage.getItem(PUSH_TOKEN_STORAGE_KEY);
};

const storePushToken = (token: string | null) => {
  if (token) {
    window.sessionStorage.setItem(PUSH_TOKEN_STORAGE_KEY, token);
  } else {
    window.sessionStorage.removeItem(PUSH_TOKEN_STORAGE_KEY);
  }
};

export async function requestWebPushToken(): Promise<WebPushTokenResult> {
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') {
    return { token: null, permission };
  }

  const vapidKey = import.meta.env.VITE_FIREBASE_VAPID_KEY;
  if (!vapidKey) {
    return {
      token: null,
      permission,
      error: 'VITE_FIREBASE_VAPID_KEY is missing from your env file.',
    };
  }

  try {
    const messaging = await getMessagingInstance();
    if (!messaging) {
      return {
        token: null,
        permission,
        error: 'Push is not supported in this browser. Use Chrome on desktop or Android.',
      };
    }

    const token = await getToken(messaging, { vapidKey });
    storePushToken(token);
    return { token, permission };
  } catch (error: unknown) {
    const message =
      error instanceof Error ? error.message : 'Could not register browser notifications.';
    return { token: null, permission, error: message };
  }
}

export async function revokeWebPushToken(): Promise<void> {
  const messaging = await getMessagingInstance();
  if (messaging) {
    await deleteToken(messaging);
  }
  storePushToken(null);
}
