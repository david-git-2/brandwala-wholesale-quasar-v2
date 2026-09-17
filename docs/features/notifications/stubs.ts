/**
 * Tasks & Notifications Stubs & Mock Data Provider
 * Used for isolated notification inbox testing and task manager verification.
 */

export interface NotificationStub {
  id: string;
  event_type: string;
  title: string;
  message: string;
  action_url?: string;
  read_at?: string;
  created_at: string;
}

export interface TaskStub {
  id: string;
  title: string;
  description?: string;
  priority: 'low' | 'medium' | 'high' | 'urgent';
  status: 'pending' | 'in_progress' | 'completed' | 'cancelled';
  assigned_to_name: string;
  due_date?: string;
  created_at: string;
}

export const mockNotifications: NotificationStub[] = [
  {
    id: 'notif-001',
    event_type: 'shipment.received',
    title: 'Shipment Received at Warehouse',
    message: 'SHP-202609-001 received. 38 items ready for stock organization.',
    action_url: '/app/procurement/stock',
    created_at: new Date(Date.now() - 1000 * 60 * 15).toISOString(),
  },
  {
    id: 'notif-002',
    event_type: 'order.placed',
    title: 'New Dropship Order Placed',
    message: 'Order DS-ORD-202609-1001 requires stock picking in Uttara.',
    action_url: '/app/dropship/orders',
    created_at: new Date(Date.now() - 1000 * 60 * 60).toISOString(),
  },
];

export const mockTasks: TaskStub[] = [
  {
    id: 'tsk-001',
    title: 'Inspect damaged boxes on SHP-001',
    description: 'Verify 2 damaged garment boxes with warehouse supervisor',
    priority: 'urgent',
    status: 'pending',
    assigned_to_name: 'Nusrat Jahan',
    due_date: '2026-09-18',
    created_at: new Date(Date.now() - 3600000 * 4).toISOString(),
  },
];

export async function fetchMockNotifications(): Promise<NotificationStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockNotifications];
}
