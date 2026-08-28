<template>
  <q-page class="shipment-items-v2-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Top Sticky Section: Shipment Name & Column Buttons -->
    <div class="shipment-items-top-section bg-white border-bottom q-px-md q-py-sm shrink-0">
      <div class="row items-center justify-between no-wrap">
        <!-- Left: Reactive Shipment Info -->
        <div class="row items-center q-gutter-x-sm no-wrap ellipsis">
          <span class="text-caption text-weight-bold text-grey-6 font-mono">
            {{ displayShipmentCode }}
          </span>
          <span class="text-grey-4">·</span>
          <div class="text-subtitle2 text-weight-bold text-grey-9 ellipsis">
            {{ drawerShipmentName || 'Untitled Shipment' }}
          </div>
          <q-badge
            rounded
            class="text-weight-bold text-capitalize q-ml-xs text-xxs"
            :color="getStatusColor(drawerShipmentStatus).color"
            :text-color="getStatusColor(drawerShipmentStatus).textColor"
          >
            {{ formatStatusLabel(drawerShipmentStatus) }}
          </q-badge>
        </div>

        <!-- Right: Header Buttons & Settings -->
        <div class="row items-center q-gutter-x-sm no-wrap">
          <!-- Selection Actions: Exactly 1 Item Selected -> Edit & Delete -->
          <template v-if="selectedItemIds.length === 1">
            <q-btn
              color="primary"
              icon="ph ph-pencil-simple"
              label="Edit"
              unelevated
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-sq-btn text-weight-bold"
              style="border-radius: 8px"
              @click="editSingleSelectedItem"
            >
              <q-tooltip>Edit selected item</q-tooltip>
            </q-btn>
            <q-btn
              color="negative"
              icon="ph ph-trash"
              label="Delete"
              outline
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-sq-btn text-weight-bold"
              style="border-radius: 8px"
              @click="deleteSingleSelectedItem"
            >
              <q-tooltip>Delete selected item</q-tooltip>
            </q-btn>
          </template>

          <!-- Selection Actions: Multiple Items Selected -> Bulk Delete -->
          <template v-else-if="selectedItemIds.length > 1">
            <q-btn
              color="negative"
              icon="ph ph-trash"
              :label="`Bulk Delete (${selectedItemIds.length})`"
              unelevated
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-sq-btn text-weight-bold"
              style="border-radius: 8px"
              @click="bulkDeleteSelectedItems"
            >
              <q-tooltip>Delete {{ selectedItemIds.length }} selected items</q-tooltip>
            </q-btn>
          </template>

          <!-- Add Items Button -->
          <q-btn
            outline
            dense
            no-caps
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-sm"
            icon="ph ph-plus"
            label="Add Items"
            size="sm"
            @click="triggerAddItems"
          >
            <q-tooltip>Add Items to Shipment</q-tooltip>
          </q-btn>

          <!-- Column Settings Dropdown Menu -->
          <q-btn
            flat
            dense
            no-caps
            color="grey-8"
            class="rounded-sq-btn text-weight-bold q-px-sm border-grey"
            icon="ph ph-sliders-horizontal"
            label="Columns"
            size="sm"
          >
            <q-menu>
              <q-list style="min-width: 220px" class="q-py-xs">
                <q-item>
                  <q-item-section>
                    <div class="text-subtitle2 text-weight-bold text-primary">Table Columns</div>
                  </q-item-section>
                </q-item>
                <q-item clickable @click="toggleSelectAllColumns">
                  <q-item-section>
                    <q-checkbox :model-value="allColumnsVisible" label="Select / Deselect All" />
                  </q-item-section>
                </q-item>
                <q-separator class="q-my-xs" />
                <q-item v-for="col in baseTableColumns" :key="col.name" clickable @click="visibleColumnMap[col.name] = !visibleColumnMap[col.name]">
                  <q-item-section>
                    <q-checkbox v-model="visibleColumnMap[col.name]" :label="col.label" />
                  </q-item-section>
                </q-item>
                <template v-if="customColumns.length">
                  <q-separator class="q-my-xs" />
                  <q-item-label header class="text-caption text-weight-bold text-grey-8 q-py-2xs">Custom Columns</q-item-label>
                  <q-item v-for="col in customColumns" :key="col.name" clickable @click="visibleColumnMap[col.name] = !visibleColumnMap[col.name]">
                    <q-item-section>
                      <q-checkbox v-model="visibleColumnMap[col.name]" :label="col.label" />
                    </q-item-section>
                  </q-item>
                </template>
              </q-list>
            </q-menu>
          </q-btn>

          <!-- Settings Gear Button (Opens Side Popup) -->
          <q-btn
            flat
            round
            dense
            color="grey-8"
            icon="ph ph-gear"
            size="sm"
            @click="settingsDrawerOpen = true"
          >
            <q-tooltip>Settings</q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <!-- Middle Scrollable Section: Clean Full-width V2 Table with Internal Horizontal Scroll -->
    <div
      ref="tableScrollContainerRef"
      class="shipment-items-middle-section col overflow-auto q-pa-none bg-white hide-native-scrollbar"
      style="overflow-x: auto; overflow-y: auto"
      @scroll="onTableScroll"
    >
      <q-markup-table flat class="shipment-items-markup-table bg-white" style="min-width: 1280px; width: 100%">
        <thead>
          <tr>
            <th class="text-center" style="width: 36px; min-width: 36px">
              <q-checkbox :model-value="allSelected" dense size="sm" @update:model-value="(val) => allSelected = !!val" />
            </th>
            <th class="text-right" style="width: 52px; min-width: 52px">SL</th>
            <th class="text-left" style="width: 90px; min-width: 90px">Image</th>
            <th v-if="visibleColumnMap.name" class="text-left" style="min-width: 180px; width: 260px; white-space: normal">Name</th>
            <th v-if="visibleColumnMap.product_codes" class="text-left" style="min-width: 120px; width: 130px">Codes</th>
            <th v-if="visibleColumnMap.purchase_price" class="text-center bw-ops-col-tint--price" style="min-width: 95px; width: 105px">
              Price {{ currentPurchaseCurrencySymbol }}
            </th>
            <th v-if="visibleColumnMap.cost_bdt" class="text-center bw-ops-col-tint--cost" style="min-width: 95px; width: 105px">
              Cost {{ currentCostCurrencySymbol }}
            </th>
            <th v-if="visibleColumnMap.ordered_quantity" class="text-center bw-ops-col-tint--qty" style="min-width: 85px; width: 95px">
              Qty
            </th>
            <th v-if="visibleColumnMap.product_weight" class="text-center" style="min-width: 85px; width: 95px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
              <div>Product</div>
              <div>Weight</div>
            </th>
            <th v-if="visibleColumnMap.package_weight" class="text-center bw-ops-col-tint--weight" style="min-width: 85px; width: 95px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
              <div>Package</div>
              <div>Weight</div>
            </th>
            <!-- Dynamically added custom columns -->
            <template v-for="col in customColumns" :key="col.name">
              <th v-if="visibleColumnMap[col.name]" class="text-left" style="min-width: 100px">{{ col.label }}</th>
            </template>
          </tr>
        </thead>
        <tbody>
          <template
            v-for="(item, index) in displayedItems"
            :key="item.id"
          >
            <!-- Section Header Break Row in All Items View -->
            <tr
              v-if="isFirstItemOfSection(item, index)"
              class="section-break-row bg-grey-2"
            >
              <td :colspan="totalVisibleColumnsCount" class="q-py-xs q-px-md text-weight-bold text-grey-9">
                <div class="row items-center justify-between">
                  <div class="row items-center q-gutter-x-sm">
                    <q-icon name="ph ph-folder-open" size="16px" color="primary" />
                    <span class="text-subtitle2 text-weight-bolder">{{ getSectionTitle(item.sectionId) }}</span>
                    <span class="text-caption text-grey-6 font-mono">• {{ getSectionVendor(item.sectionId) }}</span>
                    <q-badge color="grey-3" text-color="grey-8" class="text-weight-bold text-xxs">
                      {{ getSectionItemCount(item.sectionId) }} item<span v-if="getSectionItemCount(item.sectionId) > 1">s</span>
                    </q-badge>
                  </div>
                  <div class="row items-center q-gutter-x-md text-caption text-grey-7 font-mono">
                    <span>Units: <b>{{ getSectionTotalQty(item.sectionId) }}</b></span>
                    <span>Total: <b>{{ currentPurchaseCurrencySymbol }}{{ getSectionTotalPurchase(item.sectionId).toFixed(2) }}</b></span>
                  </div>
                </div>
              </td>
            </tr>

            <!-- Line Item Row -->
            <tr
              class="shipment-item-row cursor-pointer"
              :class="{ 'row-selected': item.selected }"
            >
              <!-- Select -->
              <td class="text-center" @click.stop>
                <q-checkbox
                  :model-value="item.selected"
                  dense
                  size="sm"
                  @update:model-value="(val) => toggleRowSelection(item.id, !!val)"
                />
              </td>

              <!-- SL with Move Buttons -->
              <td class="text-right text-weight-medium text-grey-7">
                <div class="row items-center justify-end no-wrap">
                  <span>{{ index + 1 }}</span>
                  <div class="column items-center justify-center q-ml-xs">
                    <q-btn
                      flat
                      round
                      dense
                      size="xs"
                      icon="ph ph-caret-up"
                      :disable="index === 0"
                      class="q-my-none"
                      style="height: 12px; min-height: 12px"
                      @click.stop="moveItem(index, 'up')"
                    />
                    <q-btn
                      flat
                      round
                      dense
                      size="xs"
                      icon="ph ph-caret-down"
                      :disable="index === displayedItems.length - 1"
                      class="q-my-none"
                      style="height: 12px; min-height: 12px"
                      @click.stop="moveItem(index, 'down')"
                    />
                  </div>
                </div>
              </td>

            <!-- Image (0.85 inch ≈ 82px) -->
            <td class="shipment-image-col">
              <q-avatar square size="82px" class="avatar-soft-sq bg-grey-2 border-grey overflow-hidden" style="width: 0.85in; height: 0.85in">
                <img :src="item.image" alt="item" style="object-fit: cover; width: 100%; height: 100%" />
              </q-avatar>
            </td>

            <!-- Name (Multiline Wrapped) -->
            <td v-if="visibleColumnMap.name" style="width: 260px; max-width: 280px; white-space: normal !important; word-break: break-word" @click="openEditItem(item.rawItem || item)">
              <div class="text-weight-bold text-grey-9 hover-underline" style="font-size: 13px; line-height: 1.35; word-break: break-word; white-space: normal">
                {{ item.name }}
              </div>
            </td>

            <!-- Product Codes with 1-click copy -->
            <td v-if="visibleColumnMap.product_codes" class="font-mono text-caption">
              <div class="column q-gutter-y-2xs" style="line-height: 1.1">
                <div v-if="item.code" class="row items-center justify-between no-wrap">
                  <div class="ellipsis">
                    <span class="text-grey-6 text-uppercase" style="font-size: 8px">C: </span>
                    <b class="text-dark" style="font-size: 10px">{{ item.code }}</b>
                  </div>
                  <q-btn
                    flat
                    dense
                    round
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-7"
                    style="font-size: 9px; padding: 0"
                    @click.stop="copyToClipboard(item.code, 'Product Code')"
                  >
                    <q-tooltip>Copy Code</q-tooltip>
                  </q-btn>
                </div>
                <div v-if="item.rawItem?.barcode" class="row items-center justify-between no-wrap">
                  <div class="ellipsis">
                    <span class="text-grey-6 text-uppercase" style="font-size: 8px">B: </span>
                    <span class="text-grey-9" style="font-size: 10px">{{ item.rawItem.barcode }}</span>
                  </div>
                  <q-btn
                    flat
                    dense
                    round
                    size="xs"
                    icon="ph ph-copy"
                    color="grey-7"
                    style="font-size: 9px; padding: 0"
                    @click.stop="copyToClipboard(item.rawItem.barcode, 'Barcode')"
                  >
                    <q-tooltip>Copy Barcode</q-tooltip>
                  </q-btn>
                </div>
              </div>
            </td>

            <!-- Purchase Price (Inline Editable) -->
            <td v-if="visibleColumnMap.purchase_price" class="text-center bw-ops-col-tint--price">
              <div class="row justify-center">
                <q-input
                  :model-value="getDraftValue(item, 'purchase_price')"
                  type="number"
                  step="0.01"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-edit-input"
                  style="max-width: 85px"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'purchase_price', val)"
                  @blur="saveDraftValue(item, 'purchase_price', { decimals: 2 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
              </div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-2xs" style="font-size: 10px">
                T: {{ currentPurchaseCurrencySymbol }}{{ ((item.price || 0) * (item.quantity || 0)).toFixed(2) }}
              </div>
            </td>

            <!-- Landed Cost -->
            <td v-if="visibleColumnMap.cost_bdt" class="text-center bw-ops-col-tint--cost">
              <div class="font-mono text-weight-bold text-primary" style="font-size: 12px">
                {{ currentCostCurrencySymbol }}{{ Number(item.cost / (item.quantity || 1) || 0).toFixed(2) }}
              </div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-2xs" style="font-size: 10px">
                T: {{ currentCostCurrencySymbol }}{{ Number(item.cost || 0).toLocaleString() }}
              </div>
            </td>

            <!-- Ordered Quantity (Inline Editable) -->
            <td v-if="visibleColumnMap.ordered_quantity" class="text-center bw-ops-col-tint--qty">
              <div class="row justify-center">
                <q-input
                  :model-value="getDraftValue(item, 'ordered_quantity')"
                  type="number"
                  min="1"
                  step="1"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-edit-input"
                  style="max-width: 75px"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'ordered_quantity', val)"
                  @blur="saveDraftValue(item, 'ordered_quantity')"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
              </div>
            </td>

            <!-- Product Weight (Inline Editable) -->
            <td v-if="visibleColumnMap.product_weight" class="text-center font-mono text-grey-8">
              <div class="row justify-center">
                <q-input
                  :model-value="getDraftValue(item, 'product_weight')"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-edit-input"
                  style="max-width: 85px"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'product_weight', val)"
                  @blur="saveDraftValue(item, 'product_weight', { decimals: 3 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
              </div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-2xs" style="font-size: 10px">
                T: {{ ((getDraftValue(item, 'product_weight') || 0.25) * (item.quantity || 0)).toFixed(2) }} kg
              </div>
            </td>

            <!-- Package Weight (Inline Editable) -->
            <td v-if="visibleColumnMap.package_weight" class="text-center bw-ops-col-tint--weight font-mono text-grey-8">
              <div class="row justify-center">
                <q-input
                  :model-value="getDraftValue(item, 'package_weight')"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  hide-bottom-space
                  class="bg-white rounded-borders inline-edit-input"
                  style="max-width: 85px"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'package_weight', val)"
                  @blur="saveDraftValue(item, 'package_weight', { decimals: 3 })"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
              </div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-2xs" style="font-size: 10px">
                T: {{ ((getDraftValue(item, 'package_weight') || 0.35) * (item.quantity || 0)).toFixed(2) }} kg
              </div>
            </td>

            <!-- Dynamically added custom column cells -->
            <template v-for="col in customColumns" :key="col.name">
              <td v-if="visibleColumnMap[col.name]" class="text-grey-7 font-mono text-caption">
                {{ (item as any)[col.name] || '-' }}
              </td>
            </template>
          </tr>
          </template>

          <!-- Empty State Row when shipment has 0 items -->
          <tr v-if="displayedItems.length === 0">
            <td :colspan="totalVisibleColumnsCount" class="text-center q-py-xl text-grey-6">
              <div class="column items-center justify-center q-py-lg">
                <q-icon name="ph ph-package" size="48px" class="text-grey-4 q-mb-sm" />
                <div class="text-subtitle1 text-weight-bold text-grey-8">No line items in this shipment</div>
                <div class="text-caption text-grey-6 q-mb-md">
                  Click the "+ Item" button in the toolbar above to search and add products from catalog.
                </div>
                <q-btn
                  color="primary"
                  icon="ph ph-plus"
                  label="Add First Item"
                  unelevated
                  no-caps
                  class="rounded-borders"
                  @click="triggerAddItems"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <!-- Bottom Sticky Section: Excel-style Dark Bar with Sheet Tabs & Right Horizontal Scrollbar -->
    <div class="shipment-items-bottom-section excel-bottom-bar shrink-0 row items-center no-wrap">
      <!-- Left: Navigation Scroll Arrows ( |<  <  >  >| ) -->
      <div class="row items-center no-wrap excel-left-nav">
        <button class="excel-icon-btn" title="First Sheet" @click="scrollToTab('start')">
          <q-icon name="ph ph-caret-line-left" size="15px" />
        </button>
        <button class="excel-icon-btn" title="Previous Sheet" @click="scrollTabs(-100)">
          <q-icon name="ph ph-caret-left" size="15px" />
        </button>
        <button class="excel-icon-btn" title="Next Sheet" @click="scrollTabs(100)">
          <q-icon name="ph ph-caret-right" size="15px" />
        </button>
        <button class="excel-icon-btn" title="Last Sheet" @click="scrollToTab('end')">
          <q-icon name="ph ph-caret-line-right" size="15px" />
        </button>
      </div>

      <!-- Sheet Tabs Container -->
      <div ref="tabsContainerRef" class="excel-tabs-scroll-container row items-center no-wrap">
        <div
          v-for="sheet in sheets"
          :key="sheet.id"
          class="excel-tab-item row items-center no-wrap cursor-pointer"
          :class="{ 'excel-tab-item--active': activeSheetId === sheet.id }"
          @click="activeSheetId = sheet.id"
        >
          <span class="excel-tab-label">{{ sheet.name }}</span>

          <!-- Right Click Context Menu -->
          <q-menu context-menu>
            <q-list dense style="min-width: 200px" class="q-py-xs">
              <!-- View Details Header Item (Read Only Summary) -->
              <q-item clickable v-ripple @click="openViewSectionDialog(sheet)">
                <q-item-section avatar style="min-width: 28px">
                  <q-icon name="ph ph-info" size="16px" color="primary" />
                </q-item-section>
                <q-item-section class="text-caption text-weight-medium">View Details</q-item-section>
              </q-item>

              <q-item clickable v-ripple @click="openEditSectionDialog(sheet)">
                <q-item-section avatar style="min-width: 28px">
                  <q-icon name="ph ph-pencil-simple" size="16px" color="grey-8" />
                </q-item-section>
                <q-item-section class="text-caption text-weight-medium">Edit Details</q-item-section>
              </q-item>

              <q-separator class="q-my-xs" />

              <q-item
                clickable
                v-ripple
                :disable="sheets.length <= 1"
                class="text-negative"
                @click="removeSheet(sheet.id)"
              >
                <q-item-section avatar style="min-width: 28px">
                  <q-icon name="ph ph-trash" size="16px" color="negative" />
                </q-item-section>
                <q-item-section class="text-caption text-weight-medium">Delete Section</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </div>
      </div>

      <!-- Plus Button for Add New Section / Invoice Sheet -->
      <button class="excel-icon-btn excel-plus-btn q-mr-sm" title="Add Section / Invoice" @click="openAddSectionDialog">
        <q-icon name="ph ph-plus" size="16px" />
      </button>

      <!-- Splitter / Divider Bar -->
      <div class="excel-splitter-bar" />

      <!-- Right Side Horizontal Scrollbar Track & Thumb -->
      <div class="excel-scrollbar-wrapper col row items-center no-wrap">
        <!-- Scrollbar Left End Arrow -->
        <button class="excel-scroll-arrow-btn" @click="scrollTableByStep(-120)">
          <q-icon name="ph ph-caret-left" size="13px" />
        </button>

        <!-- Scrollbar Track & Thumb -->
        <div
          ref="scrollTrackRef"
          class="excel-scroll-track col cursor-pointer"
          @click="onTrackClick"
        >
          <div
            class="excel-scroll-thumb"
            :style="{ width: scrollThumbWidth + '%', left: scrollThumbLeft + '%' }"
            @mousedown="startThumbDrag"
          />
        </div>

        <!-- Scrollbar Right End Arrow -->
        <button class="excel-scroll-arrow-btn" @click="scrollTableByStep(120)">
          <q-icon name="ph ph-caret-right" size="13px" />
        </button>

        <div class="excel-end-cap" />
      </div>
    </div>

    <!-- Right Side Settings Popup with Tabs -->
    <q-dialog
      v-model="settingsDrawerOpen"
      position="right"
      transition-show="jump-left"
      transition-hide="jump-right"
    >
      <q-card
        class="column no-wrap bg-white q-ma-md rounded-borders-lg overflow-hidden shadow-10"
        style="width: 520px; max-width: 95vw; height: calc(100vh - 32px); border-radius: 16px"
      >
        <!-- Top Tabs Bar (Labels only) -->
        <div class="bg-grey-1 border-bottom q-px-sm">
          <q-tabs
            v-model="activeDrawerTab"
            dense
            no-caps
            active-color="primary"
            indicator-color="primary"
            align="justify"
            class="text-grey-7 text-weight-medium"
          >
            <q-tab name="details" label="Details" />
            <q-tab name="summary" label="Summary" />
            <q-tab name="rates" label="Rates" />
            <q-tab name="status" label="Status" />
          </q-tabs>
        </div>

        <!-- Tab Panels (Blank bodies ready for content) -->
        <q-tab-panels v-model="activeDrawerTab" animated class="col bg-white">
          <!-- Details Tab Panel (Name, Type, Cargo, Primary Vendor) -->
          <q-tab-panel name="details" class="q-pa-md bg-white">
            <div class="column q-gutter-y-md">
              <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
                <q-icon name="ph ph-identification-badge" size="18px" color="primary" />
                <span>General Information</span>
              </div>

              <!-- 1. Shipment Name Input -->
              <div>
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Shipment Name</div>
                <q-input
                  v-model="drawerShipmentName"
                  outlined
                  dense
                  placeholder="e.g. Inbound Shipment #89 - Summer Collection"
                  class="bg-white"
                  :loading="updatingName"
                  @blur="saveShipmentName"
                  @keyup.enter="saveShipmentName"
                >
                  <template #prepend>
                    <q-icon name="ph ph-tag" size="18px" color="grey-6" />
                  </template>
                </q-input>
              </div>

              <!-- 2. Shipment Type Select -->
              <div>
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Shipment Type</div>
                <q-select
                  v-model="drawerShipmentType"
                  :options="drawerTypeOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  class="bg-white"
                  @update:model-value="saveShipmentType"
                >
                  <template #prepend>
                    <q-icon name="ph ph-globe" size="18px" color="grey-6" />
                  </template>
                </q-select>
              </div>

              <!-- 3. Cargo Company Select -->
              <div>
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Cargo Company</div>
                <q-select
                  v-model="drawerCargoId"
                  :options="cargoOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  clearable
                  placeholder="Select Cargo Company"
                  class="bg-white"
                  @update:model-value="saveShipmentCargo"
                >
                  <template #prepend>
                    <q-icon name="ph ph-airplane-tilt" size="18px" color="grey-6" />
                  </template>
                </q-select>
              </div>

              <!-- 4. Primary Vendor Select -->
              <div>
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Primary Vendor</div>
                <q-select
                  v-model="drawerVendorId"
                  :options="vendorOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  clearable
                  placeholder="Select Primary Vendor"
                  class="bg-white"
                  @update:model-value="saveShipmentVendor"
                >
                  <template #prepend>
                    <q-icon name="ph ph-storefront" size="18px" color="grey-6" />
                  </template>
                </q-select>
              </div>

              <!-- 5. Customer Status Mode Selector -->
              <div>
                <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Customer Status Mode</div>
                <q-select
                  v-model="drawerCustomerStatusMode"
                  :options="customerStatusModeOptions"
                  emit-value
                  map-options
                  outlined
                  dense
                  class="bg-white"
                  @update:model-value="saveShipmentCustomerStatusMode"
                >
                  <template #prepend>
                    <q-icon name="ph ph-user-circle" size="18px" color="grey-6" />
                  </template>
                </q-select>
                <div class="text-caption text-grey-6 text-xxs q-mt-xs">
                  Controls how shipment journey updates are displayed to customers.
                </div>
              </div>
            </div>
          </q-tab-panel>

          <!-- Summary Tab Panel (Landed Cost Summary) -->
          <q-tab-panel name="summary" class="q-pa-md bg-white">
            <div class="column q-gutter-y-md">
              <div class="row items-center justify-between">
                <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
                  <q-icon name="ph ph-receipt" size="18px" color="primary" />
                  <span>Landed Cost Summary</span>
                </div>
                <q-chip dense square color="blue-1" text-color="primary" class="text-weight-bold text-xxs q-ma-none">
                  Live Calculations
                </q-chip>
              </div>

              <!-- 1. Shipment Physical Totals -->
              <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
                <div class="text-xxs text-weight-bold text-grey-6 uppercase q-mb-xs" style="letter-spacing: 0.5px">
                  Physical Quantities & Weight
                </div>
                <div class="row justify-between q-py-xs text-caption">
                  <span class="text-grey-7">Total Units:</span>
                  <span class="text-weight-bold font-mono text-grey-9">
                    {{ totals.quantity.toLocaleString() }} pcs
                  </span>
                </div>
                <div class="row justify-between q-py-xs text-caption">
                  <span class="text-grey-7">Packaging Weight:</span>
                  <span class="text-weight-bold font-mono text-grey-9">
                    {{ totals.packagingWeightKg.toFixed(2) }} kg
                  </span>
                </div>
                <div class="row justify-between q-py-xs text-caption">
                  <span class="text-grey-7">Invoice Cargo Weight:</span>
                  <span class="text-weight-bold font-mono text-primary">
                    {{ (totals.cargoWeightKg || 0).toFixed(2) }} kg
                  </span>
                </div>
                <div class="row justify-between q-py-xs text-caption">
                  <span class="text-grey-7">Box Weight Sum:</span>
                  <span class="text-weight-bold font-mono text-grey-9">
                    {{ currentShipmentBoxesTotal.toFixed(2) }} kg
                  </span>
                </div>
              </div>

              <!-- 2. Purchase Currency Breakdown -->
              <div class="q-gutter-y-xs">
                <div class="text-xxs text-weight-bold text-grey-6 uppercase" style="letter-spacing: 0.5px">
                  Purchase Currency ({{ currentPurchaseCurrencySymbol }} {{ currentPurchaseCurrency?.code || 'GBP' }})
                </div>
                <div class="row justify-between q-py-xs text-caption">
                  <span class="text-grey-7">Product Purchase Cost:</span>
                  <span class="text-weight-bold font-mono text-grey-9">
                    {{ currentPurchaseCurrencySymbol }}{{ totals.goodsPurchase.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                  </span>
                </div>
                <div class="row justify-between q-py-xs text-caption">
                  <span class="text-grey-7">Cargo Freight Cost:</span>
                  <span class="text-weight-bold font-mono text-grey-9">
                    {{ currentPurchaseCurrencySymbol }}{{ totals.cargoPurchase.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                  </span>
                </div>
                <div class="row justify-between q-py-xs bg-grey-1 q-px-sm rounded-borders text-caption">
                  <span class="text-weight-bold text-grey-8">Total Purchase Cost:</span>
                  <span class="text-weight-bold font-mono text-primary">
                    {{ currentPurchaseCurrencySymbol }}{{ totals.totalPurchase.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                  </span>
                </div>
              </div>

              <q-separator />

              <!-- 3. Landed Cost Currency Breakdown -->
              <div class="q-gutter-y-xs">
                <div class="text-xxs text-weight-bold text-grey-6 uppercase" style="letter-spacing: 0.5px">
                  Cost Currency ({{ currentCostCurrencySymbol }} {{ currentCostCurrency?.code || 'BDT' }})
                </div>
                <div class="row justify-between q-py-xs text-caption">
                  <span class="text-grey-7">Product Landed Cost:</span>
                  <span class="text-weight-bold font-mono text-grey-9">
                    {{ currentCostCurrencySymbol }}{{ totals.goodsCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                  </span>
                </div>
                <div class="row justify-between q-py-xs text-caption">
                  <span class="text-grey-7">Cargo Landed Cost:</span>
                  <span class="text-weight-bold font-mono text-grey-9">
                    {{ currentCostCurrencySymbol }}{{ totals.cargoCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                  </span>
                </div>
                <div class="row justify-between items-center q-pa-sm bg-primary text-white rounded-borders">
                  <span class="text-subtitle2 text-weight-bold">Total Landed Cost:</span>
                  <span class="text-subtitle1 text-weight-bolder font-mono">
                    {{ currentCostCurrencySymbol }}{{ totals.totalCost.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
                  </span>
                </div>
              </div>

              <!-- 4. Live Blended Rate -->
              <div class="bg-blue-1 text-blue-10 q-pa-sm rounded-borders text-center border-grey">
                <div class="text-xxs text-weight-bold uppercase" style="letter-spacing: 0.5px">
                  Live Blended Transaction Rate
                </div>
                <div class="text-h6 text-weight-bolder font-mono q-my-xs text-primary">
                  <template v-if="totals.transactionRate != null">
                    {{ currentCostCurrencySymbol }}{{ totals.transactionRate.toFixed(4) }} / {{ currentPurchaseCurrencySymbol }}
                  </template>
                  <template v-else>
                    —
                  </template>
                </div>
                <div class="text-caption text-blue-9 text-xxs">
                  Weighted by product exchange & cargo conversion
                </div>
              </div>
            </div>
          </q-tab-panel>

          <!-- Rates Tab Panel (Total Weight, Cargo, Product) -->
          <q-tab-panel name="rates" class="q-pa-md bg-white">
            <div class="column q-gutter-y-lg">
              <!-- 1. Total Weight Section -->
              <div>
                <div class="text-caption text-weight-bold text-grey-7 text-uppercase q-mb-xs" style="letter-spacing: 0.5px">
                  Total Weight
                </div>
                <q-input
                  v-model.number="totalWeightInput"
                  label="Total Weight"
                  type="number"
                  outlined
                  dense
                  placeholder="0.00"
                  suffix="kg"
                  class="bg-white font-mono"
                  :loading="savingRates"
                  @blur="saveRates"
                >
                  <template #prepend>
                    <q-icon name="ph ph-scales" size="18px" color="grey-6" />
                  </template>
                </q-input>
              </div>

              <q-separator />

              <!-- 2. Cargo Rates Section -->
              <div class="column q-gutter-y-sm">
                <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                  Cargo
                </div>

                <div class="q-pa-sm bg-grey-1 rounded-borders border-grey column q-gutter-y-sm">
                  <div class="row q-col-gutter-sm">
                    <!-- Amount -->
                    <div class="col-6">
                      <q-input
                        v-model.number="cargoAmountInput"
                        label="Amount"
                        type="number"
                        dense
                        outlined
                        placeholder="0.00"
                        :prefix="currentPurchaseCurrencySymbol"
                        class="bg-white font-mono"
                        :loading="savingRates"
                        @blur="saveRates"
                      />
                    </div>

                    <!-- Rate -->
                    <div class="col-6">
                      <q-input
                        v-model.number="cargoRateInput"
                        label="Rate"
                        type="number"
                        dense
                        outlined
                        placeholder="0.00"
                        :prefix="currentCostCurrencySymbol"
                        class="bg-white font-mono"
                        :loading="savingRates"
                        @blur="saveRates"
                      />
                    </div>
                  </div>

                  <!-- Note -->
                  <div>
                    <q-input
                      v-model="cargoNoteInput"
                      label="Note"
                      dense
                      outlined
                      placeholder="e.g. Air freight per kg rate & handling charges"
                      class="bg-white"
                      @blur="saveRates"
                    />
                  </div>
                </div>
              </div>

              <q-separator />

              <!-- 3. Product Rates Section -->
              <div class="column q-gutter-y-sm">
                <div class="row items-center justify-between">
                  <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                    Product
                  </div>
                  <q-btn
                    outline
                    dense
                    no-caps
                    size="xs"
                    color="primary"
                    icon="ph ph-plus"
                    label="Add Rate"
                    class="q-px-sm rounded-btn text-weight-bold"
                    @click="addProductRateRow"
                  />
                </div>

                <div class="column q-gutter-y-sm">
                  <div
                    v-for="(prodRate, idx) in productRatesList"
                    :key="prodRate.id"
                    class="q-pa-sm bg-grey-1 rounded-borders border-grey column q-gutter-y-sm"
                  >
                    <div class="row items-center justify-between">
                      <span class="text-caption text-weight-bold text-grey-8">Rate #{{ idx + 1 }}</span>
                      <q-btn
                        v-if="productRatesList.length > 1"
                        flat
                        round
                        dense
                        size="xs"
                        icon="ph ph-trash"
                        color="negative"
                        @click="removeProductRateRow(idx)"
                      >
                        <q-tooltip>Remove Rate</q-tooltip>
                      </q-btn>
                    </div>

                    <div class="row q-col-gutter-sm">
                      <!-- Amount -->
                      <div class="col-6">
                        <q-input
                          v-model.number="prodRate.amount"
                          label="Amount"
                          type="number"
                          dense
                          outlined
                          placeholder="0.00"
                          :prefix="currentPurchaseCurrencySymbol"
                          class="bg-white font-mono"
                          :loading="savingRates"
                          @blur="saveRates"
                        />
                      </div>

                      <!-- Rate -->
                      <div class="col-6">
                        <q-input
                          v-model.number="prodRate.rate"
                          label="Rate"
                          type="number"
                          dense
                          outlined
                          placeholder="0.00"
                          :prefix="currentCostCurrencySymbol"
                          class="bg-white font-mono"
                          :loading="savingRates"
                          @blur="saveRates"
                        />
                      </div>
                    </div>

                    <!-- Note -->
                    <div>
                      <q-input
                        v-model="prodRate.note"
                        label="Note"
                        dense
                        outlined
                        placeholder="e.g. Bank TT, cash conversion, vendor balance"
                        class="bg-white"
                        @blur="saveRates"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </q-tab-panel>

          <!-- Status Tab Panel (Shipment Status & Customer Status) -->
          <q-tab-panel name="status" class="q-pa-md bg-white">
            <div class="column q-gutter-y-lg">
              <!-- 1. Internal Shipment Status -->
              <div class="column q-gutter-y-sm">
                <div class="row items-center justify-between">
                  <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                    Shipment Status (Internal)
                  </div>
                  <q-chip
                    dense
                    square
                    :color="getStatusColor(drawerShipmentStatus).color"
                    :text-color="getStatusColor(drawerShipmentStatus).textColor"
                    class="text-weight-bold text-capitalize text-xxs q-ma-none soft-chip"
                  >
                    {{ drawerShipmentStatus }}
                  </q-chip>
                </div>

                <div class="q-pa-sm bg-grey-1 rounded-borders border-grey">
                  <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Update Operational Status</div>
                  <q-select
                    v-model="drawerShipmentStatus"
                    :options="internalShipmentStatusOptions"
                    emit-value
                    map-options
                    outlined
                    dense
                    class="bg-white"
                    @update:model-value="saveShipmentStatus"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-truck" size="18px" color="grey-6" />
                    </template>
                  </q-select>
                  <div class="text-caption text-grey-6 text-xxs q-mt-xs">
                    Current internal operational and warehouse processing status.
                  </div>
                </div>
              </div>

              <q-separator />

              <!-- 2. Customer Tracking Status -->
              <div class="column q-gutter-y-sm">
                <div class="row items-center justify-between">
                  <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.5px">
                    Customer Tracking Status
                  </div>
                  <q-chip
                    dense
                    square
                    color="cyan-1"
                    text-color="cyan-9"
                    class="text-weight-bold text-xxs q-ma-none soft-chip"
                  >
                    Mode: {{ drawerCustomerStatusMode === 'auto' ? 'Auto-synced' : 'Custom Manual' }}
                  </q-chip>
                </div>

                <div class="q-pa-sm bg-grey-1 rounded-borders border-grey">
                  <q-select
                    v-model="drawerCustomerStatus"
                    label="Customer Facing Stage"
                    :options="customerStatusOptions"
                    emit-value
                    map-options
                    outlined
                    dense
                    class="bg-white"
                    :disable="drawerCustomerStatusMode === 'auto'"
                    @update:model-value="saveCustomerStatus"
                  >
                    <template #prepend>
                      <q-icon name="ph ph-users" size="18px" color="grey-6" />
                    </template>
                  </q-select>
                  <div v-if="drawerCustomerStatusMode === 'auto'" class="text-caption text-grey-6 text-xxs q-mt-xs">
                    In auto mode, customer tracking automatically mirrors internal stages.
                  </div>
                </div>
              </div>
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </q-card>
    </q-dialog>

    <!-- Add / Edit Section / Invoice Sheet Dialog -->
    <q-dialog v-model="showAddSectionDialog" persistent>
      <q-card style="width: 520px; max-width: 95vw; border-radius: 12px" class="bg-white">
        <q-form @submit="saveSectionSheet">
          <!-- Dialog Header -->
          <div class="row items-center justify-between q-pa-md border-bottom bg-grey-1">
            <div class="row items-center q-gutter-x-sm">
              <q-icon name="ph ph-receipt" size="20px" color="primary" />
              <div class="text-subtitle1 text-weight-bold text-grey-9">
                {{ isEditingSection ? 'Edit Section / Invoice Details' : 'New Section / Invoice Sheet' }}
              </div>
            </div>
            <q-btn flat round dense icon="ph ph-x" size="sm" color="grey-7" v-close-popup />
          </div>

          <!-- Dialog Body -->
          <div class="q-pa-md column q-gutter-y-sm">
            <!-- Section Name -->
            <q-input
              v-model="newSectionForm.title"
              label="Section / Sheet Name *"
              outlined
              dense
              placeholder="e.g. Silk Dresses / Batch A"
              :rules="[(val) => !!val?.trim() || 'Section name is required']"
              autofocus
            >
              <template #prepend>
                <q-icon name="ph ph-folder" size="18px" color="grey-6" />
              </template>
            </q-input>

            <!-- Invoice Number & Date -->
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="newSectionForm.invoiceNumber"
                  label="Invoice Number"
                  outlined
                  dense
                  placeholder="e.g. INV-2026-088"
                >
                  <template #prepend>
                    <q-icon name="ph ph-hash" size="18px" color="grey-6" />
                  </template>
                </q-input>
              </div>

              <div class="col-12 col-sm-6">
                <q-input
                  v-model="newSectionForm.invoiceDate"
                  label="Invoice Date"
                  outlined
                  dense
                  readonly
                  clearable
                >
                  <template #prepend>
                    <q-icon name="ph ph-calendar" size="18px" color="grey-6" />
                  </template>
                  <template #append>
                    <q-icon name="ph ph-calendar-plus" class="cursor-pointer" size="18px">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-date v-model="newSectionForm.invoiceDate" mask="YYYY-MM-DD">
                          <div class="row items-center justify-end">
                            <q-btn v-close-popup label="Done" color="primary" flat />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
              </div>
            </div>

            <!-- Notes -->
            <q-input
              v-model="newSectionForm.notes"
              label="Notes / Comments"
              outlined
              dense
              type="textarea"
              rows="2"
              placeholder="Packing details, custom invoice instructions..."
            />
          </div>

          <!-- Dialog Actions -->
          <div class="row justify-end q-pa-md border-top bg-grey-1 q-gutter-x-sm">
            <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
            <q-btn
              type="submit"
              unelevated
              no-caps
              :label="isEditingSection ? 'Save Changes' : 'Create Sheet'"
              color="primary"
              class="rounded-sq-btn text-weight-bold q-px-md"
              style="border-radius: 8px"
            />
          </div>
        </q-form>
      </q-card>
    </q-dialog>

    <!-- View Section / Invoice Details Modal -->
    <q-dialog v-model="showViewSectionDialog">
      <q-card style="width: 480px; max-width: 95vw; border-radius: 12px" class="bg-white">
        <!-- Dialog Header -->
        <div class="row items-center justify-between q-pa-md border-bottom bg-grey-1">
          <div class="row items-center q-gutter-x-sm">
            <q-icon name="ph ph-info" size="20px" color="primary" />
            <div class="text-subtitle1 text-weight-bold text-grey-9">Section / Invoice Details</div>
          </div>
          <q-btn flat round dense icon="ph ph-x" size="sm" color="grey-7" v-close-popup />
        </div>

        <!-- Dialog Body -->
        <div class="q-pa-md column q-gutter-y-sm">
          <!-- Section / Sheet Name -->
          <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
            <div class="text-caption text-weight-medium text-grey-6">Section / Sheet Name</div>
            <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-2xs">
              {{ viewingSectionData.name || 'Untitled Section' }}
            </div>
          </div>

          <!-- Invoice Number & Date -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
                <div class="text-caption text-weight-medium text-grey-6">Invoice Number</div>
                <div class="text-subtitle2 font-mono text-weight-bold text-grey-9 q-mt-2xs">
                  {{ viewingSectionData.invoiceNumber || '—' }}
                </div>
              </div>
            </div>

            <div class="col-12 col-sm-6">
              <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
                <div class="text-caption text-weight-medium text-grey-6">Invoice Date</div>
                <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-2xs">
                  {{ viewingSectionData.invoiceDate || '—' }}
                </div>
              </div>
            </div>
          </div>

          <!-- Notes -->
          <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
            <div class="text-caption text-weight-medium text-grey-6">Notes / Comments</div>
            <div class="text-body2 text-grey-8 q-mt-2xs" style="white-space: pre-wrap">
              {{ viewingSectionData.notes || 'No special notes entered for this invoice section.' }}
            </div>
          </div>
        </div>

        <!-- Dialog Footer -->
        <div class="row justify-between items-center q-pa-md border-top bg-grey-1">
          <q-btn
            flat
            no-caps
            color="primary"
            icon="ph ph-pencil-simple"
            label="Edit Details"
            @click="switchToEditFromView"
          />
          <q-btn flat no-caps label="Close" color="grey-7" v-close-popup />
        </div>
      </q-card>
    </q-dialog>

    <!-- Add Custom Column Dialog -->
    <q-dialog v-model="showAddColumnDialog">
      <q-card style="width: 420px; max-width: 95vw; border-radius: 12px" class="bg-white">
        <q-form @submit="addCustomColumn">
          <div class="row items-center justify-between q-pa-md border-bottom bg-grey-1">
            <div class="row items-center q-gutter-x-sm">
              <q-icon name="ph ph-columns" size="20px" color="primary" />
              <div class="text-subtitle1 text-weight-bold text-grey-9">Add Custom Column</div>
            </div>
            <q-btn flat round dense icon="ph ph-x" size="sm" color="grey-7" v-close-popup />
          </div>

          <div class="q-pa-md column q-gutter-y-sm">
            <q-input
              v-model="newColumnName"
              label="Column Name / Header *"
              outlined
              dense
              placeholder="e.g. Fabric Details / Color Code"
              :rules="[(val) => !!val?.trim() || 'Column name is required']"
              autofocus
            >
              <template #prepend>
                <q-icon name="ph ph-text-t" size="18px" color="grey-6" />
              </template>
            </q-input>

            <q-select
              v-model="newColumnType"
              label="Data Type"
              :options="[
                { label: 'Text', value: 'text' },
                { label: 'Number / Currency', value: 'number' },
                { label: 'Date', value: 'date' }
              ]"
              emit-value
              map-options
              outlined
              dense
            >
              <template #prepend>
                <q-icon name="ph ph-faders" size="18px" color="grey-6" />
              </template>
            </q-select>
          </div>

          <div class="row justify-end q-pa-md border-top bg-grey-1 q-gutter-x-sm">
            <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
            <q-btn
              type="submit"
              unelevated
              no-caps
              label="Add Column"
              color="primary"
              class="rounded-sq-btn text-weight-bold q-px-md"
              style="border-radius: 8px"
            />
          </div>
        </q-form>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { useCargoCompaniesQuery } from '../composables/useProcurementStockQuery';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import AddShipmentItemsDrawer from '../components/AddShipmentItemsDrawer.vue';
import ShipmentItemFormDialog from '../components/ShipmentItemFormDialog.vue';
import ShipmentLineItemsTable, { type ColumnKey } from '../components/ShipmentLineItemsTable.vue';
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { useInboundShipmentActions } from '../composables/useInboundShipmentActions';

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('lines');
const calculations = useInboundShipmentCalculations();
const actions = useInboundShipmentActions({
  shipmentId,
  activeTab,
  calculations,
});

const {
  shipmentForLiveCosting,
  availableColumnOptions,
  visibleColumns: baseVisibleColumns,
  currentPurchaseCurrency,
  currentPurchaseCurrencySymbol,
  currentCostCurrency,
  currentCostCurrencySymbol,
  totals,
  currentShipmentBoxesTotal,
  shipmentCargoWeightKg,
  hasCargoInvoiceWeight,
} = calculations;

const {
  openEditItem,
  confirmDeleteItem,
} = actions;

const activeVisibleColumns = computed<ColumnKey[]>(() => {
  return baseTableColumns
    .filter((col) => visibleColumnMap[col.name])
    .map((col) => col.name as ColumnKey);
});

const rawDisplayedItems = computed(() => {
  const storeItems = shipmentStore.currentShipmentItems ?? [];
  const activeSection = sheets.value.find((s) => s.id === activeSheetId.value);
  const activeSectionDbId = activeSection?.dbId;
  if (activeSectionDbId != null) {
    return storeItems.filter((it) => it.section_id === activeSectionDbId);
  }
  return storeItems;
});

const settingsDrawerOpen = ref(false);
const activeDrawerTab = ref('details');

const triggerAddItems = () => {
  const activeSection = sheets.value.find((s) => s.id === activeSheetId.value);
  const activeSectionDbId = activeSection?.dbId ?? null;

  if (shipmentId && !isNaN(shipmentId)) {
    $q.dialog({
      component: AddShipmentItemsDrawer,
      componentProps: {
        shipmentId,
        initialSectionId: activeSectionDbId,
      },
    });
  }
};

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const currentTenantId = computed(() => authStore.tenantId);
const { data: cargoData } = useCargoCompaniesQuery(currentTenantId);

const cargoCompanies = computed(() => cargoData.value ?? []);

const cargoOptions = computed(() =>
  cargoCompanies.value.map((c) => ({
    label: `${c.name} (${c.code})`,
    value: c.id,
  })),
);

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({
    label: v.is_default ? `${v.name} (default)` : v.name,
    value: v.id,
  })),
);

// Drawer Details Form State
const drawerShipmentName = ref('');
const drawerShipmentType = ref<'international' | 'local' | 'transfer'>('international');
const drawerCargoId = ref<number | null>(null);
const drawerVendorId = ref<number | null>(null);
const drawerCustomerStatusMode = ref<'auto' | 'custom'>('auto');
const drawerShipmentStatus = ref('draft');
const updatingName = ref(false);

// Sync store shipment into drawer and headers
watch(
  () => shipmentStore.currentShipment,
  (shipment) => {
    if (shipment) {
      if (shipment.name) drawerShipmentName.value = shipment.name;
      if (shipment.type) drawerShipmentType.value = shipment.type;
      if (shipment.status) drawerShipmentStatus.value = shipment.status;
      if (shipment.cargo_company_id) drawerCargoId.value = shipment.cargo_company_id;
      if (shipment.vendor_id) drawerVendorId.value = shipment.vendor_id;
    }
  },
  { immediate: true },
);

const saveShipmentName = async () => {
  if (!shipmentId || isNaN(shipmentId)) return;
  const trimmed = drawerShipmentName.value.trim();
  if (!trimmed || trimmed === shipmentStore.currentShipment?.name) return;

  updatingName.value = true;
  try {
    await shipmentStore.updateShipment(shipmentId, { name: trimmed });
    showSuccessNotification('Shipment name updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update shipment name');
    drawerShipmentName.value = shipmentStore.currentShipment?.name || '';
  } finally {
    updatingName.value = false;
  }
};

const saveShipmentType = async (val: string) => {
  if (!shipmentId || isNaN(shipmentId) || !val) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { type: val as any });
    showSuccessNotification('Shipment type updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update shipment type');
  }
};

const saveShipmentCargo = async (val: number | null) => {
  if (!shipmentId || isNaN(shipmentId)) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { cargo_company_id: val });
    showSuccessNotification('Cargo company updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update cargo');
  }
};

const saveShipmentVendor = async (val: number | null) => {
  if (!shipmentId || isNaN(shipmentId)) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { vendor_id: val });
    showSuccessNotification('Primary vendor updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update vendor');
  }
};

const saveShipmentCustomerStatusMode = async (val: 'auto' | 'custom') => {
  if (!shipmentId || isNaN(shipmentId) || !val) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { customer_status_mode: val } as any);
    showSuccessNotification('Customer status mode updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update customer status mode');
  }
};

const saveShipmentStatus = async (val: string) => {
  if (!shipmentId || isNaN(shipmentId) || !val) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { status: val as any });
    await shipmentStore.fetchShipmentDetails(shipmentId);
    showSuccessNotification(`Shipment status updated to ${val}`);
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update shipment status');
  }
};

const saveCustomerStatus = async (val: string) => {
  if (!shipmentId || isNaN(shipmentId) || !val) return;
  try {
    await shipmentStore.updateShipment(shipmentId, { customer_tracking_status: val } as any);
    showSuccessNotification(`Customer tracking updated to ${val}`);
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to update customer status');
  }
};

const customerStatusModeOptions = [
  { label: 'Auto (Follows Shipment Stages)', value: 'auto' },
  { label: 'Custom Manual Status', value: 'custom' },
];
const internalShipmentStatusOptions = [
  { label: 'Draft', value: 'draft' },
  { label: 'In Transit', value: 'in_transit' },
  { label: 'Received', value: 'received' },
  { label: 'Cancelled', value: 'cancelled' },
];

const drawerCustomerStatus = ref('in_transit');

const customerStatusOptions = [
  { label: 'Order Placed & Confirmed', value: 'confirmed' },
  { label: 'Sourced from Supplier', value: 'sourced' },
  { label: 'Packed at Origin Warehouse', value: 'packed' },
  { label: 'In International Transit', value: 'in_transit' },
  { label: 'Customs Processing', value: 'customs' },
  { label: 'Arrived at Local Hub', value: 'local_hub' },
  { label: 'Ready for Delivery / Pickup', value: 'ready' },
  { label: 'Delivered', value: 'delivered' },
];

// Drawer Rates Form State & Sync with Store Cost Entries
const totalWeightInput = ref<number | null>(null);
const cargoAmountInput = ref<number | null>(null);
const cargoRateInput = ref<number | null>(null);
const cargoNoteInput = ref('');
const savingRates = ref(false);

interface ProductRateItem {
  id: string;
  dbId?: number | null;
  amount: number | null;
  rate: number | null;
  note: string;
}

const productRatesList = ref<ProductRateItem[]>([]);

const syncRatesFromStore = () => {
  const ship = shipmentStore.currentShipment;
  const entries = shipmentStore.currentCostEntries || [];

  // Total weight
  totalWeightInput.value =
    ship?.total_weight_kg ??
    ship?.received_weight ??
    null;

  // Cargo entry
  const cargoEntry = entries.find((e: any) => e.cost_type === 'cargo');
  if (cargoEntry) {
    cargoAmountInput.value = cargoEntry.amount != null ? Number(cargoEntry.amount) : null;
    cargoRateInput.value = cargoEntry.exchange_rate != null ? Number(cargoEntry.exchange_rate) : null;
    const meta = (cargoEntry.metadata as Record<string, unknown> | null) ?? {};
    cargoNoteInput.value = typeof meta.note === 'string' ? meta.note : '';
  } else {
    cargoAmountInput.value = null;
    cargoRateInput.value = null;
    cargoNoteInput.value = '';
  }

  // Product entries
  const prodEntries = entries.filter((e: any) => e.cost_type === 'product');
  if (prodEntries.length > 0) {
    productRatesList.value = prodEntries.map((pe: any) => {
      const meta = (pe.metadata as Record<string, unknown> | null) ?? {};
      return {
        id: `db_${pe.id}`,
        dbId: pe.id,
        amount: pe.amount != null ? Number(pe.amount) : null,
        rate: pe.exchange_rate != null ? Number(pe.exchange_rate) : null,
        note: typeof meta.note === 'string' ? meta.note : '',
      };
    });
  } else {
    productRatesList.value = [
      {
        id: 'rate_default',
        dbId: null,
        amount: null,
        rate: null,
        note: '',
      },
    ];
  }
};

watch(
  () => [shipmentStore.currentShipment, shipmentStore.currentCostEntries],
  () => {
    if (!savingRates.value) {
      syncRatesFromStore();
    }
  },
  { immediate: true, deep: true },
);

const addProductRateRow = () => {
  productRatesList.value.push({
    id: `rate_${Date.now()}`,
    dbId: null,
    amount: null,
    rate: null,
    note: '',
  });
};

const removeProductRateRow = async (index: number) => {
  if (productRatesList.value.length > 1) {
    productRatesList.value.splice(index, 1);
    await saveRates();
  }
};

const saveRates = async () => {
  if (!shipmentId || isNaN(shipmentId) || savingRates.value) return;

  savingRates.value = true;
  try {
    // 1. Update total cargo weight if modified
    const currentWeight = shipmentStore.currentShipment?.total_weight_kg ?? shipmentStore.currentShipment?.received_weight;
    if (totalWeightInput.value !== currentWeight) {
      await shipmentStore.updateShipment(shipmentId, {
        total_weight_kg: totalWeightInput.value != null ? Number(totalWeightInput.value) : null,
        received_weight: totalWeightInput.value != null ? Number(totalWeightInput.value) : null,
      });
    }

    // 2. Prepare drafts for cost entries
    const drafts: any[] = [];
    const ship = shipmentStore.currentShipment;

    // Cargo draft
    if (cargoAmountInput.value != null || cargoRateInput.value != null || cargoNoteInput.value.trim()) {
      const existingCargo = (shipmentStore.currentCostEntries || []).find((e: any) => e.cost_type === 'cargo');
      drafts.push({
        id: existingCargo?.id ?? null,
        cost_type: 'cargo',
        amount: Number(cargoAmountInput.value) || 0,
        exchange_rate: Number(cargoRateInput.value) || 1,
        payment_source: null,
        entity_type: ship?.cargo_company_id ? 'cargo_company' : null,
        entity_id: ship?.cargo_company_id ?? null,
        per_kg_rate: null,
        note: cargoNoteInput.value.trim() || null,
        section_id: null,
      });
    }

    // Product drafts
    for (const pr of productRatesList.value) {
      if (pr.amount != null || pr.rate != null || pr.note.trim()) {
        drafts.push({
          id: pr.dbId ?? null,
          cost_type: 'product',
          amount: Number(pr.amount) || 0,
          exchange_rate: Number(pr.rate) || 1,
          payment_source: null,
          entity_type: ship?.vendor_id ? 'vendor' : null,
          entity_id: ship?.vendor_id ?? null,
          per_kg_rate: null,
          note: pr.note.trim() || null,
          section_id: null,
        });
      }
    }

    if (drafts.length > 0) {
      await shipmentStore.saveCostEntries(shipmentId, drafts);
    }

    showSuccessNotification('Rates & weights updated');
  } catch (err: unknown) {
    showErrorNotification((err as Error)?.message || 'Failed to save rates');
  } finally {
    savingRates.value = false;
  }
};

const drawerTypeOptions = [
  { label: 'International', value: 'international' },
  { label: 'Local', value: 'local' },
  { label: 'Transfer', value: 'transfer' },
];

const baseTableColumns = [
  { name: 'name', label: 'Product Name' },
  { name: 'product_codes', label: 'Codes / Identifiers' },
  { name: 'purchase_price', label: 'Purchase Price' },
  { name: 'cost_bdt', label: 'Landed Cost' },
  { name: 'ordered_quantity', label: 'Ordered Quantity' },
  { name: 'product_weight', label: 'Product Weight' },
  { name: 'package_weight', label: 'Package Weight' },
];

const visibleColumnMap = reactive<Record<string, boolean>>({
  name: true,
  product_codes: true,
  section: true,
  purchase_price: true,
  cost_bdt: true,
  ordered_quantity: true,
  product_weight: true,
  package_weight: true,
  actions: true,
});

const allColumnsVisible = computed(() => {
  const allNames = [...baseTableColumns.map((c) => c.name), ...customColumns.value.map((c) => c.name)];
  return allNames.length > 0 && allNames.every((n) => visibleColumnMap[n]);
});

const toggleSelectAllColumns = () => {
  const willShow = !allColumnsVisible.value;
  baseTableColumns.forEach((c) => {
    visibleColumnMap[c.name] = willShow;
  });
  customColumns.value.forEach((c) => {
    visibleColumnMap[c.name] = willShow;
  });
};

const showAddColumnDialog = ref(false);
const newColumnName = ref('');
const newColumnType = ref('text');

const customColumns = ref<Array<{ name: string; label: string; type: string }>>([]);

const addCustomColumn = () => {
  const trimmed = newColumnName.value.trim();
  if (!trimmed) return;
  const colKey = `custom_${Date.now()}`;
  customColumns.value.push({
    name: colKey,
    label: trimmed,
    type: newColumnType.value,
  });
  visibleColumnMap[colKey] = true;
  newColumnName.value = '';
  newColumnType.value = 'text';
  showAddColumnDialog.value = false;
};

const selectedItemIds = ref<number[]>([]);

// Get section / vendor lookup helpers
const getSectionTitle = (sectionId?: number | null) => {
  if (!sectionId) return 'Main Order';
  const found = shipmentStore.currentShipmentSections.find((s) => s.id === sectionId);
  return found?.title || `Section #${sectionId}`;
};

const getSectionVendor = (sectionId?: number | null) => {
  if (!sectionId) {
    const primaryVendorId = shipmentStore.currentShipment?.vendor_id;
    if (primaryVendorId) {
      const v = vendorStore.items.find((v) => v.id === primaryVendorId);
      if (v) return v.name;
    }
    return 'Primary Vendor';
  }
  const found = shipmentStore.currentShipmentSections.find((s) => s.id === sectionId);
  return found?.vendor?.name || 'Primary Vendor';
};

const totalVisibleColumnsCount = computed(() => {
  let count = 3; // checkbox, SL, image
  if (visibleColumnMap.name) count++;
  if (visibleColumnMap.product_codes) count++;
  if (visibleColumnMap.purchase_price) count++;
  if (visibleColumnMap.cost_bdt) count++;
  if (visibleColumnMap.ordered_quantity) count++;
  if (visibleColumnMap.product_weight) count++;
  if (visibleColumnMap.package_weight) count++;
  for (const col of customColumns.value) {
    if (visibleColumnMap[col.name]) count++;
  }
  return count;
});

const isFirstItemOfSection = (item: any, index: number) => {
  // Only show section break headers when viewing 'All Items' and there are sections defined
  if (activeSheetId.value !== 'sheet_all') return false;
  if (!shipmentStore.currentShipmentSections || shipmentStore.currentShipmentSections.length <= 1) return false;
  if (index === 0) return true;
  const prevItem = displayedItems.value[index - 1];
  return (prevItem as any)?.sectionId !== item.sectionId;
};

const getSectionItemCount = (sectionId?: number | null) => {
  const items = shipmentStore.currentShipmentItems || [];
  return items.filter((it) => (it.section_id ?? null) === (sectionId ?? null)).length;
};

const getSectionTotalQty = (sectionId?: number | null) => {
  const items = shipmentStore.currentShipmentItems || [];
  return items
    .filter((it) => (it.section_id ?? null) === (sectionId ?? null))
    .reduce((sum, it) => sum + (Number(it.ordered_quantity) || 0), 0);
};

const getSectionTotalPurchase = (sectionId?: number | null) => {
  const items = shipmentStore.currentShipmentItems || [];
  return items
    .filter((it) => (it.section_id ?? null) === (sectionId ?? null))
    .reduce((sum, it) => sum + (Number(it.purchase_price) || 0) * (Number(it.ordered_quantity) || 0), 0);
};

// Dynamic table rows connected to live store items with dummy fallback
const displayedItems = computed(() => {
  const storeItems = shipmentStore.currentShipmentItems;
  if (storeItems && storeItems.length > 0) {
    // Filter by active sheet if a specific section is selected
    const activeSection = sheets.value.find((s) => s.id === activeSheetId.value);
    const activeSectionDbId = activeSection?.dbId;

    let filtered = storeItems;
    if (activeSectionDbId != null) {
      filtered = storeItems.filter((it) => it.section_id === activeSectionDbId);
    }

    return filtered.map((item, idx) => {
      const pPrice = Number(item.purchase_price) || 0;
      const oQty = Number(item.ordered_quantity) || 0;
      const unitCost = Number(item.unit_cost_bdt) || Number(item.unit_landed_cost) || pPrice * 15;
      const totalCost = Number(item.cost_bdt) || unitCost * oQty;
      const vendorName = getSectionVendor(item.section_id);
      const vendorInitials = vendorName
        .split(' ')
        .map((w) => w[0])
        .join('')
        .slice(0, 2)
        .toUpperCase();

      return {
        id: item.id || idx + 1,
        selected: selectedItemIds.value.includes(item.id),
        name: item.name || 'Unnamed Product',
        code: item.product_code || item.barcode || `ITEM-${item.id}`,
        category: getSectionTitle(item.section_id),
        sectionId: item.section_id ?? null,
        vendor: vendorName,
        vendorInitials: vendorInitials || 'PV',
        quantity: oQty,
        price: pPrice,
        cost: totalCost,
        status: item.is_received ? 'received' : drawerShipmentStatus.value || 'in_transit',
        image: item.image_url || 'https://images.unsplash.com/photo-1601924994987-69e26d50dc26?w=100&auto=format&fit=crop&q=60',
        rawItem: item,
      };
    });
  }

  return [];
});

const allSelected = computed({
  get: () => displayedItems.value.length > 0 && displayedItems.value.every((i) => i.selected),
  set: (val: boolean) => {
    if (val) {
      selectedItemIds.value = displayedItems.value.map((i) => i.id);
    } else {
      selectedItemIds.value = [];
    }
  },
});

// Inline Draft Edit State & Handlers
const draftValues = reactive<Record<string, any>>({});
const activeSaves = new Set<string>();

const getDraftValue = (item: any, field: string) => {
  const key = `${item.id}_${field}`;
  if (key in draftValues) return draftValues[key];
  if (item.rawItem && field in item.rawItem) return item.rawItem[field];
  if (field === 'purchase_price') return item.price;
  if (field === 'ordered_quantity') return item.quantity;
  if (field === 'product_weight') return 0.25;
  if (field === 'package_weight') return 0.35;
  return item[field] ?? '';
};

const setDraftValue = (item: any, field: string, value: any) => {
  const key = `${item.id}_${field}`;
  draftValues[key] = value;
};

const saveDraftValue = async (item: any, field: string, options?: { decimals?: number }) => {
  const key = `${item.id}_${field}`;
  if (!(key in draftValues)) return;
  const rawVal = draftValues[key];
  let normalized = rawVal === '' || rawVal == null ? null : Number(rawVal);
  if (normalized != null && options?.decimals != null && !isNaN(normalized)) {
    normalized = Number(normalized.toFixed(options.decimals));
  }

  // Update local item immediately
  if (field === 'purchase_price') item.price = normalized ?? 0;
  if (field === 'ordered_quantity') item.quantity = normalized ?? 0;
  if (item.rawItem) item.rawItem[field] = normalized;

  if (shipmentId && item.rawItem?.id) {
    if (activeSaves.has(key)) return;
    activeSaves.add(key);
    try {
      await shipmentStore.updateShipmentItem(item.rawItem.id, { [field]: normalized });
      $q.notify({
        message: `Updated ${field.replace('_', ' ')}`,
        color: 'positive',
        icon: 'ph ph-check-circle',
        timeout: 1000,
      });
    } catch (err) {
      $q.notify({
        message: 'Failed to update item',
        color: 'negative',
        icon: 'ph ph-warning-circle',
      });
    } finally {
      activeSaves.delete(key);
    }
  }
};

const copyToClipboard = (text: any, label: string) => {
  if (!text) return;
  void navigator.clipboard.writeText(String(text));
  $q.notify({
    message: `Copied ${label} to clipboard`,
    color: 'positive',
    icon: 'ph ph-copy',
    timeout: 1000,
  });
};

const moveItem = async (index: number, direction: 'up' | 'down') => {
  const targetIndex = direction === 'up' ? index - 1 : index + 1;
  const items = shipmentStore.currentShipmentItems || [];
  if (targetIndex < 0 || targetIndex >= items.length) return;

  if (shipmentId && !isNaN(shipmentId)) {
    const reordered = [...items];
    const temp = reordered[index];
    reordered[index] = reordered[targetIndex];
    reordered[targetIndex] = temp;

    const itemsOrder = reordered.map((item, idx) => ({
      id: item.id,
      sort_order: idx * 10,
    }));
    try {
      await shipmentStore.reorderShipmentItems(shipmentId, itemsOrder);
      await shipmentStore.fetchShipmentDetails(shipmentId);
    } catch (err: unknown) {
      console.error('Failed to reorder items', err);
    }
  }
};

const editSingleSelectedItem = () => {
  if (selectedItemIds.value.length !== 1) return;
  const targetId = selectedItemIds.value[0];
  const item = (shipmentStore.currentShipmentItems ?? []).find((it) => it.id === targetId);
  if (item) {
    openEditItem(item);
  }
};

const deleteSingleSelectedItem = () => {
  if (selectedItemIds.value.length !== 1) return;
  const targetId = selectedItemIds.value[0];
  if (targetId != null) {
    confirmDeleteItem(targetId);
    selectedItemIds.value = [];
  }
};

const bulkDeleteSelectedItems = () => {
  if (selectedItemIds.value.length === 0) return;
  const count = selectedItemIds.value.length;
  $q.dialog({
    title: 'Confirm Bulk Deletion',
    message: `Are you sure you want to delete ${count} selected item${count === 1 ? '' : 's'}?`,
    cancel: true,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: true,
    },
  }).onOk(() => {
    void (async () => {
      if (shipmentId && !isNaN(shipmentId)) {
        try {
          await shipmentStore.deleteShipmentItemsBulk(shipmentId, selectedItemIds.value);
          $q.notify({
            message: `Deleted ${count} items successfully`,
            color: 'positive',
            icon: 'ph ph-check-circle',
          });
          selectedItemIds.value = [];
        } catch (err: unknown) {
          $q.notify({
            message: (err as Error).message || 'Failed to delete items',
            color: 'negative',
            icon: 'ph ph-warning-circle',
          });
        }
      }
    })();
  });
};

// Excel Sheets Management: sync backend sections into sheets
interface SheetTabItem {
  id: string;
  name: string;
  dbId?: number;
  invoiceNumber?: string;
  invoiceDate?: string;
  notes?: string;
}

const tabsContainerRef = ref<HTMLElement | null>(null);
const tableScrollContainerRef = ref<HTMLElement | null>(null);
const scrollTrackRef = ref<HTMLElement | null>(null);

const activeSheetId = ref('sheet_all');
const sheets = ref<SheetTabItem[]>([
  { id: 'sheet_all', name: 'All Items' },
]);

watch(
  () => shipmentStore.currentShipmentSections,
  (sections) => {
    if (sections && sections.length > 0) {
      const generated: SheetTabItem[] = [
        { id: 'sheet_all', name: 'All Items' },
        ...sections.map((sec) => ({
          id: `section_${sec.id}`,
          dbId: sec.id,
          name: sec.title || `Section #${sec.id}`,
          invoiceNumber: (sec as any).invoice_number || sec.metadata?.invoice_number || '',
          invoiceDate: (sec as any).invoice_date || sec.metadata?.invoice_date || '',
          notes: (sec as any).notes || sec.metadata?.notes || '',
        })),
      ];
      sheets.value = generated;
      if (!generated.some((s) => s.id === activeSheetId.value)) {
        activeSheetId.value = 'sheet_all';
      }
    }
  },
  { immediate: true },
);

const scrollThumbWidth = ref(30);
const scrollThumbLeft = ref(0);

// Sync scrollbar thumb position when table scrolls
const updateScrollbarFromTable = () => {
  const el = tableScrollContainerRef.value;
  if (!el) return;
  const maxScrollLeft = el.scrollWidth - el.clientWidth;
  if (maxScrollLeft <= 0) {
    scrollThumbWidth.value = 100;
    scrollThumbLeft.value = 0;
    return;
  }
  const ratio = el.clientWidth / el.scrollWidth;
  const thumbWidthPct = Math.max(15, Math.min(80, ratio * 100));
  scrollThumbWidth.value = thumbWidthPct;
  const scrollFraction = el.scrollLeft / maxScrollLeft;
  const availableTrackPct = 100 - thumbWidthPct;
  scrollThumbLeft.value = scrollFraction * availableTrackPct;
};

const onTableScroll = () => {
  updateScrollbarFromTable();
};

onMounted(() => {
  if (shipmentId && !isNaN(shipmentId)) {
    void shipmentStore.fetchShipmentDetails(shipmentId);
  }
  updateScrollbarFromTable();
  window.addEventListener('resize', updateScrollbarFromTable);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateScrollbarFromTable);
});

// Scroll table by clicking arrows
const scrollTableByStep = (delta: number) => {
  if (tableScrollContainerRef.value) {
    tableScrollContainerRef.value.scrollBy({ left: delta, behavior: 'smooth' });
  }
};

// Click directly on track to jump
const onTrackClick = (e: MouseEvent) => {
  const track = scrollTrackRef.value;
  const table = tableScrollContainerRef.value;
  if (!track || !table) return;
  const rect = track.getBoundingClientRect();
  const clickX = e.clientX - rect.left;
  const trackWidth = rect.width;
  const fraction = Math.max(0, Math.min(1, clickX / trackWidth));
  const maxScrollLeft = table.scrollWidth - table.clientWidth;
  table.scrollTo({ left: fraction * maxScrollLeft, behavior: 'smooth' });
};

// Drag scrollbar thumb
const startThumbDrag = (e: MouseEvent) => {
  e.preventDefault();
  e.stopPropagation();
  const track = scrollTrackRef.value;
  const table = tableScrollContainerRef.value;
  if (!track || !table) return;

  const startX = e.clientX;
  const startScrollLeft = table.scrollLeft;
  const trackRect = track.getBoundingClientRect();
  const availableTrackWidth = trackRect.width * (1 - scrollThumbWidth.value / 100);
  const maxScrollLeft = table.scrollWidth - table.clientWidth;

  const onMouseMove = (moveEvent: MouseEvent) => {
    if (availableTrackWidth <= 0) return;
    const deltaX = moveEvent.clientX - startX;
    const deltaScroll = (deltaX / availableTrackWidth) * maxScrollLeft;
    table.scrollLeft = Math.max(0, Math.min(maxScrollLeft, startScrollLeft + deltaScroll));
  };

  const onMouseUp = () => {
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mouseup', onMouseUp);
  };

  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
};

const scrollTabs = (offset: number) => {
  if (tabsContainerRef.value) {
    tabsContainerRef.value.scrollBy({ left: offset, behavior: 'smooth' });
  }
};

const scrollToTab = (pos: 'start' | 'end') => {
  if (tabsContainerRef.value) {
    tabsContainerRef.value.scrollTo({
      left: pos === 'start' ? 0 : tabsContainerRef.value.scrollWidth,
      behavior: 'smooth',
    });
  }
};

// Sheet / Section State & Management
const showAddSectionDialog = ref(false);
const showViewSectionDialog = ref(false);
const isEditingSection = ref(false);
const editingSheetId = ref<string | null>(null);

const viewingSectionData = ref<{
  id: string;
  name: string;
  invoiceNumber?: string;
  invoiceDate?: string;
  notes?: string;
}>({
  id: '',
  name: '',
});

const newSectionForm = reactive({
  title: '',
  invoiceNumber: '',
  invoiceDate: '',
  notes: '',
});

const openViewSectionDialog = (sheet: { id: string; name: string; invoiceNumber?: string; invoiceDate?: string; notes?: string }) => {
  viewingSectionData.value = { ...sheet };
  showViewSectionDialog.value = true;
};

const switchToEditFromView = () => {
  showViewSectionDialog.value = false;
  openEditSectionDialog(viewingSectionData.value);
};

const openAddSectionDialog = () => {
  isEditingSection.value = false;
  editingSheetId.value = null;
  newSectionForm.title = `Invoice Section ${sheets.value.length + 1}`;
  newSectionForm.invoiceNumber = '';
  newSectionForm.invoiceDate = '';
  newSectionForm.notes = '';
  showAddSectionDialog.value = true;
};

const openEditSectionDialog = (sheet: { id: string; name: string; invoiceNumber?: string; invoiceDate?: string; notes?: string }) => {
  isEditingSection.value = true;
  editingSheetId.value = sheet.id;
  newSectionForm.title = sheet.name;
  newSectionForm.invoiceNumber = sheet.invoiceNumber || '';
  newSectionForm.invoiceDate = sheet.invoiceDate || '';
  newSectionForm.notes = sheet.notes || '';
  showAddSectionDialog.value = true;
};

const saveSectionSheet = async () => {
  const trimmed = newSectionForm.title.trim();
  if (!trimmed) return;

  if (isEditingSection.value && editingSheetId.value) {
    const target = sheets.value.find((s) => s.id === editingSheetId.value);
    if (target) {
      target.name = trimmed;
      target.invoiceNumber = newSectionForm.invoiceNumber;
      target.invoiceDate = newSectionForm.invoiceDate;
      target.notes = newSectionForm.notes;

      if (shipmentId && target.dbId) {
        try {
          await shipmentStore.updateShipmentSection(target.dbId, {
            title: trimmed,
            invoice_number: newSectionForm.invoiceNumber || undefined,
            invoice_date: newSectionForm.invoiceDate || undefined,
            notes: newSectionForm.notes || undefined,
          });
          await shipmentStore.fetchShipmentDetails(shipmentId);
        } catch (err: unknown) {
          console.error('Failed to update section in DB', err);
        }
      }
    }
  } else {
    let createdDbId: number | undefined;
    if (shipmentId && !isNaN(shipmentId)) {
      try {
        const created = await shipmentStore.createShipmentSection(shipmentId, {
          title: trimmed,
          invoice_number: newSectionForm.invoiceNumber || undefined,
          invoice_date: newSectionForm.invoiceDate || undefined,
          notes: newSectionForm.notes || undefined,
        });
        createdDbId = created?.id;
        await shipmentStore.fetchShipmentDetails(shipmentId);
      } catch (err: unknown) {
        console.error('Failed to create section in DB', err);
      }
    }

    const newId = createdDbId ? `section_${createdDbId}` : `section_${Date.now()}`;
    sheets.value.push({
      id: newId,
      dbId: createdDbId,
      name: trimmed,
      invoiceNumber: newSectionForm.invoiceNumber,
      invoiceDate: newSectionForm.invoiceDate,
      notes: newSectionForm.notes,
    });
    activeSheetId.value = newId;
    setTimeout(() => scrollToTab('end'), 50);
  }

  showAddSectionDialog.value = false;
};

const addDummySheet = () => {
  openAddSectionDialog();
};

const removeSheet = async (id: string) => {
  const target = sheets.value.find((s) => s.id === id);
  if (!target) return;

  if (shipmentId && target.dbId) {
    try {
      await shipmentStore.deleteShipmentSection(target.dbId);
      await shipmentStore.fetchShipmentDetails(shipmentId);
    } catch (err: unknown) {
      console.error('Failed to delete section in DB', err);
    }
  }

  const idx = sheets.value.findIndex((s) => s.id === id);
  if (idx !== -1) {
    sheets.value.splice(idx, 1);
    if (activeSheetId.value === id && sheets.value.length > 0) {
      activeSheetId.value = sheets.value[Math.max(0, idx - 1)].id;
    }
  }
};

const displayShipmentCode = computed(() => {
  const codeNum = shipmentStore.currentShipment?.tenant_shipment_id ?? shipmentId;
  if (codeNum && !isNaN(codeNum)) {
    return `#SHP-${String(codeNum).padStart(4, '0')}`;
  }
  return 'Shipment';
});

const formatStatusLabel = (status: string) => {
  switch (status) {
    case 'in_transit':
      return 'In Transit';
    case 'customs':
      return 'Customs';
    case 'received':
      return 'Received';
    case 'allocated':
      return 'Allocated';
    case 'completed':
      return 'Completed';
    case 'ordered':
      return 'Ordered';
    case 'draft':
      return 'Draft';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status ? status.replace(/_/g, ' ') : 'Draft';
  }
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'received':
    case 'completed':
      return { color: 'positive', textColor: 'white' };
    case 'in_transit':
      return { color: 'warning', textColor: 'dark' };
    case 'customs':
      return { color: 'purple-6', textColor: 'white' };
    case 'allocated':
      return { color: 'indigo-6', textColor: 'white' };
    case 'ordered':
      return { color: 'blue-6', textColor: 'white' };
    case 'cancelled':
      return { color: 'negative', textColor: 'white' };
    case 'draft':
    case 'pending':
    default:
      return { color: 'grey-4', textColor: 'grey-9' };
  }
};
</script>

<style scoped>
.section-break-row {
  background: #f1f5f9 !important;
  border-top: 2px solid #cbd5e1 !important;
  border-bottom: 1px solid #cbd5e1 !important;
  user-select: none;
}
.section-break-row td {
  background: #f1f5f9 !important;
  height: 38px !important;
}
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-top {
  border-top: 1px solid #e2e8f0;
}
.border-grey {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.shrink-0 {
  flex-shrink: 0;
}
.h-full {
  height: 100%;
}
.avatar-soft-sq {
  border-radius: 6px;
}
.soft-chip {
  border-radius: 6px;
  font-size: 11px;
}
.text-xxs {
  font-size: 11px;
}
.line-clamp-1 {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.font-mono {
  font-family: monospace;
}
.min-width-auto {
  min-width: auto;
}
.hide-native-scrollbar {
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE 10+ */
}
.hide-native-scrollbar::-webkit-scrollbar {
  display: none; /* Chrome/Safari */
}

:deep(.shipment-table-scroll-wrap) {
  overflow: visible !important;
}

.shipment-items-markup-table th.bw-ops-col-tint--price,
.shipment-items-markup-table td.bw-ops-col-tint--price {
  background-color: #daf3e4 !important;
  box-shadow: inset 2px 0 0 #059669;
}

.shipment-items-markup-table th.bw-ops-col-tint--cost,
.shipment-items-markup-table td.bw-ops-col-tint--cost {
  background-color: #ffe8d1 !important;
  box-shadow: inset 2px 0 0 #ea580c;
}

.shipment-items-markup-table th.bw-ops-col-tint--qty,
.shipment-items-markup-table td.bw-ops-col-tint--qty {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

.shipment-items-markup-table th.bw-ops-col-tint--weight,
.shipment-items-markup-table td.bw-ops-col-tint--weight {
  background-color: #e8d7f7 !important;
  box-shadow: inset 2px 0 0 #9333ea;
}

.shipment-items-markup-table tr.row-selected td {
  background-color: #e0f2fe !important;
}

.shipment-items-markup-table tr:hover td {
  filter: brightness(0.98);
}

/* Hide number input spinners (increment and decrement arrows) */
:deep(.inline-edit-input input[type='number']::-webkit-outer-spin-button),
:deep(.inline-edit-input input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(.inline-edit-input input[type='number']) {
  -moz-appearance: textfield;
  appearance: textfield;
}

:deep(.inline-edit-input .q-field__control) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 4px !important;
}

:deep(.inline-edit-input input) {
  padding: 0 !important;
  height: 26px !important;
  font-size: 12px;
}

/* Excel Style Light Bottom Bar */
.excel-bottom-bar {
  height: 36px;
  min-height: 36px;
  background-color: #f8fafc;
  color: #475569;
  border-top: 1px solid #cbd5e1;
  padding: 0 8px;
  user-select: none;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

.excel-left-nav {
  display: flex;
  align-items: center;
  gap: 2px;
}

.excel-icon-btn {
  background: transparent;
  border: none;
  color: #64748b;
  padding: 4px 6px;
  cursor: pointer;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 26px;
  min-width: 24px;
  transition: all 0.15s;
}

.excel-icon-btn:hover {
  background: #e2e8f0;
  color: #1e293b;
}

.excel-plus-btn {
  color: #475569;
  margin-left: 4px;
}

.excel-tabs-scroll-container {
  overflow-x: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
  display: flex;
  align-items: center;
  height: 100%;
}
.excel-tabs-scroll-container::-webkit-scrollbar {
  display: none;
}

.excel-tab-item {
  height: 36px;
  padding: 0 16px;
  color: #64748b;
  font-size: 13px;
  border-bottom: 3px solid transparent;
  transition: all 0.15s;
}

.excel-tab-item:hover {
  color: #1e293b;
  background-color: #e2e8f0;
}

.excel-tab-item--active {
  color: #059669; /* Emerald text */
  border-bottom: 3px solid #059669;
  background-color: #ffffff;
  font-weight: 600;
}

.excel-tab-label {
  white-space: nowrap;
}

.excel-tab-close {
  opacity: 0.5;
  cursor: pointer;
}
.excel-tab-close:hover {
  opacity: 1;
  color: #ef4444;
}

/* Excel Splitter Bar between tabs and right scrollbar */
.excel-splitter-bar {
  width: 5px;
  height: 20px;
  background: #cbd5e1;
  border-radius: 2px;
  margin: 0 10px;
  cursor: col-resize;
}

/* Excel Right Scrollbar */
.excel-scrollbar-wrapper {
  background-color: #f8fafc;
  height: 24px;
  display: flex;
  align-items: center;
  gap: 3px;
}

.excel-scroll-arrow-btn {
  background: #ffffff;
  border: 1px solid #cbd5e1;
  color: #64748b;
  height: 20px;
  width: 20px;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 3px;
  transition: all 0.15s;
}

.excel-scroll-arrow-btn:hover {
  background: #e2e8f0;
  color: #0f172a;
}

.excel-scroll-track {
  height: 14px;
  background-color: #e2e8f0;
  border: 1px solid #cbd5e1;
  border-radius: 7px;
  position: relative;
  overflow: hidden;
  margin: 0 4px;
}

.excel-scroll-thumb {
  position: absolute;
  top: 0;
  height: 100%;
  background-color: #94a3b8;
  border-radius: 7px;
  cursor: pointer;
}

.excel-scroll-thumb:hover {
  background-color: #64748b;
}

.excel-end-cap {
  width: 3px;
  height: 18px;
  background-color: #cbd5e1;
  margin-left: 2px;
}
</style>
