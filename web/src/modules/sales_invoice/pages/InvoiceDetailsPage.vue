<template>
  <q-page class="q-pa-md global-invoice-details-page">
    <PageInitialLoader v-if="loading" />

    <div v-else-if="error" class="text-center q-pa-xl text-negative">{{ error }}</div>

    <div v-else-if="invoice" class="q-gutter-y-md">
      <!-- Header Row -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat dense icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline text-primary">Sales Invoice</div>
              <h1 class="text-h5 text-weight-bold q-my-none">
                {{ invoice.invoice_no || 'Draft Invoice' }}
              </h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Invoice ID: {{ invoice.id }}-{{ form.invoice_date || invoice.invoice_date }}
              </p>
            </div>
          </div>
        </div>
        <div class="col-auto row q-gutter-sm items-center">


          <q-btn
            v-if="showPreview"
            flat
            dense
            color="secondary"
            icon="o_visibility"
            @click="openPreview"
          >
            <q-tooltip>Preview</q-tooltip>
          </q-btn>

          <q-btn
            v-if="invoice.invoice_status === 'draft'"
            color="primary"
            unelevated
            no-caps
            icon="add"
            label="Add Stock"
            @click="stockDialog = true"
          />

          <q-btn
            v-if="
              invoice.invoice_status === 'draft' ||
              (invoice.invoice_status === 'posted' && canUnpostOrVoid)
            "
            flat
            dense
            icon="more_vert"
            aria-label="Actions"
          >
            <q-tooltip>More Actions</q-tooltip>
            <q-menu auto-close>
              <q-list style="min-width: 150px">
                <q-item
                  v-if="invoice.invoice_status === 'draft'"
                  clickable
                  class="text-negative"
                  :disable="deletingInvoice"
                  @click="onDeleteInvoice"
                >
                  <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                    <q-icon name="delete" />
                  </q-item-section>
                  <q-item-section>Delete Draft</q-item-section>
                </q-item>

                <q-item
                  v-if="
                    invoice.invoice_status === 'draft' && invoice.invoice_type === 'wholesale'
                  "
                  clickable
                  class="text-primary"
                  :disable="convertingInvoice"
                  @click="onConvertWholesaleToRetail"
                >
                  <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                    <q-icon name="swap_horiz" />
                  </q-item-section>
                  <q-item-section>Convert to Retail</q-item-section>
                </q-item>

                <q-item
                  v-if="invoice.invoice_status === 'posted' && canUnpostOrVoid"
                  clickable
                  class="text-negative"
                  :disable="voidingInvoice"
                  @click="changeInvoiceStatus('voided')"
                >
                  <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                    <q-icon name="cancel" />
                  </q-item-section>
                  <q-item-section>Void Invoice</q-item-section>
                </q-item>

                <q-item
                  v-if="invoice.invoice_status === 'posted' && canUnpostOrVoid"
                  clickable
                  class="text-warning"
                  :disable="unpostingInvoice"
                  @click="changeInvoiceStatus('draft')"
                >
                  <q-item-section avatar class="q-pr-none" style="min-width: 32px">
                    <q-icon name="undo" />
                  </q-item-section>
                  <q-item-section>Undo Post (Draft)</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>
        </div>
      </section>

      <!-- Status Workflow Strip -->
      <q-card flat bordered class="q-pa-sm q-mb-md">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-grow row items-center q-gutter-xs status-workflow-row">
            <template v-for="(st, idx) in ['draft', 'posted']" :key="st">
              <q-btn
                :color="invoice.invoice_status === st ? (st === 'posted' ? 'positive' : 'orange') : (invoice.invoice_status === 'posted' && st === 'draft' ? 'grey-5' : 'grey-3')"
                :text-color="invoice.invoice_status === st ? 'white' : (invoice.invoice_status === 'posted' && st === 'draft' ? 'grey-9' : 'grey-7')"
                :outline="invoice.invoice_status !== st"
                :unelevated="invoice.invoice_status === st"
                dense
                no-caps
                class="q-px-md text-caption text-weight-bold"
                :loading="(st === 'posted' && postingInvoice) || (st === 'draft' && unpostingInvoice)"
                :disable="(postingInvoice || unpostingInvoice || voidingInvoice) || isTransitionDisabled(st)"
                @click="changeInvoiceStatus(st)"
              >
                <q-icon v-if="invoice.invoice_status === st" name="check_circle" size="14px" class="q-mr-xs" />
                {{ st.charAt(0).toUpperCase() + st.slice(1) }}
              </q-btn>
              <q-icon
                v-if="idx === 0"
                name="chevron_right"
                color="grey-5"
                size="18px"
                class="status-workflow-chevron"
              />
            </template>
            <q-separator vertical class="q-mx-sm status-workflow-sep" />
            <q-btn
              :color="invoice.invoice_status === 'voided' ? 'negative' : 'grey-3'"
              :text-color="invoice.invoice_status === 'voided' ? 'white' : 'grey-7'"
              :outline="invoice.invoice_status !== 'voided'"
              :unelevated="invoice.invoice_status === 'voided'"
              dense
              no-caps
              class="q-px-md text-caption text-weight-bold"
              :loading="voidingInvoice"
              :disable="(postingInvoice || unpostingInvoice || voidingInvoice) || (isTransitionDisabled('voided') && invoice.invoice_status !== 'voided')"
              @click="changeInvoiceStatus('voided')"
            >
              <q-icon v-if="invoice.invoice_status === 'voided'" name="cancel" size="14px" class="q-mr-xs" />
              Voided
            </q-btn>
          </div>
          <div class="col-auto row items-center q-gutter-sm">
            <q-chip square dense class="status-chip text-weight-bold text-capitalize">
              {{ invoice.invoice_type }}
            </q-chip>
            <q-chip square dense class="status-chip text-weight-bold text-uppercase">
              {{ invoice.payment_status }}
            </q-chip>
          </div>
        </div>
      </q-card>

      <!-- Main Columns Layout -->
      <div class="row q-col-gutter-lg invoice-details-page-container">
        <!-- Left Side: Main content area (Items, note, hero stats) -->
        <div :class="showSidebar ? 'col-12 col-md-8 transition-width' : 'col-12 transition-width'" class="q-gutter-y-md scroll-col">
          
          <!-- Hero Stats Banner -->
          <q-card flat class="hero-stats-card text-white q-pa-lg">
            <div class="row items-center justify-between q-col-gutter-md">
              <div class="col-12 col-sm-5">
                <div class="text-caption text-uppercase text-weight-medium opacity-80">Total Amount Due</div>
                <div class="text-h4 text-weight-bolder q-mt-xs q-mb-none">
                  {{ formatAmount(invoice.total_amount) }}
                </div>
              </div>
              <div class="col-grow row items-center justify-end q-col-gutter-lg text-right gt-xs">
                <div>
                  <div class="text-caption text-uppercase opacity-80">Total Paid</div>
                  <div class="text-h5 text-weight-bold q-mt-xs">{{ formatAmount(invoice.paid_amount) }}</div>
                </div>
                <q-separator vertical dark class="q-mx-md" style="height: 40px;" />
                <div>
                  <div class="text-caption text-uppercase opacity-80">Balance Due</div>
                  <div class="text-h5 text-weight-bold q-mt-xs text-yellow-3">{{ formatAmount(invoice.due_amount) }}</div>
                </div>
              </div>
              <!-- Mobile view fallback for sub stats -->
              <div class="col-12 row items-center justify-between lt-sm q-mt-md">
                <div>
                  <div class="text-caption text-uppercase opacity-80">Paid</div>
                  <div class="text-subtitle1 text-weight-bold">{{ formatAmount(invoice.paid_amount) }}</div>
                </div>
                <div>
                  <div class="text-caption text-uppercase opacity-80">Balance Due</div>
                  <div class="text-subtitle1 text-weight-bold text-yellow-3">{{ formatAmount(invoice.due_amount) }}</div>
                </div>
              </div>
            </div>
          </q-card>

          <!-- Items Table Card -->
          <q-card flat class="floating-surface shadow-1">
            <q-card-section class="row items-center q-py-md">
              <q-btn
                flat
                round
                dense
                color="primary"
                :icon="showSidebar ? 'keyboard_double_arrow_right' : 'keyboard_double_arrow_left'"
                @click="showSidebar = !showSidebar"
                class="q-mr-sm"
              >
                <q-tooltip>{{ showSidebar ? 'Hide Sidebar' : 'Show Sidebar' }}</q-tooltip>
              </q-btn>
              <div class="text-subtitle1 text-weight-bold">Invoice Items ({{ items.length }})</div>
              <q-space />
              
              <div v-if="invoice.invoice_status === 'draft'" class="row q-gutter-sm">
                <q-btn
                  v-if="items.length > 0"
                  color="secondary"
                  icon="content_paste"
                  label="Bulk Paste"
                  unelevated
                  dense
                  no-caps
                  class="pill-btn slim-btn"
                  @click="openBulkPaste"
                />
              </div>
            </q-card-section>
            
            <q-separator />
            
            <q-card-section v-if="!items.length" class="text-grey-7 text-center q-pa-xl">
              <q-icon name="inventory" size="48px" color="grey-4" class="q-mb-md" />
              <div class="text-subtitle2 text-grey-6">No items yet. Add items from global stock.</div>
            </q-card-section>
            
            <q-markup-table v-else flat dense wrap-cells class="invoice-items-table q-px-sm">
              <thead>
                <tr>
                  <th class="text-left" style="width: 40px">SL</th>
                  <th style="width: 60px"></th>
                  <th class="text-left">Product</th>
                  <th class="text-right">Qty</th>
                  <th class="text-right">Cost</th>
                  <th class="text-right">Sell</th>
                  <th v-if="isDropship" class="text-right">Recipient</th>
                  <th class="text-right">Total</th>
                  <th v-if="invoice.invoice_status === 'posted'" class="text-right">Margin</th>
                  <th v-if="invoice.invoice_status === 'draft'" style="width: 50px"></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, idx) in items" :key="row.id" class="invoice-item-row">
                  <td class="text-left">{{ idx + 1 }}</td>
                  <td>
                    <div class="invoice-item-image-box shadow-1">
                      <SmartImage
                        :src="row.image_url"
                        alt="item snapshot"
                        img-class="invoice-item-image"
                        fallback-class="invoice-item-image-fallback"
                        :enable-edit="false"
                      />
                    </div>
                  </td>
                  <td class="text-weight-medium">
                    <div style="white-space: normal; word-break: break-word; min-width: 150px; max-width: 300px;">{{ row.name_snapshot }}</div>
                  </td>
                  <td class="text-right">
                    <span
                      class="text-weight-bold"
                      :class="{
                        'cursor-pointer text-underline-dashed text-primary': invoice.invoice_status === 'draft',
                      }"
                    >
                      {{ row.quantity }}
                      <q-icon name="edit" size="10px" class="q-ml-xs text-grey-5" v-if="invoice.invoice_status === 'draft'" />
                    </span>
                    <q-popup-edit
                      v-if="invoice.invoice_status === 'draft'"
                      :model-value="row.quantity"
                      buttons
                      persistent
                      label-set="Save"
                      label-cancel="Cancel"
                      v-slot="scope"
                      @save="(val) => onUpdateItemField(row, 'quantity', val)"
                    >
                      <q-input
                        :model-value="scope.value ?? ''"
                        type="number"
                        dense
                        outlined
                        autofocus
                        min="1"
                        step="1"
                        @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                        @keyup.enter="scope.set"
                      />
                    </q-popup-edit>
                    <div
                      v-if="row.return_quantity > 0"
                      class="text-caption text-orange text-weight-bold"
                    >
                      Returned: {{ row.return_quantity }}
                    </div>
                  </td>
                  <td class="text-right text-grey-7">
                    {{ formatItemUnitCost(row) }}
                  </td>
                  <td class="text-right">
                    <span
                      :class="{
                        'cursor-pointer text-underline-dashed text-primary': invoice.invoice_status === 'draft',
                      }"
                    >
                      {{ formatAmount(row.sell_price_amount) }}
                      <q-icon name="edit" size="10px" class="q-ml-xs text-grey-5" v-if="invoice.invoice_status === 'draft'" />
                    </span>
                    <q-popup-edit
                      v-if="invoice.invoice_status === 'draft'"
                      :model-value="row.sell_price_amount"
                      buttons
                      persistent
                      label-set="Save"
                      label-cancel="Cancel"
                      v-slot="scope"
                      @save="(val) => onUpdateItemField(row, 'sell_price_amount', val)"
                    >
                      <q-input
                        :model-value="scope.value ?? ''"
                        type="number"
                        dense
                        outlined
                        autofocus
                        min="0"
                        step="0.01"
                        @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                        @keyup.enter="scope.set"
                      />
                    </q-popup-edit>
                  </td>
                  <td v-if="isDropship" class="text-right">
                    <span
                      :class="{
                        'cursor-pointer text-underline-dashed text-primary': invoice.invoice_status === 'draft',
                      }"
                    >
                      {{ formatAmount(row.recipient_price_amount ?? row.sell_price_amount) }}
                      <q-icon name="edit" size="10px" class="q-ml-xs text-grey-5" v-if="invoice.invoice_status === 'draft'" />
                    </span>
                    <q-popup-edit
                      v-if="invoice.invoice_status === 'draft'"
                      :model-value="row.recipient_price_amount ?? row.sell_price_amount"
                      buttons
                      persistent
                      label-set="Save"
                      label-cancel="Cancel"
                      v-slot="scope"
                      @save="(val) => onUpdateItemField(row, 'recipient_price_amount', val)"
                    >
                      <q-input
                        :model-value="scope.value ?? ''"
                        type="number"
                        dense
                        outlined
                        autofocus
                        min="0"
                        step="0.01"
                        @update:model-value="(v) => (scope.value = v === '' ? null : Number(v))"
                        @keyup.enter="scope.set"
                      />
                    </q-popup-edit>
                  </td>
                  <td class="text-right text-weight-bold">
                    {{ formatAmount(row.line_total_amount) }}
                  </td>
                  <td v-if="invoice.invoice_status === 'posted'" class="text-right text-positive">
                    {{ formatAmount(lineMarginForRow(row)) }}
                  </td>
                  <td v-if="invoice.invoice_status === 'draft'" class="text-right">
                    <q-btn
                      flat
                      round
                      dense
                      color="negative"
                      icon="delete"
                      size="sm"
                      @click="onRemoveItem(row.id)"
                    >
                      <q-tooltip>Remove Item</q-tooltip>
                    </q-btn>
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>

          <!-- Internal Notes Card -->
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="row items-center justify-between no-wrap q-mb-sm">
              <div class="text-subtitle2 text-weight-bold">Internal Notes</div>
              <q-btn
                v-if="invoice.invoice_status === 'draft'"
                flat
                round
                dense
                color="primary"
                icon="edit"
                size="sm"
                @click="openEditNoteDialog"
              >
                <q-tooltip>Edit Note</q-tooltip>
              </q-btn>
            </div>
            <div
              v-if="invoice.note"
              ref="notePreviewRef"
              class="text-body2 text-grey-8 invoice-note-preview invoice-note-preview--clamped"
              :class="{ 'invoice-note-preview--overflow cursor-pointer': noteOverflows }"
              v-html="invoice.note"
              @click="noteOverflows && (viewNoteDialog = true)"
            />
            <div v-else class="text-body2 text-grey-4 italic">No private notes added.</div>
            <div
              v-if="noteOverflows"
              class="text-caption text-primary q-mt-xs cursor-pointer"
              @click="viewNoteDialog = true"
            >
              View full note
            </div>
          </q-card>
        </div>

        <!-- Right Side: Sidebar Meta details -->
        <div v-if="showSidebar" class="col-12 col-md-4 q-gutter-y-md scroll-col">
          
          <!-- Primary CTA Action Card -->
          <q-card flat class="floating-surface shadow-2 q-pa-md bg-grey-1" style="border: 1px solid var(--bw-theme-border)">
            <div class="column q-gutter-y-sm">
              <!-- CTA Button based on state -->
              <template v-if="invoice.invoice_status === 'draft'">
                <q-btn
                  color="primary"
                  unelevated
                  class="full-width text-subtitle2 text-weight-bold pill-btn q-py-sm"
                  icon="send"
                  label="POST INVOICE"
                  :loading="postingInvoice"
                  @click="changeInvoiceStatus('posted')"
                />
                <div class="text-caption text-grey-7 text-center q-px-xs">
                  Note: Once posted, this invoice will be committed to the stock ledger and marked as current.
                </div>
              </template>
              
              <template v-else-if="invoice.invoice_status === 'posted'">
                <template v-if="invoice.due_amount > 0">
                  <q-btn
                    color="primary"
                    unelevated
                    class="full-width text-subtitle2 text-weight-bold pill-btn q-py-sm"
                    icon="payment"
                    :label="isDropship ? 'RECORD COD' : 'RECORD PAYMENT'"
                    @click="isDropship ? openCodDialog() : openPaymentDialog()"
                  />
                  <div class="text-caption text-grey-7 text-center q-px-xs">
                    Note: Record customer payments/COD collections to settle the outstanding balance.
                  </div>
                </template>
                <template v-else>
                  <q-btn
                    color="positive"
                    unelevated
                    disable
                    class="full-width text-subtitle2 text-weight-bold pill-btn q-py-sm"
                    icon="check_circle"
                    label="INVOICE SETTLED"
                  />
                  <div class="text-caption text-positive text-center q-px-xs">
                    Note: This invoice has been fully paid and settled.
                  </div>
                </template>
              </template>
              
              <template v-else-if="invoice.invoice_status === 'voided'">
                <q-btn
                  color="grey-6"
                  unelevated
                  disable
                  class="full-width text-subtitle2 text-weight-bold pill-btn q-py-sm"
                  icon="cancel"
                  label="INVOICE VOIDED"
                />
                <div class="text-caption text-grey-6 text-center q-px-xs">
                  Note: This invoice is voided and cannot be modified.
                </div>
              </template>
            </div>
          </q-card>

          <!-- Invoice Information (Draft Only) -->
          <q-card v-if="invoice.invoice_status === 'draft'" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Invoice Information</div>
            <div class="q-gutter-y-sm">
              <q-input
                v-model="form.invoice_no"
                label="Invoice Name / Number *"
                dense
                outlined
                class="soft-input text-subtitle2 text-weight-bold"
                @blur="onHeaderUpdate"
              />
              <q-input
                v-model="form.invoice_date"
                label="Invoice Date *"
                dense
                outlined
                readonly
                class="soft-input text-caption"
              >
                <template #append>
                  <q-icon name="event" class="cursor-pointer">
                    <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                      <q-date
                        v-model="form.invoice_date"
                        mask="YYYY-MM-DD"
                        @update:model-value="onDateChange"
                      >
                        <div class="row items-center justify-end">
                          <q-btn v-close-popup label="Close" color="primary" flat />
                        </div>
                      </q-date>
                    </q-popup-proxy>
                  </q-icon>
                </template>
              </q-input>
            </div>
          </q-card>

          <!-- Billing & Delivery Card -->
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="row items-center justify-between q-mb-sm">
              <div class="text-subtitle2 text-weight-bold">Billing & Delivery</div>
              <q-btn
                v-if="invoice.invoice_status === 'draft'"
                flat
                dense
                no-caps
                color="primary"
                :label="editingRecipient ? 'DONE' : 'CHANGE'"
                class="text-weight-bold font-size-12"
                @click="editingRecipient ? (onHeaderUpdate(), editingRecipient = false) : editingRecipient = true"
              />
            </div>
            
            <div class="q-gutter-y-sm">
              <div>
                <div class="text-overline text-grey-6 text-weight-bold" style="line-height: 1.2">Customer</div>
                <div class="text-body2 text-weight-medium">{{ invoice.billing_profiles?.name || '—' }}</div>
                <div v-if="invoice.billing_profiles?.email" class="text-caption text-grey-7">
                  {{ invoice.billing_profiles.email }}
                </div>
              </div>
              
              <q-separator class="q-my-xs" />
              
              <div>
                <div class="text-overline text-grey-6 text-weight-bold" style="line-height: 1.2">Shipping Address</div>
                
                <!-- Edit mode (Draft state only) -->
                <div v-if="editingRecipient" class="q-gutter-y-xs q-mt-xs">
                  <q-input
                    v-model="form.recipient_name"
                    label="Name *"
                    dense
                    outlined
                    class="soft-input"
                    @blur="onHeaderUpdate"
                  />
                  <q-input
                    v-model="form.recipient_phone"
                    label="Phone"
                    dense
                    outlined
                    class="soft-input"
                    @blur="onHeaderUpdate"
                  />
                  <q-input
                    v-model="form.recipient_address"
                    label="Address"
                    type="textarea"
                    rows="2"
                    dense
                    outlined
                    class="soft-input"
                    @blur="onHeaderUpdate"
                  />
                </div>
                
                <!-- View mode -->
                <div v-else>
                  <div class="text-body2 text-weight-medium">{{ invoice.recipient_name || '—' }}</div>
                  <div v-if="invoice.recipient_phone" class="text-caption text-grey-7">
                    {{ invoice.recipient_phone }}
                  </div>
                  <div v-if="invoice.recipient_address" class="text-caption text-grey-7">
                    {{ invoice.recipient_address }}
                  </div>
                </div>
              </div>
            </div>
          </q-card>

          <!-- Charges & Discounts Card -->
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Charges & Discounts</div>
            <div class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">Delivery Charge</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.shipping_charge"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">
                  {{ formatAmount(invoice.shipping_charge) }}
                </div>
              </div>
            </div>
            <div v-if="showCharges" class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">COD Charge</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.cod_charge"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">
                  {{ formatAmount(invoice.cod_charge) }}
                </div>
              </div>
            </div>
            <div v-if="showCharges" class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">Wrapping Charge</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.wrapping_charge"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">
                  {{ formatAmount(invoice.wrapping_charge) }}
                </div>
              </div>
            </div>
            <div v-if="showCharges" class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium">Print Charge</div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.print_charge"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right">
                  {{ formatAmount(invoice.print_charge) }}
                </div>
              </div>
            </div>
            <div class="row items-center q-mb-sm q-gutter-sm">
              <div class="col text-caption text-weight-medium text-primary text-weight-bold">
                Discount
              </div>
              <div class="col">
                <q-input
                  v-if="invoice.invoice_status === 'draft'"
                  v-model.number="form.discount_amount"
                  type="number"
                  dense
                  outlined
                  class="soft-input"
                  min="0"
                  @blur="onHeaderUpdate"
                />
                <div v-else class="text-body2 text-right text-red text-weight-bold">
                  {{ formatAmount(invoice.discount_amount) }}
                </div>
              </div>
            </div>
          </q-card>

          <!-- Dropship Settlements (Payouts & Collections) -->
          <q-card v-if="isDropship" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Dropship Settlement</div>
            <div class="text-caption text-grey-8">
              Collection: {{ invoice.collection_source || 'recipient' }}
            </div>
            <div class="text-body2 q-mt-xs text-weight-medium">
              Middle-man payout: {{ formatAmount(invoice.middle_man_payout_amount ?? 0) }}
            </div>
            <div
              class="text-caption text-uppercase text-weight-bold"
              :class="invoice.middle_man_payout_status === 'paid' ? 'text-positive' : 'text-grey-7'"
            >
              Payout status: {{ invoice.middle_man_payout_status || 'pending' }}
            </div>
            <div class="row q-gutter-sm q-mt-sm">
              <q-btn
                v-if="showPayments && invoice.invoice_status === 'posted' && invoice.due_amount > 0"
                class="col pill-btn slim-btn"
                color="primary"
                no-caps
                label="Record COD"
                @click="openCodDialog"
              />
              <q-btn
                v-if="
                  showPayments &&
                  invoice.invoice_status === 'posted' &&
                  invoice.middle_man_payout_status !== 'paid' &&
                  (invoice.middle_man_payout_amount ?? 0) > 0
                "
                class="col pill-btn slim-btn"
                color="secondary"
                no-caps
                label="Payout"
                outline
                @click="payoutDialog = true"
              />
            </div>
            <q-btn
              v-if="showPayments && invoice.invoice_status === 'posted' && invoice.due_amount > 0"
              class="full-width pill-btn slim-btn q-mt-sm"
              color="orange"
              no-caps
              outline
              label="Settle / Write-off remaining"
              @click="openSettleDialog"
            />
          </q-card>

          <!-- Retail / Wholesale Payments -->
          <q-card
            v-if="
              showPayments &&
              !isDropship &&
              invoice.invoice_status === 'posted' &&
              invoice.due_amount > 0
            "
            flat
            class="floating-surface shadow-1 q-pa-md"
          >
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Collections</div>
            <div class="row q-gutter-sm">
              <q-btn
                color="primary"
                no-caps
                class="col pill-btn slim-btn"
                label="Record Payment"
                @click="openPaymentDialog"
              />
              <q-btn
                color="orange"
                no-caps
                outline
                class="col pill-btn slim-btn"
                label="Settle / Write-off"
                @click="openSettleDialog"
              />
            </div>
          </q-card>

          <!-- Adjust to Total (Draft Only) -->
          <q-card
            v-if="invoice.invoice_status === 'draft' && items.length > 0"
            flat
            class="floating-surface shadow-1 q-pa-md"
          >
            <div class="text-subtitle2 text-weight-bold q-mb-xs">
              {{ isDropship ? 'Adjust to Total (Customer)' : 'Adjust to Total' }}
            </div>
            <div class="text-caption text-grey-7 q-mb-sm">
              Enter the final total you want; item prices auto-adjust to match.
            </div>
            <div class="row items-center q-gutter-sm no-wrap">
              <q-input
                v-model.number="targetTotal"
                type="number"
                dense
                outlined
                class="soft-input col"
                min="0"
                placeholder="Desired total"
                :loading="targetPreviewing"
                @update:model-value="onTargetTotalInput"
              />
              <q-btn
                color="primary"
                no-caps
                class="pill-btn slim-btn"
                label="Apply"
                :disable="!targetPreview || !!targetError || applyingTarget"
                :loading="applyingTarget"
                @click="onApplyTargetTotal"
              />
            </div>

            <div v-if="targetError" class="text-caption text-negative q-mt-sm">
              {{ targetError }}
            </div>

            <div v-else-if="targetPreview" class="q-mt-sm">
              <q-separator class="q-mb-sm" />
              <div class="row justify-between text-caption text-grey-8">
                <span>Current total</span><span>{{ formatAmount(targetPreview.current_total) }}</span>
              </div>
              <div class="row justify-between text-caption text-grey-8">
                <span>Desired total</span><span>{{ formatAmount(targetPreview.target_total) }}</span>
              </div>
              <div class="row justify-between text-body2 text-weight-medium">
                <span>Adjustment</span>
                <span :class="targetPreview.adjustment >= 0 ? 'text-positive' : 'text-negative'">
                  {{ targetPreview.adjustment >= 0 ? '+' : '' }}{{ formatAmount(targetPreview.adjustment) }}
                </span>
              </div>
              <q-separator class="q-my-sm" />
              <div v-for="line in targetPreview.lines" :key="line.item_id" class="q-mb-xs">
                <div class="text-caption text-weight-medium ellipsis">{{ line.name }}</div>
                <div class="row justify-between text-caption text-grey-8">
                  <span>
                    {{ line.quantity }} &times; {{ formatAmount(line.old_price) }} &rarr;
                    {{ formatAmount(line.new_price) }}
                  </span>
                  <span :class="line.unit_delta >= 0 ? 'text-positive' : 'text-negative'">
                    {{ line.unit_delta >= 0 ? '+' : '' }}{{ formatAmount(line.unit_delta) }}/unit
                  </span>
                </div>
              </div>
            </div>
          </q-card>

          <!-- Totals Breakdown Card -->
          <q-card flat class="floating-surface shadow-1 q-pa-md q-gutter-y-xs">
            <div class="row justify-between text-body2">
              <span>Subtotal</span><span>{{ formatAmount(invoice.subtotal_amount) }}</span>
            </div>
            <div v-if="isDropship" class="row justify-between text-caption text-grey-7">
              <span>Face subtotal</span><span>{{ formatAmount(invoice.face_subtotal_amount ?? 0) }}</span>
            </div>
            <div class="row justify-between text-body2 text-grey-8">
              <span>Total Cost</span><span>{{ formatAmount(totalCost) }}</span>
            </div>
            <div class="row justify-between text-body2 text-grey-8">
              <span>Total Qty</span><span>{{ totalQuantity }}</span>
            </div>
            <q-separator class="q-my-xs" />
            <div
              v-if="(invoice.settlement_discount_amount ?? 0) > 0"
              class="row justify-between text-body2 text-orange-9"
            >
              <span>Settlement discount</span><span>-{{ formatAmount(invoice.settlement_discount_amount ?? 0) }}</span>
            </div>
            <div class="row justify-between text-subtitle1 text-weight-bold text-primary">
              <span>Total Amount</span><span>{{ formatAmount(invoice.total_amount) }}</span>
            </div>
            <q-separator class="q-my-xs" />
            <div class="row justify-between text-body2 text-weight-medium">
              <span>{{ invoice.invoice_status === 'posted' ? 'Gross Profit' : 'Est. Gross Profit' }}</span>
              <span :class="estimatedProfit >= 0 ? 'text-positive' : 'text-negative'">
                {{ formatAmount(estimatedProfit) }}
              </span>
            </div>
            <div class="row justify-between text-body2 text-grey-8">
              <span>Avg Profit Rate</span><span>{{ averageProfitRate }}</span>
            </div>
          </q-card>

          <!-- Dropship Settlement / Courier Remittance -->
          <q-card v-if="isDropship" flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">Courier Remittance</div>
            <div class="q-gutter-y-xs">
              <q-input
                dense
                outlined
                readonly
                :model-value="linkedOrderRemittance?.courier_remittance_ref || '—'"
                label="Remittance Batch ID"
                class="soft-input text-caption"
              />
              <q-input
                dense
                outlined
                readonly
                :model-value="linkedOrderRemittance?.courier_bank_trx_id || '—'"
                label="Bank / MFS Trx Ref"
                class="soft-input text-caption"
              />
              <div v-if="linkedOrderRemittance" class="text-caption text-grey-7 q-mt-xs">
                Order
                <router-link
                  class="text-primary text-weight-medium"
                  :to="{
                    name: 'app-shop-dropship-order-detail-page',
                    params: {
                      tenantSlug: route.params.tenantSlug,
                      id: linkedOrderRemittance.id,
                    },
                  }"
                >
                  {{ linkedOrderRemittance.order_no }}
                </router-link>
                · {{ linkedOrderRemittance.status.replace(/_/g, ' ') }}
              </div>
              <q-badge
                v-else
                color="grey-3"
                text-color="grey-8"
                class="q-mt-xs"
                style="display: block; text-align: center"
              >
                No linked dropship order
              </q-badge>
            </div>
          </q-card>

          <!-- Returns Card -->
          <q-card
            v-if="showReturns && invoice.invoice_status === 'posted'"
            flat
            class="floating-surface shadow-1 q-pa-md"
          >
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Returns</div>
            <q-btn
              color="orange"
              no-caps
              outline
              class="pill-btn slim-btn full-width"
              label="Add Return"
              @click="returnDialog = true"
            />
          </q-card>
        </div>
      </div>
    </div>

    <!-- Add From Stock Dialog -->
    <q-dialog v-model="stockDialog" persistent>
      <q-card
        style="
          width: 1100px;
          max-width: 95vw;
          border-radius: 16px;
          background: var(--bw-theme-surface);
          border: 1px solid var(--bw-theme-border);
        "
        class="q-pa-sm shadow-2"
      >
        <q-card-section class="text-h6 text-weight-bold row items-center justify-between q-pb-none">
          <span>Add From Stock</span>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="q-pt-md">
          <div class="row q-col-gutter-md">
            <!-- Search Panel -->
            <div class="col-12 col-md-6 column">
              <div class="text-subtitle2 text-weight-bold q-mb-sm">Search Stock</div>
              <NetworkStockSearchPanel
                v-if="invoice && stockDialog"
                mode="invoice"
                :context-tenant-id="invoice.tenant_id"
                selectable
                :show-search-controls="true"
                @select="onSelectStockRow"
              />
            </div>

            <!-- Cart Panel -->
            <div class="col-12 col-md-6 column">
              <div class="text-subtitle2 text-weight-bold q-mb-sm row items-center justify-between">
                <span>Selected Items (Cart)</span>
                <div class="row items-center q-gutter-x-sm">
                  <q-btn
                    v-if="stockCart.length"
                    flat
                    dense
                    no-caps
                    color="negative"
                    label="Clear Cart"
                    size="sm"
                    @click="stockCart = []"
                    class="pill-btn"
                  />
                  <q-badge color="primary" class="q-px-sm q-py-xs" style="border-radius: 8px">
                    {{ stockCart.length }} item(s)
                  </q-badge>
                </div>
              </div>

              <div
                class="border rounded-borders q-pa-sm scroll"
                style="
                  height: 450px;
                  background: var(--bw-theme-surface);
                  border: 1px solid var(--bw-theme-border);
                  border-radius: 12px;
                "
              >
                <div
                  v-if="stockCart.length === 0"
                  class="column items-center justify-center text-grey-5 q-py-xl"
                  style="height: 100%"
                >
                  <q-icon name="shopping_cart" size="48px" class="q-mb-sm" />
                  <div class="text-subtitle2">Cart is empty</div>
                  <div class="text-caption text-center">
                    Click items in the search results to add them here
                  </div>
                </div>

                <q-list v-else separator>
                  <q-item
                    v-for="(item, idx) in stockCart"
                    :key="item.global_stock_id"
                    class="q-py-md q-px-sm"
                  >
                    <q-item-section avatar>
                      <q-avatar rounded size="48px" class="bg-grey-2 shadow-1">
                        <img
                          :src="item.image_url || 'https://placehold.co/48x48?text=No+Image'"
                          alt="product image"
                          style="object-fit: contain"
                        />
                      </q-avatar>
                    </q-item-section>

                    <q-item-section>
                      <q-item-label class="text-weight-bold text-subtitle2">{{
                        item.name
                      }}</q-item-label>
                      <q-item-label caption class="text-grey-7 row q-gutter-x-md flex-wrap">
                        <span v-if="item.product_code">Code: {{ item.product_code }}</span>
                        <span v-if="item.is_own_tenant" class="text-green-9 text-weight-bold"
                          >Own Stock</span
                        >
                        <span v-else-if="item.holding_tenant_name" class="text-grey-8">{{
                          item.holding_tenant_name
                        }}</span>
                        <span v-if="item.shipment_name" class="text-primary text-weight-bold">
                          Shipment: {{ item.shipment_name }}
                        </span>
                      </q-item-label>

                      <!-- Editable fields for each item -->
                      <div class="row q-col-gutter-sm q-mt-xs">
                        <div class="col-4">
                          <q-input
                            v-model.number="item.quantity"
                            type="number"
                            label="Quantity"
                            dense
                            outlined
                            min="1"
                            class="soft-input"
                          />
                        </div>
                        <div class="col-4">
                          <q-input
                            v-model.number="item.sell_price_amount"
                            type="number"
                            label="Sell Price"
                            dense
                            outlined
                            min="0"
                            class="soft-input"
                          />
                        </div>
                        <div class="col-4" v-if="isDropship">
                          <q-input
                            v-model.number="item.recipient_price_amount"
                            type="number"
                            label="Recipient"
                            dense
                            outlined
                            min="0"
                            class="soft-input"
                          />
                        </div>
                      </div>
                    </q-item-section>

                    <q-item-section side>
                      <q-btn
                        flat
                        round
                        dense
                        color="negative"
                        icon="delete"
                        size="sm"
                        @click="stockCart.splice(idx, 1)"
                      >
                        <q-tooltip>Remove</q-tooltip>
                      </q-btn>
                    </q-item-section>
                  </q-item>
                </q-list>
              </div>
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            :label="
              stockCart.length
                ? `Add ${stockCart.length} Item${stockCart.length === 1 ? '' : 's'}`
                : 'Add'
            "
            :loading="addingItem"
            :disable="stockCart.length === 0"
            @click="onAddCartItems"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Record Payment Dialog -->
    <q-dialog v-model="paymentDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Record Payment</q-card-section>
        <q-card-section class="q-gutter-md">
          <q-input
            v-model.number="paymentAmount"
            type="number"
            label="Amount"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-input
            v-model="paymentDate"
            label="Payment Date"
            outlined
            dense
            readonly
            class="soft-input"
          >
            <template #append>
              <q-icon name="event" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="paymentDate" mask="YYYY-MM-DD" />
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
          <q-select
            v-model="paymentMethod"
            :options="paymentMethodOptions"
            label="Method"
            outlined
            dense
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            label="Save"
            :loading="paymentSaving"
            @click="onRecordPayment"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Record COD Dialog -->
    <q-dialog v-model="codDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Record COD Collection</q-card-section>
        <q-card-section class="q-gutter-md">
          <q-input
            v-model.number="codAmount"
            type="number"
            label="Amount collected"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-input
            v-model="codDate"
            label="Collection Date"
            outlined
            dense
            readonly
            class="soft-input"
          >
            <template #append>
              <q-icon name="event" class="cursor-pointer">
                <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="codDate" mask="YYYY-MM-DD" />
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
          <q-select
            v-model="codMethod"
            :options="paymentMethodOptions"
            label="Method"
            outlined
            dense
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            label="Save"
            :loading="paymentSaving"
            @click="onRecordCod"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Settlement / Write-off Dialog -->
    <q-dialog v-model="settleDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Settle / Write-off</q-card-section>
        <q-card-section>
          <div class="text-caption text-grey-7 q-mb-sm">
            Records a settlement discount that closes the remaining due. Outstanding:
            {{ formatAmount(invoice?.due_amount ?? 0) }}
          </div>
          <q-input
            v-model.number="settleAmount"
            type="number"
            label="Discount amount"
            outlined
            dense
            min="0"
            :max="invoice?.due_amount ?? 0"
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="orange"
            label="Apply"
            :loading="paymentSaving"
            @click="onApplySettlement"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Pay Middle Man Dialog -->
    <q-dialog v-model="payoutDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 360px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Pay Middle Man</q-card-section>
        <q-card-section>
          <q-input
            v-model.number="payoutAmount"
            type="number"
            label="Payout amount"
            outlined
            dense
            min="0"
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            label="Save"
            :loading="paymentSaving"
            @click="onRecordPayout"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Add Return Dialog -->
    <q-dialog v-model="returnDialog" persistent>
      <q-card class="q-pa-md" style="min-width: 400px; border-radius: 16px">
        <q-card-section class="text-h6 text-weight-bold">Add Return</q-card-section>
        <q-card-section class="q-gutter-y-sm">
          <q-select
            v-model="returnItemId"
            :options="returnItemOptions"
            label="Invoice item"
            outlined
            dense
            emit-value
            map-options
            class="soft-input"
          />
          <q-input
            v-model.number="returnQty"
            type="number"
            label="Quantity"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-input
            v-model.number="returnFaceAmount"
            type="number"
            label="Customer Refund Amount (Face)"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-input
            v-model.number="returnAccountingAmount"
            type="number"
            label="Seller Deduction Amount (Accounting)"
            outlined
            dense
            min="0"
            class="soft-input"
          />
          <q-input
            v-model.number="returnCharge"
            type="number"
            label="Return charge (optional)"
            outlined
            dense
            min="0"
            class="soft-input"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
          <q-btn
            color="primary"
            label="Save"
            :loading="returnSaving"
            @click="onAddReturn"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- View Note Dialog -->
    <q-dialog v-model="viewNoteDialog">
      <q-card
        class="q-pa-md"
        style="min-width: 500px; width: 90vw; max-width: 800px; border-radius: 16px"
      >
        <q-card-section class="text-h6 text-weight-bold">Invoice Note</q-card-section>
        <q-card-section class="invoice-note-preview invoice-note-preview--full scroll">
          <div v-html="invoice?.note || '—'"></div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Close" v-close-popup class="pill-btn" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Edit Note Dialog -->
    <q-dialog v-model="editNoteDialog" persistent>
      <q-card
        class="q-pa-md"
        style="min-width: 500px; width: 90vw; max-width: 800px; border-radius: 16px"
      >
        <q-card-section class="text-h6 text-weight-bold">Edit Invoice Note</q-card-section>
        <q-card-section>
          <RichTextEditor v-model="noteEditValue" min-height="12rem" />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup class="pill-btn" :disable="savingNote" />
          <q-btn
            color="primary"
            label="Save"
            :loading="savingNote"
            @click="saveNote"
            class="pill-btn"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch, reactive } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';

import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import RichTextEditor from 'src/components/ui/RichTextEditor.vue';
import SmartImage from 'src/components/SmartImage.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import {
  showSuccessNotification,
  showWarningDialog,
  showWarningNotification,
  requestConfirmation,
} from 'src/utils/appFeedback';

import { cleanEditorHtml } from 'src/utils/editor';
import { invoiceRepository } from '../repositories/invoiceRepository';
import type { TargetTotalSummary } from '../repositories/invoiceRepository';
import { dropshipLedgerRepository } from 'src/modules/shop_order/repositories/dropshipLedgerRepository';
import NetworkStockSearchPanel from '../components/NetworkStockSearchPanel.vue';
import InvoiceBulkPasteDialog from '../components/InvoiceBulkPasteDialog.vue';
import { invoiceGrossProfit, lineMargin } from 'src/modules/reporting_treasury/utils/margin';
import type { StockNetworkRow } from 'src/modules/global/types';
import { useInvoiceItemUnitCosts } from '../composables/useInvoiceItemUnitCosts';
import type { GlobalInvoiceDetail, GlobalInvoiceItemRow } from '../types';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

const goBack = () => {
  void router.push({
    name: 'app-global-invoices-page',
    params: { tenantSlug: route.params.tenantSlug },
  });
};

const loading = ref(true);
const error = ref<string | null>(null);
const invoice = ref<GlobalInvoiceDetail | null>(null);
const items = ref<GlobalInvoiceItemRow[]>([]);
const linkedOrderRemittance = ref<Awaited<
  ReturnType<typeof dropshipLedgerRepository.getShopOrderRemittanceByInvoiceId>
>>(null);
const { resolveItemUnitCosts, getItemUnitCost } = useInvoiceItemUnitCosts();

const noteEditValue = ref('');
const editNoteDialog = ref(false);
const viewNoteDialog = ref(false);
const savingNote = ref(false);
const notePreviewRef = ref<HTMLElement | null>(null);
const noteOverflows = ref(false);

const checkNoteOverflow = () => {
  const el = notePreviewRef.value;
  noteOverflows.value = el ? el.scrollHeight > el.clientHeight + 1 : false;
};

watch(
  () => invoice.value?.note,
  async () => {
    await nextTick();
    checkNoteOverflow();
  },
);

const stockDialog = ref(false);
const addingItem = ref(false);

interface StockCartItem {
  global_stock_id: number;
  product_id: number | null;
  name: string;
  barcode: string | null;
  product_code: string | null;
  image_url: string | null;
  unitCost: number;
  holding_tenant_name: string | null;
  is_own_tenant: boolean;
  shipment_name: string | null;
  quantity: number;
  sell_price_amount: number;
  recipient_price_amount: number;
}
const stockCart = ref<StockCartItem[]>([]);

const paymentDialog = ref(false);
const codDialog = ref(false);
const settleDialog = ref(false);
const payoutDialog = ref(false);
const paymentAmount = ref(0);
const codAmount = ref(0);
const settleAmount = ref(0);
const payoutAmount = ref(0);
const paymentSaving = ref(false);

const localToday = (): string => {
  const d = new Date();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
};
const paymentMethodOptions = ['cash', 'bkash', 'bank_transfer', 'nagad'];
const paymentDate = ref(localToday());
const paymentMethod = ref('cash');
const codDate = ref(localToday());
const codMethod = ref('cash');

const openPaymentDialog = () => {
  paymentAmount.value = 0;
  paymentDate.value = localToday();
  paymentMethod.value = 'cash';
  paymentDialog.value = true;
};
const openCodDialog = () => {
  codAmount.value = 0;
  codDate.value = localToday();
  codMethod.value = 'cash';
  codDialog.value = true;
};

const returnDialog = ref(false);
const returnItemId = ref<number | null>(null);
const returnQty = ref(1);
const returnFaceAmount = ref(0);
const returnAccountingAmount = ref(0);
const returnCharge = ref(0);
const returnSaving = ref(false);

const postingInvoice = ref(false);
const voidingInvoice = ref(false);
const unpostingInvoice = ref(false);
const deletingInvoice = ref(false);
const convertingInvoice = ref(false);

const targetTotal = ref<number | null>(null);
const targetPreview = ref<TargetTotalSummary | null>(null);
const targetError = ref<string | null>(null);
const targetPreviewing = ref(false);
const applyingTarget = ref(false);
let targetDebounce: ReturnType<typeof setTimeout> | null = null;

const showPreview = true;
const showPayments = true;
const showReturns = true;
const showSidebar = ref(true);
const editingRecipient = ref(false);

// Reactive form representing currently saved values on header
const form = reactive({
  discount_amount: 0,
  shipping_charge: 0,
  cod_charge: 0,
  wrapping_charge: 0,
  print_charge: 0,
  recipient_name: '',
  recipient_phone: '',
  recipient_address: '',
  note: '',
  invoice_no: '',
  invoice_date: '',
});

const invoiceId = computed(() => Number(route.params.id));

const isDropship = computed(() => invoice.value?.invoice_type === 'dropship');

const loadLinkedOrderRemittance = async (inv: GlobalInvoiceDetail | null) => {
  if (!inv || inv.invoice_type !== 'dropship') {
    linkedOrderRemittance.value = null;
    return;
  }
  try {
    linkedOrderRemittance.value =
      await dropshipLedgerRepository.getShopOrderRemittanceByInvoiceId(inv.id);
  } catch {
    linkedOrderRemittance.value = null;
  }
};
const isWholesale = computed(() => invoice.value?.invoice_type === 'wholesale');
const showCharges = computed(() => !isWholesale.value);

const returnItemOptions = computed(() =>
  items.value.map((row) => ({ label: row.name_snapshot, value: row.id })),
);

const formatAmount = (value: number) => formatAmountBdt(value);

const formatItemUnitCost = (row: GlobalInvoiceItemRow) => {
  const unitCost = getItemUnitCost(row);
  return unitCost == null ? '—' : formatAmount(unitCost);
};

const lineMarginForRow = (row: GlobalInvoiceItemRow) =>
  lineMargin({
    sell_price_amount: row.sell_price_amount,
    unit_cost_price: getItemUnitCost(row) ?? 0,
    quantity: row.quantity,
    line_discount_amount: row.line_discount_amount,
  });

const totalCost = computed(() => {
  return items.value.reduce((sum, row) => sum + (getItemUnitCost(row) ?? 0) * row.quantity, 0);
});
const totalQuantity = computed(() => {
  return items.value.reduce((sum, row) => sum + row.quantity, 0);
});
const estimatedProfit = computed(() => {
  if (!invoice.value) return 0;
  return invoiceGrossProfit(
    {
      invoice_type: invoice.value.invoice_type as 'wholesale' | 'retail' | 'dropship',
      shipping_charge: invoice.value.shipping_charge,
      cod_charge: invoice.value.cod_charge,
      print_charge: invoice.value.print_charge,
      wrapping_charge: invoice.value.wrapping_charge,
      discount_amount: invoice.value.discount_amount,
      settlement_discount_amount: invoice.value.settlement_discount_amount,
      invoice_status: 'posted', // force posted to calculate profit
    },
    items.value.map((row) => ({
      ...row,
      id: row.id,
      unit_cost_price: getItemUnitCost(row) ?? 0,
    })),
  );
});

const averageProfitRate = computed(() => {
  const cost = totalCost.value;
  if (cost <= 0) return '-';
  const profit = estimatedProfit.value;
  const rate = (profit / cost) * 100;
  return `${rate.toFixed(2)}%`;
});

const loadInvoice = async () => {
  loading.value = true;
  error.value = null;
  try {
    const [inv, invItems] = await Promise.all([
      invoiceRepository.getGlobalInvoiceById(invoiceId.value),
      invoiceRepository.listGlobalInvoiceItems(invoiceId.value),
    ]);
    invoice.value = inv;
    items.value = invItems;
    await resolveItemUnitCosts(invItems);
    await loadLinkedOrderRemittance(inv);

    // Sync form values
    form.discount_amount = inv.discount_amount;
    form.shipping_charge = inv.shipping_charge;
    form.cod_charge = inv.cod_charge;
    form.wrapping_charge = inv.wrapping_charge;
    form.print_charge = inv.print_charge;
    form.recipient_name = inv.recipient_name || '';
    form.recipient_phone = inv.recipient_phone || '';
    form.recipient_address = inv.recipient_address || '';
    form.note = inv.note || '';
    form.invoice_no = inv.invoice_no || '';
    form.invoice_date = inv.invoice_date || '';
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load invoice.';
  } finally {
    loading.value = false;
  }
};

const refreshInvoiceHeader = async () => {
  try {
    const inv = await invoiceRepository.getGlobalInvoiceById(invoiceId.value);
    invoice.value = inv;
    await loadLinkedOrderRemittance(inv);

    // Sync form values
    form.discount_amount = inv.discount_amount;
    form.shipping_charge = inv.shipping_charge;
    form.cod_charge = inv.cod_charge;
    form.wrapping_charge = inv.wrapping_charge;
    form.print_charge = inv.print_charge;
    form.recipient_name = inv.recipient_name || '';
    form.recipient_phone = inv.recipient_phone || '';
    form.recipient_address = inv.recipient_address || '';
    form.note = inv.note || '';
    form.invoice_no = inv.invoice_no || '';
    form.invoice_date = inv.invoice_date || '';
  } catch (e) {
    console.error('Failed to refresh invoice header', e);
  }
};

const onSelectStockRow = (row: StockNetworkRow) => {
  const unitCost = row.resolvedUnitCost ?? 0;
  const existingIdx = stockCart.value.findIndex(
    (item) => item.global_stock_id === row.global_stock_id,
  );
  if (existingIdx > -1) {
    const existing = stockCart.value[existingIdx];
    if (existing) {
      existing.quantity++;
      stockCart.value.splice(existingIdx, 1);
      stockCart.value.unshift(existing);
    }
  } else {
    stockCart.value.unshift({
      global_stock_id: row.global_stock_id,
      product_id: row.product_id,
      name: row.name,
      barcode: row.barcode,
      product_code: row.product_code,
      image_url: row.image_url,
      unitCost,
      holding_tenant_name: row.holding_tenant_name ?? null,
      is_own_tenant: row.is_own_tenant,
      shipment_name: row.shipment_name ?? null,
      quantity: 1,
      sell_price_amount: unitCost,
      recipient_price_amount: unitCost,
    });
  }
};

const onAddCartItems = async () => {
  if (!invoice.value || stockCart.value.length === 0) return;
  addingItem.value = true;
  try {
    // Process items in opposite order of the stack display (oldest first)
    // to avoid Postgres lock contention and preserve chronological list order
    const itemsToInsert = [...stockCart.value].reverse();
    for (const item of itemsToInsert) {
      const payload = {
        invoice_id: invoice.value.id,
        global_stock_id: item.global_stock_id,
        quantity: item.quantity,
        sell_price_amount: item.sell_price_amount,
      };
      if (isDropship.value) {
        await invoiceRepository.addGlobalInvoiceItem({
          ...payload,
          recipient_price_amount: item.recipient_price_amount,
        });
      } else {
        await invoiceRepository.addGlobalInvoiceItem(payload);
      }
    }
    stockDialog.value = false;
    stockCart.value = [];
    await loadInvoice();
    showSuccessNotification('Items added to invoice successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to add items.');
  } finally {
    addingItem.value = false;
  }
};

const onRemoveItem = async (itemId: number) => {
  if (!invoice.value) return;
  try {
    await invoiceRepository.removeGlobalInvoiceItem(itemId);
    items.value = items.value.filter((item) => item.id !== itemId);
    await refreshInvoiceHeader();
    showSuccessNotification('Item removed successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to remove item.');
  }
};

const onUpdateItemField = async (
  row: GlobalInvoiceItemRow,
  field: 'quantity' | 'sell_price_amount' | 'recipient_price_amount',
  value: any,
) => {
  if (!invoice.value) return;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    showWarningNotification('Value must be 0 or greater.');
    return;
  }
  if (field === 'quantity' && parsed <= 0) {
    showWarningNotification('Quantity must be greater than 0.');
    return;
  }

  const quantity = field === 'quantity' ? parsed : row.quantity;
  const sellPrice = field === 'sell_price_amount' ? parsed : row.sell_price_amount;
  const recipientPrice =
    field === 'recipient_price_amount'
      ? parsed
      : (row.recipient_price_amount ?? row.sell_price_amount);

  try {
    await invoiceRepository.updateGlobalInvoiceItem({
      id: row.id,
      quantity,
      sell_price_amount: sellPrice,
      recipient_price_amount: recipientPrice,
    });
    const itemIdx = items.value.findIndex((item) => item.id === row.id);
    const existing = itemIdx > -1 ? items.value[itemIdx] : null;
    if (existing) {
      existing.quantity = quantity;
      existing.sell_price_amount = sellPrice;
      existing.recipient_price_amount = recipientPrice;
    }
    await refreshInvoiceHeader();
    showSuccessNotification('Item updated successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to update item.');
  }
};

const openBulkPaste = () => {
  $q.dialog({
    component: InvoiceBulkPasteDialog,
    componentProps: { items: items.value, isDropship: isDropship.value },
  }).onOk(() => {
    void (async () => {
      items.value = await invoiceRepository.listGlobalInvoiceItems(invoiceId.value);
      await resolveItemUnitCosts(items.value);
      await refreshInvoiceHeader();
      showSuccessNotification('Bulk update applied.');
    })();
  });
};

const onTargetTotalInput = () => {
  if (targetDebounce) clearTimeout(targetDebounce);
  targetError.value = null;
  const value = targetTotal.value;
  if (!invoice.value || value === null || !Number.isFinite(value) || value < 0) {
    targetPreview.value = null;
    targetPreviewing.value = false;
    return;
  }
  targetPreviewing.value = true;
  targetDebounce = setTimeout(() => {
    void (async () => {
      try {
        targetPreview.value = await invoiceRepository.applyGlobalInvoiceTargetTotal({
          id: invoice.value!.id,
          target_total: value,
          dry_run: true,
        });
        targetError.value = null;
      } catch (e) {
        targetPreview.value = null;
        targetError.value = e instanceof Error ? e.message : 'Cannot preview adjustment.';
      } finally {
        targetPreviewing.value = false;
      }
    })();
  }, 400);
};

const onApplyTargetTotal = async () => {
  if (!invoice.value || targetTotal.value === null) return;
  applyingTarget.value = true;
  try {
    await invoiceRepository.applyGlobalInvoiceTargetTotal({
      id: invoice.value.id,
      target_total: targetTotal.value,
      dry_run: false,
    });
    targetTotal.value = null;
    targetPreview.value = null;
    targetError.value = null;
    await loadInvoice();
    showSuccessNotification('Invoice adjusted to target total.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to adjust invoice total.');
  } finally {
    applyingTarget.value = false;
  }
};

const getMonthYear = (dateStr: string) => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleString('en-GB', { month: 'short', year: 'numeric' });
};

const onDateChange = async (val: string) => {
  if (!invoice.value) return;

  const monthYear = getMonthYear(val);
  const isWholesale = invoice.value.invoice_type === 'wholesale';
  const isDropship = invoice.value.invoice_type === 'dropship';
  const isRetail = invoice.value.invoice_type === 'retail';
  const isRetailDirect = isRetail && !invoice.value.billing_profile_id;

  let expectedProfileName = '';
  if (isWholesale || isDropship || (isRetail && invoice.value.billing_profile_id)) {
    expectedProfileName = invoice.value.billing_profiles?.name || '';
  } else if (isRetailDirect) {
    expectedProfileName = 'Retail Direct';
  }

  const currentNo = form.invoice_no.trim();
  if (!currentNo || currentNo.startsWith('Invoice - ')) {
    const newName = expectedProfileName
      ? `Invoice - ${expectedProfileName} - ${monthYear}`
      : `Invoice - ${monthYear}`;
    form.invoice_no = newName;
  }

  await onHeaderUpdate();
};

const onHeaderUpdate = async () => {
  if (!invoice.value) return;
  try {
    await invoiceRepository.updateGlobalInvoiceHeader({
      id: invoice.value.id,
      discount_amount: form.discount_amount,
      shipping_charge: form.shipping_charge,
      cod_charge: form.cod_charge,
      wrapping_charge: form.wrapping_charge,
      print_charge: form.print_charge,
      recipient_name: form.recipient_name.trim() || null,
      recipient_phone: form.recipient_phone.trim() || null,
      recipient_address: form.recipient_address.trim() || null,
      note: cleanEditorHtml(form.note || ''),
      invoice_no: form.invoice_no.trim() || null,
      invoice_date: form.invoice_date || null,
    });
    await refreshInvoiceHeader();
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to update invoice details.');
  }
};

const openEditNoteDialog = () => {
  noteEditValue.value = invoice.value?.note || '';
  editNoteDialog.value = true;
};

const saveNote = async () => {
  if (!invoice.value) return;
  savingNote.value = true;
  try {
    await invoiceRepository.updateGlobalInvoiceHeader({
      id: invoice.value.id,
      discount_amount: form.discount_amount,
      shipping_charge: form.shipping_charge,
      cod_charge: form.cod_charge,
      wrapping_charge: form.wrapping_charge,
      print_charge: form.print_charge,
      recipient_name: form.recipient_name.trim() || null,
      recipient_phone: form.recipient_phone.trim() || null,
      recipient_address: form.recipient_address.trim() || null,
      note: cleanEditorHtml(noteEditValue.value),
      invoice_no: form.invoice_no.trim() || null,
      invoice_date: form.invoice_date || null,
    });
    await refreshInvoiceHeader();
    editNoteDialog.value = false;
    showSuccessNotification('Invoice note updated successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to update invoice note.');
  } finally {
    savingNote.value = false;
  }
};

const onPostInvoice = async () => {
  if (!invoice.value) return;
  postingInvoice.value = true;
  try {
    await invoiceRepository.postGlobalInvoice(invoice.value.id);
    await loadInvoice();
    showSuccessNotification('Invoice posted successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to post invoice.');
  } finally {
    postingInvoice.value = false;
  }
};

const onVoidInvoice = async () => {
  if (!invoice.value) return;
  voidingInvoice.value = true;
  try {
    await invoiceRepository.voidGlobalInvoice(invoice.value.id);
    await loadInvoice();
    showSuccessNotification('Invoice voided successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to void invoice.');
  } finally {
    voidingInvoice.value = false;
  }
};

const onUnpostInvoice = async () => {
  if (!invoice.value) return;
  unpostingInvoice.value = true;
  try {
    await invoiceRepository.unpostGlobalInvoice(invoice.value.id);
    await loadInvoice();
    showSuccessNotification('Invoice unposted (reverted to draft) successfully.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to unpost invoice.');
  } finally {
    unpostingInvoice.value = false;
  }
};

const canUnpostOrVoid = computed(() => {
  if (!invoice.value) return false;
  if (invoice.value.paid_amount > 0) return false;
  const hasReturns = items.value.some((item) => item.return_quantity > 0);
  return !hasReturns;
});

const isTransitionDisabled = (targetStatus: string) => {
  if (!invoice.value) return true;
  const current = invoice.value.invoice_status;
  if (current === targetStatus) return true;

  if (current === 'draft') {
    return targetStatus !== 'posted';
  }
  if (current === 'posted') {
    if (targetStatus === 'draft' || targetStatus === 'voided') {
      return !canUnpostOrVoid.value;
    }
    return true;
  }
  if (current === 'voided') {
    return true;
  }
  return true;
};

const changeInvoiceStatus = (newStatus: string) => {
  if (!invoice.value) return;
  const current = invoice.value.invoice_status;
  if (current === newStatus) return;

  if (newStatus === 'posted') {
    $q.dialog({
      title: 'Post Invoice',
      message:
        'Are you sure you want to post this invoice? This will lock the invoice and deduct the items from stock.',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void onPostInvoice();
    });
  } else if (newStatus === 'draft') {
    $q.dialog({
      title: 'Undo Post / Unpost Invoice',
      message:
        'Are you sure you want to unpost this invoice and revert it to draft? This will restore the stock quantities.',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void onUnpostInvoice();
    });
  } else if (newStatus === 'voided') {
    $q.dialog({
      title: 'Void Invoice',
      message:
        'Are you sure you want to void this invoice? This action will cancel the invoice and restore the stock quantities. It cannot be undone.',
      cancel: true,
      persistent: true,
    }).onOk(() => {
      void onVoidInvoice();
    });
  }
};

const onDeleteInvoice = async () => {
  if (!invoice.value) return;
  const confirmed = await requestConfirmation(
    'Are you sure you want to delete this draft invoice? This action cannot be undone.',
    'Delete Invoice Draft',
    'Delete',
  );
  if (!confirmed) return;
  deletingInvoice.value = true;
  try {
    await invoiceRepository.deleteGlobalInvoice(invoice.value.id);
    showSuccessNotification('Draft invoice deleted successfully.');
    void router.push({
      name: 'app-global-invoices-page',
      params: { tenantSlug: authStore.tenantSlug },
    });
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to delete invoice.');
  } finally {
    deletingInvoice.value = false;
  }
};

const onConvertWholesaleToRetail = async () => {
  if (!invoice.value) return;
  const confirmed = await requestConfirmation(
    'Are you sure you want to convert this wholesale draft invoice to retail account mode? This action cannot be undone.',
    'Convert Invoice to Retail',
    'Convert',
  );
  if (!confirmed) return;
  convertingInvoice.value = true;
  try {
    await invoiceRepository.convertWholesaleDraftToRetail(invoice.value.id);
    showSuccessNotification('Wholesale invoice converted to Retail successfully.');
    await loadInvoice();
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Failed to convert invoice.');
  } finally {
    convertingInvoice.value = false;
  }
};

const openPreview = () => {
  void router.push({
    name: 'app-global-invoice-preview',
    params: { tenantSlug: authStore.tenantSlug, id: invoiceId.value },
  });
};

const onRecordPayment = async () => {
  if (!invoice.value?.billing_profile_id) return;
  paymentSaving.value = true;
  try {
    await invoiceRepository.recordBillingProfilePayment({
      tenant_id: invoice.value.tenant_id,
      billing_profile_id: invoice.value.billing_profile_id,
      amount: paymentAmount.value,
      payment_date: paymentDate.value,
      method: paymentMethod.value,
      allocations: [{ global_invoice_id: invoice.value.id, amount: paymentAmount.value }],
    });
    paymentDialog.value = false;
    await refreshInvoiceHeader();
    showSuccessNotification('Payment recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Payment failed.');
  } finally {
    paymentSaving.value = false;
  }
};

const onRecordCod = async () => {
  if (!invoice.value) return;
  paymentSaving.value = true;
  try {
    await invoiceRepository.recordRecipientInvoiceCollection(invoice.value.id, codAmount.value, {
      payment_date: codDate.value,
      method: codMethod.value,
    });
    codDialog.value = false;
    await refreshInvoiceHeader();
    showSuccessNotification('COD recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'COD recording failed.');
  } finally {
    paymentSaving.value = false;
  }
};

const openSettleDialog = () => {
  settleAmount.value = invoice.value?.due_amount ?? 0;
  settleDialog.value = true;
};

const onApplySettlement = async () => {
  if (!invoice.value) return;
  paymentSaving.value = true;
  try {
    await invoiceRepository.applySettlementDiscount(invoice.value.id, settleAmount.value);
    settleDialog.value = false;
    await refreshInvoiceHeader();
    showSuccessNotification('Settlement discount applied.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Settlement failed.');
  } finally {
    paymentSaving.value = false;
  }
};

const onRecordPayout = async () => {
  if (!invoice.value?.billing_profile_id) return;
  paymentSaving.value = true;
  try {
    await invoiceRepository.createMiddleManPayout({
      tenant_id: invoice.value.tenant_id,
      billing_profile_id: invoice.value.billing_profile_id,
      global_invoice_id: invoice.value.id,
      amount: payoutAmount.value,
    });
    payoutDialog.value = false;
    await refreshInvoiceHeader();
    showSuccessNotification('Payout recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Payout failed.');
  } finally {
    paymentSaving.value = false;
  }
};

const onAddReturn = async () => {
  if (!invoice.value || !returnItemId.value) return;
  returnSaving.value = true;
  try {
    await invoiceRepository.addGlobalReturnItem({
      invoice_id: invoice.value.id,
      invoice_item_id: returnItemId.value,
      quantity: returnQty.value,
      return_face_amount: returnFaceAmount.value,
      return_accounting_amount: returnAccountingAmount.value,
      return_charge_amount: returnCharge.value || 0,
    });
    returnDialog.value = false;
    await loadInvoice();
    showSuccessNotification('Return recorded.');
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Return failed.');
  } finally {
    returnSaving.value = false;
  }
};

watch(stockDialog, (open) => {
  if (!open) {
    stockCart.value = [];
  }
});

watch([returnItemId, returnQty], () => {
  if (!returnItemId.value) return;
  const item = items.value.find((i) => i.id === returnItemId.value);
  if (item) {
    const qty = Number(returnQty.value || 0);
    const sellPrice = Number(item.sell_price_amount || 0);
    const recipientPrice = Number(item.recipient_price_amount || sellPrice);

    returnAccountingAmount.value = sellPrice * qty;
    returnFaceAmount.value = recipientPrice * qty;
  }
});

onMounted(() => {
  void loadInvoice();
});
</script>

<style scoped>
.text-underline-dashed {
  text-decoration: underline dashed;
}
.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}
.status-chip {
  border-radius: 6px !important;
}
.hero-surface {
  border-radius: 16px;
}
.pill-btn {
  border-radius: 8px;
}
.slim-btn {
  min-height: 32px;
  padding-left: 14px;
  padding-right: 14px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
.transition-width {
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}
.invoice-item-image-box {
  width: 48px;
  height: 48px;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f8f9fa;
}
.global-invoice-details-page :deep(.invoice-item-image),
.global-invoice-details-page :deep(.invoice-item-image-fallback) {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.invoice-items-table {
  background: transparent;
}
.invoice-item-row:hover {
  background: rgba(37, 99, 235, 0.03);
}
.invoice-note-preview--clamped {
  max-height: 120px;
  overflow: hidden;
  position: relative;
}
.invoice-note-preview--overflow::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 36px;
  background: linear-gradient(transparent, var(--bw-theme-surface, #fff));
  pointer-events: none;
}
.invoice-note-preview--full {
  max-height: 70vh;
  overflow-y: auto;
}
.invoice-note-preview :deep(p) {
  margin: 0 0 8px 0;
}
.invoice-note-preview :deep(p:last-child) {
  margin-bottom: 0;
}
.invoice-note-preview :deep(ul),
.invoice-note-preview :deep(ol) {
  margin: 0 0 8px 0;
  padding-left: 20px;
}
.invoice-note-preview :deep(table) {
  width: 100%;
  border-collapse: collapse;
  margin: 12px 0;
}
.invoice-note-preview :deep(th),
.invoice-note-preview :deep(td) {
  border: 1px solid rgba(0, 0, 0, 0.12);
  padding: 8px 12px;
  text-align: left;
}
.invoice-note-preview :deep(th) {
  background-color: rgba(0, 0, 0, 0.04);
  font-weight: bold;
}

/* Redesigned UI styling rules */
.stepper-container {
  border-radius: 12px;
  border: 1px solid var(--bw-theme-border, #e2e8f0);
}
.stepper-track-wrapper {
  width: 100%;
  max-width: 600px;
  margin: 0 auto;
}
.stepper-track-line {
  position: absolute;
  top: 24px;
  left: 40px;
  right: 40px;
  height: 2px;
  background-color: var(--bw-theme-border, #e2e8f0);
  z-index: 0;
}
.stepper-track-progress {
  position: absolute;
  top: 24px;
  left: 40px;
  height: 2px;
  background-color: var(--bw-theme-primary, #0252df);
  z-index: 1;
  transition: width 0.3s ease;
}
.stepper-step {
  z-index: 2;
  position: relative;
  width: 80px;
}
.stepper-circle {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px solid var(--bw-theme-border, #e2e8f0);
  transition: all 0.3s ease;
  background-color: white;
}
.stepper-circle--done {
  background-color: var(--bw-theme-primary, #0252df);
  border-color: var(--bw-theme-primary, #0252df);
  color: white;
}
.stepper-circle--active {
  background-color: white;
  border-color: var(--bw-theme-primary, #0252df);
  color: var(--bw-theme-primary, #0252df);
  box-shadow: 0 0 0 4px rgba(2, 82, 223, 0.15);
}
.stepper-circle--pending {
  background-color: white;
  border-color: var(--bw-theme-border, #cbd5e1);
  color: var(--bw-theme-muted, #94a3b8);
}
.stepper-circle--voided {
  background-color: var(--q-negative, #ea3838);
  border-color: var(--q-negative, #ea3838);
  color: white;
}
.stepper-text {
  font-size: 13px;
  transition: color 0.3s ease;
}
.hero-stats-card {
  border-radius: 16px;
  background: linear-gradient(135deg, #0252df 0%, #003db3 100%);
  box-shadow: var(--bw-theme-shadow);
}
.font-size-11 {
  font-size: 11px;
}
.font-size-12 {
  font-size: 12px;
}
@media (max-width: 599px) {
  .mt-mobile {
    margin-top: 16px;
  }
}
@media (min-width: 1024px) {
  .invoice-details-page-container {
    height: calc(100vh - 210px);
    overflow: hidden;
  }
  .scroll-col {
    height: 100%;
    overflow-y: auto;
    padding-bottom: 24px;
  }
  .scroll-col::-webkit-scrollbar {
    width: 6px;
  }
  .scroll-col::-webkit-scrollbar-track {
    background: transparent;
  }
  .scroll-col::-webkit-scrollbar-thumb {
    background: rgba(0, 0, 0, 0.08);
    border-radius: 4px;
  }
  .scroll-col::-webkit-scrollbar-thumb:hover {
    background: rgba(0, 0, 0, 0.16);
  }
}
</style>
