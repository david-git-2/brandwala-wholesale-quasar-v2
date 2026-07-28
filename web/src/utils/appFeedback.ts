import { Dialog, Notify } from 'quasar';

type ApiResultLike = {
  success: boolean;
  error?: string;
};

const DEFAULT_ERROR_MESSAGE = 'Something went wrong. Please try again.';

export const showSuccessNotification = (message: string) => {
  Notify.create({
    type: 'positive',
    message,
    position: 'top-right',
    timeout: 2200,
    progress: true,
  });
};

export const showErrorNotification = (message: string) => {
  Notify.create({
    type: 'negative',
    message,
    position: 'top-right',
    timeout: 3000,
    progress: true,
  });
};

export const showWarningNotification = (message: string) => {
  Notify.create({
    type: 'warning',
    message,
    position: 'top-right',
    timeout: 2500,
    progress: true,
  });
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
      },
      ok: {
        label: confirmLabel,
        unelevated: true,
        color: 'primary',
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
