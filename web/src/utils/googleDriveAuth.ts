import { supabase } from 'src/boot/supabase';
import {
  captureGoogleDriveTokensFromSession,
  clearGoogleDriveTokens,
  getStoredGoogleDriveToken,
} from './googleDriveTokenStore';

export const GOOGLE_DRIVE_FILE_SCOPE = 'https://www.googleapis.com/auth/drive.file';
export const GOOGLE_DRIVE_AUTH_CALLBACK_FLAG = 'drive_auth';

export class GoogleDriveAuthRequiredError extends Error {
  constructor(
    message = 'Google Drive access required. Sign in with Google and allow Drive permission.',
  ) {
    super(message);
    this.name = 'GoogleDriveAuthRequiredError';
  }
}

export function isGoogleDrivePermissionError(status: number, body?: string): boolean {
  if (status !== 403) return false;
  const normalized = (body || '').toLowerCase();
  return (
    normalized.includes('insufficient') ||
    normalized.includes('access_not_configured') ||
    normalized.includes('forbidden') ||
    normalized === ''
  );
}

export function throwIfGoogleDrivePermissionDenied(
  status: number,
  body: string,
  context: string,
): void {
  if (!isGoogleDrivePermissionError(status, body)) return;

  throw new GoogleDriveAuthRequiredError(
    `${context}. Sign in with Google as ${getDriveSyncAdminEmail()} and allow Drive access when prompted.`,
  );
}

function isDriveFeatureEnabled(): boolean {
  const flag = import.meta.env.VITE_GOOGLE_DRIVE_UPLOAD_ENABLED;

  return String(flag ?? '').toLowerCase() === 'true';
}

export function getDriveSyncAdminEmail(): string {
  const configured = import.meta.env.VITE_GOOGLE_DRIVE_ADMIN_EMAIL;

  return (configured || 'tradeflowbd2026@gmail.com').trim().toLowerCase();
}

export function canShowDriveSyncForUser(email: string | null | undefined): boolean {
  if (!isDriveFeatureEnabled()) return false;
  const normalized = email?.trim().toLowerCase();
  if (!normalized) return false;
  return normalized === getDriveSyncAdminEmail();
}

export function getGoogleOAuthDriveOptions():
  { scopes: string; queryParams: { access_type: string; prompt: string } } | Record<string, never> {
  if (!isDriveFeatureEnabled()) return {};

  return {
    scopes: GOOGLE_DRIVE_FILE_SCOPE,
    queryParams: {
      access_type: 'offline',
      prompt: 'consent',
    },
  };
}

function getOAuthCallbackBaseUrl(): string {
  const configured = import.meta.env.VITE_PRODUCTION_APP_URL || import.meta.env.VITE_LOCAL_APP_URL;

  if (configured) {
    return String(configured).replace(/\/$/, '');
  }

  if (typeof window !== 'undefined') {
    return window.location.origin;
  }

  return '';
}

export async function getGoogleDriveAccessToken(): Promise<string> {
  const {
    data: { session },
    error,
  } = await supabase.auth.getSession();

  if (error || !session?.user) {
    throw new GoogleDriveAuthRequiredError('Sign in again to sync to Google Drive.');
  }

  captureGoogleDriveTokensFromSession(session);

  const storedToken = getStoredGoogleDriveToken(session.user.id, session.user.email);
  if (storedToken) {
    return storedToken;
  }

  if (session.provider_token?.trim()) {
    return session.provider_token.trim();
  }

  throw new GoogleDriveAuthRequiredError(
    'Allow Google Drive access when prompted, then try sync again.',
  );
}

export async function requestGoogleDriveAccess(redirectPath?: string): Promise<void> {
  const callbackBaseUrl = getOAuthCallbackBaseUrl();
  const callbackSearchParams = new URLSearchParams({
    scope: 'app',
    [GOOGLE_DRIVE_AUTH_CALLBACK_FLAG]: '1',
  });

  if (redirectPath?.trim()) {
    callbackSearchParams.set('redirect', redirectPath.trim());
  }

  clearGoogleDriveTokens();

  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${callbackBaseUrl}/auth/callback?${callbackSearchParams.toString()}`,
      scopes: GOOGLE_DRIVE_FILE_SCOPE,
      queryParams: {
        access_type: 'offline',
        prompt: 'consent',
        include_granted_scopes: 'true',
      },
    },
  });

  if (error) throw error;
}
