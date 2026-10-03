export type NotificationPresentation = {
  icon: string;
  kindLabel: string;
  fallbackAction: string;
};

const EVENT_PRESENTATION: Record<string, NotificationPresentation> = {
  'catalog.order.created': {
    icon: 'ph ph-shopping-cart',
    kindLabel: 'New order',
    fallbackAction: 'Open the order to price items',
  },
  'catalog.order.confirmed': {
    icon: 'ph ph-check-circle',
    kindLabel: 'Order confirmed',
    fallbackAction: 'Start buying when ready',
  },
  'catalog.order.packed': {
    icon: 'ph ph-package',
    kindLabel: 'Packed',
    fallbackAction: 'Confirm take, condition, or return on the delivery paper',
  },
  'catalog.order.delivered': {
    icon: 'ph ph-truck',
    kindLabel: 'Delivered',
    fallbackAction: 'Open the order',
  },
  'catalog.order.cancelled': {
    icon: 'ph ph-x-circle',
    kindLabel: 'Cancelled',
    fallbackAction: 'Open the order',
  },
  'catalog.offer.sent': {
    icon: 'ph ph-tag',
    kindLabel: 'Offer',
    fallbackAction: 'Open the order to review prices',
  },
  'catalog.offer.final': {
    icon: 'ph ph-handshake',
    kindLabel: 'Final offer',
    fallbackAction: 'Check price and quantity, then confirm',
  },
  'catalog.offer.countered': {
    icon: 'ph ph-arrows-left-right',
    kindLabel: 'Counter offer',
    fallbackAction: 'Open the order and send the last offer',
  },
  'task.assigned': {
    icon: 'ph ph-check-square',
    kindLabel: 'Task',
    fallbackAction: 'Open this task',
  },
};

const DEFAULT_PRESENTATION: NotificationPresentation = {
  icon: 'ph ph-bell',
  kindLabel: 'Update',
  fallbackAction: 'Open for details',
};

export const getNotificationPresentation = (eventType: string): NotificationPresentation =>
  EVENT_PRESENTATION[eventType] ?? DEFAULT_PRESENTATION;
