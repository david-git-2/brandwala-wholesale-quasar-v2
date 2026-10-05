export const GLOBAL_SHIPMENT_STATUSES = ['draft', 'in_transit', 'received', 'cancelled'] as const;

export const GLOBAL_SHIPMENT_WORKFLOW_STATUSES = ['draft', 'in_transit', 'received'] as const;

export type GlobalShipmentStatus = (typeof GLOBAL_SHIPMENT_STATUSES)[number];

export type GlobalShipmentWorkflowStatus = (typeof GLOBAL_SHIPMENT_WORKFLOW_STATUSES)[number];

export function isGlobalShipmentStatus(value: string): value is GlobalShipmentStatus {
  return (GLOBAL_SHIPMENT_STATUSES as readonly string[]).includes(value);
}

export type ShipmentStatusChangeConfirmCopy = {
  title: string;
  message: string;
  okLabel: string;
};

/** Confirm dialog copy when changing workflow status (not receive/cancel). */
export function shipmentStatusChangeConfirmCopy(
  newStatus: GlobalShipmentStatus,
): ShipmentStatusChangeConfirmCopy {
  switch (newStatus) {
    case 'in_transit':
      return {
        title: 'Mark shipment in transit',
        message:
          'Use this when goods have left the vendor and are on the way. You can add land splits on each line before receive. Nothing is posted to stock yet.',
        okLabel: 'Mark in transit',
      };
    case 'draft':
      return {
        title: 'Return to draft',
        message:
          'Moves the shipment back to Draft so you can change lines and costs. Receive and stock posting stay unavailable until you dispatch again.',
        okLabel: 'Set to draft',
      };
    default:
      return {
        title: 'Confirm status change',
        message: `Change this shipment to "${formatGlobalShipmentStatus(newStatus)}"?`,
        okLabel: `Set to ${formatGlobalShipmentStatus(newStatus)}`,
      };
  }
}

export function formatGlobalShipmentStatus(status: string | null | undefined): string {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'draft':
      return 'Draft';
    case 'in_transit':
      return 'In Transit';
    case 'received':
      return 'Received';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status ? status.replace(/_/g, ' ') : '—';
  }
}

export interface GlobalShipmentStatusChipStyle {
  color: string;
  textColor: string;
}

export function globalShipmentStatusChipStyle(
  status: string | null | undefined,
): GlobalShipmentStatusChipStyle {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'received':
      return { color: 'positive', textColor: 'white' };
    case 'in_transit':
      return { color: 'warning', textColor: 'dark' };
    case 'cancelled':
      return { color: 'negative', textColor: 'white' };
    case 'draft':
    default:
      return { color: 'grey-4', textColor: 'grey-9' };
  }
}

/** Quasar button color token for workflow bar chips */
export function globalShipmentStatusWorkflowColor(status: string): string {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'in_transit':
      return 'orange-8';
    case 'received':
      return 'green-7';
    case 'cancelled':
      return 'negative';
    default:
      return 'primary';
  }
}
