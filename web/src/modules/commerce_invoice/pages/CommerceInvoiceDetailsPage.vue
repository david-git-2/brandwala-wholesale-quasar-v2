<template>
  <q-page class="q-pa-md commerce-invoice-details-page">
    <!-- Loading State -->
    <PageInitialLoader v-if="loading" />

    <!-- Error State -->
    <div v-else-if="error" class="column items-center justify-center q-pa-xl text-black empty-state-block floating-surface shadow-1">
      <q-icon name="error_outline" size="64px" class="q-mb-sm text-red" />
      <div class="text-subtitle1 text-weight-medium text-black">{{ error }}</div>
    </div>

    <!-- Details View -->
    <div v-else-if="invoice" class="invoice-details-wrap q-gutter-y-sm">
      <!-- Header Hero Card -->
      <q-card flat class="hero-surface floating-surface shadow-1 q-pa-sm q-px-md" :style="headerStyle">
        <div class="row items-center justify-between">
          <div>
            <div class="text-h6 text-weight-bold text-black">Invoice #{{ invoice.id }}</div>
            <div class="text-caption text-grey-8 row items-center q-gutter-x-sm wrap">
              <span>Order Ref: <span class="text-black text-weight-medium">#{{ invoice.order_id }}</span></span>
              <span class="q-ml-md">Invoice Date:
                <span class="text-black text-weight-medium cursor-pointer">
                  {{ invoice.invoice_date || '-' }}
                  <q-popup-proxy ref="headerDateProxy" cover transition-show="scale" transition-hide="scale">
                    <q-date :model-value="invoice.invoice_date" mask="YYYY-MM-DD" @update:model-value="(val) => { void onUpdateInvoiceCharge('invoice_date', val); headerDateProxy?.hide(); }">
                      <div class="row items-center justify-end">
                        <q-btn v-close-popup label="Close" color="primary" flat />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </span>
              </span>
            </div>
          </div>
          <div class="row items-center q-gutter-sm">
            <q-btn color="negative" icon="o_delete" flat dense class="pill-btn slim-btn" @click="onDeleteInvoice">
              <q-tooltip>Delete Invoice</q-tooltip>
            </q-btn>
            <!-- Preview Button -->
            <q-btn
              flat
              dense
              color="secondary"
              icon="o_visibility"
              class="pill-btn slim-btn"
              @click="openInvoicePreview"
            >
              <q-tooltip>Preview Invoice</q-tooltip>
            </q-btn>
            <q-btn color="primary" icon="o_search" flat dense class="pill-btn slim-btn" @click="openSearchDialogForAdd">
              <q-tooltip>Add From Stock</q-tooltip>
            </q-btn>

            <!-- Invoice Status Chip Selector -->
            <q-chip
              square
              dense
              clickable
              :style="statusChipStyle(invoice.status)"
              class="status-chip text-weight-bold q-px-md q-py-sm"
            >
              <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(invoice.status) }"></span>
              {{ formatStatusLabel(invoice.status).toUpperCase() }}
              <q-menu auto-close>
                <q-list dense style="min-width: 150px">
                  <q-item
                    v-for="opt in statusOptions"
                    :key="opt"
                    clickable
                    v-close-popup
                    @click="onStatusMenuSelect(invoice.id, opt)"
                  >
                    <q-item-section>{{ formatStatusLabel(opt).toUpperCase() }}</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-chip>

            <!-- Paid Status Chip -->
            <q-chip
              square
              dense
              :color="invoice.is_customer_group_paid ? 'green' : 'red'"
              text-color="white"
              class="text-weight-bold status-chip q-px-md q-py-sm"
            >
              {{ invoice.is_customer_group_paid ? 'PAID' : 'UNPAID' }}
            </q-chip>
          </div>
        </div>
      </q-card>

      <!-- Main Content Grid -->
      <div class="row q-col-gutter-md q-mt-xs">
        <!-- Left Panel: Items Table (col-12 col-md-8) -->
        <div class="col-12 col-md-8">
          <q-card flat class="floating-surface shadow-1 full-height column">
            <!-- Items Header & Add From Stock button -->
            <q-card-section class="row items-center justify-between q-py-sm q-px-md">
              <div class="text-subtitle1 text-weight-bold text-black row items-center">
                <q-icon name="shopping_bag" class="q-mr-xs text-primary" size="22px" />
                <span>Invoice Items ({{ items.length }})</span>
              </div>
              <q-btn
                color="primary"
                icon="add"
                label="Add Items"
                no-caps
                class="pill-btn slim-btn shadow-1"
                @click="openSearchDialogForAdd"
              >
                <q-tooltip>Add From Stock</q-tooltip>
              </q-btn>
            </q-card-section>

            <q-separator />

            <q-card-section class="q-pa-none col scroll">
              <div v-if="!items.length" class="text-grey-7 q-pa-xl text-center">
                <q-icon name="o_shopping_bag" size="48px" class="q-mb-xs text-grey-4" />
                <div class="text-subtitle2 text-weight-medium">No items on this invoice</div>
                <div class="text-caption text-grey-6">Click "Add Items" to add products from stock.</div>
              </div>
              <div v-else class="invoice-table-wrap">
                <q-markup-table flat wrap-cells class="invoice-items-table">
                  <thead>
                    <tr>
                      <th class="text-left" style="width: 56px">SL</th>
                      <th class="text-left" style="width: 72px">Image</th>
                      <th class="text-left">Product / ID</th>
                      <th class="text-right">Cost Price</th>
                      <th class="text-right">Sell Price</th>
                      <th class="text-right">Recipient Price</th>
                      <th class="text-right" style="width: 80px">Qty</th>
                      <th class="text-right">Line Total</th>
                      <th class="text-right" style="width: 90px">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(row, idx) in items" :key="row.id" class="item-row">
                      <td class="text-grey-7">{{ idx + 1 }}</td>
                      <td>
                        <q-avatar rounded size="48px" class="bg-grey-2 border-all shadow-1">
                          <img :src="row.image_url || 'https://placehold.co/48x48?text=No+Image'" alt="" style="object-fit: contain;" />
                        </q-avatar>
                      </td>
                      <td style="white-space: normal; word-break: break-word; min-width: 200px;">
                        <div class="text-weight-bold text-grey-9">{{ row.products?.name || 'Product ID: ' + row.product_id }}</div>
                        <div class="text-caption text-grey-7">Code: {{ row.products?.product_code || '-' }}</div>
                        <div class="text-caption text-grey-7">
                          Shipment:
                          <template v-if="row.inventory_items?.source_type === 'shipment' && row.inventory_items?.source_id">
                            #{{ row.inventory_items.tenant_shipment_id ?? row.inventory_items.source_id }}
                            <template v-if="row.inventory_items.shipment_name">
                              - {{ row.inventory_items.shipment_name }}
                            </template>
                          </template>
                          <template v-else>
                            -
                          </template>
                        </div>
                        <div class="text-caption text-grey-7">
                          Stock:
                          <template v-if="row.inventory_item_id">
                            #{{ row.inventory_item_id }} - {{ row.inventory_items?.name || 'Assigned' }}
                          </template>
                          <template v-else>
                            Not assigned
                          </template>
                        </div>
                      </td>
                      <td class="text-right">৳{{ formatAmount(Number(row.cost_bdt || 0)) }}</td>
                      <!-- Sell Price (editable) -->
                      <td class="text-right editable-cell cursor-pointer">
                        <div class="row items-center justify-end text-primary text-weight-medium">
                          <span>৳{{ formatAmount(Number(row.sell_price_bdt || 0)) }}</span>
                          <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                        </div>
                        <q-popup-edit
                          :model-value="row.sell_price_bdt"
                          buttons
                          label-set="Save"
                          label-cancel="Cancel"
                          @save="(val) => onInlineUpdateItem(row, 'sell_price_bdt', val)"
                          v-slot="scope"
                        >
                          <q-input
                            v-model.number="scope.value"
                            type="number"
                            dense
                            autofocus
                            min="0"
                            label="Sell Price"
                          />
                        </q-popup-edit>
                      </td>
                      <!-- Recipient Price (editable) -->
                      <td class="text-right editable-cell cursor-pointer">
                        <div class="row items-center justify-end text-primary text-weight-medium">
                          <span>৳{{ formatAmount(Number(row.recipient_price_bdt || 0)) }}</span>
                          <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                        </div>
                        <q-popup-edit
                          :model-value="row.recipient_price_bdt"
                          buttons
                          label-set="Save"
                          label-cancel="Cancel"
                          @save="(val) => onInlineUpdateItem(row, 'recipient_price_bdt', val)"
                          v-slot="scope"
                        >
                          <q-input
                            v-model.number="scope.value"
                            type="number"
                            dense
                            autofocus
                            min="0"
                            label="Recipient Price"
                          />
                        </q-popup-edit>
                      </td>
                      <!-- Quantity (editable) -->
                      <td class="text-right editable-cell cursor-pointer">
                        <div class="row items-center justify-end text-primary text-weight-medium">
                          <span>{{ row.quantity }}</span>
                          <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                        </div>
                        <q-popup-edit
                          :model-value="row.quantity"
                          buttons
                          label-set="Save"
                          label-cancel="Cancel"
                          @save="(val) => onInlineUpdateItem(row, 'quantity', val)"
                          v-slot="scope"
                        >
                          <q-input
                            v-model.number="scope.value"
                            type="number"
                            dense
                            autofocus
                            min="1"
                            label="Quantity"
                          />
                        </q-popup-edit>
                      </td>
                      <td class="text-right text-weight-bold">৳{{ formatAmount(Number(row.quantity || 0) * Number(row.recipient_price_bdt || 0)) }}</td>
                      <td class="text-right">
                        <q-btn
                          flat
                          round
                          dense
                          :icon="row.inventory_item_id ? 'o_link_off' : 'o_inventory_2'"
                          :color="row.inventory_item_id ? 'negative' : 'primary'"
                          @click="row.inventory_item_id ? unassignInventoryItem(row) : openSearchDialogForAssign(row)"
                        >
                          <q-tooltip>{{ row.inventory_item_id ? 'Unassign Stock' : 'Assign Stock' }}</q-tooltip>
                        </q-btn>
                        <q-btn
                          flat
                          round
                          dense
                          icon="o_delete"
                          color="negative"
                          @click="removeItem(row.id)"
                        >
                          <q-tooltip>Remove from Invoice</q-tooltip>
                        </q-btn>
                      </td>
                    </tr>
                    <!-- Totals Row -->
                    <tr class="totals-row">
                      <td colspan="6" class="text-right text-weight-bold text-black">Total Quantity</td>
                      <td class="text-right text-weight-bold text-black">{{ totalQuantity }}</td>
                      <td class="text-right text-weight-bold text-primary">৳{{ formatAmount(subtotalAmount) }}</td>
                      <td></td>
                    </tr>
                  </tbody>
                </q-markup-table>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Right Panel: Summary & Details (col-12 col-md-4) -->
        <div class="col-12 col-md-4 q-gutter-y-md">
          <!-- Billing Summary Card (Receipt style) -->
          <q-card flat class="floating-surface shadow-1 q-pa-md receipt-card">
            <div class="text-subtitle2 text-weight-bold text-primary q-mb-md row items-center">
              <q-icon name="o_receipt" class="q-mr-xs" size="20px" />
              <span>Billing Summary</span>
            </div>

            <div class="q-gutter-y-sm">
              <!-- Subtotal -->
              <div class="row justify-between items-center text-body2 q-py-xs">
                <div class="text-grey-7">Subtotal</div>
                <div class="text-weight-bold text-black">৳{{ formatAmount(subtotalAmount) }}</div>
              </div>

              <!-- Delivery Charge -->
              <div class="row justify-between items-center text-body2 q-py-xs editable-field">
                <div class="text-grey-7">Delivery Charge</div>
                <div class="text-weight-bold text-black cursor-pointer row items-center">
                  <span>৳{{ formatAmount(invoice.delivery_charge) }}</span>
                  <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                  <q-popup-edit
                    v-if="invoice.invoice_type !== 'wholesale'"
                    :model-value="Number(invoice.delivery_charge || 0)"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="(val) => onUpdateInvoiceCharge('delivery_charge', val)"
                    v-slot="scope"
                  >
                    <q-input
                      v-model.number="scope.value"
                      type="number"
                      dense
                      autofocus
                      min="0"
                      label="Delivery Charge"
                    />
                  </q-popup-edit>
                  <q-tooltip v-if="invoice.invoice_type === 'wholesale'">Wholesale invoices have no delivery charge</q-tooltip>
                </div>
              </div>

              <!-- Wrapping Charge -->
              <div class="row justify-between items-center text-body2 q-py-xs editable-field">
                <div class="text-grey-7">Wrapping Charge</div>
                <div class="text-weight-bold text-black cursor-pointer row items-center">
                  <span>৳{{ formatAmount(invoice.wrapping_charge) }}</span>
                  <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                  <q-popup-edit
                    v-if="invoice.invoice_type !== 'wholesale'"
                    :model-value="Number(invoice.wrapping_charge || 0)"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="(val) => onUpdateInvoiceCharge('wrapping_charge', val)"
                    v-slot="scope"
                  >
                    <q-input
                      v-model.number="scope.value"
                      type="number"
                      dense
                      autofocus
                      min="0"
                      label="Wrapping Charge"
                    />
                  </q-popup-edit>
                  <q-tooltip v-if="invoice.invoice_type === 'wholesale'">Wholesale invoices have no wrapping charge</q-tooltip>
                </div>
              </div>

              <!-- COD Charge -->
              <div class="row justify-between items-center text-body2 q-py-xs editable-field">
                <div class="text-grey-7">COD Charge</div>
                <div class="text-weight-bold text-black cursor-pointer row items-center">
                  <span>৳{{ formatAmount(invoice.cod) }}</span>
                  <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                  <q-popup-edit
                    v-if="invoice.invoice_type !== 'wholesale'"
                    :model-value="Number(invoice.cod || 0)"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="(val) => onUpdateInvoiceCharge('cod', val)"
                    v-slot="scope"
                  >
                    <q-input
                      v-model.number="scope.value"
                      type="number"
                      dense
                      autofocus
                      min="0"
                      label="COD Charge"
                    />
                  </q-popup-edit>
                  <q-tooltip v-if="invoice.invoice_type === 'wholesale'">Wholesale invoices have no COD charge</q-tooltip>
                </div>
              </div>

              <!-- Discount -->
              <div class="row justify-between items-center text-body2 q-py-xs editable-field">
                <div class="text-grey-7">Discount</div>
                <div class="text-weight-bold text-orange-9 cursor-pointer row items-center">
                  <span>-৳{{ formatAmount(Number(invoice.discount_amount || 0)) }}</span>
                  <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                  <q-popup-edit
                    :model-value="Number(invoice.discount_amount || 0)"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="(val) => onUpdateInvoiceCharge('discount_amount', val)"
                    v-slot="scope"
                  >
                    <q-input
                      v-model.number="scope.value"
                      type="number"
                      dense
                      autofocus
                      min="0"
                      label="Discount Amount"
                    />
                  </q-popup-edit>
                </div>
              </div>

              <q-separator class="q-my-xs" />

              <!-- Grand Total -->
              <div class="row justify-between items-center q-py-xs">
                <div class="text-subtitle2 text-weight-bold text-grey-9">Grand Total</div>
                <div class="text-subtitle1 text-weight-bolder text-black">৳{{ formatAmount(Number(invoice.total_amount || 0)) }}</div>
              </div>

              <!-- Paid Amount -->
              <div class="row justify-between items-center text-body2 q-py-xs editable-field">
                <div class="text-grey-7">Paid Amount</div>
                <div class="text-weight-bold text-primary cursor-pointer row items-center">
                  <span>৳{{ formatAmount(Number(invoice.amount_paid || 0)) }}</span>
                  <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                  <q-popup-edit
                    :model-value="Number(invoice.amount_paid || 0)"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="(val) => onUpdateInvoiceCharge('amount_paid', val)"
                    v-slot="scope"
                  >
                    <q-input
                      v-model.number="scope.value"
                      type="number"
                      dense
                      autofocus
                      min="0"
                      label="Paid Amount"
                    />
                  </q-popup-edit>
                </div>
              </div>

              <!-- Amount Due status section -->
              <div
                class="row justify-between items-center q-pa-sm q-mt-sm rounded-borders text-subtitle2"
                :class="Number(invoice.amount_due || 0) > 0 ? 'bg-red-1 text-red-9' : 'bg-green-1 text-green-9'"
              >
                <div class="text-weight-bold">Amount Due</div>
                <div class="text-weight-bolder">৳{{ formatAmount(Number(invoice.amount_due || 0)) }}</div>
              </div>
            </div>
          </q-card>

          <!-- Recipient Details Card -->
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold text-primary q-mb-md row items-center">
              <q-icon name="o_assignment" class="q-mr-xs" size="20px" />
              <span>Recipient Details</span>
            </div>

            <div class="q-gutter-y-xs">
              <div v-if="invoice && invoice.billing_profiles" class="q-gutter-y-sm">
                <div>
                  <div class="text-caption text-grey-7 text-weight-medium">Recipient Name</div>
                  <div class="text-body2 text-weight-bold text-grey-9">{{ invoice.billing_profiles.name }}</div>
                </div>
                <template v-if="invoice.invoice_type !== 'wholesale'">
                  <div>
                    <div class="text-caption text-grey-7 text-weight-medium">Recipient Phone</div>
                    <div class="text-body2 text-weight-medium text-grey-9">{{ invoice.billing_profiles.phone || '-' }}</div>
                  </div>
                  <div>
                    <div class="text-caption text-grey-7 text-weight-medium">Recipient Email</div>
                    <div class="text-body2 text-weight-medium text-grey-9">{{ invoice.billing_profiles.email || '-' }}</div>
                  </div>
                  <div>
                    <div class="text-caption text-grey-7 text-weight-medium">Billing/Shipping Address</div>
                    <div class="text-body2 text-grey-9 text-weight-medium" style="white-space: pre-wrap;">{{ invoice.billing_profiles.address || '-' }}</div>
                  </div>
                </template>
                <template v-else>
                  <div>
                    <div class="text-caption text-grey-7 text-weight-medium">Recipient Email</div>
                    <div class="text-body2 text-weight-medium text-grey-9">{{ invoice.billing_profiles.email || '-' }}</div>
                  </div>
                </template>
              </div>
              <div v-else-if="order" class="q-gutter-y-sm">
                <div>
                  <div class="text-caption text-grey-7 text-weight-medium">Recipient Name</div>
                  <div class="text-body2 text-weight-bold text-grey-9">{{ order.recipient_name }}</div>
                </div>
                <template v-if="invoice && invoice.invoice_type !== 'wholesale'">
                  <div>
                    <div class="text-caption text-grey-7 text-weight-medium">Recipient Phone</div>
                    <div class="text-body2 text-weight-medium text-grey-9">{{ order.recipient_phone }}</div>
                  </div>
                  <div>
                    <div class="text-caption text-grey-7 text-weight-medium">Shipping Address</div>
                    <div class="text-body2 text-grey-9 text-weight-medium" style="white-space: pre-wrap;">{{ order.shipping_address }}</div>
                  </div>
                </template>
              </div>
              <div v-else class="text-grey-6 q-pa-xs">No associated details found.</div>
            </div>
          </q-card>

          <!-- Delivery details card -->
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold text-primary q-mb-md row items-center">
              <q-icon name="o_local_shipping" class="q-mr-xs" size="20px" />
              <span>Delivery Details</span>
            </div>

            <div class="q-gutter-y-sm">
              <div class="editable-field">
                <div class="text-caption text-grey-7 text-weight-medium">Delivered By</div>
                <div class="text-body2 text-weight-bold text-grey-9 cursor-pointer row items-center">
                  <span>{{ invoice.delivered_by || 'Not Assigned' }}</span>
                  <q-icon name="edit" size="12px" class="edit-pencil-icon q-ml-xs" />
                  <q-popup-edit
                    v-if="invoice.invoice_type !== 'wholesale'"
                    :model-value="invoice.delivered_by || ''"
                    buttons
                    label-set="Save"
                    label-cancel="Cancel"
                    @save="(val) => onUpdateInvoiceCharge('delivered_by', val)"
                    v-slot="scope"
                  >
                    <q-input
                      v-model="scope.value"
                      dense
                      autofocus
                      label="Courier / Delivered By"
                    />
                  </q-popup-edit>
                  <q-tooltip v-if="invoice.invoice_type === 'wholesale'">Wholesale invoices have no Courier details</q-tooltip>
                </div>
              </div>
              <div>
                <div class="text-caption text-grey-7 text-weight-medium">Invoice Type</div>
                <div class="text-body2 text-weight-bold text-capitalize text-grey-9">{{ invoice.invoice_type || 'retail' }}</div>
              </div>
            </div>
          </q-card>
        </div>
      </div>
    </div>

    <!-- Inventory Search Dialog -->
    <q-dialog v-model="searchDialogOpen" backdrop-filter="blur(4px)">
      <q-card style="width: 1000px; max-width: 95vw; max-height: 85vh" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-py-sm">
          <div class="row items-center q-gutter-sm">
            <q-icon name="inventory_2" size="24px" color="primary" />
            <div class="text-h6 text-weight-bold text-black">{{ searchMode === 'assign' ? 'Assign Stock Item' : 'Add Item From Stock' }}</div>
          </div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />

        <q-card-section class="scroll q-pt-md" style="max-height: calc(85vh - 80px)">
          <!-- Search Toolbar -->
          <div class="row items-center q-col-gutter-sm q-mb-md">
            <div class="col-12 col-sm-3">
              <q-select
                v-model="searchBy"
                :options="searchByOptions"
                label="Search By"
                outlined
                dense
                emit-value
                map-options
                option-value="value"
                option-label="label"
                class="soft-input"
              />
            </div>
            <div class="col-12 col-sm-9 row no-wrap items-center q-gutter-xs">
              <q-input
                v-model="searchTerm"
                placeholder="Type to search stock batch..."
                outlined
                dense
                autofocus
                class="col soft-input"
                :loading="searchingInventory"
                @keyup.enter="searchInventoryItems"
              >
                <template #prepend>
                  <q-icon name="o_search" />
                </template>
                <template #append v-if="searchTerm">
                  <q-btn flat round dense icon="o_close" size="xs" @click="searchTerm = ''; searchResults = []" />
                </template>
              </q-input>
              <q-btn
                color="primary"
                no-caps
                label="Search"
                class="pill-btn slim-btn shadow-1"
                :loading="searchingInventory"
                @click="searchInventoryItems"
              />
            </div>
          </div>

          <div v-if="searchingInventory" class="row justify-center q-my-lg">
            <q-spinner-dots size="40px" color="primary" />
          </div>

          <div v-else-if="!sortedSearchItemsGrouped.length" class="text-center text-grey-7 q-py-xl">
            <q-icon name="o_inventory" size="48px" color="grey-4" class="q-mb-sm" />
            <div class="text-weight-medium">No stock items found.</div>
            <div class="text-caption text-grey-6">Try searching with a different term or field option.</div>
          </div>

          <!-- Grouped Subtypes Stock Search Results -->
          <div v-else class="q-gutter-y-md">
            <q-card
              v-for="group in sortedSearchItemsGrouped"
              :key="group.key"
              flat
              class="floating-surface shadow-1 border-light"
            >
              <q-card-section class="q-pa-md">
                <!-- Product details header -->
                <div class="row items-center no-wrap q-mb-md">
                  <q-avatar rounded size="64px" class="q-mr-md bg-grey-2 shadow-1">
                    <img :src="group.image_url || 'https://placehold.co/64x64?text=No+Image'" alt="" style="object-fit: contain;" />
                  </q-avatar>
                  <div class="col">
                    <div class="text-subtitle1 text-weight-bold text-black row items-center wrap">
                      <span>{{ group.name }}</span>
                      <q-badge color="purple" outline class="q-ml-sm" v-if="group.tenant_name">
                        {{ group.tenant_name }}
                      </q-badge>
                      <q-badge outline color="primary" class="q-ml-sm" v-if="group.shipment?.shipment">
                        Shipment #{{ group.shipment.shipment.tenant_shipment_id ?? group.shipment.shipment.id }} - {{ group.shipment.shipment.name }}
                      </q-badge>
                    </div>
                    <div class="row items-center q-gutter-x-md text-caption text-grey-7 q-mt-xs">
                      <span v-if="group.product_code">Code: <strong class="text-black">{{ group.product_code }}</strong></span>
                      <span v-if="group.barcode">Barcode: <strong class="text-black">{{ group.barcode }}</strong></span>
                      <span v-if="group.product_id">Product ID: <strong class="text-black">{{ group.product_id }}</strong></span>
                    </div>
                  </div>
                </div>

                <!-- Subtype list -->
                <div class="q-gutter-y-xs">
                  <div
                    v-for="subtype in (['standard', 'boxless', 'box_damage', 'expired'] as const)"
                    :key="subtype"
                    v-show="getSubtypeItem(group, subtype) && getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype) > 0"
                    class="row items-center justify-between q-py-sm border-top"
                  >
                    <!-- Subtype details -->
                    <div class="col-12 col-sm-5 text-subtitle2 text-grey-9 row items-center q-gutter-xs">
                      <q-icon
                        :name="getSubtypeIcon(subtype)"
                        :color="getSubtypeIconColor(subtype)"
                        size="18px"
                      />
                      <div class="column q-ml-xs">
                        <span class="text-weight-bold text-black" style="font-size: 13px;">{{ getSubtypeItem(group, subtype)?.name || getSubtypeLabel(subtype) }}</span>
                        <span class="text-caption text-grey-7" style="font-size: 11px;">Stock #: <strong class="text-black">{{ getSubtypeItem(group, subtype)?.id }}</strong></span>
                      </div>
                      <div class="row items-center q-gutter-xs q-mt-xs q-ml-sm">
                        <q-badge color="green-2" text-color="green-10" dense>
                          Stock: {{ getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype) }}
                        </q-badge>
                        <q-badge color="grey-3" text-color="grey-9" dense>
                          Cost: {{ getSubtypeItem(group, subtype)?.cost ?? 0 }} BDT
                        </q-badge>
                      </div>
                    </div>

                    <!-- Inputs / Action -->
                    <div class="col-12 col-sm-7 row items-center justify-end q-gutter-sm q-mt-xs-sm q-mt-sm-none">
                      <!-- Quantity input -->
                      <q-input
                        v-if="searchMode === 'add'"
                        :model-value="getAddQuantity(getSubtypeItem(group, subtype)?.id ?? -1)"
                        @update:model-value="(val) => setAddQuantity(getSubtypeItem(group, subtype)?.id ?? -1, val)"
                        type="number"
                        label="Quantity"
                        dense
                        outlined
                        class="soft-input text-center no-number-steppers"
                        style="width: 140px"
                        min="1"
                        :max="getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype)"
                      >
                        <template #prepend>
                          <q-btn
                            flat
                            round
                            dense
                            icon="remove"
                            size="sm"
                            class="q-mr-xs"
                            @click="decrementQty(getSubtypeItem(group, subtype)?.id ?? -1)"
                          />
                        </template>
                        <template #append>
                          <q-btn
                            flat
                            round
                            dense
                            icon="add"
                            size="sm"
                            class="q-ml-xs"
                            @click="incrementQty(getSubtypeItem(group, subtype)?.id ?? -1, getAvailableQuantityForSubtype(getSubtypeItem(group, subtype) ?? undefined, subtype))"
                          />
                        </template>
                      </q-input>

                      <!-- Sell Price input -->
                      <q-input
                        v-if="searchMode === 'add'"
                        :model-value="getSellPrice(getSubtypeItem(group, subtype)?.id ?? -1, Number(getSubtypeItem(group, subtype)?.cost || 0))"
                        @update:model-value="(val) => setSellPrice(getSubtypeItem(group, subtype)?.id ?? -1, val)"
                        type="number"
                        dense
                        outlined
                        min="0"
                        label="Sell Price (BDT)"
                        class="soft-input no-number-steppers"
                        style="width: 130px"
                      />

                      <!-- Recipient Price input -->
                      <q-input
                        v-if="searchMode === 'add'"
                        :model-value="getRecipientPrice(getSubtypeItem(group, subtype)?.id ?? -1, Number(getSubtypeItem(group, subtype)?.cost || 0))"
                        @update:model-value="(val) => setRecipientPrice(getSubtypeItem(group, subtype)?.id ?? -1, val)"
                        type="number"
                        dense
                        outlined
                        min="0"
                        label="Recipient Price"
                        class="soft-input no-number-steppers"
                        style="width: 130px"
                      />

                      <q-btn
                        color="primary"
                        no-caps
                        :label="searchMode === 'assign' ? 'Assign' : 'Add To Invoice'"
                        :icon="searchMode === 'assign' ? 'check' : 'add'"
                        class="pill-btn slim-btn shadow-1"
                        :loading="Boolean(addItemLoading[getSubtypeItem(group, subtype)?.id ?? -1])"
                        :disable="!invoice"
                        @click="onSelectInventoryItem(getSubtypeItem(group, subtype)!)"
                      />
                    </div>
                  </div>
                </div>
              </q-card-section>
            </q-card>
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, reactive, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar, type QPopupProxy } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceInvoiceService } from '../services/commerceInvoiceService'
import { useInventoryStore } from 'src/modules/inventory/stores/inventoryStore'
import type { InventoryItemWithStock } from 'src/modules/inventory/types'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const inventoryStore = useInventoryStore()
const $q = useQuasar()

const headerDateProxy = ref<QPopupProxy | null>(null)

type CommerceInvoiceRow = {
  id: number
  order_id: number
  delivery_charge: number
  wrapping_charge: number
  cod: number
  total_amount: number
  amount_paid: number
  amount_due: number
  is_customer_group_paid: boolean
  delivered_by: string | null
  created_at: string
  status: 'draft' | 'ready' | 'handed_to_customer'
  discount_amount?: number
  invoice_type?: 'retail' | 'wholesale'
  invoice_date?: string | null
  billing_profiles?: {
    id: number
    name: string
    email: string | null
    phone: string | null
    address: string | null
    color?: string | null
  } | null
}

type CommerceOrderRow = {
  recipient_name: string
  recipient_phone: string | null
  shipping_address: string | null
  invoice_ids?: number[] | null
}

type CommerceInvoiceItemRow = {
  id: number
  product_id: number
  quantity: number
  cost_bdt: number
  sell_price_bdt: number
  recipient_price_bdt: number
  image_url: string | null
  inventory_item_id: number | null
  source_type?: 'manual' | 'shipment' | null
  source_id?: number | null
  products?: {
    name?: string | null
    product_code?: string | null
  } | null
  inventory_items?: {
    name?: string | null
    cost?: number | null
    product_code?: string | null
    barcode?: string | null
    source_type?: string | null
    source_id?: number | null
    shipment_name?: string | null
    tenant_shipment_id?: number | null
  } | null
}

// State
const loading = ref(true)
const error = ref<string | null>(null)
const invoice = ref<CommerceInvoiceRow | null>(null)
const order = ref<CommerceOrderRow | null>(null)
const items = ref<CommerceInvoiceItemRow[]>([])

// Stock search & subtypes state
const searchDialogOpen = ref(false)
const searchMode = ref<'add' | 'assign'>('add')
const selectedOrderItem = ref<CommerceInvoiceItemRow | null>(null)
const searchTerm = ref('')
const searchBy = ref<'name' | 'product_id' | 'product_code' | 'barcode'>('name')
const searchByOptions = [
  { label: 'Name', value: 'name' },
  { label: 'Product ID', value: 'product_id' },
  { label: 'Product Code', value: 'product_code' },
  { label: 'Barcode', value: 'barcode' },
]
const searchingInventory = ref(false)
const searchResults = ref<InventoryItemWithStock[]>([])

// Detailed add inputs by inventory_item_id
const addQuantityByItemId = ref<Record<number, number | null>>({})
const sellPriceByItemId = ref<Record<number, number | null>>({})
const recipientPriceByItemId = ref<Record<number, number | null>>({})
const addItemLoading = ref<Record<number, boolean>>({})

const invoiceId = computed(() => Number(route.params.invoiceId))

const subtotalAmount = computed(() => {
  return items.value.reduce((sum, item) => sum + (Number(item.quantity) * Number(item.recipient_price_bdt)), 0)
})

const totalQuantity = computed(() => {
  return items.value.reduce((sum, item) => sum + Number(item.quantity), 0)
})

const headerStyle = computed(() => {
  const color = invoice.value?.billing_profiles?.color
  if (color) {
    return {
      borderLeft: `6px solid ${color}`,
    }
  }
  return {}
})

const loadInvoiceDetails = async () => {
  if (Number.isNaN(invoiceId.value)) {
    error.value = 'Invalid Invoice ID.'
    loading.value = false
    return
  }

  loading.value = true
  error.value = null
  try {
    const res = await commerceInvoiceService.getCommerceInvoiceDetails(invoiceId.value)
    if (res.success && res.data) {
      invoice.value = res.data.invoice as CommerceInvoiceRow
      order.value = res.data.order
      items.value = res.data.items as CommerceInvoiceItemRow[]
    } else {
      error.value = res.error || 'Failed to load commerce invoice details.'
    }
  } finally {
    loading.value = false
  }
}

const openInvoicePreview = () => {
  if (!invoice.value) return
  const routeData = router.resolve({
    name: 'app-commerce-invoice-preview',
    params: {
      tenantSlug: authStore.tenantSlug ?? undefined,
      invoiceId: invoice.value.id,
    },
  })
  window.open(routeData.href, '_blank')
}

const statusOptions: string[] = ['draft', 'invoicing', 'issued', 'partially_paid', 'paid', 'overdue', 'cancelled']

const formatStatusLabel = (status?: string | null) => {
  const value = status || 'draft'
  if (value === 'handed_to_customer') return 'handed to customer'
  if (value === 'partially_paid') return 'partially paid'
  return value
}

const statusChipStyle = (status?: string | null) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'draft') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
      boxShadow: '0 1px 2px rgba(106, 74, 20, 0.18)',
    }
  }
  if (value === 'invoicing') {
    return {
      backgroundColor: '#e1bee7',
      color: '#4a148c',
      border: '1px solid #ce93d8',
      boxShadow: '0 1px 2px rgba(74, 20, 140, 0.18)',
    }
  }
  if (value === 'issued') {
    return {
      backgroundColor: '#d7e7f6',
      color: '#1a4562',
      border: '1px solid #9ebfdc',
      boxShadow: '0 1px 2px rgba(26, 69, 98, 0.18)',
    }
  }
  if (value === 'partially_paid') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
      boxShadow: '0 1px 2px rgba(40, 53, 147, 0.18)',
    }
  }
  if (value === 'paid') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
      boxShadow: '0 1px 2px rgba(31, 93, 60, 0.18)',
    }
  }
  if (value === 'overdue') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
      boxShadow: '0 1px 2px rgba(111, 43, 58, 0.18)',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f5f5f5',
      color: '#616161',
      border: '1px solid #e0e0e0',
      boxShadow: '0 1px 2px rgba(97, 97, 97, 0.18)',
    }
  }
  // legacy fallback
  if (value === 'ready') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
      boxShadow: '0 1px 2px rgba(39, 72, 122, 0.18)',
    }
  }
  return {
    backgroundColor: '#dbe5f3',
    color: '#3b4b66',
    border: '1px solid #b9c8dd',
    boxShadow: '0 1px 2px rgba(59, 75, 102, 0.18)',
  }
}

const statusDotColor = (status?: string | null) => {
  const value = (status ?? '').toLowerCase()
  if (value === 'draft') return '#9a6a24'
  if (value === 'invoicing') return '#8e24aa'
  if (value === 'issued') return '#2f6e92'
  if (value === 'partially_paid') return '#3f51b5'
  if (value === 'paid') return '#2f8b5d'
  if (value === 'overdue') return '#a64c62'
  if (value === 'cancelled') return '#757575'
  if (value === 'ready') return '#3f67b3'
  return '#66758c'
}

const onStatusMenuSelect = async (invoiceId: number, nextStatus: string) => {
  loading.value = true
  try {
    const res = await commerceInvoiceService.updateCommerceInvoiceStatus(invoiceId, nextStatus)
    if (res.success) {
      showSuccessNotification('Invoice status updated successfully.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to update invoice status.')
    }
  } finally {
    loading.value = false
  }
}

const onUpdateInvoiceCharge = async (key: string, val: unknown) => {
  if (!invoice.value) return
  loading.value = true
  try {
    const chargesPayload: Record<string, unknown> = {
      delivery_charge: Number(invoice.value.delivery_charge) || 0,
      wrapping_charge: Number(invoice.value.wrapping_charge) || 0,
      cod: Number(invoice.value.cod) || 0,
      amount_paid: Number(invoice.value.amount_paid) || 0,
      discount_amount: Number(invoice.value.discount_amount) || 0,
      invoice_date: invoice.value.invoice_date || '',
      delivered_by: invoice.value.delivered_by || '',
    }
    
    chargesPayload[key] = val

    if (invoice.value.invoice_type === 'wholesale') {
      chargesPayload.delivery_charge = 0
      chargesPayload.wrapping_charge = 0
      chargesPayload.cod = 0
      chargesPayload.delivered_by = ''
    }

    const res = await commerceInvoiceService.updateCommerceInvoiceCharges(invoice.value.id, chargesPayload as any)
    if (res.success) {
      showSuccessNotification('Invoice charge updated successfully.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to update invoice.')
    }
  } finally {
    loading.value = false
  }
}

const onDeleteInvoice = () => {
  if (!invoice.value) return

  const linkedInvoicesText = order.value?.invoice_ids?.length
    ? `This order currently has linked invoice(s): ${order.value.invoice_ids.map((id) => `#${id}`).join(', ')}.`
    : 'This order does not have any linked invoices listed yet.'

  $q.dialog({
    title: 'Delete Invoice?',
    message: `This will permanently delete Invoice #${invoice.value.id}, remove its related accounting records, unassign and restock any linked inventory items, and remove the invoice ID from the order. ${linkedInvoicesText}`,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: true,
    },
    cancel: {
      label: 'Cancel',
      color: 'grey-7',
      flat: true,
    },
  }).onOk(() => {
    void (async () => {
      loading.value = true
      try {
        const res = await commerceInvoiceService.deleteCommerceInvoice(invoice.value!.id)
        if (res.success) {
          showSuccessNotification(`Invoice #${invoice.value!.id} deleted successfully.`)
          await router.push({
            path: (() => {
              const tenantSlugParam = route.params.tenantSlug
              const tenantSlug = Array.isArray(tenantSlugParam) ? tenantSlugParam[0] : tenantSlugParam
              return tenantSlug ? `/${tenantSlug}/app/commerce-shop/invoices` : '/app/commerce-shop/invoices'
            })(),
          })
        } else {
          showWarningDialog(res.error || 'Failed to delete invoice.')
        }
      } finally {
        loading.value = false
      }
    })()
  })
}

const removeItem = async (orderItemId: number) => {
  loading.value = true
  try {
    const res = await commerceInvoiceService.removeCommerceInvoiceItem(orderItemId, invoiceId.value)
    if (res.success) {
      showSuccessNotification('Item removed from invoice.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to remove item.')
    }
  } finally {
    loading.value = false
  }
}

const unassignInventoryItem = async (row: CommerceInvoiceItemRow) => {
  if (!invoice.value) return
  const confirm = window.confirm('Unassign this stock item and restock it?')
  if (!confirm) return

  loading.value = true
  try {
    const res = await commerceInvoiceService.unassignOrderItemInventory(invoiceId.value, row.id)
    if (res.success) {
      showSuccessNotification('Stock item unassigned and restocked.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to unassign stock item.')
    }
  } finally {
    loading.value = false
  }
}

const onInlineUpdateItem = async (row: CommerceInvoiceItemRow, field: 'quantity' | 'sell_price_bdt' | 'recipient_price_bdt', value: string | number | null) => {
  if (!invoice.value) return
  loading.value = true
  try {
    const payload = {
      quantity: Number(row.quantity) || 1,
      sell_price_bdt: Number(row.sell_price_bdt) || 0,
      recipient_price_bdt: Number(row.recipient_price_bdt) || 0,
    }
    if (field === 'quantity') {
      payload.quantity = Math.max(1, Math.floor(Number(value || 1)))
    } else if (field === 'sell_price_bdt') {
      payload.sell_price_bdt = Math.max(0, Number(value || 0))
    } else if (field === 'recipient_price_bdt') {
      payload.recipient_price_bdt = Math.max(0, Number(value || 0))
    }

    if (field === 'quantity' && row.inventory_item_id) {
      const stockRes = await inventoryStore.fetchGlobalInventoryItems({
        filters: { id: row.inventory_item_id },
        page: 1,
        page_size: 1
      })
      if (stockRes.success && stockRes.data?.data?.[0]) {
        const stockItem = stockRes.data.data[0]
        const usableQty = Number(stockItem.quantities?.usable || 0)
        const currentQty = Number(row.quantity)
        const delta = payload.quantity - currentQty
        if (delta > usableQty) {
          showWarningDialog(`Not enough usable stock. Available: ${usableQty}, Requested change: ${delta}`)
          return
        }
      }
    }

    const res = await commerceInvoiceService.updateCommerceInvoiceItem(invoice.value.id, row.id, payload)
    if (res.success) {
      showSuccessNotification('Item updated successfully.')
      await loadInvoiceDetails()
    } else {
      showWarningDialog(res.error || 'Failed to update item.')
    }
  } finally {
    loading.value = false
  }
}

// Subtypes stock search implementation
interface GroupedInventoryStock {
  key: string
  name: string
  image_url: string | null
  product_id: number | null
  barcode: string | null
  product_code: string | null
  cost: number | null
  tenant_name: string | null
  tenant_id: number
  shipment: InventoryItemWithStock['shipment']
  subtypes: {
    standard?: InventoryItemWithStock
    boxless?: InventoryItemWithStock
    box_damage?: InventoryItemWithStock
    expired?: InventoryItemWithStock
  }
}

const cleanName = (name: string) => {
  return name
    .replace(/\s*\(Boxless\)$/i, '')
    .replace(/\s*\(Box Damage\)$/i, '')
    .replace(/\s*\(Expired\)$/i, '')
    .replace(/\s*\(Stolen\/Missing\)$/i, '')
    .replace(/\s*\(Stolen\)$/i, '')
}

const getSubtypeFromItem = (item: { name: string }) => {
  const name = item.name || ''
  if (name.endsWith(' (Boxless)')) return 'boxless'
  if (name.endsWith(' (Box Damage)')) return 'box_damage'
  if (name.endsWith(' (Expired)')) return 'expired'
  return 'standard'
}

const sortedSearchItemsGrouped = computed<GroupedInventoryStock[]>(() => {
  const groups: Record<string, GroupedInventoryStock> = {}

  for (const item of searchResults.value) {
    const subtype = getSubtypeFromItem(item)
    const baseName = cleanName(item.name)
    const shipmentId = item.shipment?.shipment?.id ? String(Number(item.shipment.shipment.id)) : 'none'
    const key = `${item.tenant_id}_${item.product_id || baseName}_${shipmentId}`

    let group = groups[key]
    if (!group) {
      group = {
        key,
        name: baseName,
        image_url: item.image_url ?? null,
        product_id: item.product_id,
        barcode: item.barcode,
        product_code: item.product_code,
        cost: item.cost,
        tenant_name: item.tenant_name ?? null,
        tenant_id: item.tenant_id,
        shipment: item.shipment,
        subtypes: {},
      }
      groups[key] = group
    }

    group.subtypes[subtype] = item

    if (subtype === 'standard') {
      group.image_url = item.image_url || group.image_url
      group.barcode = item.barcode || group.barcode
      group.product_code = item.product_code || group.product_code
      group.cost = item.cost !== null ? item.cost : group.cost
    }
  }

  return Object.values(groups).sort((a, b) => {
    const shipmentIdA = Number(a.shipment?.shipment?.id ?? Number.MAX_SAFE_INTEGER)
    const shipmentIdB = Number(b.shipment?.shipment?.id ?? Number.MAX_SAFE_INTEGER)
    return shipmentIdA - shipmentIdB
  })
})

const getAvailableQuantityForSubtype = (item: InventoryItemWithStock | undefined, subtype: 'standard' | 'boxless' | 'box_damage' | 'expired'): number => {
  if (!item || !item.stock) return 0
  const stock = item.stock
  if (subtype === 'standard') {
    return Math.max(0, Number(stock.available_quantity ?? 0) - Number(stock.reserved_quantity ?? 0))
  }
  if (subtype === 'boxless' || subtype === 'box_damage') {
    return Math.max(0, Number(stock.open_box_quantity ?? 0))
  }
  if (subtype === 'expired') {
    return Math.max(0, Number(stock.expired_quantity ?? 0))
  }
  return 0
}

const getSubtypeItem = (
  group: GroupedInventoryStock,
  subtype: 'standard' | 'boxless' | 'box_damage' | 'expired',
) => group.subtypes[subtype] ?? null

const getSubtypeLabel = (subtype: 'standard' | 'boxless' | 'box_damage' | 'expired') => {
  switch (subtype) {
    case 'standard': return 'Standard/Usable'
    case 'boxless': return 'Boxless'
    case 'box_damage': return 'Box Damage'
    case 'expired': return 'Expired'
  }
}

const getSubtypeIcon = (subtype: 'standard' | 'boxless' | 'box_damage' | 'expired') => {
  switch (subtype) {
    case 'standard': return 'check_circle'
    case 'boxless': return 'o_archive'
    case 'box_damage': return 'warning'
    case 'expired': return 'schedule'
  }
}

const getSubtypeIconColor = (subtype: 'standard' | 'boxless' | 'box_damage' | 'expired') => {
  switch (subtype) {
    case 'standard': return 'positive'
    case 'boxless': return 'primary'
    case 'box_damage': return 'warning'
    case 'expired': return 'negative'
  }
}

const getAddQuantity = (itemId: number): number => {
  if (addQuantityByItemId.value[itemId] === undefined || addQuantityByItemId.value[itemId] === null) {
    addQuantityByItemId.value[itemId] = Math.max(1, Number(selectedOrderItem.value?.quantity || 1))
  }
  return addQuantityByItemId.value[itemId] as number
}

const getSellPrice = (itemId: number, defaultCost: number): number => {
  if (sellPriceByItemId.value[itemId] === undefined || sellPriceByItemId.value[itemId] === null) {
    sellPriceByItemId.value[itemId] = Number(selectedOrderItem.value?.sell_price_bdt || defaultCost || 0)
  }
  return sellPriceByItemId.value[itemId] as number
}

const getRecipientPrice = (itemId: number, defaultCost: number): number => {
  if (recipientPriceByItemId.value[itemId] === undefined || recipientPriceByItemId.value[itemId] === null) {
    recipientPriceByItemId.value[itemId] = Number(selectedOrderItem.value?.recipient_price_bdt || defaultCost || 0)
  }
  return recipientPriceByItemId.value[itemId] as number
}

const setAddQuantity = (itemId: number, value: string | number | null) => {
  addQuantityByItemId.value[itemId] = Number(value) || 1
}

const setSellPrice = (itemId: number, value: string | number | null) => {
  sellPriceByItemId.value[itemId] = Number(value) || 0
}

const setRecipientPrice = (itemId: number, value: string | number | null) => {
  recipientPriceByItemId.value[itemId] = Number(value) || 0
}

const incrementQty = (itemId: number, maxVal: number) => {
  const current = getAddQuantity(itemId)
  if (current < maxVal) {
    addQuantityByItemId.value[itemId] = current + 1
  }
}

const decrementQty = (itemId: number) => {
  const current = getAddQuantity(itemId)
  if (current > 1) {
    addQuantityByItemId.value[itemId] = current - 1
  }
}

const resetSearchDialogState = () => {
  searchMode.value = 'add'
  selectedOrderItem.value = null
  searchTerm.value = ''
  searchBy.value = 'name'
  searchResults.value = []
  addQuantityByItemId.value = {}
  sellPriceByItemId.value = {}
  recipientPriceByItemId.value = {}
  addItemLoading.value = {}
}

const openSearchDialogForAdd = () => {
  resetSearchDialogState()
  searchMode.value = 'add'
  searchDialogOpen.value = true
}

const openSearchDialogForAssign = (row: CommerceInvoiceItemRow) => {
  resetSearchDialogState()
  searchMode.value = 'assign'
  selectedOrderItem.value = row
  searchBy.value = 'product_id'
  searchTerm.value = String(row.product_id || '')
  searchDialogOpen.value = true
  void searchInventoryItems()
}

const searchInventoryItems = async () => {
  if (!authStore.tenantId) return
  searchingInventory.value = true
  try {
    const filters: Record<string, unknown> = {}
    const trimmed = searchTerm.value.trim()

    if (searchMode.value === 'assign' && selectedOrderItem.value?.product_id) {
      filters.product_id = Number(selectedOrderItem.value.product_id)
    }

    if (trimmed) {
      if (searchBy.value === 'product_id') {
        const parsed = Number(trimmed)
        if (!Number.isFinite(parsed) || parsed <= 0) {
          showWarningDialog('Product ID must be a valid number.')
          searchResults.value = []
          return
        }
        filters.product_id = Math.floor(parsed)
      } else {
        filters[searchBy.value] = trimmed
      }
    }

    const res = await inventoryStore.fetchGlobalInventoryItems({
      filters,
      page: 1,
      page_size: 50,
      sortBy: 'source_id',
      sortOrder: 'asc',
    })

    if (res.success && res.data?.data) {
      searchResults.value = res.data.data
    } else {
      searchResults.value = []
    }
  } finally {
    searchingInventory.value = false
  }
}

const addInventoryItemToInvoice = async (inventoryItem: InventoryItemWithStock) => {
  if (!invoice.value) return
  if (!inventoryItem.product_id) {
    showWarningDialog('Selected stock item is not linked to a product.')
    return
  }

  const qty = getAddQuantity(inventoryItem.id)
  const sell = getSellPrice(inventoryItem.id, Number(inventoryItem.cost || 0))
  const recipient = getRecipientPrice(inventoryItem.id, Number(inventoryItem.cost || 0))

  if (qty <= 0) {
    showWarningDialog('Please enter a valid quantity.')
    return
  }
  if (sell < 0 || recipient < 0) {
    showWarningDialog('Sell and recipient prices must be zero or higher.')
    return
  }
  
  const subtype = getSubtypeFromItem(inventoryItem) as 'standard' | 'boxless' | 'box_damage' | 'expired'
  const usableStock = getAvailableQuantityForSubtype(inventoryItem, subtype)
  if (qty > usableStock) {
    showWarningDialog('Quantity is greater than usable stock for this item subtype.')
    return
  }

  addItemLoading.value[inventoryItem.id] = true
  try {
    const res = await commerceInvoiceService.addCommerceInvoiceItem(invoiceId.value, invoice.value.order_id, {
      product_id: Number(inventoryItem.product_id),
      quantity: qty,
      cost_bdt: Number(inventoryItem.cost || 0),
      sell_price_bdt: sell,
      recipient_price_bdt: recipient,
      image_url: inventoryItem.image_url,
      inventory_item_id: inventoryItem.id,
    })

    if (res.success) {
      showSuccessNotification(`Added "${inventoryItem.name}" from stock to invoice.`)
      await loadInvoiceDetails()
      searchDialogOpen.value = false
    } else {
      showWarningDialog(res.error || 'Failed to add stock item.')
    }
  } finally {
    addItemLoading.value[inventoryItem.id] = false
  }
}

const assignInventoryItemToOrderItem = async (inventoryItem: InventoryItemWithStock) => {
  const row = selectedOrderItem.value
  if (!row) {
    showWarningDialog('Please choose an order item first.')
    return
  }

  const subtype = getSubtypeFromItem(inventoryItem) as 'standard' | 'boxless' | 'box_damage' | 'expired'
  const usableStock = getAvailableQuantityForSubtype(inventoryItem, subtype)
  const requiredQty = Math.max(1, Number(row.quantity || 1))
  if (requiredQty > usableStock) {
    showWarningDialog('Not enough usable stock for this order item quantity.')
    return
  }

  addItemLoading.value[inventoryItem.id] = true
  try {
    const res = await commerceInvoiceService.updateOrderItemInventoryAssignment(
      invoiceId.value,
      Number(row.id),
      Number(inventoryItem.id),
    )

    if (res.success) {
      showSuccessNotification('Stock item assigned and cost updated.')
      await loadInvoiceDetails()
      searchDialogOpen.value = false
      selectedOrderItem.value = null
    } else {
      showWarningDialog(res.error || 'Failed to assign stock item.')
    }
  } finally {
    addItemLoading.value[inventoryItem.id] = false
  }
}

const onSelectInventoryItem = async (inventoryItem: InventoryItemWithStock) => {
  if (searchMode.value === 'assign') {
    await assignInventoryItemToOrderItem(inventoryItem)
    return
  }
  await addInventoryItemToInvoice(inventoryItem)
}

const formatAmount = (val: number) => Number(val || 0).toFixed(2)

onMounted(() => {
  void loadInvoiceDetails()
})
</script>

<style scoped>
.commerce-invoice-details-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86) !important;
  border-radius: 14px !important;
  border: 1px solid rgba(34, 56, 101, 0.08) !important;
  backdrop-filter: blur(6px) !important;
}

.hero-surface {
  border-radius: 16px !important;
}

.empty-state-block {
  text-align: center;
  background: rgba(255, 255, 255, 0.7);
}

.border-all {
  border: 1px solid rgba(34, 56, 101, 0.08);
}

.pill-btn {
  border-radius: 8px !important;
}

.slim-btn {
  min-height: 32px !important;
  padding-left: 12px !important;
  padding-right: 12px !important;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px !important;
  background: rgba(255, 255, 255, 0.82) !important;
}

.invoice-table-wrap {
  overflow-x: auto;
  overflow-y: auto;
  max-height: calc(100vh - 340px);
}

.invoice-items-table :deep(th) {
  background: color-mix(in srgb, #f7f9fc 96%, rgba(34, 56, 101, 0.04) 4%);
  font-size: 12px;
  font-weight: 600;
  color: #3b4b66;
  padding: 10px 12px;
  white-space: nowrap;
  position: sticky;
  top: 0;
  z-index: 2;
  border-bottom: 1px solid rgba(34, 56, 101, 0.1);
}

.invoice-items-table :deep(td) {
  padding: 8px 12px;
  font-size: 13px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.05);
  vertical-align: middle;
}

.invoice-items-table :deep(.totals-row td) {
  background: rgba(248, 250, 254, 0.95) !important;
  border-top: 2px solid rgba(34, 56, 101, 0.12) !important;
  font-size: 13px;
}

.product-search-item {
  border-radius: 10px;
  transition: all 0.2s ease;
}

.product-search-item:hover {
  background-color: rgba(34, 56, 101, 0.02);
}

.border-light {
  border: 1px solid rgba(34, 56, 101, 0.06) !important;
}

.border-top {
  border-top: 1px solid rgba(34, 56, 101, 0.08) !important;
}

.status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  color: #2c3e50 !important;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.no-number-steppers :deep(input[type='number']) {
  appearance: textfield;
  -moz-appearance: textfield;
}

.no-number-steppers :deep(input[type='number']::-webkit-outer-spin-button),
.no-number-steppers :deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

/* Redesign enhancements */
.edit-pencil-icon {
  opacity: 0.35;
  transition: all 0.22s cubic-bezier(0.4, 0, 0.2, 1);
  color: #3b4b66;
}

.editable-cell:hover .edit-pencil-icon,
.editable-field:hover .edit-pencil-icon,
.edit-pencil-icon:hover {
  opacity: 1 !important;
  color: var(--q-primary) !important;
  transform: scale(1.15);
}

.editable-cell,
.editable-field {
  transition: background-color 0.2s ease;
}

.editable-cell:hover,
.editable-field:hover {
  background-color: rgba(34, 56, 101, 0.035) !important;
}

.receipt-card {
  border-left: 4px solid var(--q-primary) !important;
  border-top-left-radius: 4px !important;
  border-bottom-left-radius: 4px !important;
}

.item-row {
  transition: background-color 0.2s ease;
}

.item-row:hover {
  background-color: rgba(34, 56, 101, 0.015);
}

.rounded-borders {
  border-radius: 8px !important;
}
</style>
