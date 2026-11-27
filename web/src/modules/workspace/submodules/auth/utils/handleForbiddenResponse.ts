import { showWarningDialog } from 'src/utils/appFeedback';

const recentDialogs = new Map<string, number>();
const DIALOG_DEDUP_MS = 2000;

export function wasForbiddenDialogRecentlyShown(message: string): boolean {
  const lastShown = recentDialogs.get(message);
  if (lastShown && Date.now() - lastShown < DIALOG_DEDUP_MS) {
    return true;
  }
  return false;
}

export async function handleForbiddenResponse(response: Response) {
  let message = 'You do not have permission to perform this action.';

  try {
    const cloned = response.clone();
    const body = await cloned.json();
    if (body) {
      message = body.message || body.error || body.hint || body.details || message;
    }
  } catch {
    // Fail silent and use fallback message if JSON parsing fails
  }

  if (wasForbiddenDialogRecentlyShown(message)) {
    return;
  }

  recentDialogs.set(message, Date.now());
  showWarningDialog(message, 'Access denied');
}
