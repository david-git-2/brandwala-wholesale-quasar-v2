<template>
  <q-page class="shipment-items-v2-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Top Sticky Section: Shipment Name, Status Workflow & Actions -->
    <div class="shipment-items-top-section bg-white border-bottom q-px-lg q-py-md shrink-0 shadow-xs">
      <div class="row items-center justify-between q-gutter-y-sm wrap">
        <!-- Left: Name + Status Workflow -->
        <div class="col-grow row items-center q-gutter-md wrap" style="min-width: 0">
          <div class="text-subtitle1 text-weight-bolder text-grey-9 ellipsis" style="font-size: 15px">
            {{ shipmentStore.currentShipment?.name || 'Untitled Shipment' }}
          </div>
          <ShipmentStatusWorkflowBar
            class="shipment-header-workflow"
            :status="shipmentStore.currentShipment?.status ?? 'draft'"
            :updating="updatingStatus"
            :target-status="targetUpdatingStatus"
            @update-status="changeStatus"
          />
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

          <!-- Add Items Button (Disabled on 'All Items' tab) -->
          <q-btn
            outline
            dense
            no-caps
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-sm"
            icon="ph ph-plus"
            label="Add Items"
            size="sm"
            :disable="activeSheetId === 'sheet_all'"
            @click="triggerAddItems"
          >
            <q-tooltip>
              {{ activeSheetId === 'sheet_all' ? 'Select a specific section tab below to add items' : 'Add Items to current Section' }}
            </q-tooltip>
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
            @click="openSettingsDrawer('details')"
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
      <q-markup-table flat class="shipment-items-markup-table bg-white" style="min-width: 1080px; width: 100%">
        <thead>
          <tr>
            <th class="text-center q-pa-none" style="width: 18px; min-width: 18px">
              <q-checkbox :model-value="allSelected" dense size="xs" @update:model-value="(val) => allSelected = !!val" />
            </th>
            <th class="text-center q-pa-none" style="width: 36px; min-width: 36px; max-width: 36px">SL</th>
            <th class="text-left" style="width: 82px; min-width: 82px">Image</th>
            <th v-if="visibleColumnMap.name" class="text-left" style="min-width: 120px; width: 120px; max-width: 120px; white-space: normal">Name</th>
            <th v-if="visibleColumnMap.product_codes" class="text-left" style="min-width: 105px; width: 115px">Codes</th>
            <th v-if="visibleColumnMap.purchase_price" class="text-center bw-ops-col-tint--price" style="min-width: 56px; width: 56px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <span>Price {{ currentPurchaseCurrencySymbol }}</span>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('purchase_price')"
                >
                  <q-tooltip>Bulk Paste Price</q-tooltip>
                </q-btn>
              </div>
            </th>
            <th v-if="visibleColumnMap.cost_bdt" class="text-center bw-ops-col-tint--cost" style="min-width: 56px; width: 56px">
              Cost
            </th>
            <th v-if="visibleColumnMap.ordered_quantity" class="text-center bw-ops-col-tint--qty" style="min-width: 56px; width: 56px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <span>Qty</span>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('ordered_quantity')"
                >
                  <q-tooltip>Bulk Paste Quantity</q-tooltip>
                </q-btn>
              </div>
            </th>
            <th v-if="visibleColumnMap.product_weight" class="text-center" style="min-width: 56px; width: 56px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <div>
                  <div>Product</div>
                  <div>Weight</div>
                </div>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('product_weight')"
                >
                  <q-tooltip>Bulk Paste Product Weight</q-tooltip>
                </q-btn>
              </div>
            </th>
            <th v-if="visibleColumnMap.package_weight" class="text-center bw-ops-col-tint--weight" style="min-width: 56px; width: 56px; line-height: 1.2; padding-top: 4px; padding-bottom: 4px">
              <div class="row items-center justify-center no-wrap q-gutter-x-2xs">
                <div>
                  <div>Package</div>
                  <div>Weight</div>
                </div>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-clipboard-text"
                  color="grey-7"
                  class="bulk-paste-header-btn"
                  @click.stop="openBulkPasteDialog('package_weight')"
                >
                  <q-tooltip>Bulk Paste Package Weight</q-tooltip>
                </q-btn>
              </div>
            </th>
            <!-- Dynamically added custom columns -->
            <template v-for="col in customColumns" :key="col.name">
              <th v-if="visibleColumnMap[col.name]" class="text-left" style="min-width: 90px">{{ col.label }}</th>
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
              <td class="text-center q-pa-none" style="width: 18px; min-width: 18px" @click.stop>
                <q-checkbox
                  :model-value="item.selected"
                  dense
                  size="xs"
                  @update:model-value="(val) => toggleRowSelection(item.id, !!val)"
                />
              </td>

              <!-- SL with In-Place Editable Input -->
              <td class="text-center text-weight-medium text-grey-7 q-pa-none" style="width: 36px; min-width: 36px; max-width: 36px" @click.stop>
                <div class="row items-center justify-center no-wrap">
                  <q-input
                    :model-value="index + 1"
                    type="number"
                    min="1"
                    :max="displayedItems.length"
                    dense
                    outlined
                    hide-bottom-space
                    class="inline-edit-input excel-cell-input"
                    style="max-width: 32px"
                    input-class="text-center text-weight-bold font-mono"
                    @change="(val: any) => onSlPositionChange(index, val)"
                    @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                  />
                </div>
              </td>

            <!-- Image (0.85 inch ≈ 82px) -->
            <td class="shipment-image-col">
              <q-avatar square size="82px" class="avatar-soft-sq bg-grey-2 border-grey overflow-hidden" style="width: 0.85in; height: 0.85in">
                <img :src="item.image" alt="item" style="object-fit: cover; width: 100%; height: 100%" />
              </q-avatar>
            </td>

            <!-- Name (Multiline Wrapped) -->
            <td v-if="visibleColumnMap.name" style="width: 120px; min-width: 120px; max-width: 120px; white-space: normal !important; word-break: break-word" @click="openEditItem(item.rawItem || item)">
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
            <td v-if="visibleColumnMap.purchase_price" class="text-center bw-ops-col-tint--price" style="width: 56px; min-width: 56px">
              <div class="row justify-center">
                <q-input
                  :model-value="getDraftValue(item, 'purchase_price')"
                  type="number"
                  step="0.01"
                  dense
                  outlined
                  hide-bottom-space
                  class="inline-edit-input excel-cell-input"
                  style="max-width: 50px"
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
            <td v-if="visibleColumnMap.cost_bdt" class="text-center bw-ops-col-tint--cost" style="width: 56px; min-width: 56px">
              <div class="font-mono text-weight-bold text-primary" style="font-size: 12px">
                {{ Number(item.cost / (item.quantity || 1) || 0).toFixed(2) }}
              </div>
              <div class="text-caption text-grey-7 text-weight-normal q-mt-2xs" style="font-size: 10px">
                T: {{ Number(item.cost || 0).toLocaleString() }}
              </div>
            </td>

            <!-- Ordered Quantity (Inline Editable) -->
            <td v-if="visibleColumnMap.ordered_quantity" class="text-center bw-ops-col-tint--qty" style="width: 56px; min-width: 56px">
              <div class="row justify-center">
                <q-input
                  :model-value="getDraftValue(item, 'ordered_quantity')"
                  type="number"
                  min="1"
                  step="1"
                  dense
                  outlined
                  hide-bottom-space
                  class="inline-edit-input excel-cell-input"
                  style="max-width: 50px"
                  input-class="text-center text-weight-bold"
                  @update:model-value="(val) => setDraftValue(item, 'ordered_quantity', val)"
                  @blur="saveDraftValue(item, 'ordered_quantity')"
                  @keyup.enter="(e: any) => (e.target as HTMLElement)?.blur()"
                />
              </div>
            </td>

            <!-- Product Weight (Inline Editable) -->
            <td v-if="visibleColumnMap.product_weight" class="text-center font-mono text-grey-8" style="width: 56px; min-width: 56px">
              <div class="row justify-center">
                <q-input
                  :model-value="getDraftValue(item, 'product_weight')"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  hide-bottom-space
                  class="inline-edit-input excel-cell-input"
                  style="max-width: 50px"
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
            <td v-if="visibleColumnMap.package_weight" class="text-center bw-ops-col-tint--weight font-mono text-grey-8" style="width: 56px; min-width: 56px">
              <div class="row justify-center">
                <q-input
                  :model-value="getDraftValue(item, 'package_weight')"
                  type="number"
                  step="0.001"
                  dense
                  outlined
                  hide-bottom-space
                  class="inline-edit-input excel-cell-input"
                  style="max-width: 50px"
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
                  {{ activeSheetId === 'sheet_all' ? 'Please select a section tab from the bottom bar to add items.' : 'Click the "+ Add Items" button above or below to search and add products.' }}
                </div>
                <q-btn
                  color="primary"
                  icon="ph ph-plus"
                  label="Add First Item"
                  unelevated
                  no-caps
                  class="rounded-borders"
                  :disable="activeSheetId === 'sheet_all'"
                  @click="triggerAddItems"
                >
                  <q-tooltip v-if="activeSheetId === 'sheet_all'">
                    Select a section tab at the bottom first
                  </q-tooltip>
                </q-btn>
              </div>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <!-- Bottom Sticky Section: Excel-style Bar with Sheet Tabs & Right Horizontal Scrollbar -->
    <ShipmentExcelBottomBar
      ref="excelBottomBarRef"
      :sheets="sheets"
      :active-sheet-id="activeSheetId"
      :scroll-thumb-width="scrollThumbWidth"
      :scroll-thumb-left="scrollThumbLeft"
      @update:active-sheet-id="onSheetTabChange"
      @add-section="openAddSectionDialog"
      @view-section="openViewSectionDialog"
      @edit-section="openEditSectionDialog"
      @remove-sheet="removeSheet"
      @scroll-step="scrollTableByStep"
      @track-click="onTrackClick"
      @thumb-drag-start="startThumbDrag"
    />

    <!-- Right Side Settings Popup with Tabs -->
    <ShipmentSettingsDrawer
      v-model="settingsDrawerOpen"
      :shipment-id="shipmentId"
      :calculations="calculations"
      :cargo-options="cargoOptions"
      :vendor-options="vendorOptions"
      :initial-tab="settingsDrawerTab"
      :progress-flow-options="progressFlowOptions"
      :progress-tag-options="progressTagOptions"
      :progress-flow-id="shipmentStore.currentShipment?.progress_flow_id ?? null"
      :progress-tag-id="shipmentStore.currentShipment?.progress_tag_id ?? null"
      :progress-updating="progressUpdating"
      :progress-target-id="progressTargetId"
      :child-tenant-options="childTenantOptions"
      :child-tenants-loading="childTenantsLoading"
      :selected-child-tenant-id="selectedChildTenantId"
      :assigning-child="assigningChild"
      :assigned-child-tenant-id="shipmentStore.currentShipment?.assigned_child_tenant_id ?? null"
      @update-flow="changeProgressFlow"
      @update-progress="changeProgress"
      @update:selected-child-tenant-id="onSelectedChildTenantIdUpdate"
      @save-assign-child="saveAssignChild"
      @clear-assign-child="clearAssignChild"
    />

    <!-- Add / Edit Section Sheet Dialog -->
    <ShipmentSectionSheetDialog
      v-model="showAddSectionDialog"
      :is-editing="isEditingSection"
      :initial-data="editingSectionData"
      @save="onSaveSectionSheet"
    />

    <!-- View Section Details Modal -->
    <ShipmentSectionViewDialog
      v-model="showViewSectionDialog"
      :section-data="viewingSectionData"
      @edit="switchToEditFromView"
    />

    <!-- Add Custom Column Dialog -->
    <AddCustomColumnDialog
      v-model="showAddColumnDialog"
      @add-column="onAddCustomColumn"
    />

    <!-- Bulk Paste Dialog (UI-only for pasting column values) -->
    <q-dialog v-model="showBulkPasteDialog" persistent>
      <q-card style="width: 520px; max-width: 95vw; border-radius: 12px">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="row items-center q-gutter-x-sm">
            <q-avatar color="primary" text-color="white" icon="ph ph-clipboard-text" size="32px" />
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Bulk Paste {{ bulkPasteFieldLabel }}</div>
              <div class="text-caption text-grey-6">Paste tab-separated or newline-separated values from Excel/Sheets</div>
            </div>
          </div>
          <q-btn v-close-popup icon="ph ph-x" flat round dense color="grey-6" />
        </q-card-section>

        <q-card-section class="q-py-md">
          <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">Paste Area</div>
          <q-input
            v-model="bulkPasteText"
            type="textarea"
            outlined
            dense
            rows="8"
            placeholder="Paste your copied column values here (e.g. from Excel)..."
            class="bg-white font-mono"
            style="font-size: 13px"
            autofocus
          />
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-pa-md bg-grey-1">
          <q-btn v-close-popup flat label="Cancel" color="grey-7" no-caps :disable="bulkPasteSaving" />
          <q-btn
            unelevated
            color="primary"
            icon="ph ph-check"
            label="Apply Paste"
            no-caps
            class="rounded-borders q-px-md text-weight-bold"
            :loading="bulkPasteSaving"
            :disable="bulkPasteSaving"
            @click="applyBulkPaste"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRoute } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { useCargoCompaniesQuery } from '../composables/useProcurementStockQuery';
import AddShipmentItemsDrawer from '../components/AddShipmentItemsDrawer.vue';
import ShipmentExcelBottomBar, { type SheetTabItem } from '../components/ShipmentExcelBottomBar.vue';
import ShipmentSettingsDrawer from '../components/ShipmentSettingsDrawer.vue';
import ShipmentSectionSheetDialog, { type SectionFormData } from '../components/ShipmentSectionSheetDialog.vue';
import ShipmentSectionViewDialog, { type SectionViewData } from '../components/ShipmentSectionViewDialog.vue';
import AddCustomColumnDialog from '../components/AddCustomColumnDialog.vue';
import ShipmentStatusWorkflowBar from '../components/ShipmentStatusWorkflowBar.vue';
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { useInboundShipmentActions } from '../composables/useInboundShipmentActions';

const $q = useQuasar();
const route = useRoute();
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
  currentPurchaseCurrencySymbol,
  currentCostCurrencySymbol,
} = calculations;

const {
  openEditItem,
  confirmDeleteItem,
  changeStatus,
  changeProgress,
  changeProgressFlow,
  updatingStatus,
  targetUpdatingStatus,
  progressTargetId,
  progressFlowOptions,
  progressTagOptions,
  progressUpdating,
  childTenantOptions,
  childTenantsLoading,
  selectedChildTenantId,
  assigningChild,
  saveAssignChild,
  clearAssignChild,
  openAddItems,
} = actions;

const settingsDrawerOpen = ref(false);
const settingsDrawerTab = ref('details');

const openSettingsDrawer = (tab = 'details') => {
  settingsDrawerTab.value = tab;
  settingsDrawerOpen.value = true;
};

const onSelectedChildTenantIdUpdate = (val: number | null) => {
  selectedChildTenantId.value = val;
};

const showAddColumnDialog = ref(false);
const showAddSectionDialog = ref(false);
const showViewSectionDialog = ref(false);
const isEditingSection = ref(false);
const editingSectionData = ref<SectionFormData | null>(null);
const viewingSectionData = ref<SectionViewData | null>(null);
const excelBottomBarRef = ref<InstanceType<typeof ShipmentExcelBottomBar> | null>(null);

// Bulk Paste Dialog State
const showBulkPasteDialog = ref(false);
const bulkPasteField = ref<'purchase_price' | 'ordered_quantity' | 'product_weight' | 'package_weight'>('purchase_price');
const bulkPasteStartItem = ref<any>(null);
const bulkPasteText = ref('');
const bulkPasteSaving = ref(false);

const bulkPasteFieldLabel = computed(() => {
  switch (bulkPasteField.value) {
    case 'purchase_price':
      return 'Price';
    case 'ordered_quantity':
      return 'Quantity';
    case 'product_weight':
      return 'Product Weight';
    case 'package_weight':
      return 'Package Weight';
    default:
      return 'Values';
  }
});

const openBulkPasteDialog = (
  field: 'purchase_price' | 'ordered_quantity' | 'product_weight' | 'package_weight',
  startItem?: any,
) => {
  bulkPasteField.value = field;
  bulkPasteStartItem.value = startItem || null;
  bulkPasteText.value = '';
  bulkPasteSaving.value = false;
  showBulkPasteDialog.value = true;
};

const applyBulkPaste = async () => {
  const text = bulkPasteText.value.trim();
  if (!text) {
    showBulkPasteDialog.value = false;
    return;
  }

  // Parse lines or tab-separated entries
  const tokens = text
    .split(/[\r\n\t]+/)
    .map((t) => t.trim())
    .filter((t) => t.length > 0);

  if (tokens.length === 0) {
    showBulkPasteDialog.value = false;
    return;
  }

  const items = displayedItems.value;
  let startIndex = 0;
  if (bulkPasteStartItem.value) {
    const foundIdx = items.findIndex((it) => it.id === bulkPasteStartItem.value.id);
    if (foundIdx !== -1) {
      startIndex = foundIdx;
    }
  }

  let count = 0;
  const field = bulkPasteField.value;
  const updates: Array<{ id: number; payload: Record<string, any> }> = [];

  for (let i = 0; i < tokens.length; i++) {
    const targetItem = items[startIndex + i];
    if (!targetItem) break;

    const val = Number(tokens[i]);
    if (!isNaN(val)) {
      let normalized = val;
      if (field === 'purchase_price') {
        normalized = Number(val.toFixed(2));
        targetItem.price = normalized;
      } else if (field === 'ordered_quantity') {
        normalized = Math.max(1, Math.round(val));
        targetItem.quantity = normalized;
      } else if (field === 'product_weight' || field === 'package_weight') {
        normalized = Number(val.toFixed(3));
      }

      setDraftValue(targetItem, field, normalized);
      if (targetItem.rawItem) {
        targetItem.rawItem[field] = normalized;
      }

      const itemId = targetItem.rawItem?.id || targetItem.id;
      if (itemId) {
        updates.push({
          id: itemId,
          payload: { [field]: normalized },
        });
      }
      count++;
    }
  }

  if (updates.length > 0 && shipmentId && !isNaN(shipmentId)) {
    bulkPasteSaving.value = true;
    try {
      await shipmentStore.updateShipmentItemsBulk(shipmentId, updates);
      $q.notify({
        message: `Successfully pasted and saved ${count} ${bulkPasteFieldLabel.value} value(s)`,
        color: 'positive',
        icon: 'ph ph-check-circle',
        timeout: 1500,
      });
    } catch (err) {
      $q.notify({
        message: `Pasted ${count} value(s) locally. Failed to save to server.`,
        color: 'warning',
        icon: 'ph ph-warning-circle',
        timeout: 2000,
      });
    } finally {
      bulkPasteSaving.value = false;
    }
  } else {
    $q.notify({
      message: `Pasted ${count} value(s) into ${bulkPasteFieldLabel.value}`,
      color: 'positive',
      icon: 'ph ph-clipboard-text',
      timeout: 1500,
    });
  }

  showBulkPasteDialog.value = false;
};

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

// Table column definitions
const baseTableColumns = [
  { name: 'name', label: 'Name' },
  { name: 'product_codes', label: 'Codes' },
  { name: 'purchase_price', label: 'Price' },
  { name: 'cost_bdt', label: 'Cost' },
  { name: 'ordered_quantity', label: 'Qty' },
  { name: 'product_weight', label: 'Product Weight' },
  { name: 'package_weight', label: 'Package Weight' },
];

const visibleColumnMap = reactive<Record<string, boolean>>({
  name: true,
  product_codes: true,
  purchase_price: true,
  cost_bdt: true,
  ordered_quantity: true,
  product_weight: true,
  package_weight: true,
});

const customColumns = ref<Array<{ name: string; label: string; type: string }>>([]);

const onAddCustomColumn = (col: { name: string; label: string; type: string }) => {
  customColumns.value.push(col);
  visibleColumnMap[col.name] = true;
};

const allColumnsVisible = computed(() => {
  const baseAll = baseTableColumns.every((c) => visibleColumnMap[c.name]);
  const customAll = customColumns.value.every((c) => visibleColumnMap[c.name]);
  return baseAll && customAll;
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

const selectedItemIds = ref<number[]>([]);

const toggleRowSelection = (id: number, selected: boolean) => {
  if (selected) {
    if (!selectedItemIds.value.includes(id)) selectedItemIds.value.push(id);
  } else {
    selectedItemIds.value = selectedItemIds.value.filter((i) => i !== id);
  }
};

// Section / Vendor lookup helpers
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

// Dynamic table rows
const displayedItems = computed(() => {
  const storeItems = shipmentStore.currentShipmentItems;
  if (storeItems && storeItems.length > 0) {
    const activeSection = sheets.value.find((s) => s.id === activeSheetId.value);
    const activeSectionDbId = activeSection?.dbId;

    const firstSectionDbId = shipmentStore.currentShipmentSections?.[0]?.id ?? null;

    let filtered = storeItems;
    if (activeSectionDbId != null) {
      filtered = storeItems.filter(
        (it) => it.section_id === activeSectionDbId || (it.section_id == null && activeSectionDbId === firstSectionDbId),
      );
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

// Inline Draft Edit Handlers
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

const onSlPositionChange = async (currentIndex: number, newSlValue: any) => {
  const targetPos = parseInt(String(newSlValue), 10);
  const items = displayedItems.value || [];
  if (isNaN(targetPos) || targetPos < 1 || targetPos > items.length) return;
  const targetIndex = targetPos - 1;
  if (targetIndex === currentIndex) return;

  const fullItems = [...(shipmentStore.currentShipmentItems || [])];
  const currentItem = items[currentIndex];
  if (!currentItem) return;

  const fullCurrentIndex = fullItems.findIndex((it) => it.id === currentItem.id);
  if (fullCurrentIndex === -1) return;

  const [removed] = fullItems.splice(fullCurrentIndex, 1);

  const targetItem = items[targetIndex];
  let fullTargetIndex = fullItems.findIndex((it) => it.id === targetItem.id);
  if (fullTargetIndex === -1) {
    fullTargetIndex = targetIndex;
  } else if (targetIndex > currentIndex) {
    fullTargetIndex += 1;
  }

  fullItems.splice(fullTargetIndex, 0, removed);

  if (shipmentId && !isNaN(shipmentId)) {
    const itemsOrder = fullItems.map((item, idx) => ({
      id: item.id,
      sort_order: idx * 10,
    }));
    try {
      await shipmentStore.reorderShipmentItems(shipmentId, itemsOrder);
      await shipmentStore.fetchShipmentDetails(shipmentId);
      $q.notify({
        message: `Moved item to position #${targetPos}`,
        color: 'positive',
        icon: 'ph ph-arrows-down-up',
        timeout: 1000,
      });
    } catch (err: unknown) {
      console.error('Failed to reorder items', err);
      $q.notify({
        message: 'Failed to reorder item',
        color: 'negative',
        icon: 'ph ph-warning-circle',
      });
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

// Excel Sheets Management
const tableScrollContainerRef = ref<HTMLElement | null>(null);
const hasUserSelectedSheet = ref(false);
const activeSheetId = ref('sheet_all');
const sheets = ref<SheetTabItem[]>([
  { id: 'sheet_all', name: 'All Items' },
]);

const firstSectionSheetId = (sections: typeof shipmentStore.currentShipmentSections) =>
  sections?.length ? `section_${sections[0].id}` : null;

const onSheetTabChange = async (id: string) => {
  hasUserSelectedSheet.value = true;
  activeSheetId.value = id;
  selectedItemIds.value = [];
  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.fetchShipmentDetails(shipmentId);
    } catch (err) {
      console.error('Failed to refresh shipment items on section switch:', err);
    }
  }
};

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
      const defaultSectionId = firstSectionSheetId(sections);
      const activeStillValid = generated.some((s) => s.id === activeSheetId.value);

      if (!activeStillValid) {
        activeSheetId.value = defaultSectionId ?? 'sheet_all';
      } else if (!hasUserSelectedSheet.value && activeSheetId.value === 'sheet_all' && defaultSectionId) {
        activeSheetId.value = defaultSectionId;
      }
    }
  },
  { immediate: true },
);

const scrollThumbWidth = ref(30);
const scrollThumbLeft = ref(0);

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

const scrollTableByStep = (delta: number) => {
  if (tableScrollContainerRef.value) {
    tableScrollContainerRef.value.scrollBy({ left: delta, behavior: 'smooth' });
  }
};

const onTrackClick = (fraction: number) => {
  const table = tableScrollContainerRef.value;
  if (!table) return;
  const maxScrollLeft = table.scrollWidth - table.clientWidth;
  table.scrollTo({ left: fraction * maxScrollLeft, behavior: 'smooth' });
};

const startThumbDrag = (e: MouseEvent) => {
  e.preventDefault();
  e.stopPropagation();
  const table = tableScrollContainerRef.value;
  const track = excelBottomBarRef.value?.scrollTrackRef;
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

// Section / Invoice Sheet actions
const openViewSectionDialog = (sheet: SheetTabItem) => {
  viewingSectionData.value = { ...sheet };
  showViewSectionDialog.value = true;
};

const switchToEditFromView = () => {
  showViewSectionDialog.value = false;
  if (viewingSectionData.value) {
    openEditSectionDialog(viewingSectionData.value);
  }
};

const openAddSectionDialog = () => {
  isEditingSection.value = false;
  editingSectionData.value = {
    title: `Invoice Section ${sheets.value.length + 1}`,
    invoiceNumber: '',
    invoiceDate: '',
    notes: '',
  };
  showAddSectionDialog.value = true;
};

const openEditSectionDialog = (sheet: SheetTabItem) => {
  isEditingSection.value = true;
  editingSectionData.value = {
    id: sheet.id,
    dbId: sheet.dbId,
    title: sheet.name,
    invoiceNumber: sheet.invoiceNumber || '',
    invoiceDate: sheet.invoiceDate || '',
    notes: sheet.notes || '',
  };
  showAddSectionDialog.value = true;
};

const onSaveSectionSheet = async (data: SectionFormData) => {
  if (isEditingSection.value && data.id) {
    const target = sheets.value.find((s) => s.id === data.id);
    if (target) {
      target.name = data.title;
      target.invoiceNumber = data.invoiceNumber;
      target.invoiceDate = data.invoiceDate;
      target.notes = data.notes;

      if (shipmentId && target.dbId) {
        try {
          await shipmentStore.updateSection(target.dbId, {
            title: data.title,
            invoice_number: data.invoiceNumber || null,
            invoice_date: data.invoiceDate || null,
            notes: data.notes || null,
          });
          await shipmentStore.fetchShipmentDetails(shipmentId);
          $q.notify({
            type: 'positive',
            message: 'Section updated successfully',
          });
        } catch (err: unknown) {
          console.error('Failed to update section in DB', err);
          $q.notify({
            type: 'negative',
            message: err instanceof Error ? err.message : 'Failed to update section',
          });
        }
      }
    }
  } else {
    let createdDbId: number | undefined;
    if (shipmentId && !isNaN(shipmentId)) {
      try {
        const parentTenantId = currentTenantId.value ?? shipmentStore.currentShipment?.parent_tenant_id;
        const vendorId = shipmentStore.currentShipment?.vendor_id ?? shipmentStore.currentShipmentSections[0]?.vendor_id;
        const created = await shipmentStore.createSection({
          parent_tenant_id: parentTenantId ?? undefined,
          shipment_id: shipmentId,
          vendor_id: vendorId ?? undefined,
          title: data.title,
          invoice_number: data.invoiceNumber || null,
          invoice_date: data.invoiceDate || null,
          notes: data.notes || null,
        });
        createdDbId = created?.id;
        await shipmentStore.fetchShipmentDetails(shipmentId);
        $q.notify({
          type: 'positive',
          message: `Created section "${data.title}"`,
        });
      } catch (err: unknown) {
        console.error('Failed to create section in DB', err);
        $q.notify({
          type: 'negative',
          message: err instanceof Error ? err.message : 'Failed to create section',
        });
      }
    }

    if (createdDbId) {
      hasUserSelectedSheet.value = true;
      activeSheetId.value = `section_${createdDbId}`;
    }
    setTimeout(() => excelBottomBarRef.value?.scrollToTab('end'), 50);
  }
};

const removeSheet = async (id: string) => {
  const target = sheets.value.find((s) => s.id === id);
  if (!target) return;

  if (shipmentId && target.dbId) {
    try {
      await shipmentStore.deleteSection(target.dbId);
      await shipmentStore.fetchShipmentDetails(shipmentId);
      $q.notify({
        type: 'positive',
        message: 'Section deleted successfully',
      });
    } catch (err: unknown) {
      console.error('Failed to delete section in DB', err);
      $q.notify({
        type: 'negative',
        message: err instanceof Error ? err.message : 'Failed to delete section',
      });
    }
  }
};

</script>

<style scoped>
.shipment-header-workflow :deep(.shipment-status-toolbar) {
  border: none;
  padding-left: 0;
  padding-right: 0;
}

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
.avatar-soft-sq {
  border-radius: 6px;
}
.text-xxs {
  font-size: 11px;
}
.font-mono {
  font-family: monospace;
}
.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}
.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
}

.shipment-items-markup-table th,
.shipment-items-markup-table td {
  padding: 4px 4px !important;
  height: 48px;
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

/* Hide number input spinners */
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

:deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
  transition: all 0.1s ease-in-out;
}

:deep(.excel-cell-input .q-field__control:before),
:deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

:deep(.excel-cell-input:hover .q-field__control) {
  background-color: rgba(255, 255, 255, 0.4) !important;
}

:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: #ffffff !important;
  border: 1.5px solid #059669 !important;
  box-shadow: 0 0 0 1px #059669 !important;
}

.hover-bright {
  transition: filter 0.15s ease, transform 0.15s ease;
}
.hover-bright:hover {
  filter: brightness(0.92);
  transform: translateY(-1px);
}

.bulk-paste-header-btn {
  opacity: 0.6;
  transition: opacity 0.15s ease-in-out, transform 0.15s ease-in-out;
  padding: 0 !important;
  min-height: 18px !important;
  min-width: 18px !important;
}

.bulk-paste-header-btn:hover {
  opacity: 1 !important;
  color: var(--q-primary) !important;
  transform: scale(1.1);
}
</style>
