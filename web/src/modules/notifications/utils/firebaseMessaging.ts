import { getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import { deleteToken, getMessaging, getToken, isSupported, type Messaging } from 'firebase/messaging';

const PUSH_TOKEN_STORAGE_KEY = 'bw.fcm_token.v1';

export type FirebasePublicConfig = {
  apiKey: string;
  authDomain: string;
  projectId: string;
  messagingSenderId: string;
  appId: string;
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

const initServiceWorker = async (config: FirebasePublicConfig): Promise<ServiceWorkerRegistration> => {
  const registration = await navigator.serviceWorker.register('/firebase-messaging-sw.js');
  await navigator.serviceWorker.ready;

  const worker = registration.active ?? registration.waiting ?? registration.installing;
  worker?.postMessage({ type: 'INIT_FIREBASE', config });

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

export async function requestWebPushToken(): Promise<{ token: string | null; permission: NotificationPermission }> {
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') {
    return { token: null, permission };
  }

  const messaging = await getMessagingInstance();
  const vapidKey = import.meta.env.VITE_FIREBASE_VAPID_KEY;

  if (!messaging || !vapidKey) {
    return { token: null, permission };
  }

  const token = await getToken(messaging, { vapidKey });
  storePushToken(token);
  return { token, permission };
}

export async function revokeWebPushToken(): Promise<void> {
  const messaging = await getMessagingInstance();
  if (messaging) {
    await deleteToken(messaging);
  }
  storePushToken(null);
}
