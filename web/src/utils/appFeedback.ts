import { Dialog } from 'quasar';

import { notify } from 'src/utils/tfNotify';

type ApiResultLike = {
  success: boolean;
  error?: string;
};

const DEFAULT_ERROR_MESSAGE = 'Something went wrong. Please try again.';

export const showSuccessNotification = (message: string) => {
  notify.success(message);
};

export const showErrorNotification = (message: string) => {
  notify.error(message);
};

export const showWarningNotification = (message: string) => {
  notify.warn(message);
};

export const showWarningDialog = (message: string, title = 'Warning') => {
  Dialog.create({
    title,
    message,
    ok: {
      label: 'Close',
      flat: true,
      color: 'primary',
    },
    persistent: false,
  });
};

export const requestConfirmation = (
  message: string,
  title = 'Please confirm',
  confirmLabel = 'Confirm',
) =>
  new Promise<boolean>((resolve) => {
    Dialog.create({
      title,
      message,
      cancel: {
        label: 'Cancel',
        flat: true,
        color: 'grey-7',
        noCaps: true,
      },
      ok: {
        label: confirmLabel,
        outline: true,
        color: 'primary',
        noCaps: true,
      },
      persistent: true,
    })
      .onOk(() => resolve(true))
      .onCancel(() => resolve(false))
      .onDismiss(() => resolve(false));
  });

export const handleApiFailure = (
  result: ApiResultLike,
  fallbackMessage = DEFAULT_ERROR_MESSAGE,
  title = 'Request failed',
) => {
  if (result.success) return;

  showWarningDialog(result.error ?? fallbackMessage, title);
};

/**
 * Parses raw Supabase/PostgreSQL errors into user-friendly messages.
 * Falls back to the provided fallbackMessage if the error is unknown.
 */
export const parseSupabaseError = (
  error: any,
  fallbackMessage = DEFAULT_ERROR_MESSAGE
): string => {
  if (!error) return fallbackMessage;

  // 1. Handle Known Postgres Error Codes
  if (error.code === '23505') return 'This record already exists.';
  if (error.code === '42501') return 'You do not have permission to perform this action.';
  if (error.code === '23503') return 'Cannot delete this record because it is referenced elsewhere.';
  
  // 2. Handle Custom RPC exceptions thrown via `RAISE EXCEPTION 'Friendly message'`
  // We want to pass these through as long as they don't look like raw SQL errors.
  if (
    error.message && 
    typeof error.message === 'string' &&
    !error.message.includes('relation') && 
    !error.message.includes('syntax') &&
    !error.message.includes('column')
  ) {
     return error.message; 
  }

  // 3. Fallback for raw/unknown errors
  console.error("Supabase API Error:", error);
  return fallbackMessage;
};
