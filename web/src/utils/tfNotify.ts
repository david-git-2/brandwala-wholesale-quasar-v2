import { Notify, Screen, type QNotifyCreateOptions, type QNotifyUpdateOptions } from 'quasar';

export type TfNotifyErrorOpts = {
  retry?: () => void;
  details?: () => void;
  persistent?: boolean;
};

type TfNotifyVisual = 'success' | 'error' | 'warning' | 'info';

let idCounter = 0;

const DISMISS_ACTION = {
  icon: 'ph ph-x',
  round: true,
  dense: true,
  size: 'sm' as const,
  'aria-label': 'Dismiss',
};

function notifyPosition(): QNotifyCreateOptions['position'] {
  return Screen.lt.sm ? 'top' : 'top-right';
}

function iconFor(visual: TfNotifyVisual): string {
  switch (visual) {
    case 'success':
      return 'ph ph-check-circle';
    case 'warning':
      return 'ph ph-warning';
    case 'error':
      return 'ph ph-warning-circle';
    case 'info':
    default:
      return 'ph ph-info';
  }
}

function visualFromLegacy(opts: QNotifyCreateOptions): TfNotifyVisual {
  const type = opts.type;
  const color = typeof opts.color === 'string' ? opts.color : undefined;
  const message = (opts.message ?? '').toLowerCase();

  if (type === 'positive' || type === 'success' || color === 'positive' || color === 'teal' || color === 'green') {
    return 'success';
  }
  if (type === 'negative' || color === 'negative' || color === 'red') {
    return 'error';
  }
  if (type === 'warning' || color === 'warning' || color === 'orange' || color === 'amber') {
    return 'warning';
  }

  if (!type && !color && message) {
    if (/\b(failed|error|could not|cannot)\b/.test(message)) {
      return 'error';
    }
    if (
      /\b(saved|created|updated|deleted|copied|recorded|added|removed|success|complete|delivered)\b/.test(
        message,
      )
    ) {
      return 'success';
    }
  }

  return 'info';
}

function baseNotify(
  visual: TfNotifyVisual,
  message: string,
  extra: QNotifyUpdateOptions & { spinner?: boolean; timeout?: number } = {},
) {
  const timeout =
    extra.timeout ??
    (visual === 'success'
      ? 3000
      : visual === 'info'
        ? 4000
        : visual === 'warning'
          ? 6000
          : visual === 'error'
            ? 8000
            : 4000);

  const { actions: extraActions, spinner, timeout: _t, ...restExtra } = extra;
  const actions = extraActions ? [DISMISS_ACTION, ...extraActions] : [DISMISS_ACTION];

  return Notify.create({
    message,
    position: notifyPosition(),
    timeout: spinner ? 0 : timeout,
    progress: false,
    classes: `tf-notify tf-notify--${visual}`,
    icon: spinner ? undefined : iconFor(visual),
    spinner: spinner ?? false,
    group: restExtra.group,
    ...restExtra,
    actions,
  });
}

/** Maps legacy `$q.notify` / raw `Notify.create` options onto tf-notify styling. */
export function notifyFromQuasarOptions(opts: string | QNotifyCreateOptions) {
  const o: QNotifyCreateOptions = typeof opts === 'string' ? { message: opts } : opts;
  const message = o.message ?? '';
  const visual = visualFromLegacy(o);
  const { type: _type, color: _color, textColor: _textColor, progress: _progress, classes: _classes, ...rest } = o;

  const extraActions = o.actions?.filter((a) => a.icon !== 'close' && a.icon !== 'ph ph-x' && a['aria-label'] !== 'Dismiss');

  return baseNotify(visual, message, {
    ...rest,
    timeout: o.timeout,
    spinner: o.spinner,
    actions: extraActions?.length ? extraActions : undefined,
  });
}

/** App-wide notifier (Quasar Notify + tf-notify styling). */
export const notify = {
  success: (message: string) => baseNotify('success', message),
  info: (message: string) => baseNotify('info', message),
  warn: (message: string, actions?: QNotifyUpdateOptions['actions']) =>
    baseNotify('warning', message, { actions }),
  error: (message: string, opts: TfNotifyErrorOpts = {}) => {
    const actions: QNotifyUpdateOptions['actions'] = [];
    if (opts.retry) {
      actions.push({
        label: 'Retry',
        color: 'primary',
        handler: opts.retry,
      });
    }
    if (opts.details) {
      actions.push({
        label: 'Details',
        color: 'neutral',
        handler: opts.details,
      });
    }
    return baseNotify('error', message, {
      timeout: opts.persistent ? 0 : 8000,
      actions: actions.length ? actions : undefined,
    });
  },
  loading: (message: string) => {
    const id = `tf-notify-loading-${++idCounter}`;
    const dismiss = baseNotify('info', message, { group: id, spinner: true });
    return {
      dismiss: () => dismiss(),
      success: (msg: string) => {
        dismiss();
        baseNotify('success', msg, { group: id });
      },
      error: (msg: string) => {
        dismiss();
        baseNotify('error', msg, { group: id, timeout: 8000 });
      },
    };
  },
  undo: (message: string, onUndo: () => void) =>
    baseNotify('info', message, {
      timeout: 6000,
      actions: [{ label: 'Undo', color: 'primary', handler: onUndo }],
    }),
};

export type TfNotifyApi = typeof notify;
