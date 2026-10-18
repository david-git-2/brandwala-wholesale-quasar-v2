import { Notify, Screen, type QNotifyCreateOptions, type QNotifyUpdateOptions } from 'quasar';

export type TfNotifyErrorOpts = {
  retry?: () => void;
  details?: () => void;
  persistent?: boolean;
};

type TfNotifyVisual = 'success' | 'error' | 'warning' | 'info';

type BaseNotifyExtra = QNotifyUpdateOptions & {
  spinner?: boolean;
  timeout?: number;
  group?: QNotifyCreateOptions['group'];
};

let idCounter = 0;

const DISMISS_ACTION = {
  icon: 'ph ph-x',
  round: true,
  dense: true,
  size: 'sm' as const,
  'aria-label': 'Dismiss',
};

function notifyPosition(): NonNullable<QNotifyCreateOptions['position']> {
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

function omitUndefined<T extends Record<string, unknown>>(obj: T): Partial<T> {
  return Object.fromEntries(Object.entries(obj).filter(([, value]) => value !== undefined)) as Partial<T>;
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

function baseNotify(visual: TfNotifyVisual, message: string, extra: BaseNotifyExtra = {}) {
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

  const {
    actions: extraActions,
    spinner,
    timeout: _t,
    group,
    position: _position,
    ...restExtra
  } = extra as BaseNotifyExtra & { position?: QNotifyCreateOptions['position'] };
  const actions = extraActions ? [DISMISS_ACTION, ...extraActions] : [DISMISS_ACTION];

  const payload: QNotifyCreateOptions = {
    message,
    position: notifyPosition(),
    timeout: spinner ? 0 : timeout,
    progress: false,
    classes: `tf-notify tf-notify--${visual}`,
    spinner: spinner ?? false,
    ...omitUndefined(restExtra),
    actions,
  };

  if (!spinner) {
    payload.icon = iconFor(visual);
  }
  if (group !== undefined) {
    payload.group = group;
  }

  return Notify.create(payload);
}

/** Maps legacy `$q.notify` / raw `Notify.create` options onto tf-notify styling. */
export function notifyFromQuasarOptions(opts: string | QNotifyCreateOptions) {
  const o: QNotifyCreateOptions = typeof opts === 'string' ? { message: opts } : opts;
  const message = o.message ?? '';
  const visual = visualFromLegacy(o);
  const {
    type: _type,
    color: _color,
    textColor: _textColor,
    progress: _progress,
    classes: _classes,
    position: _position,
    spinner: legacySpinner,
    timeout: legacyTimeout,
    actions: legacyActions,
    ...rest
  } = o;

  const extraActions = legacyActions?.filter(
    (a) => a.icon !== 'close' && a.icon !== 'ph ph-x' && a['aria-label'] !== 'Dismiss',
  );

  const extra: BaseNotifyExtra = { ...rest };
  if (legacyTimeout !== undefined) {
    extra.timeout = legacyTimeout;
  }
  if (legacySpinner !== undefined) {
    extra.spinner = legacySpinner === true;
  }
  if (extraActions?.length) {
    extra.actions = extraActions;
  }

  return baseNotify(visual, message, extra);
}

/** App-wide notifier (Quasar Notify + tf-notify styling). */
export const notify = {
  success: (message: string) => baseNotify('success', message),
  info: (message: string) => baseNotify('info', message),
  warn: (message: string, actions?: QNotifyUpdateOptions['actions']) =>
    baseNotify('warning', message, actions?.length ? { actions } : {}),
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
    const extra: BaseNotifyExtra = {
      timeout: opts.persistent ? 0 : 8000,
    };
    if (actions.length) {
      extra.actions = actions;
    }
    return baseNotify('error', message, extra);
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
