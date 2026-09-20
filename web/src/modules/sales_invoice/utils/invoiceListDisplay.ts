import type { GlobalInvoiceRow } from '../types';

export const invoiceChannelLabel = (row: GlobalInvoiceRow) => {
  if (row.invoice_type === 'wholesale') return 'Trade';
  if (row.invoice_type === 'dropship') return 'Dropship';
  if (row.retail_billing_mode === 'direct') return 'Walk-in';
  return 'Retail';
};

export const invoiceChannelTone = (row: GlobalInvoiceRow) => {
  if (row.invoice_type === 'wholesale') return { color: 'purple-1', textColor: 'purple-9' };
  if (row.invoice_type === 'dropship') return { color: 'orange-1', textColor: 'orange-9' };
  if (row.retail_billing_mode === 'direct') return { color: 'green-1', textColor: 'positive' };
  return { color: 'blue-1', textColor: 'blue-9' };
};

export const formatStatusLabel = (status?: string | null) => (status || 'draft').replace(/_/g, ' ');

export const getPaymentStatusIcon = (status?: string | null) => {
  const value = (status ?? '').toLowerCase();
  if (value === 'paid') return 'ph ph-check-circle';
  if (value === 'due' || value === 'overdue') return 'ph ph-warning-circle';
  if (value === 'partial' || value === 'partially_paid') return 'ph ph-hourglass-medium';
  return 'ph ph-file-text';
};

export const invoiceListStatusSlug = (row: GlobalInvoiceRow) => {
  if (row.invoice_status === 'voided') return 'voided';
  if (row.invoice_status === 'draft' || row.invoice_status === 'proforma_generated') return 'draft';
  const ps = (row.payment_status ?? '').toLowerCase();
  if (ps === 'paid') return 'paid';
  if (ps === 'partial' || ps === 'partially_paid') return 'partial';
  if (ps === 'due' || ps === 'overdue' || ps === 'unpaid') return 'due';
  return 'default';
};

export const invoiceListStatusLabel = (row: GlobalInvoiceRow) => {
  if (row.invoice_status === 'voided') return 'Voided';
  if (row.invoice_status === 'proforma_generated') return 'Proforma';
  if (row.invoice_status === 'draft') return 'Draft';
  const ps = (row.payment_status ?? 'due').toLowerCase();
  if (ps === 'paid') return 'Paid';
  if (ps === 'partial' || ps === 'partially_paid') return 'Partial';
  if (ps === 'due' || ps === 'unpaid') return 'Due';
  return formatStatusLabel(ps);
};

export const invoiceListStatusIcon = (row: GlobalInvoiceRow) => {
  if (row.invoice_status === 'voided') return 'ph ph-prohibit';
  if (row.invoice_status === 'draft') return 'ph ph-pencil-simple';
  if (row.invoice_status === 'proforma_generated') return 'ph ph-file-text';
  return getPaymentStatusIcon(row.payment_status);
};

export const paymentStatusBadgeStyle = (status?: string | null, isDark = false) => {
  const value = (status ?? '').toLowerCase();
  if (value === 'paid') {
    return {
      backgroundColor: isDark ? 'rgba(34, 197, 94, 0.15)' : '#e8f5e9',
      color: isDark ? '#4ade80' : '#2e7d32',
      border: `1px solid ${isDark ? 'rgba(34, 197, 94, 0.3)' : '#c8e6c9'}`,
    };
  }
  if (value === 'due' || value === 'overdue') {
    return {
      backgroundColor: isDark ? 'rgba(239, 68, 68, 0.15)' : '#ffebee',
      color: isDark ? '#f87171' : '#c62828',
      border: `1px solid ${isDark ? 'rgba(239, 68, 68, 0.3)' : '#ffcdd2'}`,
    };
  }
  if (value === 'partial' || value === 'partially_paid') {
    return {
      backgroundColor: isDark ? 'rgba(59, 130, 246, 0.15)' : '#e3f2fd',
      color: isDark ? '#60a5fa' : '#1565c0',
      border: `1px solid ${isDark ? 'rgba(59, 130, 246, 0.3)' : '#bbdefb'}`,
    };
  }
  return {
    backgroundColor: isDark ? 'rgba(245, 158, 11, 0.15)' : '#fff3e0',
    color: isDark ? '#fbbf24' : '#ef6c00',
    border: `1px solid ${isDark ? 'rgba(245, 158, 11, 0.15)' : '#ffe0b2'}`,
  };
};

export const getInitials = (name?: string | null) => {
  if (!name) return 'U';
  const parts = name.trim().split(/\s+/);
  const first = parts[0] || '';
  const last = parts[parts.length - 1] || '';
  if (parts.length === 1) return first.charAt(0).toUpperCase() || 'U';
  return ((first.charAt(0) || '') + (last.charAt(0) || '')).toUpperCase() || 'U';
};
