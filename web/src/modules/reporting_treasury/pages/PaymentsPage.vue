<template>
  <q-page class="q-pa-xs page-fixed-layout column no-wrap overflow-hidden payments-page">
    <!-- 1. Unified Compact 38px Toolbar -->
    <q-card flat bordered class="q-pa-xs flex-shrink-0 q-mb-xs">
      <div class="row items-center justify-between q-col-gutter-xs no-wrap">
        <!-- Left: Segmented Filter Tabs & Status Filter -->
        <div class="col-auto row items-center q-gutter-x-xs no-wrap">
          <div class="row items-center q-gutter-x-2xs quick-filter-toggle">
            <q-btn
              v-for="tab in viewTabs"
              :key="tab.value"
              dense
              unelevated
              no-caps
              :color="paymentMode === tab.value ? 'primary' : 'transparent'"
              :text-color="paymentMode === tab.value ? 'white' : 'grey-8'"
              class="quick-filter-btn"
              @click="paymentMode = tab.value"
            >
              <q-icon :name="tab.icon" size="14px" class="q-mr-xs" />
              <span>{{ tab.label }}</span>
            </q-btn>
          </div>

          <q-separator vertical class="q-mx-2xs" />

          <!-- Quick Status Filter (For Invoices View) -->
          <q-select
            v-if="paymentMode === 'invoice'"
            v-model="invoiceStatusFilter"
            :options="statusOptions"
            outlined
            dense
            emit-value
            map-options
            options-dense
            style="min-width: 120px"
            class="dense-filter-select"
          >
            <template #prepend>
              <q-icon name="ph ph-funnel" size="14px" class="text-grey-6" />
            </template>
          </q-select>
        </div>

        <!-- Right: Search Input + Refresh -->
        <div class="col-grow row items-center justify-end q-gutter-x-xs no-wrap">
          <q-input
            v-model="searchQuery"
            outlined
            rounded
            dense
            clearable
            style="min-width: 260px; max-width: 360px"
            class="col-grow col-sm-auto dense-search-input"
            :placeholder="paymentMode === 'customer' ? 'Search customer, group, outlet...' : 'Search invoice no, outlet, phone...'"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-5" />
            </template>
          </q-input>

          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-clockwise"
            color="grey-7"
            @click="refetchAll"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
        </div>
      </div>
    </q-card>

    <!-- ======================================================================= -->
    <!-- VIEW A: CUSTOMER GROUPS LIST TABLE                                      -->
    <!-- ======================================================================= -->
    <div v-if="paymentMode === 'customer'" class="table-container col column no-wrap overflow-hidden">
      <q-table
        flat
        bordered
        dense
        :rows="customerGroups"
        :columns="customerColumns"
        row-key="id"
        :loading="isCustomerGroupsLoading"
        class="treasury-ops-table full-height"
        :pagination="{ rowsPerPage: 25 }"
      >
        <template #loading>
          <q-inner-loading showing color="primary">
            <q-spinner-dots size="32px" />
          </q-inner-loading>
        </template>

        <template #no-data>
          <div class="full-width row flex-center text-grey-6 q-py-lg">
            <q-icon name="ph ph-users-three" size="28px" class="q-mr-xs" />
            <span>No customer groups found with outstanding dues.</span>
          </div>
        </template>

        <!-- Customer Column -->
        <template #body-cell-customer="props">
          <q-td :props="props">
            <div class="row items-center q-gutter-xs no-wrap">
              <q-avatar size="24px" color="grey-3" text-color="grey-9" square class="rounded-avatar">
                <q-icon name="ph ph-buildings" size="13px" />
              </q-avatar>
              <div>
                <div class="text-weight-bold text-primary">{{ props.row.name }}</div>
                <div class="text-2xs text-grey-6 font-mono">{{ props.row.account_code }}</div>
              </div>
            </div>
          </q-td>
        </template>

        <!-- Outlets Column -->
        <template #body-cell-branches="props">
          <q-td :props="props" class="text-grey-8">
            {{ props.row.branches?.length ? props.row.branches.join(' • ') : '—' }}
          </q-td>
        </template>

        <!-- Open Invoices Count Badge -->
        <template #body-cell-invoices="props">
          <q-td :props="props" class="text-center font-mono">
            <q-badge color="grey-2" text-color="grey-9" class="text-weight-bold status-chip">
              {{ props.row.open_invoice_count }} Open
            </q-badge>
          </q-td>
        </template>

        <!-- Total Invoiced -->
        <template #body-cell-total="props">
          <q-td :props="props" class="text-right font-mono text-grey-7">
            ৳{{ formatCurrency(props.row.total_invoiced) }}
          </q-td>
        </template>

        <!-- Paid So Far -->
        <template #body-cell-paid="props">
          <q-td :props="props" class="text-right font-mono text-positive">
            {{ props.row.total_paid > 0 ? '৳' + formatCurrency(props.row.total_paid) : '—' }}
          </q-td>
        </template>

        <!-- Total Outstanding Due -->
        <template #body-cell-due="props">
          <q-td :props="props" class="text-right font-mono text-weight-bold text-negative">
            ৳{{ formatCurrency(props.row.total_due) }}
          </q-td>
        </template>

        <!-- Actions Column -->
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn
              unelevated
              size="sm"
              color="primary"
              icon="ph ph-credit-card"
              label="Settle Dues"
              no-caps
              class="rounded-btn text-weight-medium"
              @click="openBatchSettlement(props.row)"
            />
          </q-td>
        </template>
      </q-table>
    </div>

    <!-- ======================================================================= -->
    <!-- VIEW B: ALL OPEN INVOICES LIST TABLE                                    -->
    <!-- ======================================================================= -->
    <div v-else class="table-container col column no-wrap overflow-hidden">
      <q-table
        flat
        bordered
        dense
        :rows="filteredInvoices"
        :columns="invoiceColumns"
        row-key="id"
        :loading="isOpenInvoicesLoading"
        class="treasury-ops-table full-height"
        :pagination="{ rowsPerPage: 25 }"
      >
        <template #loading>
          <q-inner-loading showing color="primary">
            <q-spinner-dots size="32px" />
          </q-inner-loading>
        </template>

        <template #no-data>
          <div class="full-width row flex-center text-grey-6 q-py-lg">
            <q-icon name="ph ph-receipt" size="28px" class="q-mr-xs" />
            <span>No open due invoices found.</span>
          </div>
        </template>

        <!-- Invoice No Column -->
        <template #body-cell-invoice_no="props">
          <q-td :props="props" :class="getRowStatusClass(props.row)">
            <div class="row items-center q-gutter-2xs no-wrap">
              <span class="font-mono text-weight-bold text-primary">{{ props.row.invoice_no }}</span>
              <q-badge color="grey-2" text-color="grey-8" class="text-2xs text-uppercase" style="border-radius: 4px">
                {{ props.row.invoice_type }}
              </q-badge>
            </div>
          </q-td>
        </template>

        <!-- Outlet Column -->
        <template #body-cell-outlet="props">
          <q-td :props="props">
            <div class="text-weight-medium text-grey-9">{{ props.row.customer_group_name }}</div>
            <div class="text-2xs text-grey-6">{{ props.row.branch_name }}</div>
          </q-td>
        </template>

        <!-- Dates Column -->
        <template #body-cell-date="props">
          <q-td :props="props" class="font-mono text-grey-7">
            {{ props.row.invoice_date }}
          </q-td>
        </template>

        <!-- Due Date Column -->
        <template #body-cell-due_date="props">
          <q-td :props="props" class="font-mono" :class="isOverdue(props.row.due_date) ? 'text-negative text-weight-bold' : 'text-grey-7'">
            {{ props.row.due_date || '—' }}
          </q-td>
        </template>

        <!-- Total Column -->
        <template #body-cell-total="props">
          <q-td :props="props" class="text-right font-mono text-grey-8">
            ৳{{ formatCurrency(props.row.total_amount) }}
          </q-td>
        </template>

        <!-- Paid Column -->
        <template #body-cell-paid="props">
          <q-td :props="props" class="text-right font-mono text-positive">
            {{ props.row.paid_amount > 0 ? '৳' + formatCurrency(props.row.paid_amount) : '—' }}
          </q-td>
        </template>

        <!-- Due Balance Column -->
        <template #body-cell-due="props">
          <q-td :props="props" class="text-right font-mono text-weight-bold text-negative">
            ৳{{ formatCurrency(props.row.due_amount) }}
          </q-td>
        </template>

        <!-- Status Column -->
        <template #body-cell-status="props">
          <q-td :props="props" class="text-center">
            <q-badge
              :color="props.row.paid_amount > 0 ? 'amber-1' : 'grey-2'"
              :text-color="props.row.paid_amount > 0 ? 'amber-9' : 'grey-8'"
              class="text-uppercase text-weight-bold status-chip"
            >
              {{ props.row.paid_amount > 0 ? 'Partial' : 'Due' }}
            </q-badge>
          </q-td>
        </template>

        <!-- Actions Column -->
        <template #body-cell-actions="props">
          <q-td :props="props" class="text-right">
            <q-btn
              unelevated
              size="sm"
              color="primary"
              label="Pay"
              no-caps
              class="rounded-btn text-weight-medium"
              @click="openSinglePayment(props.row)"
            />
          </q-td>
        </template>
      </q-table>
    </div>

    <!-- ======================================================================= -->
    <!-- 1. MODERN EASY SETTLEMENT DIALOG (CUSTOMER GROUP WISE)                  -->
    <!-- ======================================================================= -->
    <q-dialog v-model="batchDialogOpen" persistent max-width="860px">
      <q-card class="bg-white text-grey-9 rounded-card column no-wrap shadow-2" style="width: 860px; max-width: 95vw; max-height: 90vh">
        <!-- Modern Dialog Header with Complete Financial Overview -->
        <div class="q-pa-md bg-grey-1 border-bottom row items-center justify-between no-wrap">
          <div class="row items-center q-gutter-sm">
            <q-avatar size="38px" color="primary" text-color="white" square class="rounded-avatar shadow-1">
              <q-icon name="ph ph-buildings" size="22px" />
            </q-avatar>
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9 leading-tight">{{ activeGroup?.name }}</div>
              <div class="text-caption text-grey-6 flex items-center q-gutter-x-xs">
                <span>{{ activeGroup?.account_code }}</span>
                <span>•</span>
                <span>{{ activeGroupInvoices.length }} Open Invoice{{ activeGroupInvoices.length > 1 ? 's' : '' }}</span>
              </div>
            </div>
          </div>

          <!-- 3-Pillar Account Balance Summary -->
          <div class="row items-center q-gutter-x-md">
            <div class="text-right">
              <div class="text-2xs text-grey-6 text-uppercase">Total Invoiced</div>
              <div class="text-caption font-mono text-weight-bold text-grey-8">
                ৳{{ formatCurrency(activeGroup?.total_invoiced || 0) }}
              </div>
            </div>

            <q-separator vertical style="height: 24px" />

            <div class="text-right">
              <div class="text-2xs text-grey-6 text-uppercase">Already Paid</div>
              <div class="text-caption font-mono text-weight-bold text-positive">
                ৳{{ formatCurrency(activeGroup?.total_paid || 0) }}
              </div>
            </div>

            <q-separator vertical style="height: 24px" />

            <div class="text-right">
              <div class="text-2xs text-grey-6 text-uppercase text-weight-bold">Current Due</div>
              <div class="text-h6 font-mono text-weight-bolder text-negative leading-tight">
                ৳{{ formatCurrency(activeGroup?.total_due || 0) }}
              </div>
            </div>

            <q-btn flat round dense icon="ph ph-x" color="grey-6" v-close-popup class="q-ml-xs" />
          </div>
        </div>

        <!-- Clean Form Inputs Area -->
        <div class="q-pa-md bg-white border-bottom">
          <div class="row q-col-gutter-sm items-start">
            <!-- Amount Input with Quick Preset Chips -->
            <div class="col-12 col-md-5">
              <div class="text-caption text-weight-bold text-grey-8 q-mb-2xs">Payment Received Now (৳)</div>
              <q-input
                v-model.number="batchPayment.amount"
                type="number"
                outlined
                dense
                prefix="৳"
                placeholder="0.00"
                class="modern-amount-input"
                input-class="text-weight-bolder text-primary text-subtitle1"
                @update:model-value="onAmountChanged"
              >
                <template #append>
                  <q-btn
                    flat
                    dense
                    no-caps
                    size="sm"
                    label="Pay Full Due"
                    color="primary"
                    class="text-weight-bold rounded-xs"
                    @click="setFullAmount"
                  />
                </template>
              </q-input>

              <!-- Quick Helper Presets -->
              <div class="row items-center q-gutter-x-xs q-mt-2xs">
                <span class="text-2xs text-grey-5">Quick:</span>
                <q-btn
                  flat
                  dense
                  no-caps
                  size="xs"
                  label="Pay Full Remaining Due"
                  color="primary"
                  class="bg-blue-1 rounded-xs q-px-xs text-weight-bold"
                  @click="setFullAmount"
                />
                <q-btn
                  flat
                  dense
                  no-caps
                  size="xs"
                  label="Clear"
                  color="grey-6"
                  class="rounded-xs q-px-xs"
                  @click="clearAmounts"
                />
              </div>
            </div>

            <!-- Payment Method & Reference -->
            <div class="col-12 col-md-4">
              <div class="text-caption text-weight-bold text-grey-8 q-mb-2xs">Payment Method</div>
              <q-select
                v-model="batchPayment.method"
                :options="paymentMethods"
                outlined
                dense
                emit-value
                map-options
                class="bg-white"
              />
            </div>

            <div class="col-12 col-md-3">
              <div class="text-caption text-weight-bold text-grey-8 q-mb-2xs">Trx ID / Ref (Optional)</div>
              <q-input
                v-model="batchPayment.reference"
                outlined
                dense
                placeholder="e.g. TR-2026-901"
                class="bg-white"
              />
            </div>
          </div>
        </div>

        <!-- Invoices List (Modern Card-List Layout) -->
        <div class="col q-pa-md overflow-auto bg-grey-50">
          <div v-if="isLoadingGroupInvoices" class="row flex-center q-pa-xl">
            <q-spinner-dots size="36px" color="primary" />
          </div>

          <div v-else class="column q-gutter-y-xs">
            <div class="row items-center justify-between text-2xs text-weight-bold text-grey-6 text-uppercase q-px-xs q-mb-2xs">
              <div>Invoice & Outlet Details</div>
              <div>Payment Allocation</div>
            </div>

            <div
              v-for="inv in activeGroupInvoices"
              :key="inv.id"
              class="invoice-settle-card q-pa-sm bg-white rounded-borders border transition-all"
              :class="{ 'invoice-card-settled': (inv.allocated_amount || 0) >= inv.due_amount && (inv.allocated_amount || 0) > 0 }"
            >
              <div class="row items-center justify-between no-wrap">
                <!-- Left: Invoice Details -->
                <div class="col-grow">
                  <div class="row items-center q-gutter-x-xs no-wrap">
                    <span class="font-mono text-weight-bolder text-primary">{{ inv.invoice_no }}</span>
                    <q-badge color="grey-2" text-color="grey-8" class="text-2xs" style="border-radius: 4px">
                      {{ inv.invoice_type }}
                    </q-badge>
                    <span class="text-caption text-grey-5">•</span>
                    <span class="text-caption text-grey-7">{{ inv.branch_name }}</span>
                    
                    <!-- Pre-existing payment status indicator -->
                    <q-badge
                      v-if="inv.paid_amount > 0"
                      color="amber-1"
                      text-color="amber-9"
                      class="text-2xs text-weight-bold q-ml-2xs"
                      style="border-radius: 4px"
                    >
                      Partial (৳{{ formatCurrency(inv.paid_amount) }} paid)
                    </q-badge>
                  </div>
                  <div class="text-2xs text-grey-5 q-mt-3xs">
                    Issued: {{ inv.invoice_date }} • Due: {{ inv.due_date || 'N/A' }}
                  </div>
                </div>

                <!-- Middle: 3-Part Financial Breakdown for this invoice -->
                <div class="col-auto text-right q-px-md font-mono">
                  <div class="text-2xs text-grey-5">
                    Total: ৳{{ formatCurrency(inv.total_amount) }}
                    <span v-if="inv.paid_amount > 0" class="text-positive text-weight-bold q-ml-2xs">
                      (৳{{ formatCurrency(inv.paid_amount) }} paid)
                    </span>
                  </div>
                  <div class="text-body2 text-weight-bold text-negative">
                    Still Due: ৳{{ formatCurrency(inv.due_amount) }}
                  </div>
                </div>

                <!-- Right: Amount to Pay Input & Full button -->
                <div class="col-auto row items-center q-gutter-x-xs no-wrap">
                  <q-input
                    v-model.number="inv.allocated_amount"
                    type="number"
                    dense
                    outlined
                    placeholder="0"
                    style="width: 120px"
                    class="bg-white"
                    input-class="text-right font-mono text-weight-bolder text-positive"
                    :min="0"
                    :max="inv.due_amount"
                    @update:model-value="onLineAllocationChanged"
                  >
                    <template #append>
                      <q-btn
                        flat
                        dense
                        size="xs"
                        label="Max"
                        color="primary"
                        class="text-weight-bold"
                        @click="setLineMax(inv)"
                      />
                    </template>
                  </q-input>

                  <!-- Status Chip for this transaction -->
                  <div style="width: 110px" class="text-center">
                    <q-badge
                      v-if="(inv.allocated_amount || 0) >= inv.due_amount && (inv.allocated_amount || 0) > 0"
                      color="positive"
                      text-color="white"
                      class="q-py-2xs q-px-xs text-weight-bold full-width"
                      style="border-radius: 6px"
                    >
                      Will Settle Due
                    </q-badge>
                    <q-badge
                      v-else-if="(inv.allocated_amount || 0) > 0"
                      color="primary"
                      text-color="white"
                      class="q-py-2xs q-px-xs text-weight-bold full-width"
                      style="border-radius: 6px"
                    >
                      +৳{{ formatCurrency(inv.allocated_amount || 0) }}
                    </q-badge>
                    <span v-else class="text-2xs text-grey-5 font-mono">No payment</span>
                  </div>
                </div>
              </div>

              <!-- Optional Concession / Write-off Expandable Option -->
              <div class="row items-center justify-between q-mt-xs pt-xs border-top-dashed text-2xs">
                <div class="row items-center q-gutter-x-xs">
                  <q-checkbox
                    v-model="inv.is_write_off_enabled"
                    dense
                    size="xs"
                    color="negative"
                    @update:model-value="onWriteOffToggle(inv)"
                  />
                  <span class="text-grey-7" :class="{ 'text-negative text-weight-bold': inv.is_write_off_enabled }">
                    Concession / Write-Off
                  </span>
                </div>

                <div v-if="inv.is_write_off_enabled" class="row items-center q-gutter-x-xs">
                  <q-input
                    v-model.number="inv.written_off_amount_input"
                    type="number"
                    dense
                    outlined
                    placeholder="Amount"
                    style="width: 90px"
                    class="bg-white"
                    input-class="text-right font-mono text-weight-bold text-negative"
                  />
                  <q-select
                    v-model="inv.written_off_reason"
                    :options="writeOffReasons"
                    dense
                    outlined
                    emit-value
                    map-options
                    style="font-size: 11px; width: 140px"
                    class="bg-white"
                  />
                </div>

                <div class="font-mono text-grey-6">
                  Remaining Due: <strong :class="getNewDue(inv) === 0 ? 'text-positive' : 'text-negative'">৳{{ formatCurrency(getNewDue(inv)) }}</strong>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Modern Summary Footer -->
        <div class="q-pa-md bg-white border-top row items-center justify-between no-wrap">
          <div class="row items-center q-gutter-x-lg">
            <div>
              <div class="text-2xs text-grey-6 text-uppercase">Payment Received</div>
              <div class="text-subtitle1 font-mono text-weight-bolder text-primary leading-tight">
                ৳{{ formatCurrency(batchPayment.amount) }}
              </div>
            </div>

            <q-separator vertical style="height: 28px" />

            <div>
              <div class="text-2xs text-grey-6 text-uppercase">Applied to Invoices</div>
              <div class="text-subtitle1 font-mono text-weight-bolder text-positive leading-tight">
                ৳{{ formatCurrency(totalBatchAllocated) }}
              </div>
            </div>

            <q-separator vertical style="height: 28px" />

            <div>
              <div class="text-2xs text-grey-6 text-uppercase">Remaining Outstanding</div>
              <div
                class="text-subtitle1 font-mono text-weight-bolder leading-tight"
                :class="remainingDueTotal === 0 ? 'text-positive' : 'text-negative'"
              >
                ৳{{ formatCurrency(remainingDueTotal) }}
              </div>
            </div>
          </div>

          <div class="row items-center q-gutter-sm">
            <q-btn flat label="Cancel" color="grey-7" no-caps v-close-popup class="rounded-btn q-px-md" />
            <q-btn
              unelevated
              color="primary"
              no-caps
              class="rounded-btn text-weight-bold q-px-lg shadow-1"
              style="font-size: 14px; height: 40px"
              :loading="isSubmittingPayment"
              :disable="batchPayment.amount <= 0 || (totalBatchAllocated === 0 && totalBatchWrittenOff === 0)"
              @click="submitBatchSettlement"
            >
              <q-icon name="ph ph-check-circle" size="18px" class="q-mr-xs" />
              <span>Post Payment (৳{{ formatCurrency(totalBatchAllocated) }})</span>
            </q-btn>
          </div>
        </div>
      </q-card>
    </q-dialog>

    <!-- ======================================================================= -->
    <!-- 2. DIRECT SINGLE INVOICE PAYMENT DIALOG                                 -->
    <!-- ======================================================================= -->
    <q-dialog v-model="singleDialogOpen" persistent max-width="480px">
      <q-card class="bg-white text-grey-9 rounded-card column no-wrap shadow-2" style="width: 480px; max-width: 95vw">
        <div class="q-pa-md bg-grey-1 border-bottom row items-center justify-between">
          <div class="row items-center q-gutter-sm">
            <q-avatar size="34px" color="primary" text-color="white" square class="rounded-avatar">
              <q-icon name="ph ph-receipt" size="18px" />
            </q-avatar>
            <div>
              <div class="text-subtitle2 text-weight-bold font-mono">{{ activeInvoice?.invoice_no }}</div>
              <div class="text-2xs text-grey-6">{{ activeInvoice?.customer_group_name }} • {{ activeInvoice?.branch_name }}</div>
            </div>
          </div>
          <q-btn flat round dense icon="ph ph-x" color="grey-6" v-close-popup />
        </div>

        <div class="q-pa-md">
          <!-- Financial Overview Card -->
          <div class="q-pa-sm bg-grey-1 rounded-borders border row items-center justify-between q-mb-md font-mono">
            <div>
              <div class="text-2xs text-grey-6 text-uppercase">Total Billed</div>
              <div class="text-caption text-weight-bold text-grey-8">৳{{ formatCurrency(activeInvoice?.total_amount || 0) }}</div>
            </div>
            <div>
              <div class="text-2xs text-grey-6 text-uppercase">Already Paid</div>
              <div class="text-caption text-weight-bold text-positive">৳{{ formatCurrency(activeInvoice?.paid_amount || 0) }}</div>
            </div>
            <div class="text-right">
              <div class="text-2xs text-grey-6 text-uppercase">Current Due</div>
              <div class="text-subtitle1 text-weight-bolder text-negative leading-tight">৳{{ formatCurrency(activeInvoice?.due_amount || 0) }}</div>
            </div>
          </div>

          <div class="column q-gutter-y-sm">
            <div>
              <div class="text-caption text-weight-bold text-grey-8 q-mb-2xs">Amount to Pay (৳)</div>
              <q-input
                v-model.number="singlePayment.amount"
                type="number"
                outlined
                dense
                prefix="৳"
                class="modern-amount-input"
                input-class="text-weight-bolder text-primary text-subtitle1"
              />
            </div>

            <div>
              <div class="text-caption text-weight-bold text-grey-8 q-mb-2xs">Payment Method</div>
              <q-select
                v-model="singlePayment.method"
                :options="paymentMethods"
                outlined
                dense
                emit-value
                map-options
              />
            </div>

            <div>
              <div class="text-caption text-weight-bold text-grey-8 q-mb-2xs">Reference / Trx ID (Optional)</div>
              <q-input
                v-model="singlePayment.reference"
                outlined
                dense
                placeholder="e.g. TR-2026-981"
              />
            </div>
          </div>
        </div>

        <div class="q-pa-md bg-white border-top row items-center justify-end q-gutter-sm">
          <q-btn flat label="Cancel" color="grey-7" no-caps v-close-popup class="rounded-btn q-px-md" />
          <q-btn
            unelevated
            color="primary"
            no-caps
            class="rounded-btn text-weight-bold q-px-lg shadow-1"
            style="height: 38px"
            :loading="isSubmittingPayment"
            :disable="singlePayment.amount <= 0"
            @click="submitSinglePayment"
          >
            <q-icon name="ph ph-check" size="16px" class="q-mr-xs" />
            <span>Confirm Payment</span>
          </q-btn>
        </div>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useQuasar, type QTableProps } from 'quasar';
import { usePayments } from '../composables/usePaymentsQuery';
import type { CustomerGroupPaymentSummary, OpenInvoicePaymentItem } from '../types/paymentsTypes';

const $q = useQuasar();

const {
  tenantId,
  searchQuery,
  customerGroups,
  isCustomerGroupsLoading,
  openInvoices,
  isOpenInvoicesLoading,
  fetchGroupInvoices,
  recordPayment,
  isSubmittingPayment,
  refetchAll,
} = usePayments();

// 1. View Mode & Search
const paymentMode = ref<'customer' | 'invoice'>('customer');
const invoiceStatusFilter = ref('all');

const viewTabs = [
  { label: 'Customer Groups', value: 'customer', icon: 'ph ph-users-three' },
  { label: 'Open Invoices', value: 'invoice', icon: 'ph ph-receipt' },
];

const statusOptions = [
  { label: 'All Open', value: 'all' },
  { label: 'Due Only', value: 'due' },
  { label: 'Partial Only', value: 'partial' },
];

const paymentMethods = [
  { label: 'Bank Transfer (EFT)', value: 'bank_transfer' },
  { label: 'bKash Merchant / MFS', value: 'bkash' },
  { label: 'Cash Collection', value: 'cash' },
  { label: 'Cheque Clearance', value: 'cheque' },
];

const writeOffReasons = [
  { label: 'Dispute Settlement', value: 'dispute_settlement' },
  { label: 'Bad Debt', value: 'bad_debt' },
  { label: 'Rounding Adjustment', value: 'rounding_adjustment' },
  { label: 'Concession Discount', value: 'concession_discount' },
];

// =========================================================================
// CUSTOMER GROUPS LIST
// =========================================================================
const customerColumns: QTableProps['columns'] = [
  { name: 'customer', label: 'Customer Group / Account', field: 'name', align: 'left' },
  { name: 'branches', label: 'Outlets', field: 'branches', align: 'left' },
  { name: 'invoices', label: 'Open Invoices', field: 'open_invoice_count', align: 'center' },
  { name: 'total', label: 'Total Invoiced', field: 'total_invoiced', align: 'right' },
  { name: 'paid', label: 'Paid So Far', field: 'total_paid', align: 'right' },
  { name: 'due', label: 'Total Outstanding Due', field: 'total_due', align: 'right' },
  { name: 'actions', label: '', field: 'id', align: 'right' },
];

// =========================================================================
// INVOICES LIST
// =========================================================================
const invoiceColumns: QTableProps['columns'] = [
  { name: 'invoice_no', label: 'Invoice No', field: 'invoice_no', align: 'left' },
  { name: 'outlet', label: 'Customer / Outlet', field: 'customer_group_name', align: 'left' },
  { name: 'date', label: 'Issue Date', field: 'invoice_date', align: 'left' },
  { name: 'due_date', label: 'Due Date', field: 'due_date', align: 'left' },
  { name: 'total', label: 'Total', field: 'total_amount', align: 'right' },
  { name: 'paid', label: 'Paid', field: 'paid_amount', align: 'right' },
  { name: 'due', label: 'Due Balance', field: 'due_amount', align: 'right' },
  { name: 'status', label: 'Status', field: 'payment_status', align: 'center' },
  { name: 'actions', label: '', field: 'id', align: 'right' },
];

const filteredInvoices = computed(() => {
  let list = openInvoices.value;
  if (invoiceStatusFilter.value === 'due') {
    list = list.filter((i) => i.paid_amount === 0);
  } else if (invoiceStatusFilter.value === 'partial') {
    list = list.filter((i) => i.paid_amount > 0);
  }
  return list;
});

function getRowStatusClass(inv: OpenInvoicePaymentItem) {
  if (inv.paid_amount > 0) return 'row-tint-partial';
  return 'row-tint-due';
}

function isOverdue(dueDate: string | null) {
  if (!dueDate) return false;
  return new Date(dueDate) < new Date();
}

// =========================================================================
// BATCH MODAL LOGIC (CUSTOMER GROUP)
// =========================================================================
const batchDialogOpen = ref(false);
const activeGroup = ref<CustomerGroupPaymentSummary | null>(null);
const activeGroupInvoices = ref<OpenInvoicePaymentItem[]>([]);
const isLoadingGroupInvoices = ref(false);

const batchPayment = reactive({
  amount: 0,
  method: 'bank_transfer',
  reference: '',
});

async function openBatchSettlement(grp: CustomerGroupPaymentSummary) {
  activeGroup.value = grp;
  batchPayment.amount = 0;
  batchPayment.reference = '';
  batchPayment.method = 'bank_transfer';
  batchDialogOpen.value = true;
  isLoadingGroupInvoices.value = true;

  try {
    const invs = await fetchGroupInvoices(grp.id);
    activeGroupInvoices.value = invs.map((i) => ({
      ...i,
      allocated_amount: 0,
      is_write_off_enabled: false,
      written_off_amount_input: 0,
      written_off_reason: 'dispute_settlement',
    }));
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: `Failed to load invoices for ${grp.name}: ${(err as Error).message}`,
      position: 'top-right',
    });
  } finally {
    isLoadingGroupInvoices.value = false;
  }
}

function setFullAmount() {
  if (!activeGroup.value) return;
  batchPayment.amount = activeGroup.value.total_due;
  applyFIFOAllocation();
}

function clearAmounts() {
  batchPayment.amount = 0;
  activeGroupInvoices.value.forEach((inv) => {
    inv.allocated_amount = 0;
  });
}

function onAmountChanged() {
  applyFIFOAllocation();
}

function applyFIFOAllocation() {
  let remaining = Number(batchPayment.amount || 0);
  for (const inv of activeGroupInvoices.value) {
    const due = inv.due_amount - (inv.is_write_off_enabled ? (inv.written_off_amount_input || 0) : 0);
    if (remaining >= due) {
      inv.allocated_amount = due;
      remaining -= due;
    } else {
      inv.allocated_amount = remaining;
      remaining = 0;
    }
  }
}

function setLineMax(inv: OpenInvoicePaymentItem) {
  const maxAllowed = inv.due_amount - (inv.is_write_off_enabled ? (inv.written_off_amount_input || 0) : 0);
  inv.allocated_amount = maxAllowed;
  onLineAllocationChanged();
}

function onLineAllocationChanged() {
  // Sync the top total payment amount with the sum of line allocations
  batchPayment.amount = totalBatchAllocated.value;
}


function onWriteOffToggle(inv: OpenInvoicePaymentItem) {
  if (inv.is_write_off_enabled) {
    inv.written_off_amount_input = Math.max(0, inv.due_amount - (inv.allocated_amount || 0));
  } else {
    inv.written_off_amount_input = 0;
  }
}

function getNewDue(inv: OpenInvoicePaymentItem) {
  const alloc = inv.allocated_amount || 0;
  const wo = inv.is_write_off_enabled ? (inv.written_off_amount_input || 0) : 0;
  return Math.max(0, inv.due_amount - alloc - wo);
}

const totalBatchAllocated = computed(() =>
  activeGroupInvoices.value.reduce((s, i) => s + (i.allocated_amount || 0), 0),
);

const totalBatchWrittenOff = computed(() =>
  activeGroupInvoices.value.reduce((s, i) => s + (i.is_write_off_enabled ? (i.written_off_amount_input || 0) : 0), 0),
);

const remainingDueTotal = computed(() =>
  activeGroupInvoices.value.reduce((s, i) => s + getNewDue(i), 0),
);

async function submitBatchSettlement() {
  if (!tenantId.value || !activeGroup.value) return;

  const allocations = activeGroupInvoices.value
    .filter((inv) => (inv.allocated_amount || 0) > 0)
    .map((inv) => ({
      invoice_id: inv.id,
      amount: inv.allocated_amount || 0,
    }));

  const writeOffs = activeGroupInvoices.value
    .filter((inv) => inv.is_write_off_enabled && (inv.written_off_amount_input || 0) > 0)
    .map((inv) => ({
      invoice_id: inv.id,
      amount: inv.written_off_amount_input || 0,
      reason: inv.written_off_reason || 'dispute_settlement',
    }));

  try {
    const res = await recordPayment({
      tenant_id: tenantId.value,
      customer_group_id: activeGroup.value.id,
      amount: Number(batchPayment.amount || 0),
      payment_date: new Date().toISOString().split('T')[0],
      method: batchPayment.method,
      reference: batchPayment.reference || null,
      allocations,
      write_offs: writeOffs,
    });

    batchDialogOpen.value = false;
    $q.notify({
      type: 'positive',
      message: `Payment of ৳${formatCurrency(res.total_amount)} posted successfully!`,
      position: 'top-right',
    });
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: `Failed to post batch payment: ${(err as Error).message}`,
      position: 'top-right',
    });
  }
}

// =========================================================================
// SINGLE INVOICE MODAL LOGIC
// =========================================================================
const singleDialogOpen = ref(false);
const activeInvoice = ref<OpenInvoicePaymentItem | null>(null);
const singlePayment = reactive({
  amount: 0,
  method: 'bank_transfer',
  reference: '',
});

function openSinglePayment(inv: OpenInvoicePaymentItem) {
  activeInvoice.value = inv;
  singlePayment.amount = inv.due_amount;
  singlePayment.reference = '';
  singlePayment.method = 'bank_transfer';
  singleDialogOpen.value = true;
}

async function submitSinglePayment() {
  if (!tenantId.value || !activeInvoice.value) return;

  try {
    const res = await recordPayment({
      tenant_id: tenantId.value,
      customer_group_id: activeInvoice.value.customer_group_id,
      amount: Number(singlePayment.amount || 0),
      payment_date: new Date().toISOString().split('T')[0],
      method: singlePayment.method,
      reference: singlePayment.reference || null,
      allocations: [
        {
          invoice_id: activeInvoice.value.id,
          amount: Number(singlePayment.amount || 0),
        },
      ],
      write_offs: [],
    });

    singleDialogOpen.value = false;
    $q.notify({
      type: 'positive',
      message: `Payment of ৳${formatCurrency(res.total_amount)} recorded for ${activeInvoice.value.invoice_no}!`,
      position: 'top-right',
    });
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: `Failed to record payment: ${(err as Error).message}`,
      position: 'top-right',
    });
  }
}

function formatCurrency(val: number) {
  return Number(val || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
  overflow: hidden;
}

.border {
  border: 1px solid var(--q-separator-color, #e2e0db);
}

.border-bottom {
  border-bottom: 1px solid var(--q-separator-color, #e2e0db);
}

.border-top {
  border-top: 1px solid var(--q-separator-color, #e2e0db);
}

.border-top-dashed {
  border-top: 1px dashed #e2e0db;
}

.rounded-card {
  border-radius: 12px;
}

.rounded-btn {
  border-radius: 8px;
}

.rounded-avatar {
  border-radius: 8px;
}

.rounded-xs {
  border-radius: 4px;
}

.status-chip {
  border-radius: 6px;
  font-size: 11px;
}

.text-2xs {
  font-size: 10px;
  line-height: 1.2;
}

.quick-filter-toggle {
  background: rgba(0, 0, 0, 0.04);
  border-radius: 8px;
  padding: 2px;
}

.quick-filter-btn {
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  padding: 4px 10px;
}

.dense-filter-select :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
  border-radius: 8px;
}

.dense-search-input :deep(.q-field__control) {
  height: 32px;
  min-height: 32px;
}

/* Row Status Accents */
.row-tint-partial {
  box-shadow: inset 3px 0 0 #f59e0b;
}

.row-tint-due {
  box-shadow: inset 3px 0 0 #9ca3af;
}

.treasury-ops-table {
  background: white;
}

.treasury-ops-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  font-weight: 700;
  font-size: 11px;
  background: #fbfaf7;
  color: #44403c;
  border-bottom: 1px solid #e7e5e4;
}

.treasury-ops-table :deep(.q-table__middle) {
  overflow-y: auto;
}

/* Invoice Card List */
.bg-grey-50 {
  background-color: #f8fafc;
}

.invoice-settle-card {
  border-radius: 8px;
  transition: all 0.2s ease-in-out;
}

.invoice-settle-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.invoice-card-settled {
  background-color: #f0fdf4 !important;
  border-color: #bbf7d0 !important;
}

.modern-amount-input :deep(.q-field__control) {
  background: white;
  border-radius: 8px;
}
</style>
