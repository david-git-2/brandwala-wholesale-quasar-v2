const STORAGE_KEY = 'tradeflow_google_drive_tokens_v1';

type StoredGoogleDriveTokens = {
  userId: string;
  email: string;
  providerToken: string;
  providerRefreshToken?: string;
  savedAt: number;
};

function readStore(): StoredGoogleDriveTokens | null {
  if (typeof window === 'undefined') return null;

  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return null;

  try {
    const parsed = JSON.parse(raw) as StoredGoogleDriveTokens;
    if (!parsed.userId || !parsed.providerToken) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function clearGoogleDriveTokens(): void {
  if (typeof window === 'undefined') return;
  window.localStorage.removeItem(STORAGE_KEY);
}

export function saveGoogleDriveTokens(input: {
  userId: string;
  email: string;
  providerToken: string;
  providerRefreshToken?: string | null;
}): void {
  if (typeof window === 'undefined') return;

  const payload: StoredGoogleDriveTokens = {
    userId: input.userId,
    email: input.email.trim().toLowerCase(),
    providerToken: input.providerToken.trim(),
    savedAt: Date.now(),
    ...(input.providerRefreshToken?.trim()
      ? { providerRefreshToken: input.providerRefreshToken.trim() }
      : {}),
  };

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
}

export function getStoredGoogleDriveToken(userId: string, email?: string | null): string | null {
  const stored = readStore();
  if (!stored || stored.userId !== userId) return null;

  const normalizedEmail = email?.trim().toLowerCase();
  if (normalizedEmail && stored.email !== normalizedEmail) return null;

  return stored.providerToken.trim() || null;
}

export function captureGoogleDriveTokensFromSession(
  session: {
    user: { id: string; email?: string | null };
    provider_token?: string | null;
    provider_refresh_token?: string | null;
  } | null,
): boolean {
  const providerToken = session?.provider_token?.trim();
  if (!session?.user?.id || !providerToken) return false;

  saveGoogleDriveTokens({
    userId: session.user.id,
    email: session.user.email || '',
    providerToken,
    ...(session.provider_refresh_token != null && session.provider_refresh_token.trim()
      ? { providerRefreshToken: session.provider_refresh_token }
      : {}),
  });

  return true;
}
