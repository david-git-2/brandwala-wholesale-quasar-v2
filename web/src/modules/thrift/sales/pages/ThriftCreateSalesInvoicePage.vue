<template>
  <q-page class="q-pa-md thrift-create-invoice-page">
    <div class="q-gutter-y-md">
      <!-- Header Section -->
      <section class="row items-start items-sm-center justify-between q-col-gutter-sm q-col-gutter-md-md">
        <div class="col-12 col-sm">
          <div class="row items-center q-gutter-x-sm no-wrap">
            <q-btn
              flat
              dense
              icon="ph ph-arrow-left"
              color="grey-7"
              :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/sales`"
              aria-label="Back to Sales"
            >
              <q-tooltip>Back to Sales</q-tooltip>
            </q-btn>
            <div class="min-w-0">
              <div class="text-overline text-primary">Thrift / Sales</div>
              <h1 class="text-h6 text-sm-h5 text-weight-bold q-my-none ellipsis">New sale</h1>
            </div>
          </div>
        </div>

        <div class="col-12 col-sm-auto row q-gutter-sm items-center justify-end">
          <LearnMoreHelpBtn guide-id="thrift_sales" class="gt-xs" />
          <q-btn
            v-if="isOnline && thriftCreateInvoiceDraftHasContent({ form: invoiceForm, items: selectedItems })"
            flat
            dense
            no-caps
            color="grey-7"
            icon="ph ph-trash"
            label="Clear draft"
            class="col-grow col-sm-auto"
            @click="discardDraft"
          />
          <q-btn
            outline
            color="grey-8"
            no-caps
            label="Cancel"
            dense
            class="col-grow col-sm-auto"
            :to="`/${authStore.tenantSlug || 'tenant'}/app/thrift/sales`"
          />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-check"
            label="Generate"
            dense
            class="col-grow col-sm-auto"
            :loading="saving"
            :disable="generateDisabled"
            @click="onSaveInvoice"
          />
        </div>
      </section>

      <q-banner
        v-if="pendingDraft"
        dense
        rounded
        class="bg-blue-1 text-grey-9"
      >
        <template #avatar>
          <q-icon name="ph ph-floppy-disk" color="primary" />
        </template>
        Unsaved Online draft found
        <span v-if="pendingDraft.updatedAt" class="text-caption text-grey-7">
          · {{ formatDraftSavedAt(pendingDraft.updatedAt) }}
        </span>
        <span v-if="pendingDraft.form.customerPhone" class="text-caption">
          · {{ pendingDraft.form.customerPhone }}
        </span>
        <template #action>
          <q-btn flat no-caps color="primary" label="Resume" @click="resumeDraft" />
          <q-btn flat no-caps color="grey-8" label="Discard" @click="discardPendingDraft" />
        </template>
      </q-banner>

      <q-card v-if="isOnline" flat bordered class="q-pa-sm">
        <div class="row items-center q-gutter-xs status-workflow-row">
          <template v-for="(st, idx) in onlineSteps" :key="st.value">
            <q-btn
              :color="onlineStep === st.value ? 'primary' : onlineStep > st.value ? 'grey-5' : 'grey-3'"
              :text-color="onlineStep === st.value ? 'white' : onlineStep > st.value ? 'grey-9' : 'grey-7'"
              :outline="onlineStep !== st.value"
              :unelevated="onlineStep === st.value"
              dense
              no-caps
              class="q-px-md text-caption text-weight-bold"
              @click="goOnlineStep(st.value)"
            >
              <q-icon
                v-if="onlineStep === st.value"
                name="ph ph-check-circle"
                size="14px"
                class="q-mr-xs"
              />
              {{ st.label }}
            </q-btn>
            <q-icon
              v-if="idx < onlineSteps.length - 1"
              name="ph ph-caret-right"
              color="grey-5"
              size="18px"
              class="status-workflow-chevron"
            />
          </template>
          <div class="col-grow" />
          <div class="text-caption text-grey-6">
            {{ draftSavedHint }}
          </div>
        </div>
      </q-card>

      <!-- Main 2-Column Content Grid -->
      <div class="row q-col-gutter-md">
        <!-- Left: Items → Channel → Customer → Online courier -->
        <div class="col-12 col-lg-8 q-gutter-y-md">
          <!-- Channel always visible -->
          <q-card flat bordered class="rounded-borders">
            <q-card-section class="q-pb-none">
              <div class="text-subtitle1 text-weight-bold row items-center">
                <q-icon name="ph ph-storefront" class="q-mr-xs text-primary" size="20px" />
                Channel
              </div>
            </q-card-section>
            <q-card-section>
              <q-btn-toggle
                v-model="invoiceForm.saleChannel"
                toggle-color="primary"
                unelevated
                dense
                no-caps
                class="full-width"
                :options="saleChannelOptions"
              />
            </q-card-section>
          </q-card>

          <!-- 1. Search & Add -->
          <q-card
            v-show="!isOnline || onlineStep === 0"
            flat
            bordered
            class="rounded-borders search-card"
          >
            <q-card-section class="q-pb-none">
              <div class="text-subtitle1 text-weight-bold row items-center justify-between">
                <span class="row items-center">
                  <q-icon name="ph ph-barcode" class="q-mr-xs text-primary" size="20px" />
                  Search & Add Thrift Items
                </span>
                <span class="text-caption text-grey-6">
                  Press Enter key or click Search button
                </span>
              </div>
            </q-card-section>
            <q-card-section class="q-gutter-y-sm">
              <div class="row q-col-gutter-sm items-center">
                <div class="col">
                  <q-input
                    v-model="searchQuery"
                    outlined
                    dense
                    placeholder="Scan barcode or type item name and press Enter..."
                    :loading="loadingStock"
                    @keyup.enter="triggerStockSearch"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-barcode" color="primary" />
                    </template>
                  </q-input>
                </div>
                <div class="col-auto">
                  <q-btn
                    color="primary"
                    unelevated
                    no-caps
                    icon="ph ph-magnifying-glass"
                    label="Search"
                    :loading="loadingStock"
                    @click="triggerStockSearch"
                  />
                </div>
              </div>

              <div v-if="hasSearched" class="q-mt-sm">
                <div v-if="searchResults.length === 0" class="q-pa-md text-center bg-grey-1 rounded-borders text-grey-7">
                  <q-icon name="ph ph-magnifying-glass" size="24px" color="grey-5" class="q-mr-xs" />
                  No available stock items match "{{ lastSearchQuery }}"
                </div>
                <q-card v-else flat bordered class="rounded-borders overflow-hidden bg-white shadow-1">
                  <div class="q-pa-xs bg-blue-1 text-primary text-caption text-weight-bold row items-center justify-between q-px-sm">
                    <span>Search Results for "{{ lastSearchQuery }}" ({{ searchResults.length }})</span>
                    <q-btn flat round dense icon="ph ph-x" size="xs" color="grey-7" @click="clearSearchResults" />
                  </div>
                  <q-list separator class="bg-white">
                    <q-item v-for="item in searchResults" :key="item.id" class="q-py-sm">
                      <q-item-section avatar>
                        <q-avatar square size="36px" class="rounded-borders overflow-hidden bg-grey-2">
                          <img v-if="item.imageUrl" :src="item.imageUrl" style="object-fit: cover; width: 100%; height: 100%;" />
                          <q-icon v-else name="ph ph-tag" color="primary" size="20px" />
                        </q-avatar>
                      </q-item-section>
                      <q-item-section>
                        <q-item-label class="text-weight-bold text-dark">
                          {{ itemLabel(item) }}
                        </q-item-label>
                        <q-item-label caption class="text-mono">
                          {{ item.barcode }}
                        </q-item-label>
                        <q-item-label caption class="q-mt-2xs">
                          <span
                            v-if="item.status === 'SOLD'"
                            class="text-weight-medium text-negative"
                          >
                            Sold
                          </span>
                          <span
                            v-else-if="item.status === 'RESERVED'"
                            class="text-weight-medium text-orange-9"
                          >
                            On hold{{ item.heldForPhone ? ` · ${item.heldForPhone}` : '' }}
                          </span>
                          <span v-else class="text-weight-medium text-positive">
                            Available: {{ item.availableQuantity }}
                          </span>
                        </q-item-label>
                      </q-item-section>
                      <q-item-section side class="text-right">
                        <div class="text-subtitle1 text-weight-bold text-primary q-mb-xs">
                          ৳{{ item.defaultSellPrice.toFixed(2) }}
                        </div>
                        <q-badge
                          v-if="item.status === 'SOLD'"
                          color="negative"
                          class="q-pa-xs text-weight-bold"
                        >
                          Sold
                        </q-badge>
                        <q-btn
                          v-else-if="!isItemAtMax(item)"
                          dense
                          size="sm"
                          color="primary"
                          icon="ph ph-plus"
                          unelevated
                          no-caps
                          :label="isItemAdded(item.id) ? 'Add +1' : 'Add'"
                          @click="addItemToInvoice(item)"
                        />
                        <q-badge
                          v-else
                          color="grey-3"
                          text-color="grey-8"
                          class="q-pa-xs text-weight-bold"
                        >
                          <q-icon name="ph ph-check" size="12px" class="q-mr-xs" color="positive" />
                          Max
                        </q-badge>
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-card>
              </div>
            </q-card-section>
          </q-card>

          <!-- Line Items Table -->
          <q-card
            v-show="!isOnline || onlineStep === 0"
            flat
            bordered
            class="rounded-borders"
          >
            <q-card-section class="q-pb-none">
              <div class="row items-center justify-between q-gutter-y-sm">
                <div class="text-subtitle1 text-weight-bold row items-center">
                  <q-icon name="ph ph-list-numbers" class="q-mr-xs text-primary" size="20px" />
                  Invoice Line Items ({{ selectedItems.length }})
                </div>

                <div class="row items-center q-gutter-x-sm no-wrap">
                  <q-input
                    :model-value="saleDateLabel"
                    label="Sale date"
                    outlined
                    dense
                    readonly
                    class="thrift-sale-date-input"
                    style="min-width: 148px; max-width: 168px"
                  >
                    <template #append>
                      <q-icon name="ph ph-calendar" class="cursor-pointer">
                        <q-popup-proxy
                          cover
                          transition-show="scale"
                          transition-hide="scale"
                        >
                          <q-date
                            v-model="invoiceForm.date"
                            mask="YYYY-MM-DD"
                          >
                            <div class="row items-center justify-end">
                              <q-btn v-close-popup label="Close" color="primary" flat dense />
                            </div>
                          </q-date>
                        </q-popup-proxy>
                      </q-icon>
                    </template>
                  </q-input>

                  <div class="row items-stretch q-gutter-x-md q-px-sm thrift-header-totals">
                    <div class="column items-end justify-center">
                      <div class="text-caption text-grey-7 text-uppercase text-weight-medium">
                        Items
                      </div>
                      <div class="text-body1 text-weight-bold text-grey-9 lh-1">
                        ৳{{ totalItemsGross.toFixed(2) }}
                      </div>
                    </div>
                    <div class="column items-end justify-center">
                      <div class="text-caption text-grey-7 text-uppercase text-weight-medium">
                        Discount
                      </div>
                      <div
                        class="text-body1 text-weight-bold lh-1"
                        :class="totalDiscounts > 0 ? 'text-negative' : 'text-grey-7'"
                      >
                        {{ totalDiscounts > 0 ? '-' : '' }}৳{{ totalDiscounts.toFixed(2) }}
                      </div>
                    </div>
                    <div class="column items-end justify-center">
                      <div class="text-caption text-grey-7 text-uppercase text-weight-medium">
                        {{ totalLabel }}
                      </div>
                      <div class="text-h6 text-weight-bolder text-primary lh-1">
                        ৳{{ displayTotal.toFixed(2) }}
                      </div>
                    </div>
                  </div>

                  <q-btn
                    v-if="selectedItems.length > 0"
                    flat
                    dense
                    no-caps
                    color="negative"
                    icon="ph ph-trash"
                    label="Clear"
                    size="sm"
                    @click="onClearAll"
                  />
                </div>
              </div>
            </q-card-section>

            <q-card-section class="q-px-none">
              <div v-if="selectedItems.length === 0" class="text-center q-pa-lg q-pa-md-xl">
                <q-icon name="ph ph-shopping-bag-open" size="48px" color="grey-4" />
                <div class="text-subtitle1 text-grey-7 q-mt-sm text-weight-medium">
                  Cart is empty
                </div>
                <div class="text-caption text-grey-5 max-w-sm q-mx-auto">
                  Scan a barcode or search above to add items.
                </div>
              </div>

              <div v-else class="thrift-invoice-table-wrap">
                <q-markup-table flat class="thrift-invoice-table">
                  <thead>
                    <tr class="text-grey-7">
                      <th class="text-left">Item</th>
                      <th class="text-center" style="width: 88px">Qty</th>
                      <th class="text-right" style="min-width: 100px">Sell</th>
                      <th v-if="canApplyDiscount" class="text-right" style="min-width: 90px">Disc.</th>
                      <th class="text-right">Line</th>
                      <th class="text-center" style="width: 40px"></th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(line, idx) in selectedItems" :key="line.stockId">
                      <td class="text-left">
                        <div class="row items-center q-gutter-x-sm no-wrap">
                          <q-avatar
                            square
                            size="32px"
                            class="rounded-borders overflow-hidden bg-grey-2 gt-xs"
                          >
                            <img
                              v-if="line.imageUrl"
                              :src="line.imageUrl"
                              style="object-fit: cover; width: 100%; height: 100%;"
                            />
                            <q-icon v-else name="ph ph-tag" color="primary" size="16px" />
                          </q-avatar>
                          <div class="min-w-0">
                            <div class="text-weight-bold text-dark ellipsis">
                              {{ lineLabel(line) }}
                            </div>
                            <div class="text-caption text-mono text-grey-7 ellipsis">
                              {{ line.barcode }}
                            </div>
                          </div>
                        </div>
                      </td>

                      <td class="text-center">
                        <q-input
                          :model-value="line.quantity"
                          type="number"
                          outlined
                          dense
                          min="1"
                          :max="line.availableQuantity"
                          input-class="text-center text-weight-bold"
                          style="max-width: 72px; margin: 0 auto"
                          @update:model-value="(v) => setLineQty(line, v)"
                        />
                      </td>

                      <td class="text-right">
                        <q-input
                          v-model.number="line.sellPrice"
                          type="number"
                          outlined
                          dense
                          step="0.5"
                          min="0"
                          input-class="text-right text-weight-bold"
                        />
                      </td>

                      <td v-if="canApplyDiscount" class="text-right">
                        <q-input
                          v-model.number="line.discountAmount"
                          type="number"
                          outlined
                          dense
                          step="0.5"
                          min="0"
                          input-class="text-right"
                        />
                      </td>

                      <td class="text-right text-weight-bold text-primary">
                        ৳{{ getLineTotal(line).toFixed(2) }}
                      </td>

                      <td class="text-center">
                        <q-btn
                          flat
                          round
                          dense
                          icon="ph ph-x"
                          color="grey-6"
                          size="sm"
                          @click="removeItem(idx)"
                        />
                      </td>
                    </tr>
                  </tbody>
                </q-markup-table>
              </div>
            </q-card-section>
          </q-card>

          <!-- Customer -->
          <q-card
            v-show="!isOnline || onlineStep === 1"
            flat
            bordered
            class="rounded-borders"
          >
            <q-card-section class="q-pb-none">
              <div class="text-subtitle1 text-weight-bold row items-center">
                <q-icon name="ph ph-user" class="q-mr-xs text-primary" size="20px" />
                Customer
              </div>
            </q-card-section>
            <q-card-section>
              <div class="row q-col-gutter-md">
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="invoiceForm.customerPhone"
                    label="Phone *"
                    outlined
                    dense
                    placeholder="e.g. 01712-345678"
                    :loading="lookingUpCustomer"
                    hint="Type phone to find existing customer"
                    :error="!!validationErrors.customerPhone"
                    :error-message="validationErrors.customerPhone"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-phone" color="grey-6" size="xs" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="invoiceForm.customerSecondaryPhone"
                    label="Secondary phone"
                    outlined
                    dense
                    placeholder="Optional alternate number"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-phone-plus" color="grey-6" size="xs" />
                    </template>
                  </q-input>
                </div>
                <div class="col-12">
                  <q-input
                    v-model="invoiceForm.customerName"
                    label="Name *"
                    outlined
                    dense
                    placeholder="e.g. Walk-in / Ayesha Rahman"
                    :error="!!validationErrors.customerName"
                    :error-message="validationErrors.customerName"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-user" color="grey-6" size="xs" />
                    </template>
                  </q-input>
                </div>
                <template v-if="isOnline">
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="invoiceForm.district"
                      outlined
                      dense
                      use-input
                      input-debounce="0"
                      label="District *"
                      :options="districtOptions"
                      option-label="name"
                      option-value="name"
                      emit-value
                      map-options
                      hide-bottom-space
                      :error="!!validationErrors.district"
                      :error-message="validationErrors.district"
                      @filter="filterDistrict"
                      @update:model-value="onDistrictChange"
                    >
                      <template #no-option>
                        <q-item>
                          <q-item-section class="text-grey">No matching district</q-item-section>
                        </q-item>
                      </template>
                      <template #option="scope">
                        <q-item v-bind="scope.itemProps">
                          <q-item-section>
                            <q-item-label>{{ scope.opt.name }}</q-item-label>
                            <q-item-label v-if="scope.opt.bnName" caption>
                              {{ scope.opt.bnName }}
                            </q-item-label>
                          </q-item-section>
                        </q-item>
                      </template>
                    </q-select>
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="invoiceForm.thana"
                      outlined
                      dense
                      use-input
                      input-debounce="0"
                      label="Thana / Upazila *"
                      :options="thanaOptions"
                      option-label="name"
                      option-value="name"
                      emit-value
                      map-options
                      hide-bottom-space
                      :error="!!validationErrors.thana"
                      :error-message="validationErrors.thana"
                      @filter="filterThana"
                      @update:model-value="onThanaChange"
                    >
                      <template #no-option>
                        <q-item>
                          <q-item-section class="text-grey">No matching thana</q-item-section>
                        </q-item>
                      </template>
                      <template #option="scope">
                        <q-item v-bind="scope.itemProps">
                          <q-item-section>
                            <q-item-label>{{ scope.opt.name }}</q-item-label>
                            <q-item-label v-if="scope.opt.bnName" caption>
                              {{ scope.opt.bnName }}
                            </q-item-label>
                          </q-item-section>
                        </q-item>
                      </template>
                    </q-select>
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-select
                      v-model="invoiceForm.postCode"
                      outlined
                      dense
                      use-input
                      input-debounce="0"
                      label="Post code / Post office"
                      :options="postcodeOptions"
                      option-label="displayLabel"
                      option-value="postCode"
                      emit-value
                      map-options
                      hide-bottom-space
                      @filter="filterPostcode"
                      @new-value="createPostcode"
                    >
                      <template #no-option>
                        <q-item>
                          <q-item-section class="text-grey">
                            Type custom post code
                          </q-item-section>
                        </q-item>
                      </template>
                      <template #option="scope">
                        <q-item v-bind="scope.itemProps">
                          <q-item-section>
                            <q-item-label>
                              {{ scope.opt.postOffice }} - {{ scope.opt.postCode }}
                            </q-item-label>
                          </q-item-section>
                        </q-item>
                      </template>
                    </q-select>
                  </div>
                  <div class="col-12">
                    <q-input
                      v-model="invoiceForm.customerAddress"
                      label="Shipping address *"
                      outlined
                      dense
                      type="textarea"
                      rows="2"
                      placeholder="House / road / area"
                      :error="!!validationErrors.customerAddress"
                      :error-message="validationErrors.customerAddress"
                    >
                      <template #prepend>
                        <q-icon name="ph ph-map-pin" color="grey-6" size="xs" />
                      </template>
                    </q-input>
                  </div>
                </template>
                <div class="col-12">
                  <q-input
                    v-model="invoiceForm.notes"
                    label="Notes (Optional)"
                    outlined
                    dense
                    placeholder="e.g. FB Marketplace order — reserved navy top"
                  />
                </div>
              </div>
            </q-card-section>
          </q-card>

          <!-- Online courier -->
          <q-card
            v-show="isOnline && onlineStep === 2"
            flat
            bordered
            class="rounded-borders"
          >
            <q-card-section class="q-pb-none">
              <div class="text-subtitle1 text-weight-bold row items-center">
                <q-icon name="ph ph-truck" class="q-mr-xs text-primary" size="20px" />
                Courier & fees
              </div>
            </q-card-section>
            <q-card-section>
              <div class="row q-col-gutter-md">
                <div class="col-12 col-sm-6">
                  <q-select
                    v-model="invoiceForm.courierProviderId"
                    :options="courierProviderOptions"
                    option-value="value"
                    option-label="label"
                    emit-value
                    map-options
                    clearable
                    outlined
                    dense
                    label="Courier provider"
                    :loading="couriersLoading"
                    hint="System + your custom couriers"
                  />
                </div>
                <div class="col-12 col-sm-6">
                  <q-input
                    v-model="invoiceForm.trackingId"
                    outlined
                    dense
                    label="Tracking ID (optional)"
                  />
                </div>
              </div>

              <div class="text-caption text-grey-7 q-mt-md q-mb-sm">
                Enter each fee, then choose who pays. Leave amount at 0 to skip.
              </div>

              <div class="column q-gutter-y-md">
                <div class="courier-fee-row row q-col-gutter-sm items-start">
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="invoiceForm.courierAmount"
                      type="number"
                      min="0"
                      step="0.01"
                      label="Delivery amount"
                      outlined
                      dense
                      prefix="৳"
                    />
                  </div>
                  <div class="col-12 col-sm-6">
                    <div class="text-caption text-grey-7 q-mb-xs">
                      Paid by
                      <span v-if="courierAmountPositive" class="text-negative">*</span>
                    </div>
                    <q-btn-toggle
                      v-model="invoiceForm.courierPaidBy"
                      toggle-color="primary"
                      unelevated
                      dense
                      no-caps
                      class="full-width"
                      :disable="!courierAmountPositive"
                      :options="courierPaidByOptions"
                      :class="{ 'courier-payer-error': !!validationErrors.courierPaidBy }"
                    />
                    <div
                      v-if="validationErrors.courierPaidBy"
                      class="text-negative text-caption q-mt-xs"
                    >
                      {{ validationErrors.courierPaidBy }}
                    </div>
                  </div>
                </div>

                <div class="courier-fee-row row q-col-gutter-sm items-start">
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="invoiceForm.codFeeAmount"
                      type="number"
                      min="0"
                      step="0.01"
                      label="COD fee"
                      outlined
                      dense
                      prefix="৳"
                    />
                  </div>
                  <div class="col-12 col-sm-6">
                    <div class="text-caption text-grey-7 q-mb-xs">
                      Paid by
                      <span v-if="codFeeAmountPositive" class="text-negative">*</span>
                    </div>
                    <q-btn-toggle
                      v-model="invoiceForm.codFeePaidBy"
                      toggle-color="primary"
                      unelevated
                      dense
                      no-caps
                      class="full-width"
                      :disable="!codFeeAmountPositive"
                      :options="courierPaidByOptions"
                      :class="{ 'courier-payer-error': !!validationErrors.codFeePaidBy }"
                    />
                    <div
                      v-if="validationErrors.codFeePaidBy"
                      class="text-negative text-caption q-mt-xs"
                    >
                      {{ validationErrors.codFeePaidBy }}
                    </div>
                  </div>
                </div>

                <div class="courier-fee-row row q-col-gutter-sm items-start">
                  <div class="col-12 col-sm-6">
                    <q-input
                      v-model.number="invoiceForm.packingAmount"
                      type="number"
                      min="0"
                      step="0.01"
                      label="Packing amount"
                      outlined
                      dense
                      prefix="৳"
                    />
                  </div>
                  <div class="col-12 col-sm-6">
                    <div class="text-caption text-grey-7 q-mb-xs">
                      Paid by
                      <span v-if="packingAmountPositive" class="text-negative">*</span>
                    </div>
                    <q-btn-toggle
                      v-model="invoiceForm.packingPaidBy"
                      toggle-color="primary"
                      unelevated
                      dense
                      no-caps
                      class="full-width"
                      :disable="!packingAmountPositive"
                      :options="courierPaidByOptions"
                      :class="{ 'courier-payer-error': !!validationErrors.packingPaidBy }"
                    />
                    <div
                      v-if="validationErrors.packingPaidBy"
                      class="text-negative text-caption q-mt-xs"
                    >
                      {{ validationErrors.packingPaidBy }}
                    </div>
                  </div>
                </div>
              </div>
            </q-card-section>
          </q-card>

          <!-- Online review -->
          <q-card
            v-show="isOnline && onlineStep === 3"
            flat
            bordered
            class="rounded-borders"
          >
            <q-card-section class="q-pb-none">
              <div class="text-subtitle1 text-weight-bold row items-center">
                <q-icon name="ph ph-clipboard-text" class="q-mr-xs text-primary" size="20px" />
                Review
              </div>
            </q-card-section>
            <q-card-section class="q-gutter-y-md">
              <div>
                <div class="text-caption text-grey-6">Items</div>
                <div class="text-weight-medium">
                  {{ selectedItems.length }} line(s) · {{ totalLabel }}
                  {{ formatThriftAmount(codExpected) }}
                </div>
              </div>
              <div>
                <div class="text-caption text-grey-6">Customer</div>
                <div class="text-weight-medium">
                  {{ invoiceForm.customerName || '—' }}
                  <span v-if="invoiceForm.customerPhone" class="text-grey-7">
                    · {{ invoiceForm.customerPhone }}
                  </span>
                </div>
                <div v-if="invoiceForm.customerSecondaryPhone" class="text-caption text-grey-7">
                  Alt: {{ invoiceForm.customerSecondaryPhone }}
                </div>
                <div class="text-body2 q-mt-xs">
                  {{ invoiceForm.customerAddress || '—' }}
                </div>
                <div class="text-caption text-grey-7">
                  {{
                    [invoiceForm.thana, invoiceForm.district, invoiceForm.postCode]
                      .filter(Boolean)
                      .join(' · ') || '—'
                  }}
                </div>
              </div>
              <div>
                <div class="text-caption text-grey-6">Courier & fees</div>
                <div class="text-body2">
                  Provider:
                  {{
                    courierProviderOptions.find(
                      (o) => o.value === invoiceForm.courierProviderId,
                    )?.label || '—'
                  }}
                </div>
                <div class="text-caption text-grey-7">
                  Delivery ৳{{ courierAmountValue }}
                  <span v-if="invoiceForm.courierPaidBy">
                    ({{ invoiceForm.courierPaidBy === 'CUSTOMER' ? 'customer' : 'shop' }})
                  </span>
                  · COD fee ৳{{ codFeeAmountValue }}
                  · Packing ৳{{ packingAmountValue }}
                </div>
                <div v-if="invoiceForm.trackingId" class="text-caption text-grey-7">
                  Tracking: {{ invoiceForm.trackingId }}
                </div>
              </div>
              <div class="text-caption text-grey-6">
                Draft is saved on this device. Generate creates the invoice.
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- Right: Sticky actions -->
        <div class="col-12 col-lg-4">
          <div class="sticky-summary">
            <q-card flat bordered class="rounded-borders bg-white shadow-1">
              <q-card-section class="bg-grey-2 q-py-sm">
                <div class="text-caption text-grey-7 row items-start">
                  <q-icon name="ph ph-info" size="xs" color="primary" class="q-mr-xs q-mt-xs" />
                  <span>
                    <template v-if="isOnline">
                      Online steps: Items → Customer → Courier → Review. Draft autosaves locally.
                    </template>
                    <template v-else>
                      Offline sales are marked paid on generate. Matching holds convert when phone matches.
                    </template>
                  </span>
                </div>
              </q-card-section>

              <q-card-section v-if="isOnline" class="q-pb-none">
                <div class="row q-col-gutter-sm">
                  <div class="col-6">
                    <q-btn
                      outline
                      color="grey-8"
                      no-caps
                      class="full-width"
                      label="Back"
                      icon="ph ph-caret-left"
                      :disable="onlineStep <= 0"
                      @click="goOnlineStep(onlineStep - 1)"
                    />
                  </div>
                  <div class="col-6">
                    <q-btn
                      v-if="onlineStep < 3"
                      color="primary"
                      unelevated
                      no-caps
                      class="full-width"
                      label="Next"
                      icon-right="ph ph-caret-right"
                      @click="goNextOnlineStep"
                    />
                    <q-btn
                      v-else
                      color="primary"
                      unelevated
                      no-caps
                      class="full-width text-weight-bold"
                      icon="ph ph-check-circle"
                      label="Generate"
                      :loading="saving"
                      :disable="generateDisabled"
                      @click="onSaveInvoice"
                    />
                  </div>
                </div>
              </q-card-section>

              <q-card-actions v-else class="q-pa-md q-gutter-y-sm">
                <q-btn
                  color="primary"
                  unelevated
                  no-caps
                  icon="ph ph-check-circle"
                  label="Generate"
                  class="full-width text-weight-bold"
                  size="lg"
                  :loading="saving"
                  :disable="generateDisabled"
                  @click="onSaveInvoice"
                />
              </q-card-actions>
            </q-card>
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onBeforeUnmount, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import LearnMoreHelpBtn from 'src/modules/help/components/LearnMoreHelpBtn.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { requestConfirmation } from 'src/utils/appFeedback';
import { useBDAddressOptions } from 'src/modules/shop_order/composables/useBDAddressOptions';
import {
  thriftSalesRepository,
  type AvailableStockItem,
  type ThriftCourierPaidBy,
  type ThriftSaleChannel,
} from '../repositories/thriftSalesRepository';
import {
  useThriftAvailableStockSearchQuery,
  type ThriftAvailableStockSearchParams,
} from '../composables/useThriftSalesQuery';
import { useCreateThriftSalesInvoiceMutation } from '../composables/useThriftSalesMutations';
import { useThriftCourierPickerQuery } from 'src/modules/thrift/courier/composables/useThriftCourierQuery';
import { formatThriftActionableError } from 'src/modules/thrift/shared/utils/formatThriftActionableError';
import { formatAppDate } from 'src/utils/dateTime';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { storeToRefs } from 'pinia';
import {
  clearThriftCreateInvoiceDraft,
  readThriftCreateInvoiceDraft,
  thriftCreateInvoiceDraftHasContent,
  writeThriftCreateInvoiceDraft,
  type ThriftCreateInvoiceDraft,
} from '../utils/thriftCreateInvoiceDraft';

const $q = useQuasar();
const router = useRouter();
const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const { hasModuleAccess } = useModulePermissions();
const canApplyDiscount = computed(() =>
  hasModuleAccess('thrift_sales', 'apply_discount'),
);

const {
  districtOptions,
  thanaOptions,
  postcodeOptions,
  loadInitialDistricts,
  updateThanaList,
  updatePostcodeList,
  filterDistrict,
  filterThana,
  filterPostcode,
  createPostcode,
} = useBDAddressOptions();

const { mutateAsync: createSalesInvoice, isPending: saving } =
  useCreateThriftSalesInvoiceMutation();

const { data: courierProviders, isFetching: couriersLoading } =
  useThriftCourierPickerQuery(tenantId);

const courierProviderOptions = computed(() =>
  (courierProviders.value ?? []).map((p) => ({
    label: p.isSystem ? p.name : `${p.name} (custom)`,
    value: p.id,
  })),
);

const invoiceForm = ref({
  saleChannel: 'IN_STORE' as ThriftSaleChannel,
  customerName: '',
  customerPhone: '',
  customerSecondaryPhone: '',
  customerAddress: '',
  district: '',
  thana: '',
  postCode: '',
  date: new Date().toISOString().split('T')[0],
  notes: '',
  courierProviderId: null as number | null,
  trackingId: '',
  courierAmount: 0 as number,
  courierPaidBy: null as ThriftCourierPaidBy | null,
  packingAmount: 0 as number,
  packingPaidBy: null as ThriftCourierPaidBy | null,
  codFeeAmount: 0 as number,
  codFeePaidBy: null as ThriftCourierPaidBy | null,
});

const validationErrors = ref<{
  customerName?: string;
  customerPhone?: string;
  customerAddress?: string;
  district?: string;
  thana?: string;
  courierPaidBy?: string;
  packingPaidBy?: string;
  codFeePaidBy?: string;
}>({});

onMounted(() => {
  void loadInitialDistricts();
  const tid = tenantId.value;
  if (tid) {
    const existing = readThriftCreateInvoiceDraft(tid);
    if (existing && thriftCreateInvoiceDraftHasContent(existing)) {
      pendingDraft.value = existing;
    }
  }
  window.addEventListener('beforeunload', onBeforeUnload);
});

async function onDistrictChange(dist: string | null) {
  invoiceForm.value.district = dist || '';
  invoiceForm.value.thana = '';
  invoiceForm.value.postCode = '';
  await updateThanaList(invoiceForm.value.district);
}

async function onThanaChange(thana: string | null) {
  invoiceForm.value.thana = thana || '';
  invoiceForm.value.postCode = '';
  await updatePostcodeList(invoiceForm.value.district, invoiceForm.value.thana);
}

const saleChannelOptions = [
  { label: 'Offline', value: 'IN_STORE' },
  { label: 'Online', value: 'ONLINE' },
];

const courierPaidByOptions = [
  { label: 'Customer', value: 'CUSTOMER' },
  { label: 'Shop', value: 'SHOP' },
];

const isOnline = computed(() => invoiceForm.value.saleChannel === 'ONLINE');

const onlineSteps = [
  { value: 0, label: 'Items' },
  { value: 1, label: 'Customer' },
  { value: 2, label: 'Courier' },
  { value: 3, label: 'Review' },
] as const;

const onlineStep = ref(0);
const pendingDraft = ref<ThriftCreateInvoiceDraft | null>(null);
const draftSavedAt = ref<string | null>(null);
const draftHydrating = ref(false);
let draftSaveTimer: ReturnType<typeof setTimeout> | null = null;
let suppressUnloadWarning = false;

const draftSavedHint = computed(() => {
  if (!isOnline.value) return '';
  if (!draftSavedAt.value) return 'Draft autosave on';
  return `Saved ${formatDraftSavedAt(draftSavedAt.value)}`;
});

const generateDisabled = computed(() => {
  if (selectedItems.value.length === 0) return true;
  if (isOnline.value && onlineStep.value !== 3) return true;
  return false;
});

function formatDraftSavedAt(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleString();
}

function goOnlineStep(step: number) {
  onlineStep.value = Math.min(3, Math.max(0, step));
}

function goNextOnlineStep() {
  if (onlineStep.value === 0 && selectedItems.value.length === 0) {
    $q.notify({ type: 'warning', message: 'Add at least one item before continuing.' });
    return;
  }
  if (onlineStep.value === 1) {
    const errors: typeof validationErrors.value = {};
    if (!invoiceForm.value.customerName.trim()) errors.customerName = 'Name is required';
    if (!invoiceForm.value.customerPhone.trim()) errors.customerPhone = 'Phone is required';
    if (!invoiceForm.value.customerAddress.trim()) {
      errors.customerAddress = 'Address is required for online sales';
    }
    if (!invoiceForm.value.district.trim()) errors.district = 'District is required';
    if (!invoiceForm.value.thana.trim()) errors.thana = 'Thana / upazila is required';
    validationErrors.value = { ...validationErrors.value, ...errors };
    if (Object.keys(errors).length) {
      $q.notify({ type: 'warning', message: 'Complete customer details before continuing.' });
      return;
    }
  }
  goOnlineStep(onlineStep.value + 1);
}

function persistDraftNow() {
  const tid = tenantId.value;
  if (!tid || !isOnline.value || draftHydrating.value) return;
  const payload = {
    form: { ...invoiceForm.value },
    items: selectedItems.value.map((i) => ({ ...i })),
    onlineStep: onlineStep.value,
  };
  if (!thriftCreateInvoiceDraftHasContent(payload)) {
    clearThriftCreateInvoiceDraft(tid);
    draftSavedAt.value = null;
    return;
  }
  writeThriftCreateInvoiceDraft(tid, payload);
  draftSavedAt.value = new Date().toISOString();
}

function scheduleDraftPersist() {
  if (!isOnline.value || draftHydrating.value) return;
  if (draftSaveTimer) clearTimeout(draftSaveTimer);
  draftSaveTimer = setTimeout(() => {
    draftSaveTimer = null;
    persistDraftNow();
  }, 400);
}

async function applyDraft(draft: ThriftCreateInvoiceDraft) {
  draftHydrating.value = true;
  try {
    invoiceForm.value = {
      ...invoiceForm.value,
      ...draft.form,
      saleChannel: 'ONLINE',
    };
    selectedItems.value = (draft.items || []).map((i) => ({ ...i }));
    onlineStep.value = Math.min(3, Math.max(0, Number(draft.onlineStep) || 0));
    draftSavedAt.value = draft.updatedAt;
    if (invoiceForm.value.district) {
      await updateThanaList(invoiceForm.value.district, invoiceForm.value.postCode);
      if (invoiceForm.value.thana) {
        await updatePostcodeList(
          invoiceForm.value.district,
          invoiceForm.value.thana,
          invoiceForm.value.postCode,
        );
      }
    }
  } finally {
    draftHydrating.value = false;
  }
}

async function resumeDraft() {
  if (!pendingDraft.value) return;
  await applyDraft(pendingDraft.value);
  pendingDraft.value = null;
  $q.notify({ type: 'info', message: 'Draft restored', timeout: 1800 });
}

function discardPendingDraft() {
  const tid = tenantId.value;
  if (tid) clearThriftCreateInvoiceDraft(tid);
  pendingDraft.value = null;
  draftSavedAt.value = null;
}

async function discardDraft() {
  const ok = await requestConfirmation(
    'Clear the Online draft on this device?',
    'Clear draft?',
    'Clear',
  );
  if (!ok) return;
  const tid = tenantId.value;
  if (tid) clearThriftCreateInvoiceDraft(tid);
  pendingDraft.value = null;
  draftSavedAt.value = null;
  $q.notify({ type: 'info', message: 'Draft cleared', timeout: 1500 });
}

function onBeforeUnload(e: BeforeUnloadEvent) {
  if (suppressUnloadWarning || !isOnline.value) return;
  if (
    !thriftCreateInvoiceDraftHasContent({
      form: invoiceForm.value,
      items: selectedItems.value,
    })
  ) {
    return;
  }
  persistDraftNow();
  e.preventDefault();
  e.returnValue = '';
}

const saleDateLabel = computed(() =>
  formatAppDate(invoiceForm.value.date, ''),
);

const totalLabel = computed(() => (isOnline.value ? 'COD expected' : 'Collect now'));

const courierAmountValue = computed(() =>
  Math.max(0, Number(invoiceForm.value.courierAmount) || 0),
);
const packingAmountValue = computed(() =>
  Math.max(0, Number(invoiceForm.value.packingAmount) || 0),
);
const codFeeAmountValue = computed(() =>
  Math.max(0, Number(invoiceForm.value.codFeeAmount) || 0),
);

const courierAmountPositive = computed(() => courierAmountValue.value > 0);
const packingAmountPositive = computed(() => packingAmountValue.value > 0);
const codFeeAmountPositive = computed(() => codFeeAmountValue.value > 0);

watch(isOnline, (online) => {
  if (!online) {
    invoiceForm.value.courierAmount = 0;
    invoiceForm.value.courierPaidBy = null;
    invoiceForm.value.packingAmount = 0;
    invoiceForm.value.packingPaidBy = null;
    invoiceForm.value.codFeeAmount = 0;
    invoiceForm.value.codFeePaidBy = null;
    invoiceForm.value.courierProviderId = null;
    invoiceForm.value.trackingId = '';
    onlineStep.value = 0;
  } else {
    onlineStep.value = 0;
    scheduleDraftPersist();
  }
});

watch(courierAmountPositive, (positive) => {
  if (!positive) {
    invoiceForm.value.courierPaidBy = null;
    return;
  }
  if (!invoiceForm.value.courierPaidBy) {
    invoiceForm.value.courierPaidBy = 'CUSTOMER';
  }
});
watch(packingAmountPositive, (positive) => {
  if (!positive) {
    invoiceForm.value.packingPaidBy = null;
    return;
  }
  if (!invoiceForm.value.packingPaidBy) {
    invoiceForm.value.packingPaidBy = 'CUSTOMER';
  }
});
watch(codFeeAmountPositive, (positive) => {
  if (!positive) {
    invoiceForm.value.codFeePaidBy = null;
    return;
  }
  if (!invoiceForm.value.codFeePaidBy) {
    invoiceForm.value.codFeePaidBy = 'CUSTOMER';
  }
});

const lookingUpCustomer = ref(false);
let customerLookupTimer: ReturnType<typeof setTimeout> | null = null;
let customerLookupSeq = 0;

watch(
  () => invoiceForm.value.customerPhone,
  (phone) => {
    if (customerLookupTimer) clearTimeout(customerLookupTimer);
    const digits = (phone || '').replace(/\D/g, '');
    if (digits.length < 4) {
      lookingUpCustomer.value = false;
      return;
    }
    customerLookupTimer = setTimeout(() => {
      void lookupCustomerByPhone(phone || '');
    }, 400);
  },
);

async function lookupCustomerByPhone(phone: string) {
  const tenantId = authStore.tenantId;
  if (!tenantId) return;

  const seq = ++customerLookupSeq;
  lookingUpCustomer.value = true;
  try {
    const results = await thriftSalesRepository.searchCustomers(tenantId, phone);
    if (seq !== customerLookupSeq) return;

    const digits = phone.replace(/\D/g, '');
    const match =
      results.find((c) => c.phoneNormalized && c.phoneNormalized === digits) ||
      results.find(
        (c) => c.phoneNormalized && digits.startsWith(c.phoneNormalized),
      ) ||
      results.find(
        (c) => c.phoneNormalized && c.phoneNormalized.startsWith(digits),
      ) ||
      results[0];

    if (!match) return;

    invoiceForm.value.customerName = match.name || '';
    invoiceForm.value.customerSecondaryPhone = match.secondaryPhone || '';
    invoiceForm.value.customerAddress = match.address || '';
    invoiceForm.value.district = match.addressParts.district || '';
    invoiceForm.value.thana = match.addressParts.thana || '';
    invoiceForm.value.postCode = match.addressParts.post_code || '';
    if (invoiceForm.value.district) {
      await updateThanaList(invoiceForm.value.district, invoiceForm.value.postCode);
      if (invoiceForm.value.thana) {
        await updatePostcodeList(
          invoiceForm.value.district,
          invoiceForm.value.thana,
          invoiceForm.value.postCode,
        );
      }
    }
  } catch (err) {
    console.error('Customer lookup failed:', err);
  } finally {
    if (seq === customerLookupSeq) lookingUpCustomer.value = false;
  }
}

onBeforeUnmount(() => {
  if (customerLookupTimer) clearTimeout(customerLookupTimer);
  if (draftSaveTimer) clearTimeout(draftSaveTimer);
  persistDraftNow();
  window.removeEventListener('beforeunload', onBeforeUnload);
});

const searchQuery = ref('');
const committedSearch = ref('');
let lastExactAutoAddKey = '';

const searchParams = computed<ThriftAvailableStockSearchParams>(() => ({
  tenantId: authStore.tenantId ?? 0,
  search: committedSearch.value,
  customerPhone: invoiceForm.value.customerPhone.trim() || undefined,
}));

const {
  data: searchResultsData,
  isFetching: loadingStock,
  error: searchError,
} = useThriftAvailableStockSearchQuery(searchParams);

const hasSearched = computed(() => !!committedSearch.value.trim());
const lastSearchQuery = computed(() => committedSearch.value);
const searchResults = computed(() => searchResultsData.value ?? []);

function triggerStockSearch() {
  const query = searchQuery.value.trim();
  if (!query) {
    committedSearch.value = '';
    lastExactAutoAddKey = '';
    return;
  }
  committedSearch.value = query;
}

function clearSearchResults() {
  committedSearch.value = '';
  searchQuery.value = '';
  lastExactAutoAddKey = '';
}

watch(searchError, (err) => {
  if (!err) return;
  console.error('Search stock error:', err);
  $q.notify({
    type: 'negative',
    message: formatThriftActionableError(err, 'Failed to search stock items.'),
  });
});

watch([searchResultsData, loadingStock, committedSearch], () => {
  if (loadingStock.value) return;
  const q = committedSearch.value.trim();
  if (!q) return;
  const results = searchResultsData.value ?? [];
  const needle = q.toLowerCase();
  const exact = results.find((r) => r.barcode.toLowerCase() === needle);
  if (!exact) return;
  const key = `${exact.id}:${needle}`;
  if (lastExactAutoAddKey === key) return;
  lastExactAutoAddKey = key;
  addItemToInvoice(exact);
});

interface InvoiceLineItem {
  stockId: number;
  name: string;
  brandName?: string | undefined;
  barcode: string;
  category: string;
  type?: string | undefined;
  color?: string | undefined;
  size?: string | undefined;
  condition?: string | undefined;
  shelfCode?: string | undefined;
  boxName?: string | undefined;
  imageUrl?: string | undefined;
  shipmentId: number;
  shipmentName?: string | undefined;
  sellPrice: number;
  discountAmount: number;
  quantity: number;
  availableQuantity: number;
}

const selectedItems = ref<InvoiceLineItem[]>([]);

watch(
  [invoiceForm, selectedItems, onlineStep, isOnline],
  () => {
    scheduleDraftPersist();
  },
  { deep: true },
);

function itemLabel(item: { name?: string | null | undefined; brandName?: string | null | undefined }): string {
  const brand = (item.brandName || '').trim();
  const name = (item.name || '').trim();
  if (brand && name && brand.toLowerCase() !== name.toLowerCase()) {
    return `${brand} · ${name}`;
  }
  return brand || name || 'Item';
}

function lineLabel(line: InvoiceLineItem): string {
  return itemLabel(line);
}

function clampQty(value: unknown, max: number): number {
  const n = Math.floor(Number(value));
  if (!Number.isFinite(n) || n < 1) return 1;
  return Math.min(n, Math.max(1, max));
}

function setLineQty(line: InvoiceLineItem, value: unknown) {
  line.quantity = clampQty(value, line.availableQuantity);
}

function isItemAdded(stockId: number): boolean {
  return selectedItems.value.some((item) => item.stockId === stockId);
}

function isItemAtMax(stock: AvailableStockItem): boolean {
  const existing = selectedItems.value.find((item) => item.stockId === stock.id);
  if (!existing) return false;
  const available = Math.max(1, stock.availableQuantity || 1);
  return existing.quantity >= available;
}

function addItemToInvoice(stock: AvailableStockItem) {
  if (stock.status === 'SOLD') {
    $q.notify({ type: 'warning', message: 'This item is already sold' });
    return;
  }
  if (stock.status === 'RESERVED') {
    const phoneDigits = invoiceForm.value.customerPhone.replace(/\D/g, '');
    const holdDigits = (stock.heldForPhone || '').replace(/\D/g, '');
    if (!phoneDigits || !holdDigits || phoneDigits !== holdDigits) {
      $q.notify({
        type: 'warning',
        message: 'This item is on hold — enter the matching customer phone to convert, or release the hold first',
      });
      return;
    }
  }

  const available = Math.max(1, stock.availableQuantity || 1);
  const existing = selectedItems.value.find((item) => item.stockId === stock.id);
  if (existing) {
    if (existing.quantity >= available) {
      $q.notify({
        type: 'warning',
        message: `Only ${available} available for this item`,
      });
      return;
    }
    existing.quantity += 1;
    clearSearchResults();
    $q.notify({
      type: 'positive',
      message: `Qty updated to ${existing.quantity}`,
      icon: 'ph ph-check',
      timeout: 1000,
    });
    return;
  }

  selectedItems.value.push({
    stockId: stock.id,
    name: stock.name,
    brandName: stock.brandName,
    barcode: stock.barcode,
    category: stock.category,
    type: stock.type,
    color: stock.color,
    size: stock.size,
    condition: stock.condition,
    shelfCode: stock.shelfCode,
    boxName: stock.boxName,
    imageUrl: stock.imageUrl,
    shipmentId: stock.shipmentId,
    shipmentName: stock.shipmentName,
    sellPrice: stock.defaultSellPrice,
    discountAmount: 0,
    quantity: 1,
    availableQuantity: available,
  });
  clearSearchResults();
  $q.notify({
    type: 'positive',
    message: `Added ${itemLabel(stock)}`,
    icon: 'ph ph-check',
    timeout: 1000,
  });
}

function removeItem(index: number) {
  selectedItems.value.splice(index, 1);
}

async function onClearAll() {
  if (selectedItems.value.length === 0) return;
  const ok = await requestConfirmation(
    'Remove all items from this sale?',
    'Clear cart',
    'Clear',
  );
  if (ok) selectedItems.value = [];
}

function getFinalPrice(line: InvoiceLineItem): number {
  return Math.max(0, (line.sellPrice || 0) - (line.discountAmount || 0));
}

function getLineTotal(line: InvoiceLineItem): number {
  return getFinalPrice(line) * (line.quantity || 1);
}

const totalDiscounts = computed(() =>
  selectedItems.value.reduce(
    (sum, line) => sum + (line.discountAmount || 0) * (line.quantity || 1),
    0,
  ),
);

const totalItemsGross = computed(() =>
  selectedItems.value.reduce(
    (sum, line) => sum + (line.sellPrice || 0) * (line.quantity || 1),
    0,
  ),
);

const totalInvoiceAmount = computed(() =>
  selectedItems.value.reduce((sum, line) => sum + getLineTotal(line), 0),
);

const codExpected = computed(() => {
  if (!isOnline.value) return totalInvoiceAmount.value;
  let total = totalInvoiceAmount.value;
  if (courierAmountPositive.value && invoiceForm.value.courierPaidBy === 'CUSTOMER') {
    total += courierAmountValue.value;
  }
  if (codFeeAmountPositive.value && invoiceForm.value.codFeePaidBy === 'CUSTOMER') {
    total += codFeeAmountValue.value;
  }
  if (packingAmountPositive.value && invoiceForm.value.packingPaidBy === 'CUSTOMER') {
    total += packingAmountValue.value;
  }
  return total;
});

const displayTotal = computed(() =>
  isOnline.value ? codExpected.value : totalInvoiceAmount.value,
);

function validateForm(): boolean {
  const errors: typeof validationErrors.value = {};
  const name = invoiceForm.value.customerName.trim();
  const phone = invoiceForm.value.customerPhone.trim();
  const address = invoiceForm.value.customerAddress.trim();

  if (!name) errors.customerName = 'Name is required';
  if (!phone) errors.customerPhone = 'Phone is required';

  if (isOnline.value) {
    if (!address) errors.customerAddress = 'Address is required for online sales';
    if (!invoiceForm.value.district.trim()) {
      errors.district = 'District is required';
    }
    if (!invoiceForm.value.thana.trim()) {
      errors.thana = 'Thana / upazila is required';
    }
    if (courierAmountPositive.value && !invoiceForm.value.courierPaidBy) {
      errors.courierPaidBy = 'Choose who pays delivery';
    }
    if (packingAmountPositive.value && !invoiceForm.value.packingPaidBy) {
      errors.packingPaidBy = 'Choose who pays packing';
    }
    if (codFeeAmountPositive.value && !invoiceForm.value.codFeePaidBy) {
      errors.codFeePaidBy = 'Choose who pays COD fee';
    }
  }

  validationErrors.value = errors;
  return Object.keys(errors).length === 0;
}

async function onSaveInvoice() {
  if (selectedItems.value.length === 0) {
    $q.notify({ type: 'warning', message: 'Add at least one item before generating.' });
    return;
  }

  if (!validateForm()) {
    $q.notify({
      type: 'warning',
      message: 'Fill required customer fields before generating.',
    });
    return;
  }

  try {
    const tenantId = authStore.tenantId;
    if (!tenantId) {
      $q.notify({ type: 'negative', message: 'Tenant context is missing.' });
      return;
    }
    const userEmail = authStore.user?.email || 'cashier@brandwala.com';

    const itemsPayload = selectedItems.value.map((line) => {
      const qty = clampQty(line.quantity, line.availableQuantity);
      const discountAmount = canApplyDiscount.value ? line.discountAmount || 0 : 0;
      return {
        stockId: line.stockId,
        sellPrice: line.sellPrice || 0,
        discountAmount,
        quantity: qty,
      };
    });

    // Offline: fees forced 0 server-side; Online sends fee rows + courier catalog.
    const courierAmount = isOnline.value ? courierAmountValue.value : 0;
    const courierPaidBy =
      isOnline.value && courierAmount > 0
        ? invoiceForm.value.courierPaidBy
        : null;
    const packingAmount = isOnline.value ? packingAmountValue.value : 0;
    const packingPaidBy =
      isOnline.value && packingAmount > 0
        ? invoiceForm.value.packingPaidBy
        : null;
    const codFeeAmount = isOnline.value ? codFeeAmountValue.value : 0;
    const codFeePaidBy =
      isOnline.value && codFeeAmount > 0
        ? invoiceForm.value.codFeePaidBy
        : null;

    const selectedProvider = (courierProviders.value ?? []).find(
      (p) => p.id === invoiceForm.value.courierProviderId,
    );
    const trackingId = invoiceForm.value.trackingId.trim();

    const result = await createSalesInvoice({
      tenantId,
      saleChannel: invoiceForm.value.saleChannel,
      customerName: invoiceForm.value.customerName.trim(),
      customerPhone: invoiceForm.value.customerPhone.trim(),
      customerSecondaryPhone:
        invoiceForm.value.customerSecondaryPhone.trim() || undefined,
      customerAddress: isOnline.value
        ? invoiceForm.value.customerAddress.trim()
        : invoiceForm.value.customerAddress.trim() || undefined,
      customerAddressParts: isOnline.value
        ? {
            district: invoiceForm.value.district.trim() || undefined,
            thana: invoiceForm.value.thana.trim() || undefined,
            post_code: invoiceForm.value.postCode.trim() || undefined,
          }
        : undefined,
      date: new Date(invoiceForm.value.date || Date.now()).toISOString(),
      notes: invoiceForm.value.notes || undefined,
      createdBy: userEmail,
      totalInvoiceAmount: totalInvoiceAmount.value,
      courierAmount,
      courierPaidBy,
      packingAmount,
      packingPaidBy,
      codFeeAmount,
      codFeePaidBy,
      courierProviderId: isOnline.value
        ? invoiceForm.value.courierProviderId
        : null,
      courierProvider: selectedProvider?.name,
      meta:
        isOnline.value && trackingId
          ? { tracking_id: trackingId }
          : undefined,
      items: itemsPayload,
    });

    $q.notify({
      type: 'positive',
      icon: 'ph ph-check-circle',
      message: isOnline.value
        ? `Online sale ${result.invoiceNumber} created (COD pending)`
        : `Offline sale ${result.invoiceNumber} generated (paid)`,
      timeout: 2500,
    });

    suppressUnloadWarning = true;
    if (tenantId) clearThriftCreateInvoiceDraft(tenantId);
    pendingDraft.value = null;
    draftSavedAt.value = null;

    const slug = authStore.tenantSlug || 'tenant';
    await router.push(`/${slug}/app/thrift/sales/${result.id}`);
  } catch (err: any) {
    console.error('Failed to create sales invoice:', err);
    $q.notify({
      type: 'negative',
      message: formatThriftActionableError(err, 'Failed to create sales invoice.'),
    });
  }
}
</script>

<style scoped>
.thrift-create-invoice-page {
  max-width: 1400px;
  margin: 0 auto;
}

.sticky-summary {
  position: sticky;
  top: 16px;
}

.max-w-sm {
  max-width: 320px;
}

.min-w-0 {
  min-width: 0;
}

.lh-1 {
  line-height: 1.1;
}

.text-mono {
  font-family: monospace;
}

.courier-payer-error {
  outline: 1px solid var(--q-negative);
  border-radius: 4px;
}

.courier-fee-row {
  padding: 0.65rem 0.75rem;
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
  border-radius: 8px;
  background: var(--bw-theme-surface, transparent);
}

.thrift-invoice-table-wrap {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.thrift-invoice-table {
  min-width: 520px;
}

.thrift-invoice-table th {
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.thrift-invoice-table td {
  padding-top: 8px;
  padding-bottom: 8px;
}

@media (max-width: 599px) {
  .thrift-create-invoice-page {
    padding-bottom: 8px;
  }

  .sticky-summary {
    position: static;
  }

  .thrift-invoice-table {
    min-width: 440px;
  }
}
.status-workflow-row {
  flex-wrap: wrap;
  row-gap: 8px;
}

@media (max-width: 599px) {
  .status-workflow-chevron {
    display: none;
  }
}
</style>
