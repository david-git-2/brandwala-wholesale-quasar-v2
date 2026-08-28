<template>
  <q-page class="shipment-overview-v2-page q-pa-md">
    <!-- Top Header: Title & Chips Row -->
    <div class="row items-center justify-between q-mb-md">
      <div class="column min-width-0">
        <!-- Title with ID (Inline Editable) -->
        <div class="row items-center q-gutter-x-xs no-wrap">
          <span class="text-caption text-weight-bold text-grey-6 font-mono">
            #{{ (shipmentStore.currentShipment as any)?.tenant_shipment_id || shipmentStore.currentShipment?.id || shipmentId }}
          </span>
          <span class="text-grey-4">·</span>

          <!-- Editable Name Input -->
          <template v-if="editingName">
            <q-input
              ref="nameEditInputRef"
              v-model="shipmentName"
              dense
              outlined
              autofocus
              hide-bottom-space
              class="bg-white text-h6 text-weight-bolder"
              style="min-width: 260px; max-width: 480px"
              @keyup.enter="commitNameEdit"
              @keyup.escape="cancelNameEdit"
              @blur="commitNameEdit"
            />
          </template>

          <!-- Display Name -->
          <template v-else>
            <div
              class="text-h6 text-weight-bolder text-grey-9 ellipsis cursor-pointer row items-center q-gutter-x-xs name-display"
              role="button"
              tabindex="0"
              @click="startNameEdit"
            >
              <span class="ellipsis">{{ shipmentName }}</span>
              <q-icon name="ph ph-pencil-simple" size="15px" color="grey-6" class="edit-icon" />
            </div>
          </template>
        </div>

        <!-- Chips Row with Backend Selectors -->
        <div class="row items-center q-gutter-xs q-mt-xs wrap">
          <!-- 1. Status Chip & Selector Menu -->
          <q-chip
            clickable
            dense
            color="primary"
            text-color="white"
            icon-right="arrow_drop_down"
            class="text-capitalize"
            :label="shipmentStore.currentShipment?.status || 'Status'"
          >
            <q-menu auto-close>
              <q-list dense style="min-width: 140px">
                <q-item
                  v-for="st in statusOptions"
                  :key="st.value"
                  clickable
                  :active="shipmentStore.currentShipment?.status === st.value"
                  @click="saveInlineStatus(st.value)"
                >
                  <q-item-section class="text-capitalize">{{ st.label }}</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-chip>

          <!-- 2. Type Chip & Selector Menu -->
          <q-chip
            clickable
            dense
            icon="ph ph-globe"
            icon-right="arrow_drop_down"
            class="text-capitalize"
            :label="currentTypeLabel"
          >
            <q-menu auto-close>
              <q-list dense style="min-width: 140px">
                <q-item
                  v-for="opt in typeOptions"
                  :key="opt.value"
                  clickable
                  :active="shipmentStore.currentShipment?.type === opt.value"
                  @click="saveInlineType(opt.value)"
                >
                  <q-item-section class="text-capitalize">{{ opt.label }}</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-chip>

          <!-- 3. Vendor Chip & Selector Menu -->
          <q-chip
            clickable
            dense
            icon="ph ph-storefront"
            icon-right="arrow_drop_down"
            :label="currentVendorLabel"
          >
            <q-menu auto-close @before-show="ensureVendorsLoaded">
              <q-list dense style="min-width: 200px; max-height: 280px" class="scroll">
                <q-item v-if="loadingVendors" dense>
                  <q-item-section class="text-grey-6">Loading vendors…</q-item-section>
                </q-item>
                <q-item
                  v-for="opt in vendorOptions"
                  :key="opt.value"
                  clickable
                  :active="shipmentStore.currentShipment?.vendor_id === opt.value"
                  @click="saveInlineVendor(opt.value)"
                >
                  <q-item-section>{{ opt.label }}</q-item-section>
                </q-item>
                <q-item v-if="!loadingVendors && !vendorOptions.length" dense>
                  <q-item-section class="text-grey-6">No vendors found</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-chip>

          <!-- 4. Cargo Chip & Selector Menu -->
          <q-chip
            clickable
            dense
            icon="ph ph-airplane-tilt"
            icon-right="arrow_drop_down"
            :label="currentCargoLabel"
          >
            <q-menu auto-close>
              <q-list dense style="min-width: 200px; max-height: 280px" class="scroll">
                <q-item v-if="loadingCargo" dense>
                  <q-item-section class="text-grey-6">Loading cargo…</q-item-section>
                </q-item>
                <q-item
                  v-if="shipmentStore.currentShipment?.cargo_company_id"
                  clickable
                  @click="saveInlineCargo(null)"
                >
                  <q-item-section class="text-negative">Clear Cargo</q-item-section>
                </q-item>
                <q-item
                  v-for="opt in cargoOptions"
                  :key="opt.value"
                  clickable
                  :active="shipmentStore.currentShipment?.cargo_company_id === opt.value"
                  @click="saveInlineCargo(opt.value)"
                >
                  <q-item-section>{{ opt.label }}</q-item-section>
                </q-item>
                <q-item v-if="!loadingCargo && !cargoOptions.length" dense>
                  <q-item-section class="text-grey-6">No cargo options</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-chip>

          <!-- 5. Shop / Tenant Chip & Selector Menu -->
          <q-chip
            clickable
            dense
            icon="ph ph-buildings"
            icon-right="arrow_drop_down"
            :label="currentShopLabel"
          >
            <q-menu auto-close>
              <q-list dense style="min-width: 220px; max-height: 280px" class="scroll">
                <q-item-label header class="text-caption text-weight-bold text-grey-8 q-py-xs">
                  Assign Shop / Tenant
                </q-item-label>
                <q-item
                  v-if="shipmentStore.currentShipment?.assigned_child_tenant_id"
                  clickable
                  @click="saveInlineShop(null)"
                >
                  <q-item-section class="text-negative">Clear Shop Assignment</q-item-section>
                </q-item>
                <q-item
                  v-for="opt in childTenantOptions"
                  :key="opt.value"
                  clickable
                  :active="shipmentStore.currentShipment?.assigned_child_tenant_id === opt.value"
                  @click="saveInlineShop(opt.value)"
                >
                  <q-item-section>{{ opt.label }}</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-chip>
        </div>
      </div>

      <!-- Header Actions: Refresh & Version Toggle -->
      <div class="row items-center q-gutter-xs">
        <q-btn
          flat
          dense
          round
          size="sm"
          color="grey-7"
          icon="ph ph-arrow-clockwise"
          :loading="shipmentStore.loading"
          @click="refreshShipmentData"
        >
          <q-tooltip>Refresh shipment data</q-tooltip>
        </q-btn>

        <q-btn-toggle
          :model-value="overviewVersion"
          flat
          dense
          no-caps
          size="sm"
          toggle-color="primary"
          color="grey-2"
          text-color="grey-8"
          :options="[
            { label: 'Legacy', value: 'legacy', icon: 'ph ph-clock-counter-clockwise' },
            { label: 'New (v2)', value: 'v2', icon: 'ph ph-sparkle' },
          ]"
          class="border-grey version-toggle"
          @update:model-value="onVersionChange"
        >
          <template #legacy>
            <q-tooltip>Switch to Legacy Overview</q-tooltip>
          </template>
          <template #v2>
            <q-tooltip>Active: New Overview</q-tooltip>
          </template>
        </q-btn-toggle>
      </div>
    </div>

    <!-- Two-Column Layout: Left Small, Right Big -->
    <div class="row q-col-gutter-md">
      <!-- Left Column: Steps List -->
      <div class="col-12 col-md-4 col-lg-3">
        <q-card flat bordered class="bg-white q-pa-xs">
          <q-list class="q-gutter-y-xs">
            <q-item
              v-for="item in navItems"
              :key="item.id"
              clickable
              class="nav-step-item q-py-sm"
              :class="{ 'is-active': activeItemId === item.id }"
              @click="activeItemId = item.id"
            >
              <q-item-section avatar style="min-width: 36px">
                <q-icon
                  :name="item.icon"
                  size="20px"
                  :color="activeItemId === item.id ? 'primary' : 'grey-7'"
                />
              </q-item-section>

              <q-item-section>
                <q-item-label class="text-weight-bold text-grey-9" style="font-size: 13px">
                  {{ item.title }}
                </q-item-label>
                <q-item-label caption class="text-grey-6" style="font-size: 11px">
                  {{ item.description }}
                </q-item-label>
              </q-item-section>

              <q-item-section side>
                <q-icon name="ph ph-caret-right" size="14px" color="grey-4" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <!-- Right Column: Content Area -->
      <div class="col-12 col-md-8 col-lg-9">
        <q-card flat bordered class="bg-white q-pa-md main-content-card">
          <!-- 1. Guideline -->
          <template v-if="activeItemId === 1">
            <div class="column q-gutter-y-md">
              <div class="row items-center q-gutter-x-sm">
                <q-icon name="ph ph-book-open-text" size="24px" color="primary" />
                <div class="text-h6 text-weight-bolder text-grey-9">Shipment Guidelines</div>
              </div>

              <div class="text-body2 text-grey-7" style="line-height: 1.6">
                Welcome to the Shipment Workflow. Follow the structured stages on the left index to manage this procurement lifecycle from vendor invoicing to warehouse stock allocation:
              </div>

              <div class="column q-gutter-y-sm q-mt-xs">
                <div class="q-pa-sm bg-grey-1 rounded-borders row items-start q-gutter-x-sm">
                  <q-icon name="ph ph-receipt" size="20px" color="primary" class="q-mt-2xs" />
                  <div class="col">
                    <div class="text-weight-bold text-grey-9 text-caption">1. Sections & Invoices</div>
                    <div class="text-caption text-grey-6">Group lines by vendor invoice into distinct procurement sections.</div>
                  </div>
                </div>

                <div class="q-pa-sm bg-grey-1 rounded-borders row items-start q-gutter-x-sm">
                  <q-icon name="ph ph-currency-circle-dollar" size="20px" color="teal-8" class="q-mt-2xs" />
                  <div class="col">
                    <div class="text-weight-bold text-grey-9 text-caption">2. Rates & Adjustments</div>
                    <div class="text-caption text-grey-6">Input total invoice value, multiple product exchange rates, and cargo freight costs.</div>
                  </div>
                </div>

                <div class="q-pa-sm bg-grey-1 rounded-borders row items-start q-gutter-x-sm">
                  <q-icon name="ph ph-warehouse" size="20px" color="indigo-8" class="q-mt-2xs" />
                  <div class="col">
                    <div class="text-weight-bold text-grey-9 text-caption">3. Receive Stock</div>
                    <div class="text-caption text-grey-6">Inspect arriving physical packages and receive items into inventory.</div>
                  </div>
                </div>

                <div class="q-pa-sm bg-grey-1 rounded-borders row items-start q-gutter-x-sm">
                  <q-icon name="ph ph-buildings" size="20px" color="purple-8" class="q-mt-2xs" />
                  <div class="col">
                    <div class="text-weight-bold text-grey-9 text-caption">4. Allocate Stock to Tenant</div>
                    <div class="text-caption text-grey-6">Distribute and allocate received quantities to wholesale child tenant accounts.</div>
                  </div>
                </div>

                <div class="q-pa-sm bg-grey-1 rounded-borders row items-start q-gutter-x-sm">
                  <q-icon name="ph ph-lock-key" size="20px" color="amber-9" class="q-mt-2xs" />
                  <div class="col">
                    <div class="text-weight-bold text-grey-9 text-caption">5. Finalize & Lock</div>
                    <div class="text-caption text-grey-6">Post financial adjustments, finalize unit landed costs, and lock shipment records.</div>
                  </div>
                </div>
              </div>
            </div>
          </template>

          <!-- 2. Sections & Invoices -->
          <template v-else-if="activeItemId === 2">
            <!-- Top Bar -->
            <div class="row items-center justify-end q-mb-md">
              <q-btn
                unelevated
                dense
                no-caps
                size="sm"
                color="primary"
                icon="ph ph-plus"
                label="Add Section"
                class="q-px-md rounded-btn text-weight-bold"
                @click="openAddSection"
              />
            </div>

            <!-- Loading State -->
            <div v-if="shipmentStore.loading" class="q-pa-xl text-center">
              <q-spinner color="primary" size="28px" />
              <div class="text-caption text-grey-6 q-mt-sm">Loading sections...</div>
            </div>

            <!-- Empty State -->
            <div v-else-if="!sectionsWithCalculations.length" class="q-pa-xl text-center">
              <q-icon name="ph ph-folder-dashed" size="40px" color="grey-4" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-bold text-grey-8">No Sections Created</div>
              <div class="text-caption text-grey-5 q-mb-md" style="max-width: 320px; margin: 0 auto">
                Add sections to group items and invoices by vendor.
              </div>
              <q-btn
                outline
                dense
                no-caps
                size="sm"
                color="primary"
                icon="ph ph-plus"
                label="Create Initial Section"
                class="q-px-md rounded-btn"
                @click="openAddSection"
              />
            </div>

            <!-- Sections List Table -->
            <div v-else class="column q-gutter-y-sm">
              <q-card
                v-for="(sec, idx) in sectionsWithCalculations"
                :key="sec.id"
                flat
                bordered
                class="section-card bg-grey-1 q-pa-sm cursor-pointer"
                @click="openSectionItems(sec.id)"
              >
                <div class="row items-center justify-between no-wrap q-col-gutter-sm">
                  <!-- Section Title & Badge -->
                  <div class="col-5 row items-center q-gutter-x-sm no-wrap">
                    <q-avatar
                      square
                      color="blue-1"
                      text-color="primary"
                      size="32px"
                      class="text-weight-bold rounded-borders"
                    >
                      <q-icon name="ph ph-receipt" size="18px" />
                    </q-avatar>
                    <div class="min-width-0">
                      <div class="row items-center q-gutter-x-xs no-wrap">
                        <span class="text-weight-bolder text-grey-9 ellipsis">
                          {{ sec.title }}
                        </span>
                        <q-badge
                          v-if="idx === 0"
                          color="blue-1"
                          text-color="primary"
                          class="text-weight-bold q-ml-xs"
                          style="font-size: 10px"
                        >
                          Primary
                        </q-badge>
                      </div>
                      <div class="text-caption text-grey-6 font-mono" style="font-size: 11px">
                        Section {{ idx + 1 }}
                      </div>
                    </div>
                  </div>

                  <!-- Invoice Info -->
                  <div class="col-2 text-center">
                    <div v-if="sec.metadata?.invoice_number" class="text-caption text-weight-bold text-grey-9 font-mono">
                      #{{ sec.metadata.invoice_number }}
                    </div>
                    <div v-else class="text-caption text-grey-4 font-mono">—</div>
                    <div v-if="sec.metadata?.invoice_date" class="text-caption text-grey-6" style="font-size: 11px">
                      {{ sec.metadata.invoice_date }}
                    </div>
                  </div>

                  <!-- Lines / Units / Weight -->
                  <div class="col-3 text-right">
                    <div class="text-caption text-weight-bolder font-mono text-grey-9">
                      <span v-if="sec.metadata?.invoice_total_amount" class="text-primary">
                        {{ sec.metadata.invoice_currency_code || '¥' }}{{ Number(sec.metadata.invoice_total_amount).toLocaleString() }}
                      </span>
                      <span v-else>
                        {{ sec.units_count }} pcs
                      </span>
                    </div>
                    <div class="text-caption text-grey-6 font-mono" style="font-size: 11px">
                      {{ sec.item_count }} lines · {{ sec.weight_kg.toFixed(2) }} kg
                    </div>
                  </div>

                  <!-- Actions -->
                  <div class="col-2 row items-center justify-end q-gutter-x-xs">
                    <q-btn
                      flat
                      round
                      dense
                      size="xs"
                      icon="ph ph-pencil-simple"
                      color="grey-7"
                      @click.stop="openEditSection(sec)"
                    >
                      <q-tooltip>Edit section</q-tooltip>
                    </q-btn>
                    <q-btn
                      flat
                      round
                      dense
                      size="xs"
                      icon="ph ph-trash"
                      color="negative"
                      :disable="sectionsWithCalculations.length <= 1"
                      @click.stop="confirmDeleteSection(sec)"
                    >
                      <q-tooltip>Delete section</q-tooltip>
                    </q-btn>
                  </div>
                </div>
              </q-card>
            </div>
          </template>

          <!-- 3. Rates & Adjustments -->
          <template v-else-if="activeItemId === 3">
            <div class="column q-gutter-y-lg">
              <!-- All Invoice Total -->
              <div>
                <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs" style="letter-spacing: 0.5px">
                  All Invoice Total
                </div>
                <div class="row q-col-gutter-sm items-center">
                  <div class="col-12 col-sm-6 col-md-5">
                    <q-input
                      v-model="invoiceTotalInput"
                      outlined
                      dense
                      placeholder="0.00"
                      prefix="¥"
                      class="bg-white font-mono text-weight-bold text-body1"
                    >
                      <template #prepend>
                        <q-icon name="ph ph-receipt" size="18px" color="grey-6" />
                      </template>
                    </q-input>
                  </div>
                  <div class="col-12 col-sm-6 text-caption text-grey-6">
                    Sum of all section invoices in base currency
                  </div>
                </div>
              </div>

              <q-separator />

              <!-- Product Rates -->
              <div>
                <div class="row items-center justify-between q-mb-sm">
                  <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                    Product Rates
                  </div>
                  <q-btn
                    outline
                    dense
                    no-caps
                    size="xs"
                    color="primary"
                    icon="ph ph-plus"
                    label="Add Product Rate"
                    class="q-px-sm rounded-btn"
                    @click="addProductRate"
                  />
                </div>

                <div class="column q-gutter-y-sm">
                  <div
                    v-for="(prodRate, idx) in productRates"
                    :key="prodRate.id"
                    class="rate-card-row q-pa-sm bg-grey-1 rounded-borders"
                  >
                    <div class="row q-col-gutter-sm items-center">
                      <!-- 1. Amount -->
                      <div class="col-12 col-sm-3">
                        <q-input
                          v-model="prodRate.amount"
                          type="number"
                          dense
                          outlined
                          placeholder="0.00"
                          label="Amount"
                          prefix="¥"
                          class="bg-white font-mono"
                        />
                      </div>

                      <!-- 2. Exchange Rate -->
                      <div class="col-12 col-sm-3">
                        <q-input
                          v-model="prodRate.exchangeRate"
                          type="number"
                          dense
                          outlined
                          placeholder="0.00"
                          label="Exchange Rate"
                          prefix="৳"
                          class="bg-white font-mono"
                        />
                      </div>

                      <!-- 3. Notes -->
                      <div class="col-12 col-sm-5">
                        <q-input
                          v-model="prodRate.notes"
                          dense
                          outlined
                          placeholder="e.g. Bank TT, cash conversion, notes"
                          label="Notes"
                          class="bg-white"
                        />
                      </div>

                      <!-- Delete Button -->
                      <div class="col-12 col-sm-1 row justify-end">
                        <q-btn
                          flat
                          round
                          dense
                          size="xs"
                          icon="ph ph-trash"
                          color="negative"
                          :disable="productRates.length <= 1"
                          @click="removeProductRate(idx)"
                        >
                          <q-tooltip>Remove rate</q-tooltip>
                        </q-btn>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <q-separator />

              <!-- Cargo Rates -->
              <div>
                <!-- Total Weight Field (Once) -->
                <div class="q-mb-md">
                  <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs" style="letter-spacing: 0.5px">
                    Total Cargo Weight
                  </div>
                  <div class="row q-col-gutter-sm items-center">
                    <div class="col-12 col-sm-6 col-md-5">
                      <q-input
                        v-model="totalCargoWeightInput"
                        type="number"
                        outlined
                        dense
                        placeholder="0.00"
                        suffix="kg"
                        class="bg-white font-mono text-weight-bold text-body1"
                      >
                        <template #prepend>
                          <q-icon name="ph ph-scales" size="18px" color="grey-6" />
                        </template>
                      </q-input>
                    </div>
                    <div class="col-12 col-sm-6 text-caption text-grey-6">
                      Total shipment cargo freight weight
                    </div>
                  </div>
                </div>

                <!-- Multiple Cargo Rates Header & List -->
                <div class="row items-center justify-between q-mb-sm">
                  <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                    Cargo Rates
                  </div>
                  <q-btn
                    outline
                    dense
                    no-caps
                    size="xs"
                    color="primary"
                    icon="ph ph-plus"
                    label="Add Cargo Rate"
                    class="q-px-sm rounded-btn"
                    @click="addCargoRate"
                  />
                </div>

                <div class="column q-gutter-y-sm">
                  <div
                    v-for="(cargoRate, idx) in cargoRates"
                    :key="cargoRate.id"
                    class="rate-card-row q-pa-sm bg-grey-1 rounded-borders"
                  >
                    <div class="row q-col-gutter-sm items-center">
                      <!-- 1. Amount -->
                      <div class="col-12 col-sm-3">
                        <q-input
                          v-model="cargoRate.amount"
                          type="number"
                          dense
                          outlined
                          placeholder="0.00"
                          label="Amount"
                          prefix="৳"
                          class="bg-white font-mono"
                        />
                      </div>

                      <!-- 2. Rate -->
                      <div class="col-12 col-sm-3">
                        <q-input
                          v-model="cargoRate.rate"
                          type="number"
                          dense
                          outlined
                          placeholder="0.00"
                          label="Rate"
                          prefix="৳"
                          class="bg-white font-mono"
                        />
                      </div>

                      <!-- 3. Description -->
                      <div class="col-12 col-sm-5">
                        <q-input
                          v-model="cargoRate.description"
                          dense
                          outlined
                          placeholder="e.g. Air freight, customs surcharge"
                          label="Description"
                          class="bg-white"
                        />
                      </div>

                      <!-- Delete Button -->
                      <div class="col-12 col-sm-1 row justify-end">
                        <q-btn
                          flat
                          round
                          dense
                          size="xs"
                          icon="ph ph-trash"
                          color="negative"
                          :disable="cargoRates.length <= 1"
                          @click="removeCargoRate(idx)"
                        >
                          <q-tooltip>Remove cargo rate</q-tooltip>
                        </q-btn>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </template>

          <!-- 4. Receive Stock -->
          <template v-else-if="activeItemId === 4">
            <div class="column items-center justify-center text-center q-py-xl text-grey-5">
              <q-icon name="ph ph-warehouse" size="40px" color="grey-4" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-bold text-grey-8">Receive Stock</div>
              <div class="text-caption text-grey-6 q-mt-xs">Check in items and add to warehouse stock.</div>
            </div>
          </template>

          <!-- 5. Allocate Stock to Tenant -->
          <template v-else-if="activeItemId === 5">
            <div class="column items-center justify-center text-center q-py-xl text-grey-5">
              <q-icon name="ph ph-buildings" size="40px" color="grey-4" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-bold text-grey-8">Allocate Stock to Tenant</div>
              <div class="text-caption text-grey-6 q-mt-xs">Assign and distribute received stock to tenant inventories.</div>
            </div>
          </template>

          <!-- 6. Finalize & Lock -->
          <template v-else-if="activeItemId === 6">
            <div class="column items-center justify-center text-center q-py-xl text-grey-5">
              <q-icon name="ph ph-lock-key" size="40px" color="grey-4" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-bold text-grey-8">Finalize & Lock</div>
              <div class="text-caption text-grey-6 q-mt-xs">Finalize costs and lock shipment.</div>
            </div>
          </template>

          <!-- 7. Custom Tracking Status -->
          <template v-else-if="activeItemId === 7">
            <div class="column items-center justify-center text-center q-py-xl text-grey-5">
              <q-icon name="ph ph-users" size="40px" color="grey-4" class="q-mb-sm" />
              <div class="text-subtitle1 text-weight-bold text-grey-8">Custom Tracking Status</div>
              <div class="text-caption text-grey-6 q-mt-xs">Custom journey stages to show to customers.</div>
            </div>
          </template>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, watch, onMounted } from 'vue';
import { QInput, useQuasar } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import {
  useCargoCompaniesQuery,
  useChildTenantsQuery,
} from '../composables/useProcurementStockQuery';
import type { ShipmentSection } from '../types/shipmentSection';
import ShipmentSectionFormDialog from '../components/ShipmentSectionFormDialog.vue';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

withDefaults(
  defineProps<{
    overviewVersion?: 'legacy' | 'v2';
  }>(),
  {
    overviewVersion: 'v2',
  },
);

const emit = defineEmits<{
  (e: 'update:overviewVersion', value: 'legacy' | 'v2'): void;
}>();

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const vendorStore = useVendorStore();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const OVERVIEW_VERSION_STORAGE_KEY = 'shipment_overview_version';

const onVersionChange = (newVersion: 'legacy' | 'v2') => {
  localStorage.setItem(OVERVIEW_VERSION_STORAGE_KEY, newVersion);
  emit('update:overviewVersion', newVersion);
};

// -------------------------------------------------------------
// Title Editing Logic
// -------------------------------------------------------------
const shipmentName = ref(shipmentStore.currentShipment?.name || `Shipment #${shipmentId}`);
const editingName = ref(false);
const originalName = ref(shipmentName.value);
const nameEditInputRef = ref<InstanceType<typeof QInput> | null>(null);

watch(
  () => shipmentStore.currentShipment?.name,
  (name) => {
    if (name && !editingName.value) {
      shipmentName.value = name;
      originalName.value = name;
    }
  },
  { immediate: true },
);

const startNameEdit = () => {
  originalName.value = shipmentName.value;
  editingName.value = true;
  void nextTick(() => {
    nameEditInputRef.value?.focus();
    nameEditInputRef.value?.select();
  });
};

const cancelNameEdit = () => {
  shipmentName.value = originalName.value;
  editingName.value = false;
};

const commitNameEdit = async () => {
  if (!editingName.value) return;
  const trimmed = shipmentName.value.trim();
  if (!trimmed) {
    shipmentName.value = originalName.value;
    editingName.value = false;
    return;
  }

  const prev = originalName.value;
  editingName.value = false;
  if (trimmed === prev) return;

  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.updateShipment(shipmentId, { name: trimmed });
      originalName.value = trimmed;
      showSuccessNotification('Shipment name updated');
    } catch (err: unknown) {
      shipmentName.value = prev;
      showErrorNotification((err as Error)?.message || 'Failed to update shipment name');
    }
  } else {
    originalName.value = trimmed;
    showSuccessNotification('Shipment name updated');
  }
};

// -------------------------------------------------------------
// Status Dropdown Logic
// -------------------------------------------------------------
const statusOptions = [
  { label: 'Draft', value: 'draft' as const },
  { label: 'Ordered', value: 'ordered' as const },
  { label: 'Shipped', value: 'shipped' as const },
  { label: 'Customs', value: 'customs' as const },
  { label: 'Received', value: 'received' as const },
  { label: 'Cancelled', value: 'cancelled' as const },
];

const saveInlineStatus = async (statusVal: 'draft' | 'ordered' | 'shipped' | 'customs' | 'received' | 'cancelled') => {
  if (!shipmentId) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { status: statusVal });
    await shipmentStore.fetchShipmentDetails(shipmentId);
    showSuccessNotification(`Status updated to ${statusVal}`);
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update status');
  }
};

// -------------------------------------------------------------
// Type Dropdown Logic
// -------------------------------------------------------------
const typeOptions = [
  { label: 'International', value: 'international' as const },
  { label: 'Local', value: 'local' as const },
  { label: 'Transfer', value: 'transfer' as const },
];

const currentTypeLabel = computed(() => {
  const type = shipmentStore.currentShipment?.type;
  return type ? type.charAt(0).toUpperCase() + type.slice(1) : 'Type';
});

const saveInlineType = async (typeVal: 'international' | 'local' | 'transfer') => {
  if (!shipmentId) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { type: typeVal });
    showSuccessNotification('Shipment type updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update shipment type');
  }
};

// -------------------------------------------------------------
// Vendor Dropdown Logic
// -------------------------------------------------------------
const loadingVendors = ref(false);
const ensureVendorsLoaded = async () => {
  if (authStore.tenantId && vendorStore.items.length === 0) {
    loadingVendors.value = true;
    try {
      await vendorStore.fetchVendors(authStore.tenantId);
    } catch (err) {
      console.error('Failed to load vendors', err);
    } finally {
      loadingVendors.value = false;
    }
  }
};

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({
    label: v.is_default ? `${v.name} (default)` : v.name,
    value: v.id,
  })),
);

const currentVendorLabel = computed(() => {
  const vId = shipmentStore.currentShipment?.vendor_id;
  if (!vId) return 'Select Vendor';
  const found = vendorStore.items.find((v) => v.id === vId);
  return found ? found.name : `Vendor #${vId}`;
});

const saveInlineVendor = async (val: number | null) => {
  if (!shipmentId || val == null) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { vendor_id: val });
    showSuccessNotification('Vendor updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update vendor');
  }
};

// -------------------------------------------------------------
// Cargo Dropdown Logic
// -------------------------------------------------------------
const currentTenantId = computed(() => authStore.tenantId);
const { data: cargoData, isLoading: loadingCargo } = useCargoCompaniesQuery(currentTenantId);

const cargoCompanies = computed(() => cargoData.value ?? []);

const cargoOptions = computed(() =>
  cargoCompanies.value.map((c) => ({
    label: `${c.name} (${c.code})`,
    value: c.id,
  })),
);

const currentCargoLabel = computed(() => {
  const cId = shipmentStore.currentShipment?.cargo_company_id;
  if (!cId) return 'Select Cargo';
  const found = cargoCompanies.value.find((c) => c.id === cId);
  return found ? found.name : `Cargo #${cId}`;
});

const saveInlineCargo = async (val: number | null) => {
  if (!shipmentId) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { cargo_company_id: val });
    showSuccessNotification('Cargo updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update cargo');
  }
};

// -------------------------------------------------------------
// Shop / Tenant Dropdown Logic
// -------------------------------------------------------------
const { data: childTenantsData } = useChildTenantsQuery(currentTenantId);

const childTenants = computed(() => childTenantsData.value ?? []);

const childTenantOptions = computed(() => {
  const current = authStore.selectedTenant;
  const opts: Array<{ label: string; value: number }> = [];
  if (current?.id) {
    opts.push({ label: `${current.name} (Main Warehouse / Self)`, value: current.id });
  }
  for (const t of childTenants.value) {
    if (t.id === current?.id) continue;
    opts.push({ label: t.name, value: t.id });
  }
  return opts;
});

const currentShopLabel = computed(() => {
  const sId = shipmentStore.currentShipment?.assigned_child_tenant_id;
  if (!sId) return 'Select Shop (Unassigned)';
  if (sId === authStore.tenantId) {
    return `Shop: ${authStore.selectedTenant?.name || 'Main Warehouse'} (Self)`;
  }
  const found = childTenants.value.find((t) => t.id === sId);
  return found ? `Shop: ${found.name}` : `Shop #${sId}`;
});

const saveInlineShop = async (val: number | null) => {
  if (!shipmentId) return;
  try {
    if (authStore.tenantId) {
      await shipmentStore.assignShipmentToChild(authStore.tenantId, val, shipmentId);
      showSuccessNotification(val ? 'Shipment assigned to shop' : 'Shop assignment cleared');
    }
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update shop assignment');
  }
};

// -------------------------------------------------------------
// Navigation & Active Step
// -------------------------------------------------------------
const activeItemId = ref(1);

const navItems = ref([
  {
    id: 1,
    title: 'Guideline',
    description: 'Overview and operational guidelines for this shipment.',
    icon: 'ph ph-book-open-text',
  },
  {
    id: 2,
    title: 'Sections & Invoices',
    description: 'Each invoice becomes a section and add items there.',
    icon: 'ph ph-receipt',
  },
  {
    id: 3,
    title: 'Rates & Adjustments',
    description: 'Add cargo & purchase rates to calculate landed cost rate.',
    icon: 'ph ph-currency-circle-dollar',
  },
  {
    id: 4,
    title: 'Receive Stock',
    description: 'Check in items and add to warehouse stock.',
    icon: 'ph ph-warehouse',
  },
  {
    id: 5,
    title: 'Allocate Stock to Tenant',
    description: 'Assign and distribute received stock to tenant inventories.',
    icon: 'ph ph-buildings',
  },
  {
    id: 6,
    title: 'Finalize & Lock',
    description: 'Finalize costs and lock shipment.',
    icon: 'ph ph-lock-key',
  },
  {
    id: 7,
    title: 'Custom Tracking Status',
    description: 'Custom journey stages to show to customers.',
    icon: 'ph ph-users',
  },
]);

interface SectionWithCalculations extends ShipmentSection {
  item_count: number;
  units_count: number;
  weight_kg: number;
}

const sectionsWithCalculations = computed<SectionWithCalculations[]>(() => {
  const sections = shipmentStore.currentShipmentSections ?? [];
  const items = shipmentStore.currentShipmentItems ?? [];
  const firstSectionId = sections[0]?.id ?? null;

  return sections.map((sec) => {
    const secItems = items.filter(
      (item) => item.section_id === sec.id || (item.section_id == null && sec.id === firstSectionId),
    );
    const units = secItems.reduce((acc, it) => acc + (Number(it.ordered_quantity) || 0), 0);
    const weight = secItems.reduce((acc, it) => {
      const pWeight = Number(it.product_weight) || 0;
      const pkgWeight = Number(it.package_weight) || 0;
      const qty = Number(it.ordered_quantity) || 0;
      const w = pkgWeight > 0 ? pkgWeight : pWeight * qty;
      return acc + w;
    }, 0);

    return {
      ...sec,
      item_count: secItems.length,
      units_count: units,
      weight_kg: weight,
    };
  });
});

// Rates State: Invoice Total + Multiple Product Rates + Multiple Cargo Rates
const invoiceTotalInput = ref<string>('45200.00');
const totalCargoWeightInput = ref<string>('68.50');

interface ProductRateItem {
  id: number;
  amount: string;
  exchangeRate: string;
  notes: string;
}

interface CargoRateItem {
  id: number;
  amount: string;
  rate: string;
  description: string;
}

let rateSeq = 1;

const productRates = ref<ProductRateItem[]>([
  {
    id: rateSeq++,
    amount: '45200.00',
    exchangeRate: '17.50',
    notes: 'Bank TT Conversion',
  },
]);

const cargoRates = ref<CargoRateItem[]>([
  {
    id: rateSeq++,
    amount: '51375.00',
    rate: '750.00',
    description: 'Air Freight Cargo',
  },
]);

const addProductRate = () => {
  productRates.value.push({
    id: rateSeq++,
    amount: '',
    exchangeRate: '',
    notes: '',
  });
};

const removeProductRate = (index: number) => {
  if (productRates.value.length > 1) {
    productRates.value.splice(index, 1);
  }
};

const addCargoRate = () => {
  cargoRates.value.push({
    id: rateSeq++,
    amount: '',
    rate: '',
    description: '',
  });
};

const removeCargoRate = (index: number) => {
  if (cargoRates.value.length > 1) {
    cargoRates.value.splice(index, 1);
  }
};

const openSectionItems = (sectionId: number) => {
  const tenantSlug = route.params.tenantSlug;
  const sId = shipmentStore.currentShipment?.id || shipmentId;
  if (!sId) return;

  const query = { sectionId: String(sectionId) };

  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-items',
      params: { tenantSlug, id: sId },
      query,
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-items',
      params: { id: sId },
      query,
    });
  }
};

const openAddSection = () => {
  if (!shipmentId || isNaN(shipmentId)) return;
  $q.dialog({
    component: ShipmentSectionFormDialog,
    componentProps: {
      shipmentId,
    },
  }).onOk(() => {
    void (async () => {
      try {
        await shipmentStore.fetchShipmentDetails(shipmentId);
        showSuccessNotification('Section created');
      } catch (err: unknown) {
        showErrorNotification((err as Error).message || 'Failed to refresh sections');
      }
    })();
  });
};

const openEditSection = (section: ShipmentSection) => {
  if (!shipmentId || isNaN(shipmentId)) return;
  $q.dialog({
    component: ShipmentSectionFormDialog,
    componentProps: {
      shipmentId,
      section,
    },
  }).onOk(() => {
    void (async () => {
      try {
        await shipmentStore.fetchShipmentDetails(shipmentId);
        showSuccessNotification('Section updated');
      } catch (err: unknown) {
        showErrorNotification((err as Error).message || 'Failed to refresh sections');
      }
    })();
  });
};

const confirmDeleteSection = (section: ShipmentSection) => {
  if (sectionsWithCalculations.value.length <= 1) {
    showErrorNotification('A shipment must have at least one section.');
    return;
  }

  $q.dialog({
    title: 'Delete Section',
    message: `Are you sure you want to delete section "${section.title}"? Items in this section will become unassigned.`,
    cancel: true,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: false,
      unelevated: true,
    },
  }).onOk(() => {
    void (async () => {
      try {
        await shipmentStore.deleteSection(section.id);
        await shipmentStore.fetchShipmentDetails(shipmentId);
        showSuccessNotification('Section deleted');
      } catch (err: unknown) {
        showErrorNotification((err as Error).message || 'Failed to delete section');
      }
    })();
  });
};

const refreshShipmentData = async () => {
  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.fetchShipmentDetails(shipmentId);
      showSuccessNotification('Shipment data refreshed');
    } catch (err) {
      showErrorNotification((err as Error).message || 'Failed to refresh shipment data');
    }
  }
};

onMounted(async () => {
  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.fetchShipmentDetails(shipmentId);
    } catch (err) {
      console.error('Failed to load shipment details:', err);
    }
  }
});
</script>

<style scoped>
.shipment-overview-v2-page {
  min-height: calc(100vh - 55px);
  background-color: var(--bw-brand-base, #f8fafc);
}

.border-grey {
  border: 1px solid #e2e8f0;
}

.version-toggle {
  border-radius: 8px;
  overflow: hidden;
}

.rounded-btn {
  border-radius: 8px;
}

.rounded-borders {
  border-radius: 8px;
}

.name-display {
  padding: 2px 4px;
  border-radius: 4px;
  transition: background-color 0.15s ease;
}

.name-display:hover {
  background-color: #e2e8f0;
}

.name-display:hover .edit-icon {
  color: var(--q-primary) !important;
}

/* Left Navigation Items */
.nav-step-item {
  border-radius: 8px;
  transition: background-color 0.15s ease;
}

.nav-step-item:hover {
  background-color: #f1f5f9;
}

.nav-step-item.is-active {
  background-color: #eff6ff;
}

.nav-step-item.is-active :deep(.q-item__label) {
  color: var(--q-primary) !important;
}

/* Right Main Content Card */
.main-content-card {
  border-radius: 8px;
  min-height: 520px;
}

/* Section Card */
.section-card {
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  transition: all 0.15s ease-in-out;
}

.section-card:hover {
  background-color: #f1f5f9 !important;
  border-color: #cbd5e1;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04);
}

/* Rate Row */
.rate-card-row {
  border: 1px solid #e2e8f0;
}

.min-width-0 {
  min-width: 0;
}
</style>
