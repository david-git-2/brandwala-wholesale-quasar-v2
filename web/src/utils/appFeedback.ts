import { Dialog, Notify } from 'quasar'

type ApiResultLike = {
  success: boolean
  error?: string
}

const DEFAULT_ERROR_MESSAGE = 'Something went wrong. Please try again.'

export const showSuccessNotification = (message: string) => {
  Notify.create({
    type: 'positive',
    message,
    position: 'top-right',
    timeout: 2200,
    progress: true,
  })
}

export const showWarningDialog = (
  message: string,
  title = 'Warning',
) => {
  Dialog.create({
    title,
    message,
    ok: {
      label: 'Close',
      flat: true,
      color: 'primary',
    },
    persistent: false,
  })
}

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
      .onDismiss(() => resolve(false))
  })

export const handleApiFailure = (
  result: ApiResultLike,
  fallbackMessage = DEFAULT_ERROR_MESSAGE,
  title = 'Request failed',
) => {
  if (result.success) return

  showWarningDialog(result.error ?? fallbackMessage, title)
}
