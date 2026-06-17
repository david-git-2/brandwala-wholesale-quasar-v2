<template>
  <q-page :class="[$q.screen.lt.sm ? 'q-pa-xs' : 'q-pa-md', 'thrift-dashboard-page']">
    
    <!-- Hero Section / Header -->
    <q-card flat class="q-mb-md header-gradient shadow-3 text-white">
      <q-card-section class="q-py-md">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="row items-center q-gutter-x-sm">
              <q-icon name="local_mall" size="32px" class="animated-icon" />
              <div>
                <div class="text-h5 text-weight-bold">Thrift Operations</div>
                <div class="text-caption text-blue-1">Manage single/bulk stocks, custom pricing, warehouse shelves, and split-shipping invoicing.</div>
              </div>
            </div>
          </div>
          <div class="col-12 col-sm-auto row q-gutter-sm justify-start justify-sm-end">
            <q-btn
              color="white"
              text-color="primary"
              unelevated
              no-caps
              icon="add_circle"
              label="Add Stock"
              class="pill-btn hover-grow"
              @click="openAddStockDialog"
            />
            <q-btn
              color="secondary"
              unelevated
              no-caps
              icon="shopping_cart"
              label="Mark As Sold"
              class="pill-btn hover-grow"
              @click="openSellDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- KPI Summary Row -->
    <div class="row q-col-gutter-md q-mb-md">
      <!-- Total Stock Item Count -->
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered class="kpi-card hover-glow shadow-1">
          <q-card-section class="row items-center justify-between q-py-sm">
            <div>
              <div class="text-caption text-grey-6 text-uppercase font-medium">Total Stocks</div>
              <div class="text-h4 text-weight-bold text-grey-9">{{ stocks.length }}</div>
            </div>
            <q-avatar color="blue-1" text-color="blue-8" icon="inventory_2" size="48px" />
          </q-card-section>
        </q-card>
      </div>

      <!-- Invoices Count -->
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered class="kpi-card hover-glow shadow-1">
          <q-card-section class="row items-center justify-between q-py-sm">
            <div>
              <div class="text-caption text-grey-6 text-uppercase font-medium">Invoices</div>
              <div class="text-h4 text-weight-bold text-grey-9">{{ invoices.length }}</div>
            </div>
            <q-avatar color="purple-1" text-color="purple-8" icon="receipt" size="48px" />
          </q-card-section>
        </q-card>
      </div>

      <!-- Total Revenue (Ledger sum) -->
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered class="kpi-card hover-glow shadow-1">
          <q-card-section class="row items-center justify-between q-py-sm">
            <div>
              <div class="text-caption text-grey-6 text-uppercase font-medium">Total Revenue</div>
              <div class="text-h4 text-weight-bold text-green-7">${{ totalRevenue.toFixed(2) }}</div>
            </div>
            <q-avatar color="green-1" text-color="green-8" icon="monetization_on" size="48px" />
          </q-card-section>
        </q-card>
      </div>

      <!-- Total Expenses -->
      <div class="col-12 col-sm-6 col-md-3">
        <q-card flat bordered class="kpi-card hover-glow shadow-1">
          <q-card-section class="row items-center justify-between q-py-sm">
            <div>
              <div class="text-caption text-grey-6 text-uppercase font-medium">Total Expenses</div>
              <div class="text-h4 text-weight-bold text-red-6">${{ totalExpenses.toFixed(2) }}</div>
            </div>
            <q-avatar color="red-1" text-color="red-8" icon="trending_down" size="48px" />
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Main Tab Panel Controls -->
    <q-card flat bordered class="q-mb-md">
      <q-tabs
        v-model="activeTab"
        dense
        class="text-grey-7"
        active-color="primary"
        indicator-color="primary"
        align="left"
        narrow-indicator
        no-caps
      >
        <q-tab name="stocks" icon="inventory" label="Stocks" />
        <q-tab name="boxes" icon="inventory_2" label="Boxes" />
        <q-tab name="invoices" icon="description" label="Invoices" />
        <q-tab name="shelves" icon="grid_view" label="Shelves" />
        <q-tab name="categories" icon="category" label="Categories" />
        <q-tab name="ledger" icon="account_balance" label="Accounting Ledger" />
      </q-tabs>
    </q-card>

    <!-- Tab Panels Content -->
    <q-tab-panels v-model="activeTab" animated class="bg-transparent">
      
      <!-- STOCKS PANEL -->
      <q-tab-panel name="stocks" class="q-pa-none">
        <q-card flat bordered>
          <q-table
            flat
            :rows="stocks"
            :columns="stockColumns"
            row-key="id"
            :loading="loading"
            class="thrift-table"
          >
            <template #body-cell-box="props">
              <q-td :props="props">
                {{ getBoxName(props.row.box_id) }}
              </q-td>
            </template>
            <template #body-cell-product_weight="props">
              <q-td :props="props">
                {{ props.value ? `${props.value} kg` : '—' }}
              </q-td>
            </template>
            <template #body-cell-extra_weight="props">
              <q-td :props="props">
                {{ props.value ? `${props.value} kg` : '—' }}
              </q-td>
            </template>
            <template #body-cell-status="props">
              <q-td :props="props">
                <q-chip
                  square
                  dense
                  :color="getStatusColor(props.value)"
                  text-color="white"
                  class="text-weight-bold text-caption text-uppercase"
                >
                  {{ props.value }}
                </q-chip>
              </q-td>
            </template>
            <template #body-cell-pricing="props">
              <q-td :props="props">
                <div v-if="props.value" class="text-caption">
                  <div><strong>Cost:</strong> ${{ props.value.cost_of_goods_sold }}</div>
                  <div><strong>Listed:</strong> ${{ props.value.listed_price }}</div>
                </div>
                <div v-else class="text-grey-5">—</div>
              </q-td>
            </template>
            <template #body-cell-actions="props">
              <q-td :props="props" class="q-gutter-x-xs">
                <q-btn
                  flat
                  round
                  dense
                  color="warning"
                  icon="report_problem"
                  size="sm"
                  @click="updateStatus(props.row.id, 'DAMAGED')"
                >
                  <q-tooltip>Mark Damaged</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  round
                  dense
                  color="negative"
                  icon="block"
                  size="sm"
                  @click="updateStatus(props.row.id, 'STOLEN')"
                >
                  <q-tooltip>Mark Stolen</q-tooltip>
                </q-btn>
              </q-td>
            </template>
          </q-table>
        </q-card>
      </q-tab-panel>

      <!-- BOXES PANEL -->
      <q-tab-panel name="boxes" class="q-pa-none">
        <div class="row justify-between items-center q-mb-md">
          <div class="text-subtitle1 text-weight-bold text-grey-8">Thrift Boxes under Shipments</div>
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="add"
            label="Add Box"
            class="pill-btn"
            @click="openBoxDialog"
          />
        </div>
        <q-card flat bordered>
          <q-table
            flat
            :rows="boxes"
            :columns="boxColumns"
            row-key="id"
            :loading="loading"
            class="thrift-table"
          >
            <template #body-cell-shipment="props">
              <q-td :props="props">
                {{ getShipmentName(props.row.shipment_id) }}
              </q-td>
            </template>
            <template #body-cell-weight="props">
              <q-td :props="props">
                {{ props.value ? `${props.value} kg` : '—' }}
              </q-td>
            </template>
            <template #body-cell-received_weight="props">
              <q-td :props="props">
                {{ props.value ? `${props.value} kg` : '—' }}
              </q-td>
            </template>
            <template #body-cell-actions="props">
              <q-td :props="props" class="text-right">
                <q-btn flat round dense icon="delete" size="sm" color="negative" @click="deleteBox(props.row.id)" />
              </q-td>
            </template>
          </q-table>
        </q-card>
      </q-tab-panel>

      <!-- INVOICES PANEL -->
      <q-tab-panel name="invoices" class="q-pa-none">
        <q-card flat bordered>
          <q-table
            flat
            :rows="invoices"
            :columns="invoiceColumns"
            row-key="id"
            :loading="loading"
            class="thrift-table"
          >
            <template #body-cell-payment_status="props">
              <q-td :props="props">
                <q-chip
                  dense
                  square
                  :color="props.value === 'PAID' ? 'green' : props.value === 'UNPAID' ? 'orange' : 'grey'"
                  text-color="white"
                  class="text-weight-bold"
                >
                  {{ props.value }}
                </q-chip>
              </q-td>
            </template>
            <template #body-cell-delivery_status="props">
              <q-td :props="props">
                <q-chip
                  dense
                  square
                  :color="props.value === 'DELIVERED' ? 'green' : props.value === 'PENDING' ? 'blue' : 'orange'"
                  text-color="white"
                  class="text-weight-bold"
                >
                  {{ props.value }}
                </q-chip>
              </q-td>
            </template>
          </q-table>
        </q-card>
      </q-tab-panel>

      <!-- SHELVES PANEL -->
      <q-tab-panel name="shelves" class="q-pa-none">
        <div class="row justify-between items-center q-mb-md">
          <div class="text-subtitle1 text-weight-bold text-grey-8">Physical Warehouse Shelves</div>
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="add"
            label="Add Shelf"
            class="pill-btn"
            @click="shelfDialog = true"
          />
        </div>
        <q-card flat bordered>
          <q-table
            flat
            :rows="shelves"
            :columns="shelfColumns"
            row-key="id"
            :loading="loading"
            class="thrift-table"
          />
        </q-card>
      </q-tab-panel>

      <!-- CATEGORIES PANEL -->
      <q-tab-panel name="categories" class="q-pa-none">
        <div class="row justify-between items-center q-mb-md">
          <div class="text-subtitle1 text-weight-bold text-grey-8">Thrift Stock Categories & Classification Types</div>
          <div class="row q-gutter-sm">
            <q-btn
              color="primary"
              unelevated
              no-caps
              icon="add"
              label="Add Category"
              class="pill-btn"
              @click="categoryDialog = true"
            />
            <q-btn
              color="secondary"
              unelevated
              no-caps
              icon="add"
              label="Add Product Style Type"
              class="pill-btn"
              @click="typeDialog = true"
            />
          </div>
        </div>
        
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-6">
            <q-card flat bordered>
              <q-card-section class="q-py-sm bg-grey-1 text-weight-bold text-grey-8">Categories</q-card-section>
              <q-table
                flat
                :rows="categories"
                :columns="categoryColumns"
                row-key="id"
                :loading="loading"
                class="thrift-table"
              />
            </q-card>
          </div>
          <div class="col-12 col-md-6">
            <q-card flat bordered>
              <q-card-section class="q-py-sm bg-grey-1 text-weight-bold text-grey-8">Product Styles / Types</q-card-section>
              <q-table
                flat
                :rows="types"
                :columns="typeColumns"
                row-key="id"
                :loading="loading"
                class="thrift-table"
              />
            </q-card>
          </div>
        </div>
      </q-tab-panel>

      <!-- ACCOUNTING LEDGER PANEL -->
      <q-tab-panel name="ledger" class="q-pa-none">
        <q-card flat bordered>
          <q-table
            flat
            :rows="ledgerEntries"
            :columns="ledgerColumns"
            row-key="id"
            :loading="loading"
            class="thrift-table"
          >
            <template #body-cell-type="props">
              <q-td :props="props">
                <q-chip
                  dense
                  square
                  :color="getLedgerTypeColor(props.value)"
                  text-color="white"
                  class="text-weight-bold text-caption text-uppercase"
                >
                  {{ props.value }}
                </q-chip>
              </q-td>
            </template>
          </q-table>
        </q-card>
      </q-tab-panel>

    </q-tab-panels>

    <!-- DIALOG: Add Stock -->
    <q-dialog v-model="stockDialog" persistent>
      <q-card style="min-width: 450px" class="modal-card">
        <q-card-section class="row items-center q-pb-none bg-primary text-white">
          <div class="text-h6 text-weight-bold">Register Thrift Stock Item</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pt-md">
          <q-form @submit="onSubmitStock" class="q-gutter-md">
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="stockForm.shipment_id"
                  outlined
                  dense
                  label="Shipment *"
                  :options="shipments"
                  option-value="id"
                  option-label="name"
                  emit-value
                  map-options
                  :rules="[val => !!val || 'Field is required']"
                  @update:model-value="onShipmentChange"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="stockForm.box_id"
                  outlined
                  dense
                  label="Box Number/Name"
                  :options="filteredBoxes"
                  option-value="id"
                  option-label="name"
                  emit-value
                  map-options
                  clearable
                />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="stockForm.category_id"
                  outlined
                  dense
                  label="Category *"
                  :options="categories"
                  option-value="id"
                  option-label="name"
                  emit-value
                  map-options
                  :rules="[val => !!val || 'Field is required']"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="stockForm.type_id"
                  outlined
                  dense
                  label="Product Style/Type *"
                  :options="types"
                  option-value="id"
                  option-label="name"
                  emit-value
                  map-options
                  :rules="[val => !!val || 'Field is required']"
                />
              </div>
            </div>

            <q-input
              v-model="stockForm.name"
              outlined
              dense
              label="Item Name *"
              :rules="[val => !!val && val.length > 0 || 'Field is required']"
            />

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="stockForm.brand_name"
                  outlined
                  dense
                  label="Brand Name (Optional)"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="stockForm.sku"
                  outlined
                  dense
                  label="SKU *"
                  :rules="[val => !!val && val.length > 0 || 'Field is required']"
                />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-select
                  v-model="stockForm.section"
                  outlined
                  dense
                  label="Section *"
                  :options="['MALE', 'FEMALE', 'UNISEX', 'KIDS', 'HOME']"
                  :rules="[val => !!val || 'Field is required']"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-select
                  v-model="stockForm.condition"
                  outlined
                  dense
                  label="Condition *"
                  :options="['NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR']"
                  :rules="[val => !!val || 'Field is required']"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-select
                  v-model="stockForm.shelf_id"
                  outlined
                  dense
                  label="Shelf Code *"
                  :options="shelves"
                  option-value="id"
                  option-label="shelf_code"
                  emit-value
                  map-options
                  :rules="[val => !!val || 'Field is required']"
                />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input
                  v-model="stockForm.color"
                  outlined
                  dense
                  label="Color *"
                  :rules="[val => !!val && val.length > 0 || 'Field is required']"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-input
                  v-model="stockForm.size"
                  outlined
                  dense
                  label="Size *"
                  :rules="[val => !!val && val.length > 0 || 'Field is required']"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="stockForm.quantity"
                  type="number"
                  outlined
                  dense
                  label="Quantity *"
                  :rules="[val => val >= 0 || 'Quantity cannot be negative']"
                />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="stockForm.product_weight"
                  type="number"
                  step="0.001"
                  outlined
                  dense
                  label="Product Weight (kg)"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="stockForm.extra_weight"
                  type="number"
                  step="0.001"
                  outlined
                  dense
                  label="Extra Weight (kg)"
                />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="pricingForm.cost_of_goods_sold"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Cost amount (COGS) *"
                  :rules="[val => val >= 0 || 'Cannot be negative']"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="pricingForm.target_price"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Target Sell Price *"
                  :rules="[val => val >= 0 || 'Cannot be negative']"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="pricingForm.listed_price"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Listed Price *"
                  :rules="[val => val >= 0 || 'Cannot be negative']"
                />
              </div>
            </div>

            <div class="row justify-end q-gutter-sm q-pt-md">
              <q-btn flat label="Cancel" v-close-popup />
              <q-btn color="primary" label="Save Item" type="submit" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- DIALOG: Sell / Mark as Sold -->
    <q-dialog v-model="sellDialog" persistent>
      <q-card style="min-width: 600px" class="modal-card">
        <q-card-section class="row items-center q-pb-none bg-secondary text-white">
          <div class="text-h6 text-weight-bold">Mark Items As Sold</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pt-md">
          <q-form @submit="onSubmitSell" class="q-gutter-md">
            
            <div class="text-subtitle2 text-grey-8">Recipient & Delivery Info</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="invoiceForm.recipient_name"
                  outlined
                  dense
                  label="Recipient Name *"
                  :rules="[val => !!val && val.length > 0 || 'Required']"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="invoiceForm.phone"
                  outlined
                  dense
                  label="Recipient Phone *"
                  :rules="[val => !!val && val.length > 0 || 'Required']"
                />
              </div>
            </div>
            
            <q-input
              v-model="invoiceForm.address"
              outlined
              dense
              type="textarea"
              rows="2"
              label="Recipient Address *"
              :rules="[val => !!val && val.length > 0 || 'Required']"
            />

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="invoiceForm.transaction_method"
                  outlined
                  dense
                  label="Transaction Method *"
                  :options="['CASH', 'CARD', 'MOBILE_BANKING', 'COD']"
                  :rules="[val => !!val || 'Required']"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="invoiceForm.invoice_number"
                  outlined
                  dense
                  label="Invoice Number *"
                  :rules="[val => !!val && val.length > 0 || 'Required']"
                />
              </div>
            </div>

            <q-separator />

            <div class="text-subtitle2 text-grey-8">Split Shipping & Service Charges</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-3">
                <q-input
                  v-model.number="invoiceForm.cod_charge"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="COD Charge"
                />
              </div>
              <div class="col-12 col-sm-3">
                <q-input
                  v-model.number="invoiceForm.packing_charge"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Packing Fee"
                />
              </div>
              <div class="col-12 col-sm-3">
                <q-input
                  v-model.number="invoiceForm.invoice_print_charge"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Print Fee"
                />
              </div>
              <div class="col-12 col-sm-3">
                <q-input
                  v-model.number="invoiceForm.shipping_charge_customer"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Shipping (Customer Paid)"
                />
              </div>
            </div>

            <q-separator />

            <div class="row justify-between items-center">
              <div class="text-subtitle2 text-grey-8">Invoice Items</div>
              <q-btn flat color="primary" icon="add" label="Add Line" size="sm" @close-popup @click="addInvoiceLine" />
            </div>

            <div v-for="(line, idx) in invoiceLines" :key="idx" class="row q-col-gutter-xs items-center q-mb-sm">
              <div class="col-12 col-sm-4">
                <q-select
                  v-model="line.stock_id"
                  outlined
                  dense
                  label="Stock *"
                  :options="availableStocks"
                  option-value="id"
                  option-label="name"
                  emit-value
                  map-options
                  @update:model-value="onStockLineSelect(idx)"
                />
              </div>
              <div class="col-2">
                <q-input
                  v-model.number="line.quantity"
                  type="number"
                  outlined
                  dense
                  label="Qty *"
                />
              </div>
              <div class="col-2">
                <q-input
                  v-model.number="line.sold_price"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Sold Price"
                />
              </div>
              <div class="col-2">
                <q-input
                  v-model.number="line.platform_fees"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Fees"
                />
              </div>
              <div class="col-2">
                <q-input
                  v-model.number="line.shipping_cost_paid_by_shop"
                  type="number"
                  step="0.01"
                  outlined
                  dense
                  label="Shop Shipping"
                />
              </div>
              <div class="col-auto">
                <q-btn flat round color="negative" icon="delete" size="sm" @click="removeInvoiceLine(idx)" />
              </div>
            </div>

            <div class="row justify-end q-gutter-sm q-pt-md">
              <q-btn flat label="Cancel" v-close-popup />
              <q-btn color="secondary" label="Issue Invoice & Deduct Stock" type="submit" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- DIALOG: Add Category -->
    <q-dialog v-model="categoryDialog">
      <q-card style="min-width: 350px">
        <q-card-section class="bg-primary text-white">
          <div class="text-subtitle1 text-weight-bold">Add Thrift Category</div>
        </q-card-section>
        <q-card-section class="q-pt-md">
          <q-input v-model="categoryName" outlined dense label="Category Name *" class="q-mb-sm" />
          <q-input v-model="categoryDesc" outlined dense label="Description" class="q-mb-md" />
          <div class="row justify-end q-gutter-sm">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn color="primary" label="Save" @click="saveCategory" />
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- DIALOG: Add Product Type -->
    <q-dialog v-model="typeDialog">
      <q-card style="min-width: 350px">
        <q-card-section class="bg-primary text-white">
          <div class="text-subtitle1 text-weight-bold">Add Product Style Type</div>
        </q-card-section>
        <q-card-section class="q-pt-md">
          <q-input v-model="typeName" outlined dense label="Style Type Name *" class="q-mb-sm" />
          <q-input v-model="typeDesc" outlined dense label="Description" class="q-mb-md" />
          <div class="row justify-end q-gutter-sm">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn color="primary" label="Save" @click="saveType" />
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- DIALOG: Add Shelf -->
    <q-dialog v-model="shelfDialog">
      <q-card style="min-width: 350px">
        <q-card-section class="bg-primary text-white">
          <div class="text-subtitle1 text-weight-bold">Add Physical Shelf Location</div>
        </q-card-section>
        <q-card-section class="q-pt-md">
          <q-input v-model="shelfName" outlined dense label="Shelf Name (e.g. Aisle 3, Bin B) *" class="q-mb-sm" />
          <q-input v-model="shelfLocationBay" outlined dense label="Location Bay (Optional)" class="q-mb-sm" />
          <q-input v-model="shelfCode" outlined dense label="Shelf Code (e.g. A3-B) *" class="q-mb-md" />
          <div class="row justify-end q-gutter-sm">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn color="primary" label="Save" @click="saveShelf" />
          </div>
        </q-card-section>
      </q-card>
      </q-dialog>

      <!-- DIALOG: Add Box -->
      <q-dialog v-model="boxDialog">
        <q-card style="min-width: 350px">
          <q-card-section class="bg-primary text-white">
            <div class="text-subtitle1 text-weight-bold">Add Thrift Box</div>
          </q-card-section>
          <q-card-section class="q-pt-md">
            <q-form @submit="saveBox" class="q-gutter-sm">
              <q-select
                v-model="boxForm.shipment_id"
                outlined
                dense
                label="Shipment *"
                :options="shipments"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                :rules="[val => !!val || 'Required']"
              />
              <q-input
                v-model="boxForm.name"
                outlined
                dense
                label="Box Number/Name *"
                :rules="[val => !!val && val.length > 0 || 'Required']"
              />
              <q-input
                v-model.number="boxForm.weight"
                type="number"
                step="0.001"
                outlined
                dense
                label="Weight (kg)"
              />
              <q-input
                v-model.number="boxForm.received_weight"
                type="number"
                step="0.001"
                outlined
                dense
                label="Received Weight (kg)"
              />
              <div class="row justify-end q-gutter-sm q-pt-sm">
                <q-btn flat label="Cancel" v-close-popup />
                <q-btn color="primary" label="Save" type="submit" />
              </div>
            </q-form>
          </q-card-section>
        </q-card>
      </q-dialog>

    </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftStore } from '../stores/thriftStore';
import { useQuasar, type QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';

const $q = useQuasar();
const authStore = useAuthStore();
const thriftStore = useThriftStore();

const activeTab = ref('stocks');

// Load values computed
const categories = computed(() => thriftStore.categories);
const types = computed(() => thriftStore.types);
const shelves = computed(() => thriftStore.shelves);
const stocks = computed(() => thriftStore.stocks);
const invoices = computed(() => thriftStore.invoices);
const ledgerEntries = computed(() => thriftStore.ledgerEntries);
const boxes = computed(() => thriftStore.boxes);
const loading = computed(() => thriftStore.loading);

const shipments = ref<any[]>([]);

async function loadShipments() {
  if (!authStore.tenantId) return;
  const { data } = await supabase
    .from('shipments')
    .select('id, name')
    .eq('tenant_id', authStore.tenantId)
    .order('name', { ascending: true });
  shipments.value = data || [];
}

function getShipmentName(id: number) {
  const sh = shipments.value.find(s => s.id === id);
  return sh ? sh.name : `#${id}`;
}

function getBoxName(boxId: number | undefined) {
  if (!boxId) return '—';
  const bx = thriftStore.boxes.find(b => b.id === boxId);
  return bx ? bx.name : `#${boxId}`;
}

// Computed stats
const totalRevenue = computed(() => {
  return ledgerEntries.value
    .filter(e => e.type === 'REVENUE')
    .reduce((acc, curr) => acc + Number(curr.amount), 0);
});

const totalExpenses = computed(() => {
  return ledgerEntries.value
    .filter(e => e.type === 'EXPENSE' || e.type === 'LOSS')
    .reduce((acc, curr) => acc + Number(curr.amount), 0);
});

const availableStocks = computed(() => {
  return stocks.value.filter(s => s.status === 'AVAILABLE' && s.quantity > 0);
});

// Dialog controls
const stockDialog = ref(false);
const sellDialog = ref(false);
const categoryDialog = ref(false);
const typeDialog = ref(false);
const shelfDialog = ref(false);

// Form model values
const stockForm = ref({
  category_id: null as number | null,
  type_id: null as number | null,
  shipment_id: null as number | null,
  box_id: null as number | null,
  name: '',
  brand_name: '',
  sku: '',
  section: 'UNISEX',
  shelf_id: null as number | null,
  color: '',
  size: '',
  condition: 'EXCELLENT',
  quantity: 1,
  product_weight: 0.25,
  extra_weight: 0,
  note: '',
});

const boxDialog = ref(false);
const boxForm = ref({
  shipment_id: null as number | null,
  name: '',
  weight: 0,
  received_weight: 0
});

const filteredBoxes = computed(() => {
  if (!stockForm.value.shipment_id) return [];
  return thriftStore.boxes.filter(b => b.shipment_id === stockForm.value.shipment_id);
});

function onShipmentChange() {
  stockForm.value.box_id = null;
}

function openBoxDialog() {
  boxForm.value = {
    shipment_id: shipments.value[0]?.id || null,
    name: '',
    weight: 0,
    received_weight: 0
  };
  boxDialog.value = true;
}

async function saveBox() {
  if (!authStore.tenantId || !boxForm.value.shipment_id || !boxForm.value.name) return;
  $q.loading.show();
  try {
    await thriftStore.createBox(
      authStore.tenantId,
      boxForm.value.shipment_id,
      boxForm.value.name,
      boxForm.value.weight,
      boxForm.value.received_weight,
      authStore.user?.email || 'admin@brandwala.com'
    );
    $q.notify({ type: 'positive', message: 'Thrift box added' });
    boxDialog.value = false;
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Box creation failed' });
  } finally {
    $q.loading.hide();
  }
}

async function deleteBox(id: number) {
  $q.loading.show();
  try {
    await thriftStore.deleteBox(id);
    $q.notify({ type: 'positive', message: 'Thrift box deleted' });
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Box deletion failed' });
  } finally {
    $q.loading.hide();
  }
}

const pricingForm = ref({
  cost_of_goods_sold: 0,
  target_price: 0,
  listed_price: 0,
});

const invoiceForm = ref({
  recipient_name: '',
  phone: '',
  address: '',
  transaction_method: 'CASH',
  invoice_number: '',
  cod_charge: 0,
  packing_charge: 0,
  invoice_print_charge: 0,
  shipping_charge_customer: 0,
});

const invoiceLines = ref<Array<{
  stock_id: number | null;
  quantity: number;
  sold_price: number;
  platform_fees: number;
  shipping_cost_paid_by_shop: number;
}>>([]);

// Simple dialog inputs
const categoryName = ref('');
const categoryDesc = ref('');
const typeName = ref('');
const typeDesc = ref('');
const shelfName = ref('');
const shelfLocationBay = ref('');
const shelfCode = ref('');

// Table columns setup
const stockColumns: QTableColumn[] = [
  { name: 'sku', align: 'left', label: 'SKU', field: 'sku', sortable: true },
  { name: 'name', align: 'left', label: 'Name', field: 'name', sortable: true },
  { name: 'brand_name', align: 'left', label: 'Brand', field: 'brand_name' },
  { name: 'section', align: 'left', label: 'Section', field: 'section' },
  { name: 'size', align: 'left', label: 'Size', field: 'size' },
  { name: 'color', align: 'left', label: 'Color', field: 'color' },
  { name: 'box', align: 'left', label: 'Box', field: 'box' },
  { name: 'product_weight', align: 'right', label: 'Product Wt', field: 'product_weight' },
  { name: 'extra_weight', align: 'right', label: 'Extra Wt', field: 'extra_weight' },
  { name: 'condition', align: 'left', label: 'Condition', field: 'condition' },
  { name: 'quantity', align: 'right', label: 'Qty', field: 'quantity', sortable: true },
  { name: 'pricing', align: 'left', label: 'Pricing', field: 'pricing' },
  { name: 'status', align: 'center', label: 'Status', field: 'status', sortable: true },
  { name: 'actions', align: 'center', label: 'Actions', field: 'actions' },
];

const boxColumns: QTableColumn[] = [
  { name: 'name', align: 'left', label: 'Box Name / Number', field: 'name', sortable: true },
  { name: 'shipment', align: 'left', label: 'Shipment', field: 'shipment' },
  { name: 'weight', align: 'right', label: 'Weight', field: 'weight' },
  { name: 'received_weight', align: 'right', label: 'Received Weight', field: 'received_weight' },
  { name: 'actions', align: 'right', label: '', field: 'actions' }
];

const invoiceColumns: QTableColumn[] = [
  { name: 'invoice_number', align: 'left', label: 'Invoice No', field: 'invoice_number', sortable: true },
  { name: 'recipient_name', align: 'left', label: 'Recipient', field: 'recipient_name', sortable: true },
  { name: 'phone', align: 'left', label: 'Phone', field: 'phone' },
  { name: 'transaction_method', align: 'left', label: 'Method', field: 'transaction_method' },
  { name: 'delivery_status', align: 'center', label: 'Delivery', field: 'delivery_status', sortable: true },
  { name: 'payment_status', align: 'center', label: 'Payment', field: 'payment_status', sortable: true },
  { name: 'total_invoice_amount', align: 'right', label: 'Total Amount', field: 'total_invoice_amount', sortable: true, format: (val: any) => `$${val}` },
  { name: 'created_at', align: 'left', label: 'Issued Date', field: 'created_at', format: (val: any) => new Date(val).toLocaleDateString() },
];

const shelfColumns: QTableColumn[] = [
  { name: 'shelf_code', align: 'left', label: 'Shelf Code', field: 'shelf_code', sortable: true },
  { name: 'name', align: 'left', label: 'Shelf Name', field: 'name', sortable: true },
  { name: 'location_bay', align: 'left', label: 'Bay Location', field: 'location_bay' },
];

const categoryColumns: QTableColumn[] = [
  { name: 'name', align: 'left', label: 'Category Name', field: 'name', sortable: true },
  { name: 'description', align: 'left', label: 'Description', field: 'description' },
];

const typeColumns: QTableColumn[] = [
  { name: 'name', align: 'left', label: 'Style Name', field: 'name', sortable: true },
  { name: 'description', align: 'left', label: 'Description', field: 'description' },
];

const ledgerColumns: QTableColumn[] = [
  { name: 'date', align: 'left', label: 'Date', field: 'date', format: (val: any) => new Date(val).toLocaleString(), sortable: true },
  { name: 'type', align: 'center', label: 'Type', field: 'type', sortable: true },
  { name: 'source', align: 'left', label: 'Source', field: 'source' },
  { name: 'amount', align: 'right', label: 'Amount', field: 'amount', format: (val: any) => `$${val}`, sortable: true },
  { name: 'note', align: 'left', label: 'Note', field: 'note' },
];

onMounted(async () => {
  if (authStore.tenantId) {
    await Promise.all([
      thriftStore.loadModuleData(authStore.tenantId),
      loadShipments()
    ]);
  }
});

watch(() => authStore.tenantId, async (newId) => {
  if (newId) {
    await Promise.all([
      thriftStore.loadModuleData(newId),
      loadShipments()
    ]);
  }
});

// Color Helpers
function getStatusColor(status: string) {
  switch (status) {
    case 'AVAILABLE': return 'green-7';
    case 'OUT_OF_STOCK': return 'grey-6';
    case 'DAMAGED': return 'warning';
    case 'STOLEN': return 'negative';
    default: return 'primary';
  }
}

function getLedgerTypeColor(type: string) {
  switch (type) {
    case 'REVENUE': return 'green-7';
    case 'EXPENSE': return 'deep-orange-7';
    case 'REFUND': return 'blue-7';
    case 'LOSS': return 'negative';
    default: return 'grey';
  }
}

// CRUD / Actions trigger
async function updateStatus(stockId: number, status: string) {
  $q.loading.show();
  try {
    await thriftStore.updateStockStatus(stockId, status);
    // Reload ledger entries to see automatic LOSS logs
    if (authStore.tenantId) {
      await thriftStore.loadModuleData(authStore.tenantId);
    }
    $q.notify({ type: 'positive', message: `Stock marked as ${status}` });
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Status update failed' });
  } finally {
    $q.loading.hide();
  }
}

// Dialog openers
function openAddStockDialog() {
  stockForm.value = {
    category_id: categories.value[0]?.id || null,
    type_id: types.value[0]?.id || null,
    shipment_id: shipments.value[0]?.id || null,
    box_id: null,
    name: '',
    brand_name: '',
    sku: 'SKU-' + Math.floor(Math.random() * 90000 + 10000),
    section: 'UNISEX',
    shelf_id: shelves.value[0]?.id || null,
    color: '',
    size: '',
    condition: 'EXCELLENT',
    quantity: 1,
    product_weight: 0.25,
    extra_weight: 0,
    note: '',
  };
  pricingForm.value = {
    cost_of_goods_sold: 0.00,
    target_price: 0.00,
    listed_price: 0.00,
  };
  stockDialog.value = true;
}

function openSellDialog() {
  invoiceForm.value = {
    recipient_name: '',
    phone: '',
    address: '',
    transaction_method: 'CASH',
    invoice_number: 'INV-THRIFT-' + Math.floor(Math.random() * 900000 + 100000),
    cod_charge: 0,
    packing_charge: 0,
    invoice_print_charge: 0,
    shipping_charge_customer: 0,
  };
  invoiceLines.value = [
    {
      stock_id: availableStocks.value[0]?.id || null,
      quantity: 1,
      sold_price: availableStocks.value[0]?.pricing?.listed_price || 0.00,
      platform_fees: 0.00,
      shipping_cost_paid_by_shop: 0.00,
    }
  ];
  sellDialog.value = true;
}

function addInvoiceLine() {
  invoiceLines.value.push({
    stock_id: availableStocks.value[0]?.id || null,
    quantity: 1,
    sold_price: availableStocks.value[0]?.pricing?.listed_price || 0.00,
    platform_fees: 0.00,
    shipping_cost_paid_by_shop: 0.00,
  });
}

function removeInvoiceLine(idx: number) {
  invoiceLines.value.splice(idx, 1);
}

function onStockLineSelect(idx: number) {
  const line = invoiceLines.value[idx];
  if (!line || !line.stock_id) return;
  const stock = stocks.value.find(s => s.id === line.stock_id);
  if (stock && stock.pricing) {
    line.sold_price = stock.pricing.listed_price;
  }
}

// Submissions
async function onSubmitStock() {
  if (!authStore.tenantId) return;
  $q.loading.show();
  try {
    await thriftStore.createStock(
      authStore.tenantId,
      stockForm.value.shipment_id!,
      stockForm.value.name,
      stockForm.value.brand_name,
      stockForm.value.category_id!,
      stockForm.value.type_id!,
      stockForm.value.section,
      stockForm.value.shelf_id!,
      stockForm.value.color,
      stockForm.value.size,
      stockForm.value.condition,
      stockForm.value.sku,
      'SINGLE',
      stockForm.value.quantity,
      stockForm.value.box_id || undefined,
      stockForm.value.product_weight || undefined,
      stockForm.value.extra_weight || undefined,
      stockForm.value.note,
      authStore.user?.email || 'admin@brandwala.com',
      pricingForm.value
    );
    $q.notify({ type: 'positive', message: 'Thrift stock item added successfully!' });
    stockDialog.value = false;
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Saving failed' });
  } finally {
    $q.loading.hide();
  }
}

async function onSubmitSell() {
  if (!authStore.tenantId) return;
  if (invoiceLines.value.length === 0) {
    $q.notify({ type: 'negative', message: 'Invoice must contain at least one item line.' });
    return;
  }
  
  $q.loading.show();
  try {
    await thriftStore.sellThriftItems({
      tenantId: authStore.tenantId,
      invoiceNumber: invoiceForm.value.invoice_number,
      recipientName: invoiceForm.value.recipient_name,
      address: invoiceForm.value.address,
      phone: invoiceForm.value.phone,
      transactionMethod: invoiceForm.value.transaction_method,
      codCharge: invoiceForm.value.cod_charge || 0,
      packingCharge: invoiceForm.value.packing_charge || 0,
      invoicePrintCharge: invoiceForm.value.invoice_print_charge || 0,
      shippingChargeCustomer: invoiceForm.value.shipping_charge_customer || 0,
      insertedBy: authStore.user?.email || 'admin@brandwala.com',
      items: invoiceLines.value.map(line => ({
        stock_id: line.stock_id!,
        quantity: line.quantity,
        sold_price: line.sold_price,
        platform_fees: line.platform_fees || 0,
        shipping_cost_paid_by_shop: line.shipping_cost_paid_by_shop || 0,
      })),
    });
    $q.notify({ type: 'positive', message: 'Thrift invoice issued and ledger logged successfully!' });
    sellDialog.value = false;
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Mark as sold operation failed' });
  } finally {
    $q.loading.hide();
  }
}

async function saveCategory() {
  if (!authStore.tenantId || !categoryName.value) return;
  $q.loading.show();
  try {
    await thriftStore.createCategory(
      authStore.tenantId,
      categoryName.value,
      categoryDesc.value,
      authStore.user?.email || 'admin@brandwala.com'
    );
    $q.notify({ type: 'positive', message: 'Category added' });
    categoryDialog.value = false;
    categoryName.value = '';
    categoryDesc.value = '';
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Category creation failed' });
  } finally {
    $q.loading.hide();
  }
}

async function saveType() {
  if (!authStore.tenantId || !typeName.value) return;
  $q.loading.show();
  try {
    await thriftStore.createType(
      authStore.tenantId,
      typeName.value,
      typeDesc.value,
      authStore.user?.email || 'admin@brandwala.com'
    );
    $q.notify({ type: 'positive', message: 'Product Type Style added' });
    typeDialog.value = false;
    typeName.value = '';
    typeDesc.value = '';
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Type creation failed' });
  } finally {
    $q.loading.hide();
  }
}

async function saveShelf() {
  if (!authStore.tenantId || !shelfName.value || !shelfCode.value) return;
  $q.loading.show();
  try {
    await thriftStore.createShelf(
      authStore.tenantId,
      shelfName.value,
      shelfLocationBay.value,
      shelfCode.value,
      authStore.user?.email || 'admin@brandwala.com'
    );
    $q.notify({ type: 'positive', message: 'Warehouse Shelf registered' });
    shelfDialog.value = false;
    shelfName.value = '';
    shelfLocationBay.value = '';
    shelfCode.value = '';
  } catch (err: any) {
    $q.notify({ type: 'negative', message: err.message || 'Shelf creation failed' });
  } finally {
    $q.loading.hide();
  }
}
</script>

<style scoped>
.header-gradient {
  background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
  border-radius: 12px;
}

.kpi-card {
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.9);
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}

.kpi-card:hover {
  transform: translateY(-4px);
}

.hover-glow:hover {
  box-shadow: 0 10px 20px rgba(99, 102, 241, 0.15);
}

.hover-grow {
  transition: transform 0.2s ease;
}

.hover-grow:hover {
  transform: scale(1.03);
}

.pill-btn {
  border-radius: 30px;
  padding: 8px 16px;
  font-weight: 600;
}

.modal-card {
  border-radius: 16px;
}

.thrift-table {
  border-radius: 8px;
}

.font-medium {
  font-weight: 500;
}

/* Icons rotate micro-animation */
.animated-icon {
  transition: transform 0.5s ease;
}
.header-gradient:hover .animated-icon {
  transform: rotate(15deg) scale(1.1);
}
</style>
