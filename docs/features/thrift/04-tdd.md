# Thrift Vertical — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/thrift/`  
> **Repository Target**: `web/src/modules/thrift/shared/repositories/`  
> **Composables**: `web/src/modules/thrift/stock/composables/`, `web/src/modules/thrift/sales/composables/`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/thrift/
├── stock/
│   ├── pages/ThriftStockPage.vue         # Inventory table with physical filters
│   ├── pages/ThriftStockTagPrintPage.vue # Batch hang-tag layout viewer
│   └── components/ThriftStockMeasurementsDialog.vue # Garment dimension editor
├── barcode/
│   ├── pages/ThriftBarcodePage.vue       # Thermal barcode batch printer
│   └── components/BarcodeRenderer.vue    # Code-128 SVG generator
├── shipment/
│   ├── pages/ThriftShipmentPage.vue      # Inbound shipment batch list
│   └── pages/ThriftShipmentDetailsPage.vue # Box intake & weight apportioner
├── sales/
│   ├── pages/ThriftSalesPage.vue         # Sales invoice history table
│   ├── pages/ThriftCreateSalesInvoicePage.vue # Rapid barcode POS checkout desk
│   └── pages/ThriftSalesReturnsPage.vue  # Post-delivery return desk
└── reports/
    └── pages/ThriftReportsPage.vue       # Shop glance dashboard & COD reports
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const thriftQueryKeys = {
  stocks: (tenantId: string, params?: Record<string, unknown>) =>
    ['thriftStocks', 'list', { tenantId, ...params }] as const,
  shipments: (tenantId: string) =>
    ['thriftShipments', 'list', tenantId] as const,
  shipmentDetail: (id: string) =>
    ['thriftShipments', 'detail', id] as const,
  barcodes: (tenantId: string, params?: Record<string, unknown>) =>
    ['thriftBarcodes', 'list', { tenantId, ...params }] as const,
  sales: (tenantId: string, params?: Record<string, unknown>) =>
    ['thriftSales', 'invoices', { tenantId, ...params }] as const,
  customerRisk: (phone: string) =>
    ['thriftSales', 'customer_risk', phone] as const,
  dashboard: (tenantId: string) =>
    ['thriftReports', 'dashboard', tenantId] as const,
};
```

---

## 3. UI Implementation Patterns & Pure Calculations

1. **Pure Utility Calculators**: Unit landed cost and retail ceiling price formulas are computed in pure TypeScript utility helpers before persisting to the backend.
2. **Barcode Scanner Rapid Mode**: Scanning a valid barcode immediately appends the item to the active POS invoice table with automatic audio feedback.
3. **Customer Risk Chip**: High-risk customers display an amber or red warning chip with historical return percentage.
