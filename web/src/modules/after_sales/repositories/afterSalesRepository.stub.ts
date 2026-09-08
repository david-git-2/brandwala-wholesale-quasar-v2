import {
  MOCK_DROPSHIP_ORDERS,
  computeHubSummary,
  mockAfterSalesState,
} from '../fixtures/mockAfterSales';
import type {
  AfterSalesCase,
  AfterSalesCaseListFilters,
  AfterSalesCaseStatus,
  AfterSalesHubSummary,
  AfterSalesPolicyProgram,
  AfterSalesReasonCode,
  CreateDropshipCasePayload,
  CreateWholesaleCasePayload,
  PolicyPreviewResult,
} from '../types/afterSales.types';

const delay = (ms = 120) => new Promise((resolve) => setTimeout(resolve, ms));

const resolveParentTenantId = (tenantId: number) =>
  tenantId === 101 || tenantId === 102 ? 1 : tenantId;

const appendEvent = (caseRow: AfterSalesCase, eventType: string, label: string) => {
  caseRow.events.push({
    id: `ev-${caseRow.id}-${caseRow.events.length + 1}`,
    event_type: eventType,
    label,
    occurred_at: new Date().toISOString(),
    actor_name: 'Desk Staff',
  });
};

const reasonToProgram = (reason: AfterSalesReasonCode): AfterSalesPolicyProgram['program'] => {
  if (reason === 'doa' || reason === 'wrong_item') return 'doa';
  if (reason === 'warranty') return 'warranty';
  return 'return_credit';
};

const resolvePolicyForReason = (reason: AfterSalesReasonCode): AfterSalesPolicyProgram => {
  const programKey = reasonToProgram(reason);
  return (
    mockAfterSalesState.policies.find((p) => p.program === programKey && p.is_active) ??
    mockAfterSalesState.policies.find((p) => p.program === programKey) ??
    mockAfterSalesState.policies[0]!
  );
};

const buildPolicySnapshot = (
  program: AfterSalesPolicyProgram,
  lineValue = 4500,
): PolicyPreviewResult => {
  let suggested = 0;
  if (program.restock_fee_type === 'percent') {
    suggested = Math.round((lineValue * program.restock_fee_value) / 100);
  } else if (program.restock_fee_type === 'flat_bdt') {
    suggested = program.restock_fee_value;
  }

  return {
    policy_id: program.id,
    policy_name: program.name,
    program: program.program,
    window_days: program.window_days,
    window_anchor: program.window_anchor,
    within_window: true,
    restock_fee_type: program.restock_fee_type,
    restock_fee_value: program.restock_fee_value,
    suggested_restock_fee: suggested,
    requires_approval: program.requires_approval,
    approval_threshold_bdt: program.approval_threshold_bdt,
  };
};

const filterCases = (
  cases: AfterSalesCase[],
  tenantId: number,
  filters: AfterSalesCaseListFilters,
): AfterSalesCase[] => {
  const parentId = resolveParentTenantId(tenantId);
  const isChildView = tenantId !== parentId;

  let rows =
    import.meta.env.DEV
      ? [...cases]
      : cases.filter((c) => c.parent_tenant_id === parentId);

  if (isChildView && !import.meta.env.DEV) {
    rows = rows.filter((c) => c.operating_tenant_id === tenantId);
  } else if (isChildView && import.meta.env.DEV) {
    rows = rows.filter(
      (c) => c.operating_tenant_id === tenantId || c.operating_tenant_id === 101 || c.operating_tenant_id === 102,
    );
    if (rows.length === 0) {
      rows = cases.filter((c) => c.operating_tenant_id === 101);
    }
  }

  if (filters.channel) {
    rows = rows.filter((c) => c.source_channel === filters.channel);
  }
  if (filters.status) {
    rows = rows.filter((c) => c.status === filters.status);
  }
  if (filters.reason) {
    rows = rows.filter((c) => c.reason_code === filters.reason);
  }
  if (filters.operating_tenant_id) {
    rows = rows.filter((c) => c.operating_tenant_id === filters.operating_tenant_id);
  }
  if (filters.search?.trim()) {
    const q = filters.search.trim().toLowerCase();
    rows = rows.filter(
      (c) =>
        c.case_no.toLowerCase().includes(q) ||
        c.customer_name.toLowerCase().includes(q) ||
        (c.sales_invoice_no?.toLowerCase().includes(q) ?? false) ||
        (c.shop_order_no?.toLowerCase().includes(q) ?? false),
    );
  }
  if (filters.date_from) {
    rows = rows.filter((c) => c.opened_at.slice(0, 10) >= filters.date_from!);
  }
  if (filters.date_to) {
    rows = rows.filter((c) => c.opened_at.slice(0, 10) <= filters.date_to!);
  }

  return rows.sort((a, b) => b.opened_at.localeCompare(a.opened_at));
};

export const afterSalesRepositoryStub = {
  async getHubSummary(tenantId: number): Promise<AfterSalesHubSummary> {
    await delay();
    const scoped = import.meta.env.DEV
      ? mockAfterSalesState.cases
      : mockAfterSalesState.cases.filter(
          (c) => c.parent_tenant_id === resolveParentTenantId(tenantId),
        );
    return computeHubSummary(scoped);
  },

  async listCases(tenantId: number, filters: AfterSalesCaseListFilters = {}): Promise<AfterSalesCase[]> {
    await delay();
    return filterCases(mockAfterSalesState.cases, tenantId, filters);
  },

  async getCase(caseId: string): Promise<AfterSalesCase | null> {
    await delay();
    return mockAfterSalesState.cases.find((c) => c.id === caseId) ?? null;
  },

  async getCaseByInvoiceId(invoiceId: number): Promise<AfterSalesCase | null> {
    await delay();
    return (
      mockAfterSalesState.cases.find(
        (c) => c.sales_invoice_id === invoiceId && c.status !== 'closed' && c.status !== 'rejected',
      ) ?? null
    );
  },

  async listPolicies(parentTenantId: number): Promise<AfterSalesPolicyProgram[]> {
    await delay();
    void parentTenantId;
    return structuredClone(mockAfterSalesState.policies);
  },

  async getPolicy(policyId: string): Promise<AfterSalesPolicyProgram | null> {
    await delay();
    const policy = mockAfterSalesState.policies.find((p) => p.id === policyId);
    return policy ? structuredClone(policy) : null;
  },

  async savePolicy(
    parentTenantId: number,
    policy: AfterSalesPolicyProgram,
  ): Promise<AfterSalesPolicyProgram> {
    await delay();
    void parentTenantId;

    const normalized: AfterSalesPolicyProgram = {
      ...policy,
      parent_tenant_id: parentTenantId,
      allowed_outcomes: [...policy.allowed_outcomes],
    };

    if (!normalized.id) {
      const seq = mockAfterSalesState.nextPolicySeq++;
      normalized.id = `pol-${String(seq).padStart(3, '0')}`;
      mockAfterSalesState.policies.push(structuredClone(normalized));
      return structuredClone(normalized);
    }

    const index = mockAfterSalesState.policies.findIndex((p) => p.id === normalized.id);
    if (index === -1) {
      mockAfterSalesState.policies.push(structuredClone(normalized));
    } else {
      mockAfterSalesState.policies[index] = structuredClone(normalized);
    }

    return structuredClone(normalized);
  },

  async upsertPolicies(
    parentTenantId: number,
    programs: AfterSalesPolicyProgram[],
  ): Promise<AfterSalesPolicyProgram[]> {
    await delay();
    void parentTenantId;
    mockAfterSalesState.policies = structuredClone(programs);
    return structuredClone(mockAfterSalesState.policies);
  },

  async resolvePolicyPreview(
    _invoiceItemId: number,
    reasonCode: AfterSalesReasonCode,
  ): Promise<PolicyPreviewResult> {
    await delay(80);
    const program = resolvePolicyForReason(reasonCode);
    return buildPolicySnapshot(program);
  },

  async createWholesaleCase(payload: CreateWholesaleCasePayload): Promise<AfterSalesCase> {
    await delay();
    const program = resolvePolicyForReason(payload.reason_code);
    const snapshot = buildPolicySnapshot(program);
    const seq = mockAfterSalesState.nextCaseSeq++;
    const id = `mock-ws-${String(seq).padStart(3, '0')}`;
    const status: AfterSalesCaseStatus = snapshot.requires_approval
      ? 'pending_approval'
      : 'awaiting_receipt';

    const newCase: AfterSalesCase = {
      id,
      case_no: `RMA-WS-20260908-${String(seq).padStart(4, '0')}`,
      status,
      source_channel: 'wholesale',
      reason_code: payload.reason_code,
      program: program.program,
      parent_tenant_id: payload.parent_tenant_id,
      operating_tenant_id: payload.operating_tenant_id,
      operating_tenant_name: payload.operating_tenant_name,
      sales_invoice_id: payload.sales_invoice_id,
      sales_invoice_no: payload.sales_invoice_no,
      shop_order_id: null,
      shop_order_no: null,
      billing_profile_id: payload.billing_profile_id,
      customer_name: payload.customer_name,
      policy_snapshot: snapshot,
      intake_source: null,
      reported_to: null,
      reporter_name: null,
      reporter_phone: null,
      intake_note: null,
      opened_at: new Date().toISOString(),
      closed_at: null,
      lines: payload.lines.map((line, index) => ({
        id: `line-${id}-${index}`,
        invoice_item_id: line.invoice_item_id,
        shop_order_item_id: null,
        product_name: line.product_name,
        requested_qty: line.requested_qty,
        received_qty: 0,
        outcome: 'pending' as const,
        restock_fee_amount: snapshot.suggested_restock_fee,
        grade_label: null,
      })),
      events: [
        {
          id: `ev-${id}-1`,
          event_type: 'opened',
          label: 'Wholesale return case opened',
          occurred_at: new Date().toISOString(),
          actor_name: 'Desk Staff',
        },
      ],
    };

    mockAfterSalesState.cases.unshift(newCase);
    return structuredClone(newCase);
  },

  async createDropshipCase(payload: CreateDropshipCasePayload): Promise<AfterSalesCase> {
    await delay();
    const program = resolvePolicyForReason(payload.reason_code);
    const snapshot = buildPolicySnapshot(program);
    const seq = mockAfterSalesState.nextCaseSeq++;
    const id = `mock-ds-${String(seq).padStart(3, '0')}`;

    const newCase: AfterSalesCase = {
      id,
      case_no: `RMA-DS-20260908-${String(seq).padStart(4, '0')}`,
      status: 'pending_approval',
      source_channel: 'dropship',
      reason_code: payload.reason_code,
      program: program.program,
      parent_tenant_id: payload.parent_tenant_id,
      operating_tenant_id: payload.operating_tenant_id,
      operating_tenant_name: payload.operating_tenant_name,
      sales_invoice_id: null,
      sales_invoice_no: null,
      shop_order_id: payload.shop_order_id,
      shop_order_no: payload.shop_order_no,
      billing_profile_id: payload.merchant_billing_profile_id,
      customer_name: payload.customer_name,
      policy_snapshot: snapshot,
      intake_source: payload.intake_source,
      reported_to: payload.reported_to,
      reporter_name: payload.reporter_name,
      reporter_phone: payload.reporter_phone,
      intake_note: payload.intake_note,
      opened_at: new Date().toISOString(),
      closed_at: null,
      lines: [
        {
          id: `line-${id}-0`,
          invoice_item_id: null,
          shop_order_item_id: payload.shop_order_id * 10,
          product_name: 'Order line (mock)',
          requested_qty: 1,
          received_qty: 0,
          outcome: 'pending',
          restock_fee_amount: snapshot.suggested_restock_fee,
          grade_label: null,
        },
      ],
      events: [
        {
          id: `ev-${id}-1`,
          event_type: 'intake_logged',
          label: 'Dropship complaint logged',
          occurred_at: new Date().toISOString(),
          actor_name: 'Desk Staff',
        },
      ],
    };

    mockAfterSalesState.cases.unshift(newCase);
    return structuredClone(newCase);
  },

  async updateCaseStatus(caseId: string, status: AfterSalesCaseStatus): Promise<AfterSalesCase> {
    await delay();
    const caseRow = mockAfterSalesState.cases.find((c) => c.id === caseId);
    if (!caseRow) throw new Error('Case not found');

    caseRow.status = status;
    if (status === 'closed') {
      caseRow.closed_at = new Date().toISOString();
      appendEvent(caseRow, 'closed', 'Case closed');
    } else if (status === 'rejected') {
      caseRow.closed_at = new Date().toISOString();
      appendEvent(caseRow, 'rejected', 'Case rejected');
    } else if (status === 'approved') {
      appendEvent(caseRow, 'approved', 'Case approved');
      caseRow.status = 'awaiting_receipt';
    } else if (status === 'awaiting_receipt') {
      appendEvent(caseRow, 'awaiting_receipt', 'Awaiting goods receipt');
    } else if (status === 'received') {
      appendEvent(caseRow, 'received', 'Goods marked received');
      caseRow.lines.forEach((line) => {
        if (line.received_qty === 0) line.received_qty = line.requested_qty;
      });
      caseRow.status = 'inspecting';
    } else if (status === 'inspecting') {
      appendEvent(caseRow, 'inspecting', 'Inspection in progress');
    } else if (status === 'executing') {
      appendEvent(caseRow, 'executing', 'Ready for execution');
    }

    return structuredClone(caseRow);
  },

  async approveCase(caseId: string): Promise<AfterSalesCase> {
    return afterSalesRepositoryStub.updateCaseStatus(caseId, 'approved');
  },

  async rejectCase(caseId: string): Promise<AfterSalesCase> {
    return afterSalesRepositoryStub.updateCaseStatus(caseId, 'rejected');
  },

  async markCaseReceived(caseId: string): Promise<AfterSalesCase> {
    return afterSalesRepositoryStub.updateCaseStatus(caseId, 'received');
  },

  async advanceCaseToExecuting(caseId: string): Promise<AfterSalesCase> {
    return afterSalesRepositoryStub.updateCaseStatus(caseId, 'executing');
  },

  async closeCase(caseId: string): Promise<AfterSalesCase> {
    return afterSalesRepositoryStub.updateCaseStatus(caseId, 'closed');
  },

  async updateCaseLines(
    caseId: string,
    lines: AfterSalesCase['lines'],
  ): Promise<AfterSalesCase> {
    await delay();
    const caseRow = mockAfterSalesState.cases.find((c) => c.id === caseId);
    if (!caseRow) throw new Error('Case not found');
    caseRow.lines = structuredClone(lines);
    appendEvent(caseRow, 'inspected', 'Line outcomes updated');
    caseRow.status = 'executing';
    return structuredClone(caseRow);
  },

  searchDropshipOrders(query: string) {
    const q = query.trim().toLowerCase();
    if (!q) return MOCK_DROPSHIP_ORDERS;
    return MOCK_DROPSHIP_ORDERS.filter(
      (o) =>
        o.order_no.toLowerCase().includes(q) ||
        o.recipient_phone.includes(q) ||
        o.recipient_name.toLowerCase().includes(q),
    );
  },

  getDropshipOrderById(orderId: number) {
    return MOCK_DROPSHIP_ORDERS.find((o) => o.id === orderId) ?? null;
  },
};
