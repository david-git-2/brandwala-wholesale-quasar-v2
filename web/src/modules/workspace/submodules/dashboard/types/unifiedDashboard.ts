import type { AttentionStripItem } from '../components/DashboardAttentionStrip.vue';
import type { InboundShipmentItem } from '../components/DashboardStockAllocationCard.vue';
import type { BrandMatrixItem } from '../components/DashboardBrandMatrix.vue';

export type UnifiedDashboardMetrics = {
  // Scorecard
  revenue: number;
  revenueDeltaPct: number;
  revenueSparkline: number[];
  revenueSubtext?: string;

  liquidCash: number;
  accountCount: number;
  cashSparkline: number[];

  receivables: number;
  agingOver30dPct: number;
  receivablesSparkline: number[];

  stockValuation: number;
  totalUnits: number;
  stockSparkline: number[];

  // Fulfillment Funnel
  fulfillment: {
    pendingCount: number;
    pendingAmount: number;
    processingCount: number;
    processingUnits: number;
    inTransitCount: number;
    deliveredCount: number;
  };

  // Warehouse Stock & Intake
  stock: {
    availableUnits: number;
    allocatedUnits: number;
    inTransitUnits: number;
    shipments: InboundShipmentItem[];
  };

  // Treasury & Working Capital
  treasury: {
    bankBalance: number;
    courierCodTotal: number;
    customerDues: number;
    vendorPayables: number;
    investorYieldDue: number;
    steadfastCod: number;
    pathaoCod: number;
  };

  // Brands Comparison
  brands: BrandMatrixItem[];

  // Triage Attention Items
  attentionItems: AttentionStripItem[];
};

export type UnifiedDashboardState = {
  metrics: UnifiedDashboardMetrics;
  isLoading: boolean;
  isError: boolean;
  refetch: () => Promise<void>;
};
