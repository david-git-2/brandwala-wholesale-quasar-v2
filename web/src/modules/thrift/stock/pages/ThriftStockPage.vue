<template>
  <q-page class="q-pa-md thrift-stock-page">
    <!-- Header -->
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm">
            <div class="text-h6 text-weight-bold">Thrift Stock</div>
            <div class="text-caption text-grey-8">Manage bulk and single items, conditions, sizes, boxes, and shelves</div>
          </div>
          <div class="col-12 col-sm-auto row justify-start justify-sm-end q-mt-xs q-mt-sm-none q-gutter-sm">
            <q-btn
              color="primary"
              outline
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="view_column"
              label="Columns"
              aria-label="Select columns"
            >
              <q-menu>
                <q-list style="min-width: 240px">
                  <q-item>
                    <q-item-section>
                      <div class="text-subtitle2">Show Columns</div>
                    </q-item-section>
                  </q-item>
                  <q-item>
                    <q-item-section>
                      <q-checkbox
                        v-model="allSelectableColumnsSelected"
                        label="Select / Deselect All"
                      />
                    </q-item-section>
                  </q-item>
                  <q-item>
                    <q-item-section>
                      <q-option-group
                        v-model="selectedColumnNames"
                        type="checkbox"
                        :options="columnSelectorOptions"
                      />
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
            <q-btn
              outline
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="download"
              label="Download CSV"
              :loading="csvExportLoading"
              @click="downloadStockCsv"
            />
            <q-btn
              outline
              color="secondary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="settings"
              label="Settings"
              @click="goToSettings"
            />
            <q-btn
              color="primary"
              no-caps
              size="sm"
              class="pill-btn slim-btn"
              icon="add"
              label="Register Stock"
              @click="openAddDialog"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Search & Filters Toolbar -->
    <div class="row items-center q-gutter-sm q-mb-md">
      <q-input
        v-model="searchText"
        outlined
        dense
        clearable
        class="col-grow"
        placeholder="Search name, brand, or barcode..."
        debounce="400"
        @update:model-value="onFiltersChanged"
      >
        <template #prepend>
          <q-icon name="search" />
        </template>
      </q-input>

      <q-btn flat round dense icon="filter_alt" @click="openFilterDrawer">
        <q-badge v-if="activeFilterCount > 0" color="primary" rounded floating>
          {{ activeFilterCount }}
        </q-badge>
      </q-btn>
    </div>

    <FilterSidebar v-model="filterDrawerOpen" title="Filters">
      <div class="q-gutter-y-md q-pa-sm">
        <q-select
          v-model="draftStatusFilter"
          :options="statusOptions"
          outlined
          dense
          label="Status"
          emit-value
          map-options
          clearable
        />
        <q-select
          v-model="draftConditionFilter"
          :options="conditionOptions"
          outlined
          dense
          label="Condition"
          emit-value
          map-options
          clearable
        />
        <div class="row justify-end q-gutter-x-sm q-mt-md">
          <q-btn flat no-caps label="Reset" color="grey-7" @click="onResetDrawerFilters" />
          <q-btn unelevated no-caps label="Apply Filters" color="primary" @click="onApplyDrawerFilters" />
        </div>
      </div>
    </FilterSidebar>

    <q-card
      v-if="selectedStockIds.length"
      flat
      class="q-mb-md floating-surface shadow-1 bulk-selection-bar"
    >
      <q-card-section class="row items-center q-col-gutter-sm q-py-sm">
        <div class="col text-body2 text-weight-medium">
          {{ selectedStockIds.length }} item{{ selectedStockIds.length === 1 ? '' : 's' }} selected
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            flat
            no-caps
            color="grey-8"
            label="Clear"
            @click="clearStockSelection"
          />
          <q-btn
            color="negative"
            no-caps
            icon="delete"
            label="Delete selected"
            @click="confirmBulkDelete"
          />
        </div>
      </q-card-section>
    </q-card>

    <PageInitialLoader v-if="loading && !stocks.length" />

    <!-- Table -->
    <q-card v-else flat class="floating-surface shadow-1 thrift-table-card">
      <q-table
        flat
        :rows="stocks"
        :columns="columns"
        :visible-columns="visibleColumns"
        :table-style="{ maxHeight: '100%' }"
        row-key="id"
        v-model:pagination="tablePagination"
        :rows-per-page-options="[10, 20, 50]"
        :loading="loading && stocks.length > 0"
        class="thrift-table"
        @request="onTableRequest"
      >
        <template #header-cell-select="props">
          <q-th :props="props" class="col-sticky-select">
            <q-checkbox
              :model-value="allPageRowsSelected"
              :indeterminate="somePageRowsSelected && !allPageRowsSelected"
              dense
              @update:model-value="toggleSelectAllPage"
            />
          </q-th>
        </template>
        <template #header-cell-sl="props">
          <q-th :props="props" class="col-sticky-sl">{{ props.col.label }}</q-th>
        </template>
        <template #header-cell-image="props">
          <q-th :props="props" class="col-sticky-image">{{ props.col.label }}</q-th>
        </template>
        <template #loading>
          <PageInitialLoader compact />
        </template>
        <template #body="props">
          <q-tr :props="props">
            <q-td
              v-for="col in props.cols"
              :key="col.name"
              :props="{ ...props, col }"
              :class="[tableCellClass(col.name), stickyCellClass(col.name)]"
            >
              <template v-if="col.name === 'select'">
                <q-checkbox
                  :model-value="selectedStockIds.includes(props.row.id)"
                  dense
                  @update:model-value="(checked) => toggleStockSelection(props.row.id, !!checked)"
                />
              </template>
              <template v-else-if="col.name === 'sl'">
                {{ (tablePagination.page - 1) * tablePagination.rowsPerPage + props.rowIndex + 1 }}
              </template>
              <template v-else-if="col.name === 'image'">
                <div class="thrift-stock-image-wrap">
                  <SmartImage
                    :src="props.row.image_url"
                    :alt="props.row.name || 'Stock image'"
                    imgClass="thrift-stock-image__img"
                    :enableEdit="false"
                  />
                </div>
              </template>
              <template v-else-if="col.name === 'barcode'">
                <div class="editable-value row items-center no-wrap">
                  <span class="col ellipsis">{{ props.row.barcode || '—' }}</span>
                  <q-btn
                    v-if="props.row.barcode"
                    flat
                    round
                    dense
                    size="xs"
                    icon="qr_code"
                    color="primary"
                    class="col-auto"
                    @click.stop="openBarcodePreview(props.row)"
                  >
                    <q-tooltip>Preview barcode</q-tooltip>
                  </q-btn>
                </div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.barcode"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onTextCellSave(props.row, 'barcode', String(value ?? ''))"
                >
                  <q-input v-model="scope.value" dense outlined autofocus />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'name'">
                <div class="editable-value">{{ props.row.name || '—' }}</div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.name"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onTextCellSave(props.row, 'name', String(value ?? ''))"
                >
                  <q-input v-model="scope.value" dense outlined autofocus />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'brand_name'">
                <div class="editable-value">{{ props.row.brand_name || '—' }}</div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.brand_name"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onTextCellSave(props.row, 'brand_name', String(value ?? ''))"
                >
                  <q-input v-model="scope.value" dense outlined autofocus />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'section'">
                <div class="editable-value">{{ props.row.section || '—' }}</div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.section"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onSectionSave(props.row, value as ThriftSection | null)"
                >
                  <q-select
                    v-model="scope.value"
                    :options="[...sectionSelectOptions]"
                    dense
                    outlined
                    clearable
                    autofocus
                  />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'size'">
                <div class="cursor-pointer text-grey-9 text-weight-medium" @click="openMeasurementsDialog(props.row)">
                  {{ formatThriftStockMeasurements(props.row) }}
                  <q-tooltip>Click to edit measurements</q-tooltip>
                </div>
              </template>
              <template v-else-if="col.name === 'box'">
                <div class="editable-value">{{ getBoxName(props.row.box_id) }}</div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.box_id ?? null"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onBoxSave(props.row, value as number | null)"
                >
                  <q-select
                    v-model="scope.value"
                    :options="boxesForShipment(props.row.shipment_id)"
                    option-value="id"
                    option-label="name"
                    emit-value
                    map-options
                    dense
                    outlined
                    clearable
                    autofocus
                  />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'product_weight'">
                <div class="editable-value">
                  {{ props.row.product_weight ? `${props.row.product_weight} g` : '—' }}
                </div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.product_weight ?? 0"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onNumberCellSave(props.row, 'product_weight', toNumber(value))"
                >
                  <q-input v-model.number="scope.value" type="number" min="0" step="1" dense outlined suffix="g" autofocus />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'extra_weight'">
                <div class="editable-value">
                  {{ props.row.extra_weight ? `${props.row.extra_weight} g` : '—' }}
                </div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.extra_weight ?? 0"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onNumberCellSave(props.row, 'extra_weight', toNumber(value))"
                >
                  <q-input v-model.number="scope.value" type="number" min="0" step="1" dense outlined suffix="g" autofocus />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'condition'">
                <div class="editable-value">{{ props.row.condition || '—' }}</div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.condition"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onConditionSave(props.row, value as ThriftCondition | null)"
                >
                  <q-select
                    v-model="scope.value"
                    :options="[...conditionSelectOptions]"
                    dense
                    outlined
                    clearable
                    autofocus
                  />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'quantity'">
                <div class="editable-value">{{ props.row.quantity ?? '—' }}</div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.quantity"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onNumberCellSave(props.row, 'quantity', toNumber(value))"
                >
                  <q-input v-model.number="scope.value" type="number" min="0" step="1" dense outlined autofocus />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'origin_purchase_price'">
                <div class="editable-value">
                  {{ formatStockPrice(props.row.origin_unit_price, shipmentPurchaseCurrency(props.row.shipment_id)) }}
                </div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.origin_unit_price ?? 0"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onOriginUnitPriceSave(props.row, toNumber(value))"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    min="0"
                    step="0.01"
                    dense
                    outlined
                    :prefix="shipmentPurchaseCurrency(props.row.shipment_id)?.symbol"
                    autofocus
                  />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'extra_origin_purchase_expense'">
                <div class="editable-value">
                  {{ formatStockPrice(props.row.extra_origin_unit_price, shipmentPurchaseCurrency(props.row.shipment_id)) }}
                </div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.extra_origin_unit_price ?? 0"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onExtraOriginUnitPriceSave(props.row, toNumber(value))"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    min="0"
                    step="0.01"
                    dense
                    outlined
                    :prefix="shipmentPurchaseCurrency(props.row.shipment_id)?.symbol"
                    autofocus
                  />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'product_unit_cost'">
                <div class="text-grey-8">
                  {{ formatStockPrice(costBreakdownByStockId[props.row.id]?.product_unit_cost || 0, shipmentCostCurrency(props.row.shipment_id)) }}
                </div>
              </template>
              <template v-else-if="col.name === 'cargo_share_per_unit'">
                <div class="text-grey-8">
                  {{ formatStockPrice(costBreakdownByStockId[props.row.id]?.cargo_share_per_unit || 0, shipmentCostCurrency(props.row.shipment_id)) }}
                </div>
              </template>
              <template v-else-if="col.name === 'ops_share_per_unit'">
                <div class="text-grey-8">
                  {{ formatStockPrice(costBreakdownByStockId[props.row.id]?.ops_share_per_unit || 0, shipmentCostCurrency(props.row.shipment_id)) }}
                </div>
              </template>
              <template v-else-if="col.name === 'additional_charges_cost'">
                <div class="editable-value">
                  {{ formatStockPrice(props.row.additional_charges_cost || 0, shipmentCostCurrency(props.row.shipment_id)) }}
                </div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.additional_charges_cost ?? 0"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => saveStockCell(props.row, { additional_charges_cost: toNumber(value) })"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    min="0"
                    step="0.01"
                    dense
                    outlined
                    :prefix="shipmentCostCurrency(props.row.shipment_id)?.symbol"
                    autofocus
                  />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'landed_unit_cost'">
                <div class="text-weight-bold text-teal">
                  {{ formatStockPrice(costBreakdownByStockId[props.row.id]?.landed_unit_cost || 0, shipmentCostCurrency(props.row.shipment_id)) }}
                </div>
              </template>
              <template v-else-if="col.name === 'suggested_sell_unit_price'">
                <div class="text-grey-8">
                  {{ formatStockPrice(costBreakdownByStockId[props.row.id]?.suggested_sell_unit_price || 0, shipmentCostCurrency(props.row.shipment_id)) }}
                </div>
              </template>
              <template v-else-if="col.name === 'listed_unit_price'">
                <div class="editable-value text-weight-bold">
                  {{ formatStockPrice(props.row.pricing?.listed_unit_price || 0, shipmentCostCurrency(props.row.shipment_id)) }}
                </div>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.pricing?.listed_unit_price ?? 0"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onPricingCellSave(props.row, 'listed_unit_price', toNumber(value))"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    min="0"
                    step="1"
                    dense
                    outlined
                    :prefix="shipmentCostCurrency(props.row.shipment_id)?.symbol"
                    autofocus
                  />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'is_listed_price_manual'">
                <q-toggle
                  :model-value="!!props.row.pricing?.is_listed_price_manual"
                  color="primary"
                  dense
                  @update:model-value="(val) => onPricingCellSave(props.row, 'is_listed_price_manual', !!val)"
                />
              </template>
              <template v-else-if="col.name === 'status'">
                <q-chip
                  dense
                  square
                  :style="statusChipStyle(props.row.status)"
                  class="thrift-status-chip editable-value"
                >
                  <span class="status-dot" :style="{ backgroundColor: statusDotColor(props.row.status) }" />
                  {{ props.row.status ?? 'AVAILABLE' }}
                </q-chip>
                <q-popup-edit
                  v-slot="scope"
                  :model-value="props.row.status"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => onStatusCellSave(props.row, String(value ?? 'AVAILABLE'))"
                >
                  <q-select
                    v-model="scope.value"
                    :options="statusOptions"
                    emit-value
                    map-options
                    dense
                    outlined
                    autofocus
                  />
                </q-popup-edit>
              </template>
              <template v-else-if="col.name === 'actions'">
                <q-btn flat round dense icon="straighten" size="sm" color="secondary" @click.stop="openMeasurementsDialog(props.row)">
                  <q-tooltip>Garment Measurements</q-tooltip>
                </q-btn>
                <q-btn flat round dense icon="o_edit" size="sm" color="primary" @click.stop="openEditDialog(props.row)">
                  <q-tooltip>Edit Details</q-tooltip>
                </q-btn>
                <q-btn flat round dense icon="delete" size="sm" color="negative" @click.stop="confirmDelete(props.row)">
                  <q-tooltip>Delete Stock</q-tooltip>
                </q-btn>
                <q-btn flat round dense icon="o_report_problem" size="sm" color="warning" @click.stop="updateStatus(props.row.id, 'DAMAGED')">
                  <q-tooltip>Mark Damaged</q-tooltip>
                </q-btn>
                <q-btn flat round dense icon="o_block" size="sm" color="negative" @click.stop="updateStatus(props.row.id, 'STOLEN')">
                  <q-tooltip>Mark Stolen</q-tooltip>
                </q-btn>
              </template>
              <template v-else>
                {{ col.value }}
              </template>
            </q-td>
          </q-tr>
        </template>
      </q-table>
    </q-card>

    <!-- Register Stock Dialog -->
    <q-dialog v-model="dialogOpen" persistent @hide="onEditDialogHide">
      <q-card style="width: 600px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">{{ editingId ? 'Edit Thrift Stock' : 'Register Thrift Stock' }}</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section>
          <q-form @submit="onSubmit" class="q-gutter-sm q-pt-sm">
            <!-- Product Image -->
            <div>
              <div class="text-caption text-grey-8 q-mb-xs">Product Image</div>
              <div
                v-if="editImage.url"
                class="stock-image-preview relative-position text-center q-pa-sm rounded-borders"
              >
                <q-img
                  :src="editImage.url"
                  style="max-height: 200px; border-radius: 8px;"
                  fit="contain"
                  spinner-color="primary"
                />
                <div class="row justify-center q-gutter-sm q-mt-sm">
                  <q-btn
                    flat
                    dense
                    no-caps
                    color="primary"
                    icon="cloud_upload"
                    label="Replace"
                    @click="openEditUploader"
                  />
                  <q-btn
                    flat
                    dense
                    no-caps
                    color="negative"
                    icon="delete"
                    label="Remove"
                    @click="imageRemoveConfirmOpen = true"
                  />
                </div>
              </div>
              <div
                v-else
                class="stock-image-upload text-center q-pa-lg rounded-borders cursor-pointer"
                @click="openEditUploader"
              >
                <q-icon name="cloud_upload" size="40px" color="primary" />
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mt-xs">Upload Image</div>
                <div class="text-caption text-grey-6">Click to select photo (uploads when you save)</div>
              </div>
            </div>

            <q-separator />

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select v-model="form.shipment_id" outlined dense label="Shipment *" :options="shipments"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']" @update:model-value="onShipmentChange" />
              </div>
              <div class="col-12 col-sm-6">
                <q-select v-model="form.box_id" outlined dense label="Box Number/Name" :options="filteredBoxes"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  clearable />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select v-model="form.category_id" outlined dense label="Category *" :options="categories"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']" />
              </div>
              <div class="col-12 col-sm-6">
                <q-select v-model="form.type_id" outlined dense label="Product Style/Type *" :options="types"
                  option-value="id" option-label="name" emit-value map-options class="soft-input"
                  :rules="[val => !!val || 'Required']">
                  <template #option="scope">
                    <q-item v-bind="scope.itemProps">
                      <q-item-section avatar>
                        <q-icon :name="resolveTypeIcon(scope.opt.icon)" />
                      </q-item-section>
                      <q-item-section>{{ scope.opt.name }}</q-item-section>
                    </q-item>
                  </template>
                  <template #selected-item="scope">
                    <span v-if="scope.opt" class="row items-center no-wrap">
                      <q-icon :name="resolveTypeIcon(scope.opt.icon)" class="q-mr-sm" />
                      {{ scope.opt.name }}
                    </span>
                  </template>
                </q-select>
              </div>
            </div>

            <q-input v-model="form.name" outlined dense label="Item Name" class="soft-input" />

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input v-model="form.brand_name" outlined dense label="Brand Name" class="soft-input" />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model="form.barcode" outlined dense label="Barcode *" class="soft-input"
                  :rules="[val => !!val && val.length > 0 || 'Required']" />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-select v-model="form.section" outlined dense label="Section" class="soft-input"
                  :options="['MALE', 'FEMALE', 'UNISEX', 'KIDS', 'HOME']"
                  clearable />
              </div>
              <div class="col-12 col-sm-4">
                <q-select v-model="form.condition" outlined dense label="Condition" class="soft-input"
                  :options="['NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR']"
                  clearable />
              </div>
              <div class="col-12 col-sm-4">
                <q-select v-model="form.shelf_id" outlined dense label="Shelf" class="soft-input"
                  :options="shelves" option-value="id" option-label="shelf_code" emit-value map-options
                  clearable />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input v-model="form.color" outlined dense label="Color" class="soft-input" />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model="form.size" outlined dense label="Size" class="soft-input" />
              </div>
              <div class="col-12 col-sm-4">
                <q-input v-model.number="form.quantity" type="number" outlined dense label="Quantity *" class="soft-input"
                  :rules="[val => val >= 0 || 'Cannot be negative']" />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input v-model.number="form.product_weight" type="number" step="1" outlined dense label="Product Weight (g)" class="soft-input" />
              </div>
              <div class="col-12 col-sm-6">
                <q-input v-model.number="form.extra_weight" type="number" step="1" outlined dense label="Extra Weight (g)" class="soft-input" />
              </div>
            </div>

            <q-separator class="q-my-xs" />
            <div class="text-caption text-grey-8 q-mb-xs">Purchase ({{ purchaseCurrency?.code ?? '—' }})</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="originUnitPrice"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Origin unit price"
                  :prefix="purchaseCurrencySymbol"
                  class="soft-input"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="extraOriginUnitPrice"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Extra origin unit price"
                  :prefix="purchaseCurrencySymbol"
                  class="soft-input"
                />
              </div>
            </div>
            <div class="row q-col-gutter-sm q-mt-xs">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="additionalChargesCost"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Additional charges cost"
                  :prefix="costCurrencySymbol"
                  class="soft-input"
                />
              </div>
            </div>

            <q-separator class="q-my-xs" />
            <div class="text-caption text-grey-8 q-mb-xs">Pricing ({{ costCurrency?.code ?? '—' }})</div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="pricing.listed_unit_price"
                  type="number"
                  step="1"
                  outlined
                  dense
                  label="Listed Price"
                  :prefix="costCurrencySymbol"
                  class="soft-input"
                />
              </div>
              <div class="col-12 col-sm-6 row items-center">
                <q-toggle
                  v-model="pricing.is_listed_price_manual"
                  color="primary"
                  label="Manual Price Override"
                />
              </div>
            </div>

            <div class="row justify-end q-gutter-sm q-pt-sm">
              <q-btn flat no-caps label="Cancel" v-close-popup />
              <q-btn color="primary" no-caps size="sm" class="pill-btn slim-btn" label="Save Stock" type="submit" />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Quick Add / Image Upload Dialog -->
    <q-dialog v-model="quickAddDialogOpen" persistent @hide="onQuickAddDialogHide">
      <q-card style="width: 450px; max-width: 95vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center justify-between q-pb-sm">
          <div class="text-h6 text-weight-bold">Quick Register Stock</div>
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>
        <q-separator />

        <q-card-section class="q-pt-md">
          <div class="q-gutter-md">
            <q-select
              v-model="quickAddForm.shipment_id"
              outlined
              dense
              label="Shipment *"
              :options="shipments"
              option-value="id"
              option-label="name"
              emit-value
              map-options
              class="soft-input"
              @update:model-value="onQuickShipmentChange"
            />

            <q-select
              v-model="quickAddForm.box_id"
              outlined
              dense
              label="Box"
              :options="quickAddFilteredBoxes"
              option-value="id"
              option-label="name"
              emit-value
              map-options
              class="soft-input"
              clearable
            />

            <q-input
              v-model="quickAddForm.brand_name"
              outlined
              dense
              label="Brand name *"
              class="soft-input"
              :rules="[(val) => !!String(val || '').trim() || 'Required']"
            />

            <q-select
              v-model="quickAddForm.condition"
              outlined
              dense
              label="Condition *"
              :options="[...conditionSelectOptions]"
              class="soft-input"
              :rules="[(val) => !!val || 'Required']"
            />

            <q-input
              v-model.number="quickAddForm.product_weight"
              outlined
              dense
              type="number"
              min="1"
              step="1"
              label="Product weight (g) *"
              suffix="g"
              class="soft-input"
              :rules="[(val) => (val != null && Number(val) > 0) || 'Required']"
            />

            <!-- Upload Area -->
            <div class="text-center q-pa-md border-dashed rounded-borders bg-grey-1 cursor-pointer" @click="uploaderTarget = 'quick'; isUploaderOpen = true">
              <div v-if="quickAddForm.imagePreviewUrl" class="text-center">
                <q-img :src="quickAddForm.imagePreviewUrl" style="max-height: 180px; border-radius: 8px;" fit="contain" />
                <div class="text-caption text-grey-8 q-mt-sm">Image selected (uploads on submit)</div>
              </div>
              <div v-else class="q-py-md">
                <q-icon name="cloud_upload" size="40px" color="primary" />
                <div class="text-subtitle2 text-weight-bold text-grey-8 q-mt-xs">Select Image *</div>
                <div class="text-caption text-grey-6">Click to choose your item photo</div>
              </div>
            </div>

            <!-- Barcode -->
            <div>
              <label class="text-caption text-weight-medium text-grey-8">Barcode</label>
              <q-input
                v-model="quickAddForm.barcode"
                outlined
                dense
                readonly
                class="soft-input q-mt-xs"
                placeholder="Select shipment to assign barcode..."
              />
              <div v-if="quickAddBarcodeLoading" class="text-caption text-grey-7 q-mt-xs">
                Loading first available barcode...
              </div>
              <div v-else-if="quickAddForm.shipment_id && !quickAddForm.barcode" class="text-caption text-negative q-mt-xs">
                No available barcode found. Generate barcodes first.
              </div>
            </div>

            <!-- Purchase default -->
            <div class="q-pa-sm rounded-borders bg-grey-2 text-caption text-grey-8">
              <div class="row justify-between">
                <span>Default origin unit price:</span>
                <span class="text-weight-bold">{{ formatThriftAmount(settingsStore.defaultOriginUnitPrice, quickAddPurchaseCurrency) }}</span>
              </div>
            </div>
          </div>
        </q-card-section>

        <q-card-section class="row justify-end q-gutter-sm q-pt-sm">
          <q-btn flat no-caps label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            no-caps
            size="sm"
            class="pill-btn slim-btn px-md"
            label="Submit & Edit Details"
            :loading="quickSubmitting"
            :disabled="!canSubmitQuickAdd"
            @click="submitQuickAdd"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Delete Confirmation Dialog -->
    <q-dialog v-model="deleteConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw;" class="floating-surface shadow-2 q-pa-md relative-position">
        <q-inner-loading :showing="deleteLoading" color="negative">
          <q-spinner size="40px" color="negative" />
          <div class="text-caption text-grey-8 q-mt-sm">Deleting stock and image...</div>
        </q-inner-loading>
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Stock Item</span>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete stock item <strong>{{ selectedRow?.name }}</strong>?
          The Cloudinary image is deleted first; the stock row is only removed if that succeeds.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup :disable="deleteLoading" />
          <q-btn
            color="negative"
            label="Delete"
            :loading="deleteLoading"
            :disable="deleteLoading"
            @click="deleteItem"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Bulk Delete Confirmation Dialog -->
    <q-dialog v-model="bulkDeleteConfirmOpen" persistent>
      <q-card style="width: 400px; max-width: 90vw;" class="floating-surface shadow-2 q-pa-md relative-position">
        <q-inner-loading :showing="bulkDeleteLoading" color="negative">
          <q-spinner size="40px" color="negative" />
          <div class="text-caption text-grey-8 q-mt-sm">Deleting selected stock and images...</div>
        </q-inner-loading>
        <q-card-section class="row items-center">
          <q-avatar icon="warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Selected Stock</span>
        </q-card-section>
        <q-card-section>
          Delete <strong>{{ selectedStockIds.length }}</strong> selected stock item(s)?
          Cloudinary images are deleted first; stock rows are only removed if image delete succeeds.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup :disable="bulkDeleteLoading" />
          <q-btn
            color="negative"
            label="Delete all"
            :loading="bulkDeleteLoading"
            :disable="bulkDeleteLoading"
            @click="deleteSelectedItems"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Remove Image Confirmation Dialog -->
    <q-dialog v-model="imageRemoveConfirmOpen" persistent>
      <q-card style="width: 350px; max-width: 90vw;" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center">
          <q-avatar icon="image" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Remove Product Image</span>
        </q-card-section>
        <q-card-section>
          Remove this product image? The change is applied when you save the stock item.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" color="grey-7" v-close-popup />
          <q-btn color="negative" label="Remove" no-caps @click="removeEditImage" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Barcode Preview Dialog -->
    <q-dialog v-model="barcodePreviewOpen">
      <q-card style="min-width: 320px; text-align: center; border-radius: 14px;">
        <q-card-section class="bg-grey-2 q-py-xs text-right">
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-lg">
          <div class="text-overline text-grey-7 q-mb-xs">THRIFT STOCK BARCODE</div>
          <div v-if="previewStockLabel" class="text-caption text-grey-7 q-mb-xs">{{ previewStockLabel }}</div>
          <div class="q-mb-md text-weight-bold text-subtitle1">{{ previewBarcodeValue }}</div>

          <div class="q-my-md q-px-md row justify-center">
            <div class="barcode-preview-frame">
              <BarcodeRenderer
                v-if="previewBarcodeValue"
                :value="previewBarcodeValue"
                :display-value="false"
                :height="48"
              />
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="center" class="q-pb-md">
          <q-btn
            color="primary"
            no-caps
            icon="content_copy"
            label="Copy barcode"
            class="pill-btn"
            @click="copyPreviewBarcode"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Global Cloudinary Uploader Dialog -->
    <CloudinaryUploaderDialog
      v-model="isUploaderOpen"
      :folder="uploaderCloudinaryFolder"
      drive-folder-path="thrift"
      defer-upload
      @selected="onImageSelected"
    />

    <PageInitialLoader v-if="actionLoading" overlay />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftStockStore } from '../stores/thriftStockStore';
import { useThriftStore } from 'src/modules/thrift/shared/stores/thriftStore';
import { useThriftSettingsStore } from 'src/modules/thrift/settings/stores/thriftSettingsStore';
import { useThriftCurrencyStore } from 'src/modules/thrift/currency/stores/thriftCurrencyStore';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import { useQuasar, copyToClipboard, type QTableColumn } from 'quasar';
import { supabase } from 'src/boot/supabase';
import SmartImage from 'src/components/SmartImage.vue';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import BarcodeRenderer from 'src/modules/thrift/barcode/components/BarcodeRenderer.vue';
import type { ThriftStock, ThriftSection, ThriftCondition } from '../types';
import { resolveTypeIcon } from 'src/modules/thrift/type/utils/typeIcon';
import type { CloudinarySelectedImage } from 'src/components/CloudinaryUploaderDialog.vue';
import {
  cleanupStockImageAssets,
  deleteStockCloudinaryImageStrict,
  uploadStockImage as uploadStockImageAssets,
  type StockImageUploadResult,
} from 'src/utils/stockImageClient';
import { deleteDriveFile } from 'src/utils/driveClient';
import {
  thriftStockRepository,
  type ThriftStockDeleteTarget,
  type ThriftStockPricingInput,
} from '../repositories/thriftStockRepository';
import {
  DEFAULT_THRIFT_CLOUDINARY_FOLDER,
  buildThriftShipmentCloudinaryFolder,
} from 'src/utils/cloudinaryClient';
import { downloadCsv, rowsToCsv } from 'src/utils/csvExport';
import { formatThriftStockMeasurements } from 'src/modules/thrift/shared/utils/formatThriftStockMeasurements';
import ThriftStockMeasurementsDialog from '../components/ThriftStockMeasurementsDialog.vue';
import {
  computeThriftUnitCosts,
  type ThriftUnitCostBreakdown,
} from 'src/modules/thrift/shared/utils/computeThriftUnitCosts';

const $q = useQuasar();
const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const store = useThriftStockStore();
const thriftStore = useThriftStore();
const settingsStore = useThriftSettingsStore();
const currencyStore = useThriftCurrencyStore();

const shipmentUnitCounts = ref<Map<number, number>>(new Map());

async function loadShipmentUnitCounts() {
  if (!authStore.tenantId) return;
  try {
    const map = await thriftStockRepository.fetchQuantityByShipment(authStore.tenantId);
    shipmentUnitCounts.value = map;
  } catch (err: unknown) {
    console.error('Failed to load shipment unit counts:', err);
  }
}

const costBreakdownByStockId = computed<Record<number, ThriftUnitCostBreakdown>>(() => {
  const settings = settingsStore.settings;
  if (!settings) return {};

  const breakdowns: Record<number, ThriftUnitCostBreakdown> = {};
  for (const stock of stocks.value) {
    const shipment = thriftStore.shipments.find((s) => s.id === stock.shipment_id);
    if (!shipment) continue;

    const U = shipmentUnitCounts.value.get(stock.shipment_id) || 1;
    const pricing = stock.pricing
      ? {
          listed_unit_price: stock.pricing.listed_unit_price,
          is_listed_price_manual: stock.pricing.is_listed_price_manual,
        }
      : undefined;

    breakdowns[stock.id] = computeThriftUnitCosts(
      {
        quantity: stock.quantity || 0,
        origin_unit_price: stock.origin_unit_price,
        extra_origin_unit_price: stock.extra_origin_unit_price,
        additional_charges_cost: stock.additional_charges_cost,
      },
      shipment,
      settings,
      U,
      pricing,
    );
  }
  return breakdowns;
});

function openMeasurementsDialog(row: ThriftStock) {
  $q.dialog({
    component: ThriftStockMeasurementsDialog,
    componentProps: {
      stock: row,
    },
  }).onOk((payload: { size: string; measurements: any }) => {
    row.size = payload.size;
    row.measurements = payload.measurements;
  });
}

interface ShipmentOption {
  id: number;
  name: string;
  purchase_currency_id: number;
  cost_currency_id: number;
}

// Dialogs state
const dialogOpen = ref(false);
const editingId = ref<number | null>(null);
const quickAddDialogOpen = ref(false);
const isUploaderOpen = ref(false);
const uploaderTarget = ref<'quick' | 'edit'>('quick');

const quickSubmitting = ref(false);
const deleteConfirmOpen = ref(false);
const deleteLoading = ref(false);
const bulkDeleteConfirmOpen = ref(false);
const bulkDeleteLoading = ref(false);
const csvExportLoading = ref(false);
const selectedStockIds = ref<number[]>([]);
const imageRemoveConfirmOpen = ref(false);
const barcodePreviewOpen = ref(false);
const previewBarcodeValue = ref('');
const previewStockLabel = ref('');
const actionLoading = ref(false);
const selectedRow = ref<ThriftStock | null>(null);

const quickAddForm = ref({
  shipment_id: null as number | null,
  box_id: null as number | null,
  barcode: '',
  brand_name: '',
  condition: 'EXCELLENT' as ThriftCondition,
  product_weight: 250 as number | null,
  imagePreviewUrl: '',
  pendingBlob: null as Blob | null,
  alsoUploadToDrive: false,
});

const quickAddBarcodeLoading = ref(false);

const canSubmitQuickAdd = computed(() => {
  const form = quickAddForm.value;
  return !!(
    form.pendingBlob
    && form.shipment_id
    && form.barcode.trim()
    && form.brand_name.trim()
    && form.condition
    && form.product_weight != null
    && Number(form.product_weight) > 0
  );
});

const editImage = ref({
  url: '',
  originalUrl: '',
  originalDriveFileId: '',
  pendingBlob: null as Blob | null,
  pendingPreviewUrl: null as string | null,
  removed: false,
  alsoUploadToDrive: false,
});

const stocks = computed(() => store.stocks);
const loading = computed(() => store.loading);

const tablePagination = ref({
  page: 1,
  rowsPerPage: 20,
  rowsNumber: 0,
});
const categories = computed(() => thriftStore.categories);
const types = computed(() => thriftStore.types);
const shelves = computed(() => thriftStore.shelves);

const form = ref({
  category_id: null as number | null,
  type_id: null as number | null,
  shipment_id: null as number | null,
  box_id: null as number | null,
  name: '',
  brand_name: '',
  barcode: '',
  section: 'UNISEX' as ThriftSection | null,
  shelf_id: null as number | null,
  color: '',
  size: '',
  condition: 'EXCELLENT' as ThriftCondition | null,
  quantity: 1,
  product_weight: 250,
  extra_weight: 0,
  note: '',
});

const uploaderCloudinaryFolder = computed(() => {
  const shipmentId =
    uploaderTarget.value === 'quick'
      ? quickAddForm.value.shipment_id
      : form.value.shipment_id;
  if (shipmentId && shipmentId > 0) {
    return buildThriftShipmentCloudinaryFolder(shipmentId);
  }
  return DEFAULT_THRIFT_CLOUDINARY_FOLDER;
});

const originUnitPrice = ref(0);
const extraOriginUnitPrice = ref(0);
const additionalChargesCost = ref(0);

const purchaseCurrency = computed(() => {
  const shipmentId = form.value.shipment_id;
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
});
const costCurrency = computed(() => {
  const shipmentId = form.value.shipment_id;
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.cost_currency_id);
});
const purchaseCurrencySymbol = computed(() => purchaseCurrency.value?.symbol ?? '');
const costCurrencySymbol = computed(() => costCurrency.value?.symbol ?? '');

const quickAddPurchaseCurrency = computed(() => {
  const shipmentId = quickAddForm.value.shipment_id;
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
});

const shipments = ref<ShipmentOption[]>([]);

const shipmentById = computed(() => {
  const map = new Map<number, ShipmentOption>();
  for (const shipment of shipments.value) {
    map.set(shipment.id, shipment);
  }
  return map;
});

function shipmentPurchaseCurrency(shipmentId: number | null | undefined): ThriftCurrency | undefined {
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.purchase_currency_id);
}

function shipmentCostCurrency(shipmentId: number | null | undefined): ThriftCurrency | undefined {
  if (!shipmentId) return undefined;
  return currencyStore.currencyById(shipmentById.value.get(shipmentId)?.cost_currency_id);
}

async function loadShipments() {
  if (!authStore.tenantId) return;
  const { data } = await supabase
    .from('thrift_shipments')
    .select('id, name, purchase_currency_id, cost_currency_id')
    .eq('tenant_id', authStore.tenantId)
    .order('name', { ascending: true });
  shipments.value = (data || []) as ShipmentOption[];
}

const filteredBoxes = computed(() => {
  if (!form.value.shipment_id) return [];
  return thriftStore.boxes.filter(b => b.shipment_id === form.value.shipment_id);
});

const quickAddFilteredBoxes = computed(() => {
  if (!quickAddForm.value.shipment_id) return [];
  return thriftStore.boxes.filter(b => b.shipment_id === quickAddForm.value.shipment_id);
});

function onShipmentChange() {
  form.value.box_id = null;
}

function onQuickShipmentChange() {
  quickAddForm.value.box_id = null;
  void loadFirstAvailableBarcode();
}

async function loadFirstAvailableBarcode() {
  if (!authStore.tenantId || !quickAddForm.value.shipment_id) {
    quickAddForm.value.barcode = '';
    return;
  }

  quickAddBarcodeLoading.value = true;
  try {
    const { data, error } = await supabase
      .from('thrift_barcodes')
      .select('barcode_id')
      .eq('tenant_id', authStore.tenantId)
      .eq('status', 'AVAILABLE')
      .order('barcode_id', { ascending: true })
      .limit(1)
      .maybeSingle();

    if (error) throw error;
    quickAddForm.value.barcode = data?.barcode_id ?? '';
  } catch (err) {
    console.error('Failed to load available barcode:', err);
    quickAddForm.value.barcode = '';
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Failed to load available barcode',
    });
  } finally {
    quickAddBarcodeLoading.value = false;
  }
}

function getBoxName(boxId: number | undefined | null) {
  if (!boxId) return '—';
  const bx = thriftStore.boxes.find(b => b.id === boxId);
  return bx ? bx.name : `#${boxId}`;
}

const pricing = ref({
  listed_unit_price: 0,
  is_listed_price_manual: false,
});

const searchText = ref('');
const filterDrawerOpen = ref(false);
const statusFilter = ref<string | null>(null);
const conditionFilter = ref<string | null>(null);
const draftStatusFilter = ref<string | null>(null);
const draftConditionFilter = ref<string | null>(null);

const activeFilterCount = computed(
  () => (statusFilter.value ? 1 : 0) + (conditionFilter.value ? 1 : 0),
);

function openFilterDrawer() {
  draftStatusFilter.value = statusFilter.value;
  draftConditionFilter.value = conditionFilter.value;
  filterDrawerOpen.value = true;
}

function onApplyDrawerFilters() {
  statusFilter.value = draftStatusFilter.value;
  conditionFilter.value = draftConditionFilter.value;
  filterDrawerOpen.value = false;
  onFiltersChanged();
}

function onResetDrawerFilters() {
  draftStatusFilter.value = null;
  draftConditionFilter.value = null;
}

const statusOptions = [
  { label: 'Available', value: 'AVAILABLE' },
  { label: 'Out of Stock', value: 'OUT_OF_STOCK' },
  { label: 'Damaged', value: 'DAMAGED' },
  { label: 'Stolen', value: 'STOLEN' },
];

const conditionOptions = [
  { label: 'New With Tags', value: 'NEW_WITH_TAGS' },
  { label: 'Excellent', value: 'EXCELLENT' },
  { label: 'Good', value: 'GOOD' },
  { label: 'Fair', value: 'FAIR' },
];

const alwaysVisibleColumns = ['select', 'sl', 'image', 'id', 'barcode', 'name', 'actions'] as const;

const columnSelectorOptions = [
  { label: 'Brand', value: 'brand_name' },
  { label: 'Section', value: 'section' },
  { label: 'Measurements', value: 'size' },
  { label: 'Box', value: 'box' },
  { label: 'Product Wt', value: 'product_weight' },
  { label: 'Extra Wt', value: 'extra_weight' },
  { label: 'Condition', value: 'condition' },
  { label: 'Qty', value: 'quantity' },
  { label: 'Origin', value: 'origin_unit_price' },
  { label: 'Extra Origin', value: 'extra_origin_unit_price' },
  { label: 'Product Cost', value: 'product_unit_cost' },
  { label: 'Cargo/Unit', value: 'cargo_share_per_unit' },
  { label: 'Ops/Unit', value: 'ops_share_per_unit' },
  { label: 'Add\'l Charges', value: 'additional_charges_cost' },
  { label: 'Landed', value: 'landed_unit_cost' },
  { label: 'Suggested Sell', value: 'suggested_sell_unit_price' },
  { label: 'Listed Sell', value: 'listed_unit_price' },
  { label: 'Manual Price', value: 'is_listed_price_manual' },
  { label: 'Status', value: 'status' },
];

const selectableColumnValues = columnSelectorOptions.map((option) => option.value);

const selectedColumnNames = ref<string[]>([...selectableColumnValues]);

const visibleColumns = computed<string[]>(() => {
  const visible = new Set<string>([
    ...alwaysVisibleColumns,
    ...selectedColumnNames.value,
  ]);
  return columns.map((column) => column.name).filter((name) => visible.has(name));
});

const allSelectableColumnsSelected = computed({
  get: () => selectableColumnValues.every((value) => selectedColumnNames.value.includes(value)),
  set: (checked: boolean) => {
    selectedColumnNames.value = checked ? [...selectableColumnValues] : [];
  },
});

const columns: QTableColumn[] = [
  { name: 'select', label: '', field: 'select', align: 'center', sortable: false, headerStyle: 'width: 44px', classes: 'col-sticky-select', headerClasses: 'col-sticky-select' },
  { name: 'sl', label: 'SL', field: 'sl', align: 'center', sortable: false, headerStyle: 'width: 50px', classes: 'col-sticky-sl', headerClasses: 'col-sticky-sl' },
  { name: 'image', align: 'center', label: 'Image', field: 'image_url', headerStyle: 'width: 104px; min-width: 104px; max-width: 104px', classes: 'col-sticky-image', headerClasses: 'col-sticky-image' },
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true, headerStyle: 'width: 70px' },
  { name: 'barcode', align: 'left', label: 'Barcode', field: 'barcode', sortable: true },
  { name: 'name', align: 'left', label: 'Name', field: 'name', sortable: true },
  { name: 'brand_name', align: 'left', label: 'Brand', field: 'brand_name' },
  { name: 'section', align: 'left', label: 'Section', field: 'section' },
  { name: 'size', align: 'left', label: 'Measurements', field: (row) => formatThriftStockMeasurements(row) },
  { name: 'box', align: 'left', label: 'Box', field: 'box' },
  { name: 'product_weight', align: 'right', label: 'Product Wt', field: 'product_weight' },
  { name: 'extra_weight', align: 'right', label: 'Extra Wt', field: 'extra_weight' },
  { name: 'condition', align: 'left', label: 'Condition', field: 'condition' },
  { name: 'quantity', align: 'right', label: 'Qty', field: 'quantity', sortable: true },
  { name: 'origin_unit_price', align: 'right', label: 'Origin', field: 'origin_unit_price' },
  { name: 'extra_origin_unit_price', align: 'right', label: 'Extra Origin', field: 'extra_origin_unit_price' },
  { name: 'product_unit_cost', align: 'right', label: 'Product Cost', field: 'product_unit_cost' },
  { name: 'cargo_share_per_unit', align: 'right', label: 'Cargo/Unit', field: 'cargo_share_per_unit' },
  { name: 'ops_share_per_unit', align: 'right', label: 'Ops/Unit', field: 'ops_share_per_unit' },
  { name: 'additional_charges_cost', align: 'right', label: 'Add\'l Charges', field: 'additional_charges_cost' },
  { name: 'landed_unit_cost', align: 'right', label: 'Landed', field: 'landed_unit_cost' },
  { name: 'suggested_sell_unit_price', align: 'right', label: 'Suggested Sell', field: 'suggested_sell_unit_price' },
  { name: 'listed_unit_price', align: 'right', label: 'Listed Sell', field: (row) => row.pricing?.listed_unit_price },
  { name: 'is_listed_price_manual', align: 'center', label: 'Manual', field: (row) => row.pricing?.is_listed_price_manual },
  { name: 'status', align: 'center', label: 'Status', field: 'status', sortable: true },
  { name: 'actions', align: 'right', label: '', field: 'actions' },
];

function formatStockPrice(
  amount: number | null | undefined,
  currency: ThriftCurrency | undefined,
): string {
  if (amount == null) return '—';
  return formatThriftAmount(amount, currency);
}

const sectionSelectOptions = ['MALE', 'FEMALE', 'UNISEX', 'KIDS', 'HOME'] as const;
const conditionSelectOptions = ['NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR'] as const;

const editableColumns = new Set([
  'barcode',
  'name',
  'brand_name',
  'section',
  'size',
  'box',
  'product_weight',
  'extra_weight',
  'condition',
  'quantity',
  'origin_unit_price',
  'extra_origin_unit_price',
  'additional_charges_cost',
  'listed_unit_price',
  'is_listed_price_manual',
  'status',
]);

function toNumber(value: unknown, fallback = 0): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function buildPricingFromRow(row: ThriftStock): ThriftStockPricingInput {
  return {
    listed_unit_price: Number(row.pricing?.listed_unit_price) || 0,
    is_listed_price_manual: !!row.pricing?.is_listed_price_manual,
  };
}

function boxesForShipment(shipmentId: number) {
  return thriftStore.boxes.filter((box) => box.shipment_id === shipmentId);
}

async function saveStockCell(
  row: ThriftStock,
  stockPatch: Partial<ThriftStock> = {},
  pricingPatch?: Partial<ThriftStockPricingInput>,
) {
  const pricing = { ...buildPricingFromRow(row), ...pricingPatch };
  const updated = await store.updateStock(row.id, stockPatch, pricing);
  Object.assign(row, stockPatch);
  if (pricingPatch) {
    row.pricing = {
      cost_of_goods_sold: pricing.cost_of_goods_sold,
      target_price: pricing.target_price,
      listed_unit_price: pricing.listed_unit_price,
      is_listed_price_manual: pricing.is_listed_price_manual,
      extra_expense_cost: pricing.extra_expense_cost ?? 0,
    };
  }
  if (updated.pricing) {
    row.pricing = updated.pricing;
  }
}

async function onTextCellSave(row: ThriftStock, field: 'name' | 'brand_name' | 'size' | 'barcode', value: string) {
  try {
    row[field] = value;
    await saveStockCell(row, { [field]: value });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

async function onNumberCellSave(
  row: ThriftStock,
  field: 'product_weight' | 'extra_weight' | 'quantity',
  value: number,
) {
  try {
    row[field] = value;
    await saveStockCell(row, { [field]: value });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

async function onSectionSave(row: ThriftStock, value: ThriftSection | null) {
  try {
    row.section = value;
    await saveStockCell(row, { section: value });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

async function onConditionSave(row: ThriftStock, value: ThriftCondition | null) {
  try {
    row.condition = value;
    await saveStockCell(row, { condition: value });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

async function onBoxSave(row: ThriftStock, boxId: number | null) {
  try {
    row.box_id = boxId ?? undefined;
    await saveStockCell(row, { box_id: boxId ?? undefined });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

async function onOriginUnitPriceSave(row: ThriftStock, value: number) {
  try {
    row.origin_unit_price = value;
    await saveStockCell(row, { origin_unit_price: value });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

async function onExtraOriginUnitPriceSave(row: ThriftStock, value: number) {
  try {
    row.extra_origin_unit_price = value;
    await saveStockCell(row, { extra_origin_unit_price: value });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

async function onPricingCellSave(
  row: ThriftStock,
  field: keyof ThriftStockPricingInput,
  value: number,
) {
  try {
    if (!row.pricing) {
      row.pricing = buildPricingFromRow(row);
    }
    row.pricing[field] = value;
    await saveStockCell(row, {}, { [field]: value });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

async function onStatusCellSave(row: ThriftStock, status: string) {
  try {
    await store.updateStockStatus(row.id, status);
    row.status = status as ThriftStock['status'];
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
    await loadStockPage();
  }
}

function stickyCellClass(columnName: string): string {
  if (columnName === 'select') return 'col-sticky-select';
  if (columnName === 'sl') return 'col-sticky-sl';
  if (columnName === 'image') return 'col-sticky-image';
  return '';
}

function tableCellClass(columnName: string): string {
  const classes: string[] = [];
  if (columnName === 'actions') classes.push('text-right');
  if (editableColumns.has(columnName)) classes.push('editable-cell');
  if (
    columnName === 'origin_purchase_price'
    || columnName === 'extra_origin_purchase_expense'
    || columnName === 'origin_unit_price'
    || columnName === 'extra_origin_unit_price'
    || columnName === 'cost_of_goods_sold'
    || columnName === 'extra_expense_cost'
    || columnName === 'target_price'
    || columnName === 'listed_price'
    || columnName === 'listed_unit_price'
    || columnName === 'product_weight'
    || columnName === 'extra_weight'
    || columnName === 'quantity'
  ) {
    classes.push('text-right');
  }
  return classes.join(' ');
}

onMounted(async () => {
  if (authStore.tenantId) {
    await Promise.all([
      loadStockPage(1),
      thriftStore.loadModuleData(authStore.tenantId),
      loadShipments(),
      settingsStore.loadSettings(authStore.tenantId),
      currencyStore.loadCurrencies(),
      loadShipmentUnitCounts(),
    ]);
  }
});

function syncTablePagination() {
  tablePagination.value.page = store.page;
  tablePagination.value.rowsPerPage = store.pageSize;
  tablePagination.value.rowsNumber = store.total;
}

async function loadStockPage(nextPage = store.page) {
  if (!authStore.tenantId) return;
  await Promise.all([
    store.loadStocks(authStore.tenantId, {
      page: nextPage,
      pageSize: tablePagination.value.rowsPerPage,
      search: searchText.value,
      status: statusFilter.value,
      condition: conditionFilter.value,
    }),
    loadShipmentUnitCounts(),
  ]);
  syncTablePagination();
}

function onFiltersChanged() {
  selectedStockIds.value = [];
  void loadStockPage(1);
}

const allPageRowsSelected = computed(() =>
  stocks.value.length > 0 && stocks.value.every((stock) => selectedStockIds.value.includes(stock.id)),
);

const somePageRowsSelected = computed(() =>
  stocks.value.some((stock) => selectedStockIds.value.includes(stock.id)),
);

function toggleStockSelection(id: number, checked: boolean) {
  if (checked) {
    if (!selectedStockIds.value.includes(id)) {
      selectedStockIds.value = [...selectedStockIds.value, id];
    }
    return;
  }
  selectedStockIds.value = selectedStockIds.value.filter((stockId) => stockId !== id);
}

function toggleSelectAllPage(checked: boolean) {
  if (checked) {
    const pageIds = stocks.value.map((stock) => stock.id);
    selectedStockIds.value = [...new Set([...selectedStockIds.value, ...pageIds])];
    return;
  }
  const pageIdSet = new Set(stocks.value.map((stock) => stock.id));
  selectedStockIds.value = selectedStockIds.value.filter((id) => !pageIdSet.has(id));
}

function clearStockSelection() {
  selectedStockIds.value = [];
}

function confirmBulkDelete() {
  if (!selectedStockIds.value.length) return;
  bulkDeleteConfirmOpen.value = true;
}

async function deleteStockTarget(target: ThriftStockDeleteTarget): Promise<void> {
  await deleteStockCloudinaryImageStrict(target.imageUrl);
  await store.deleteStock(target.id);
  if (target.driveFileId) {
    try {
      await deleteDriveFile(target.driveFileId);
    } catch (err) {
      console.warn('Drive cleanup failed after stock delete:', err);
    }
  }
}

async function cleanupAndDeleteStockTargets(targets: ThriftStockDeleteTarget[]) {
  for (const target of targets) {
    await deleteStockTarget(target);
  }
}

async function onTableRequest(props: { pagination: { page: number; rowsPerPage: number } }) {
  tablePagination.value.rowsPerPage = props.pagination.rowsPerPage;
  await loadStockPage(props.pagination.page);
}

function goToSettings() {
  const slug = route.params.tenantSlug || authStore.tenantSlug;
  const tenantSlug = Array.isArray(slug) ? slug[0] : slug;
  void router.push(tenantSlug ? `/${tenantSlug}/app/thrift/settings` : '/app/thrift/settings');
}

const STOCK_CSV_HEADERS = [
  'id',
  'barcode',
  'shipment_id',
  'name',
  'brand_name',
  'color',
  'size',
  'note',
  'category_id',
  'type_id',
  'shelf_id',
  'box_id',
  'section',
  'condition',
  'stock_type',
  'status',
  'quantity',
  'product_weight',
  'extra_weight',
  'origin_unit_price',
  'extra_origin_unit_price',
  'product_unit_cost',
  'cargo_share_per_unit',
  'ops_share_per_unit',
  'additional_charges_cost',
  'landed_unit_cost',
  'suggested_sell_unit_price',
  'listed_unit_price',
  'is_listed_price_manual',
  'image_url',
  'drive_file_id',
  'inserted_by',
  'created_at',
  'updated_at',
] as const;

async function downloadStockCsv() {
  if (!authStore.tenantId) return;
  csvExportLoading.value = true;
  try {
    const [stocks, settings, unitCountsMap] = await Promise.all([
      thriftStockRepository.fetchStocks(authStore.tenantId),
      settingsStore.settings ? Promise.resolve(settingsStore.settings) : settingsStore.loadSettings(authStore.tenantId).then(() => settingsStore.settings),
      thriftStockRepository.fetchQuantityByShipment(authStore.tenantId),
    ]);

    const rows = stocks.map((s) => {
      const shipment = thriftStore.shipments.find((sh) => sh.id === s.shipment_id);
      const U = unitCountsMap.get(s.shipment_id) || 1;
      const pricing = s.pricing
        ? {
            listed_unit_price: s.pricing.listed_unit_price,
            is_listed_price_manual: s.pricing.is_listed_price_manual,
          }
        : undefined;

      const breakdown = settings && shipment
        ? computeThriftUnitCosts(
            {
              quantity: s.quantity || 0,
              origin_unit_price: s.origin_unit_price,
              extra_origin_unit_price: s.extra_origin_unit_price,
              additional_charges_cost: s.additional_charges_cost,
            },
            shipment,
            settings,
            U,
            pricing,
          )
        : null;

      return {
        id: s.id,
        barcode: s.barcode,
        shipment_id: s.shipment_id,
        name: s.name,
        brand_name: s.brand_name ?? '',
        color: s.color,
        size: s.size,
        note: s.note ?? '',
        category_id: s.category_id ?? '',
        type_id: s.type_id ?? '',
        shelf_id: s.shelf_id ?? '',
        box_id: s.box_id ?? '',
        section: s.section ?? '',
        condition: s.condition ?? '',
        stock_type: s.stock_type,
        status: s.status,
        quantity: s.quantity,
        product_weight: s.product_weight ?? '',
        extra_weight: s.extra_weight ?? '',
        origin_unit_price: s.origin_unit_price ?? '',
        extra_origin_unit_price: s.extra_origin_unit_price ?? '',
        product_unit_cost: breakdown?.product_unit_cost ?? '',
        cargo_share_per_unit: breakdown?.cargo_share_per_unit ?? '',
        ops_share_per_unit: breakdown?.ops_share_per_unit ?? '',
        additional_charges_cost: s.additional_charges_cost ?? '',
        landed_unit_cost: breakdown?.landed_unit_cost ?? '',
        suggested_sell_unit_price: breakdown?.suggested_sell_unit_price ?? '',
        listed_unit_price: s.pricing?.listed_unit_price ?? '',
        is_listed_price_manual: !!s.pricing?.is_listed_price_manual,
        image_url: s.image_url ?? '',
        drive_file_id: s.drive_file_id ?? '',
        inserted_by: s.inserted_by,
        created_at: s.created_at,
        updated_at: s.updated_at,
      };
    });
    const csv = rowsToCsv([...STOCK_CSV_HEADERS], rows);
    const slug = authStore.tenantSlug || 'tenant';
    const date = new Date().toISOString().slice(0, 10);
    downloadCsv(`thrift-stock-backup-${slug}-${date}.csv`, csv);
    $q.notify({ type: 'positive', message: `Exported ${rows.length} stock row(s)` });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'CSV export failed' });
  } finally {
    csvExportLoading.value = false;
  }
}

async function openAddDialog() {
  quickAddForm.value = {
    shipment_id: null,
    box_id: null,
    barcode: '',
    brand_name: '',
    condition: 'EXCELLENT',
    product_weight: 250,
    imagePreviewUrl: '',
    pendingBlob: null,
    alsoUploadToDrive: false,
  };
  uploaderTarget.value = 'quick';
  if (authStore.tenantId) {
    await settingsStore.loadSettings(authStore.tenantId);
  }
  quickAddDialogOpen.value = true;
}

async function uploadStockImageBlob(
  barcode: string,
  stockId: number,
  blob: Blob,
  alsoUploadToDrive = false,
  shipmentId?: number | null,
  replace?: { imageUrl?: string; driveFileId?: string | null },
): Promise<StockImageUploadResult> {
  if (!authStore.tenantId) {
    throw new Error('Tenant is required to upload an image.');
  }
  if (!shipmentId || shipmentId <= 0) {
    throw new Error('Shipment is required to upload an image.');
  }

  return uploadStockImageAssets(blob, {
    barcode,
    stockId,
    tenantId: authStore.tenantId,
    ...(shipmentId ? { shipmentId } : {}),
    alsoUploadToDrive,
    ...(replace?.imageUrl ? { replaceImageUrl: replace.imageUrl } : {}),
    ...(replace?.driveFileId ? { replaceDriveFileId: replace.driveFileId } : {}),
    onDriveUploadFailed: (error) => {
      $q.notify({
        type: 'warning',
        message: error.message || 'Google Drive upload failed. Image saved to Cloudinary only.',
      });
    },
  });
}

function revokeBlobPreview(url: string) {
  if (url?.startsWith('blob:')) {
    URL.revokeObjectURL(url);
  }
}

function clearPendingEditImage() {
  if (editImage.value.pendingPreviewUrl) {
    revokeBlobPreview(editImage.value.pendingPreviewUrl);
  }
  editImage.value.pendingBlob = null;
  editImage.value.pendingPreviewUrl = null;
}

function onQuickImageSelected(payload: CloudinarySelectedImage) {
  if (quickAddForm.value.imagePreviewUrl?.startsWith('blob:')) {
    revokeBlobPreview(quickAddForm.value.imagePreviewUrl);
  }
  quickAddForm.value.imagePreviewUrl = payload.previewUrl;
  quickAddForm.value.pendingBlob = payload.blob;
  quickAddForm.value.alsoUploadToDrive = payload.alsoUploadToDrive ?? false;
}

function openEditUploader() {
  uploaderTarget.value = 'edit';
  isUploaderOpen.value = true;
}

function onEditImageSelected(payload: CloudinarySelectedImage) {
  clearPendingEditImage();
  editImage.value.url = payload.previewUrl;
  editImage.value.pendingBlob = payload.blob;
  editImage.value.pendingPreviewUrl = payload.previewUrl;
  editImage.value.removed = false;
  editImage.value.alsoUploadToDrive = payload.alsoUploadToDrive ?? false;
}

function onImageSelected(payload: CloudinarySelectedImage) {
  if (uploaderTarget.value === 'edit') {
    onEditImageSelected(payload);
  } else {
    onQuickImageSelected(payload);
  }
}

function removeEditImage() {
  clearPendingEditImage();
  editImage.value.url = '';
  editImage.value.removed = true;
  imageRemoveConfirmOpen.value = false;
}

function openBarcodePreview(row: ThriftStock) {
  const barcode = row.barcode?.trim();
  if (!barcode) return;

  previewBarcodeValue.value = barcode;
  previewStockLabel.value = [row.name, row.brand_name].filter(Boolean).join(' · ');
  barcodePreviewOpen.value = true;
}

async function copyPreviewBarcode() {
  const text = previewBarcodeValue.value.trim();
  if (!text) return;

  await copyToClipboard(text);
  $q.notify({
    type: 'positive',
    message: 'Barcode copied',
    position: 'top-right',
  });
}

function resetEditImage() {
  clearPendingEditImage();
  editImage.value = {
    url: '',
    originalUrl: '',
    originalDriveFileId: '',
    pendingBlob: null,
    pendingPreviewUrl: null,
    removed: false,
    alsoUploadToDrive: false,
  };
}

function onQuickAddDialogHide() {
  if (quickAddForm.value.imagePreviewUrl?.startsWith('blob:')) {
    revokeBlobPreview(quickAddForm.value.imagePreviewUrl);
  }
  quickAddForm.value.imagePreviewUrl = '';
  quickAddForm.value.pendingBlob = null;
  quickAddForm.value.alsoUploadToDrive = false;
}

function onEditDialogHide() {
  if (editImage.value.pendingPreviewUrl) {
    revokeBlobPreview(editImage.value.pendingPreviewUrl);
    editImage.value.pendingBlob = null;
    editImage.value.pendingPreviewUrl = null;
    if (!editImage.value.removed) {
      editImage.value.url = editImage.value.originalUrl;
    }
  }
}

async function submitQuickAdd() {
  if (!canSubmitQuickAdd.value || !authStore.tenantId) return;

  const brandName = quickAddForm.value.brand_name.trim();
  const condition = quickAddForm.value.condition;
  const productWeight = Number(quickAddForm.value.product_weight);

  if (!brandName) {
    $q.notify({ type: 'negative', message: 'Brand name is required' });
    return;
  }
  if (!condition) {
    $q.notify({ type: 'negative', message: 'Condition is required' });
    return;
  }
  if (!Number.isFinite(productWeight) || productWeight <= 0) {
    $q.notify({ type: 'negative', message: 'Product weight is required' });
    return;
  }
  if (!quickAddForm.value.barcode.trim()) {
    $q.notify({ type: 'negative', message: 'No available barcode to assign' });
    return;
  }
  const pendingBlob = quickAddForm.value.pendingBlob;
  if (!pendingBlob) {
    $q.notify({ type: 'negative', message: 'Image is required' });
    return;
  }

  quickSubmitting.value = true;
  const alsoUploadToDrive = quickAddForm.value.alsoUploadToDrive;
  let uploadedImage: StockImageUploadResult | null = null;

  try {
    const barcode = quickAddForm.value.barcode;

    const catId = categories.value.find(c => c.name === 'Women Clothing')?.id ?? categories.value[0]?.id;
    const typId = types.value[0]?.id;

    if (!catId || !typId) {
      throw new Error('Category or type is not available. Please refresh and try again.');
    }

    const draftStock = await store.createStock(
      authStore.tenantId,
      quickAddForm.value.shipment_id!,
      '',
      brandName,
      catId,
      typId,
      'UNISEX',
      '',
      '',
      condition,
      barcode,
      'SINGLE',
      1,
      quickAddForm.value.box_id || undefined,
      productWeight,
      0,
      'Quick register draft entry',
      authStore.user?.email || 'admin@brandwala.com',
      {
        cost_of_goods_sold: 0,
        target_price: 0,
        listed_unit_price: 0,
        extra_expense_cost: 0,
      },
      form.value.image_url || undefined,
      form.value.shelf_id,
      settingsStore.defaultOriginUnitPrice,
      0,
    );

    const { error: barcodeUpdateError } = await supabase
      .from('thrift_barcodes')
      .update({ status: 'USED' })
      .eq('tenant_id', authStore.tenantId)
      .eq('barcode_id', barcode);

    if (barcodeUpdateError) {
      throw barcodeUpdateError;
    }

    uploadedImage = await uploadStockImageBlob(
      barcode,
      draftStock.id,
      pendingBlob,
      alsoUploadToDrive,
      quickAddForm.value.shipment_id,
    );
    await store.attachStockImage(
      draftStock.id,
      uploadedImage.secureUrl,
      draftStock.inserted_by,
      uploadedImage.driveFileId,
    );

    $q.notify({
      type: 'positive',
      message: 'Draft created. Please complete other details.',
    });

    quickAddForm.value.imagePreviewUrl = '';
    quickAddForm.value.pendingBlob = null;
    quickAddForm.value.alsoUploadToDrive = false;
    quickAddDialogOpen.value = false;

    openEditDialog({
      ...draftStock,
      image_url: uploadedImage.secureUrl,
      drive_file_id: uploadedImage.driveFileId,
    });
  } catch (err: unknown) {
    if (uploadedImage) {
      await cleanupStockImageAssets({
        imageUrl: uploadedImage.secureUrl,
        ...(uploadedImage.driveFileId ? { driveFileId: uploadedImage.driveFileId } : {}),
      });
    }
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Draft creation failed',
    });
  } finally {
    quickSubmitting.value = false;
  }
}

function openEditDialog(row: ThriftStock) {
  editingId.value = row.id;
  editImage.value = {
    url: row.image_url || '',
    originalUrl: row.image_url || '',
    originalDriveFileId: row.drive_file_id || '',
    pendingBlob: null,
    pendingPreviewUrl: null,
    removed: false,
    alsoUploadToDrive: false,
  };
  form.value = {
    category_id: row.category_id,
    type_id: row.type_id,
    shipment_id: row.shipment_id,
    box_id: row.box_id || null,
    name: row.name,
    brand_name: row.brand_name || '',
    barcode: row.barcode,
    section: row.section,
    shelf_id: row.shelf_id ?? null,
    color: row.color,
    size: row.size,
    condition: row.condition,
    quantity: row.quantity,
    product_weight: row.product_weight || 0,
    extra_weight: row.extra_weight || 0,
    note: row.note || '',
  };
  originUnitPrice.value = row.origin_unit_price ?? settingsStore.defaultOriginUnitPrice;
  extraOriginUnitPrice.value = row.extra_origin_unit_price ?? 0;
  additionalChargesCost.value = row.additional_charges_cost ?? 0;
  pricing.value = {
    cost_of_goods_sold: row.pricing?.cost_of_goods_sold || 0,
    target_price: row.pricing?.target_price || 0,
    listed_unit_price: row.pricing?.listed_unit_price || 0,
    is_listed_price_manual: row.pricing?.is_listed_price_manual,
    extra_expense_cost: row.pricing?.extra_expense_cost || 0,
  };
  dialogOpen.value = true;
}

async function updateStatus(stockId: number, status: string) {
  actionLoading.value = true;
  try {
    await store.updateStockStatus(stockId, status);
    $q.notify({ type: 'positive', message: `Stock marked as ${status}` });
    await loadStockPage();
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Update failed' });
  } finally {
    actionLoading.value = false;
  }
}

function confirmDelete(row: ThriftStock) {
  selectedRow.value = row;
  deleteConfirmOpen.value = true;
}

async function deleteItem() {
  if (!selectedRow.value || deleteLoading.value) return;
  deleteLoading.value = true;
  try {
    const targets = await thriftStockRepository.fetchDeleteTargets([selectedRow.value.id]);
    await cleanupAndDeleteStockTargets(targets);
    $q.notify({
      type: 'positive',
      message: 'Stock item deleted. Barcode is available again.',
    });
    deleteConfirmOpen.value = false;
    const deletedId = selectedRow.value.id;
    selectedRow.value = null;
    selectedStockIds.value = selectedStockIds.value.filter((id) => id !== deletedId);
    await loadStockPage();
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Delete failed' });
  } finally {
    deleteLoading.value = false;
  }
}

async function deleteSelectedItems() {
  if (!selectedStockIds.value.length || bulkDeleteLoading.value) return;
  bulkDeleteLoading.value = true;
  const ids = [...selectedStockIds.value];
  try {
    const targets = await thriftStockRepository.fetchDeleteTargets(ids);
    let deletedCount = 0;
    const failures: string[] = [];

    for (const target of targets) {
      try {
        await deleteStockTarget(target);
        deletedCount += 1;
        selectedStockIds.value = selectedStockIds.value.filter((id) => id !== target.id);
      } catch (err: unknown) {
        failures.push(`#${target.id}: ${(err as Error).message || 'Delete failed'}`);
      }
    }

    if (deletedCount > 0) {
      await loadStockPage();
    }

    if (failures.length === 0) {
      $q.notify({
        type: 'positive',
        message: `Deleted ${deletedCount} stock item(s). Barcodes are available again.`,
      });
      bulkDeleteConfirmOpen.value = false;
      selectedStockIds.value = [];
      return;
    }

    if (deletedCount > 0) {
      $q.notify({
        type: 'warning',
        message: `Deleted ${deletedCount} item(s). ${failures.length} failed because Cloudinary image delete did not succeed.`,
      });
      return;
    }

    $q.notify({
      type: 'negative',
      message: failures[0] || 'Bulk delete failed',
    });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Bulk delete failed' });
  } finally {
    bulkDeleteLoading.value = false;
  }
}

async function onSubmit() {
  if (!authStore.tenantId) return;
  actionLoading.value = true;
  let orphanImage: StockImageUploadResult | null = null;

  try {
    const stockData = {
      shipment_id: form.value.shipment_id!,
      name: form.value.name,
      brand_name: form.value.brand_name,
      category_id: form.value.category_id!,
      type_id: form.value.type_id!,
      section: form.value.section,
      shelf_id: form.value.shelf_id,
      color: form.value.color,
      size: form.value.size,
      condition: form.value.condition,
      barcode: form.value.barcode,
      quantity: form.value.quantity,
      box_id: form.value.box_id || undefined,
      product_weight: form.value.product_weight || undefined,
      extra_weight: form.value.extra_weight || undefined,
      note: form.value.note,
      origin_unit_price: originUnitPrice.value || undefined,
      extra_origin_unit_price: extraOriginUnitPrice.value || undefined,
      additional_charges_cost: additionalChargesCost.value || undefined,
    };

    if (editingId.value) {
      const imageChanged = editImage.value.removed || !!editImage.value.pendingBlob;
      let imagePayload: string | null | undefined;
      let driveFilePayload: string | null | undefined;
      const previousImageUrl = editImage.value.originalUrl;
      const previousDriveFileId = editImage.value.originalDriveFileId;

      if (editImage.value.removed) {
        imagePayload = null;
        driveFilePayload = null;
      } else if (editImage.value.pendingBlob) {
        const uploaded = await uploadStockImageBlob(
          form.value.barcode,
          editingId.value,
          editImage.value.pendingBlob,
          editImage.value.alsoUploadToDrive,
          form.value.shipment_id,
          {
            imageUrl: previousImageUrl,
            driveFileId: previousDriveFileId,
          },
        );
        orphanImage = uploaded;
        imagePayload = uploaded.secureUrl;
        driveFilePayload = uploaded.driveFileId ?? null;
      }

      await store.updateStock(
        editingId.value,
        stockData satisfies Partial<ThriftStock>,
        pricing.value,
        imageChanged ? imagePayload : undefined,
        imageChanged ? driveFilePayload : undefined,
      );

      if (imageChanged && (previousImageUrl || previousDriveFileId)) {
        await cleanupStockImageAssets({
          imageUrl: previousImageUrl,
          driveFileId: previousDriveFileId,
        });
      }

      orphanImage = null;
      $q.notify({ type: 'positive', message: 'Thrift stock updated successfully' });
    } else {
      const created = await store.createStock(
        authStore.tenantId,
        form.value.shipment_id!,
        form.value.name,
        form.value.brand_name,
        form.value.category_id!,
        form.value.type_id!,
        form.value.section || 'UNISEX',
        form.value.color,
        form.value.size,
        form.value.condition || 'EXCELLENT',
        form.value.barcode,
        'SINGLE',
        form.value.quantity,
        form.value.box_id || undefined,
        form.value.product_weight || undefined,
        form.value.extra_weight || undefined,
        form.value.note,
        authStore.user?.email || 'admin@brandwala.com',
        pricing.value,
        undefined,
        form.value.shelf_id,
        originUnitPrice.value || undefined,
        extraOriginUnitPrice.value || undefined,
        additionalChargesCost.value || undefined,
      );

      if (editImage.value.pendingBlob && !editImage.value.removed) {
        const uploaded = await uploadStockImageBlob(
          form.value.barcode,
          created.id,
          editImage.value.pendingBlob,
          editImage.value.alsoUploadToDrive,
          form.value.shipment_id,
        );
        orphanImage = uploaded;
        await store.attachStockImage(
          created.id,
          uploaded.secureUrl,
          created.inserted_by,
          uploaded.driveFileId,
        );
      }

      orphanImage = null;
      $q.notify({ type: 'positive', message: 'Thrift stock registered successfully' });
    }
    resetEditImage();
    dialogOpen.value = false;
    await loadStockPage();
  } catch (err: unknown) {
    if (orphanImage) {
      await cleanupStockImageAssets({
        imageUrl: orphanImage.secureUrl,
        ...(orphanImage.driveFileId ? { driveFileId: orphanImage.driveFileId } : {}),
      });
    }
    $q.notify({ type: 'negative', message: (err as Error).message || 'Saving failed' });
  } finally {
    actionLoading.value = false;
  }
}

const normalizeStatus = (status: string | null | undefined) =>
  (status ?? '').trim().toUpperCase() || 'AVAILABLE'

const statusChipStyle = (status: string | null | undefined) => {
  const v = normalizeStatus(status)
  if (v === 'AVAILABLE') return { backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #6ee7b7' }
  if (v === 'OUT_OF_STOCK') return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' }
  if (v === 'DAMAGED') return { backgroundColor: '#fef3c7', color: '#92400e', border: '1px solid #fcd34d' }
  if (v === 'STOLEN') return { backgroundColor: '#fee2e2', color: '#7f1d1d', border: '1px solid #fca5a5' }
  return { backgroundColor: '#e5e7eb', color: '#374151', border: '1px solid #d1d5db' }
}

const statusDotColor = (status: string | null | undefined) => {
  const v = normalizeStatus(status)
  if (v === 'AVAILABLE') return '#059669'
  if (v === 'OUT_OF_STOCK') return '#9ca3af'
  if (v === 'DAMAGED') return '#d97706'
  if (v === 'STOLEN') return '#dc2626'
  return '#9ca3af'
}
</script>

<style scoped>
.thrift-stock-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.bulk-selection-bar {
  border-color: rgba(220, 38, 38, 0.18);
  background: rgba(254, 242, 242, 0.92);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.thrift-table-card {
  min-width: 0;
  max-width: 100%;
}

.thrift-table {
  max-width: 100%;
  height: clamp(400px, calc(100vh - 280px), 82vh);
  background: var(--bw-theme-base, #eef2f5);
}

.thrift-table :deep(.q-table__middle) {
  height: 100%;
  max-height: 100% !important;
  overflow: auto;
}

.thrift-table :deep(.q-table) {
  min-width: max-content;
  width: max-content;
}

.thrift-table :deep(table) {
  table-layout: fixed;
  min-width: max-content;
  width: max-content;
}

.thrift-table :deep(thead tr th) {
  position: sticky;
  z-index: 2;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.thrift-table :deep(thead tr:first-child th) {
  top: 0;
  z-index: 3;
}

.thrift-table :deep(td.col-sticky-select),
.thrift-table :deep(th.col-sticky-select),
.thrift-table :deep(.col-sticky-select) {
  position: sticky;
  left: 0;
  z-index: 2;
  width: 44px;
  min-width: 44px;
  max-width: 44px;
  padding-left: 4px;
  padding-right: 4px;
  box-sizing: border-box;
  overflow: hidden;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.thrift-table :deep(td.col-sticky-sl),
.thrift-table :deep(th.col-sticky-sl),
.thrift-table :deep(.col-sticky-sl) {
  position: sticky;
  left: 44px;
  z-index: 2;
  width: 50px;
  min-width: 50px;
  max-width: 50px;
  padding-left: 4px;
  padding-right: 4px;
  box-sizing: border-box;
  overflow: hidden;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.thrift-table :deep(td.col-sticky-image),
.thrift-table :deep(th.col-sticky-image),
.thrift-table :deep(.col-sticky-image) {
  position: sticky;
  left: 94px;
  z-index: 3;
  width: 104px;
  min-width: 104px;
  max-width: 104px;
  padding: 4px;
  box-sizing: border-box;
  overflow: hidden;
  vertical-align: middle;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.thrift-table :deep(tr:first-child th.col-sticky-select) {
  z-index: 6;
}

.thrift-table :deep(tr:first-child th.col-sticky-sl) {
  z-index: 6;
}

.thrift-table :deep(tr:first-child th.col-sticky-image) {
  z-index: 6;
}

.thrift-stock-image-wrap {
  width: 96px;
  height: 96px;
  max-width: 100%;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f7f9fc;
  border-radius: 6px;
  overflow: hidden;
}

.thrift-stock-image-wrap :deep(.smart-image-wrapper) {
  width: 96px;
  height: 96px;
  max-width: 100%;
  overflow: hidden;
}

.thrift-stock-image-wrap :deep(.thrift-stock-image__img),
.thrift-stock-image-wrap :deep(img) {
  width: 96px;
  height: 96px;
  max-width: 100%;
  object-fit: cover;
}

.editable-cell {
  cursor: pointer;
}

.editable-value {
  min-height: 24px;
  display: flex;
  align-items: center;
}

.editable-cell.text-right .editable-value {
  justify-content: flex-end;
}

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.thrift-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.stock-image-preview {
  border: 1px solid rgba(34, 56, 101, 0.1);
  background: rgba(247, 249, 252, 0.8);
}

.stock-image-upload {
  border: 2px dashed rgba(34, 56, 101, 0.2);
  background: rgba(247, 249, 252, 0.6);
  transition: border-color 0.2s ease, background 0.2s ease;
}

.stock-image-upload:hover {
  border-color: var(--q-primary);
  background: rgba(var(--q-primary-rgb, 25, 118, 210), 0.04);
}

.border-dashed {
  border: 2px dashed rgba(34, 56, 101, 0.2);
}

.barcode-preview-frame {
  width: 100%;
  max-width: 280px;
  border: 1px solid #e0e0e0;
  padding: 12px;
  border-radius: 8px;
  background: #fff;
}
</style>
