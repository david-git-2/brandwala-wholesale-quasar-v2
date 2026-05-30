<template>
  <q-page class="q-pa-md costing-details-page theme-shop">
    <PageInitialLoader v-if="initialLoading" />
    <section v-else class="bw-page__stack costing-page">
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col">
              <div class="text-h6 text-weight-bold">Costing file details</div>
              <div class="text-caption text-grey-8">
                {{ selectedFile ? `${selectedFile.name} | ${selectedFile.market || 'Not set'}` : 'Loading details...' }}
              </div>
            </div>
            <div class="col-auto row items-center q-gutter-sm">
              <q-chip
                v-if="selectedFile"
                dense
                square
                :style="statusChipStyle(selectedFile.status)"
                class="costing-status-chip q-px-md q-py-sm"
              >
                <span class="status-dot" :style="{ backgroundColor: statusDotColor(selectedFile.status) }" />
                {{ formatStatusLabel(selectedFile.status) }}
              </q-chip>
              <q-btn
                v-if="selectedFile && (selectedFile.status === 'offered' || selectedFile.status === 'po_placed')"
                outline
                color="primary"
                icon="visibility"
                label="Preview"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                @click="openPreview"
              />
              <q-btn
                v-if="selectedFile && selectedFile.status === 'draft' && canCustomerMaintainDraftItems"
                color="primary"
                no-caps
                size="sm"
                class="pill-btn slim-btn"
                label="Add item"
                @click="addItemDialogOpen = true"
              />
            </div>
          </div>
        </q-card-section>
      </q-card>

      <div v-if="selectedFile">
        <q-banner v-if="selectedFile.status === 'draft' && !canCustomerMaintainDraftItems" rounded class="bg-blue-1 text-blue-10 q-mb-md">
          Item details are maintained by staff/admin for this file.
        </q-banner>

        <div v-if="selectedFile.status === 'draft'" class="costing-page__table-section">
          <q-card flat class="floating-surface shadow-1">
            <q-table
              v-if="productRows.length"
              flat
              row-key="id"
              :rows="productRows"
              :columns="visibleColumns"
              :pagination="{ rowsPerPage: 0 }"
              hide-bottom
              class="costing-page__table costing-page__table--draft"
            >
              <template #body-cell-sl="props">
                <q-td
                  :props="props"
                  class="costing-page__sl-cell"
                  :class="getOfferedCellClass(props.row)"
                >
                  {{ props.row.sl }}
                </q-td>
              </template>

              <template #body-cell-image="props">
                <q-td
                  :props="props"
                  class="costing-page__image-table-cell"
                  :class="getOfferedCellClass(props.row)"
                >
                  <div class="costing-page__image-cell">
                    <q-img
                      v-if="props.row.imageUrl"
                      :src="props.row.imageUrl"
                      fit="contain"
                      class="costing-page__image"
                    />
                    <div v-else class="costing-page__image costing-page__image--placeholder">
                      No image
                    </div>
                  </div>
                </q-td>
              </template>

              <template #body-cell-quantity="props">
                <q-td :props="props" class="costing-page__numeric-cell">
                  {{ props.row.quantity }}
                </q-td>
              </template>

              <template #body-cell-name="props">
                <q-td
                  :props="props"
                  class="costing-page__name-cell"
                  :class="getOfferedCellClass(props.row)"
                >
                  <span class="costing-page__name-text" :title="props.row.name">
                    {{ props.row.name }}
                  </span>
                </q-td>
              </template>

              <template #body-cell-websiteUrl="props">
                <q-td
                  :props="props"
                  class="costing-page__url-cell"
                  :class="getOfferedCellClass(props.row)"
                >
                  <q-btn
                    v-if="props.row.websiteUrl"
                    flat
                    dense
                    no-caps
                    size="sm"
                    color="primary"
                    icon="open_in_new"
                    label="Open link"
                    class="pill-btn slim-btn costing-page__open-link-btn"
                    :href="props.row.websiteUrl"
                    target="_blank"
                    rel="noopener noreferrer"
                  />
                </q-td>
              </template>

              <template #body-cell-extraInformation1="props">
                <q-td :props="props" :class="getOfferedCellClass(props.row)">
                  <div v-html="props.value" class="costing-table__rich-text-cell" />
                </q-td>
              </template>

              <template #body-cell-extraInformation2="props">
                <q-td :props="props" :class="getOfferedCellClass(props.row)">
                  <div v-html="props.value" class="costing-table__rich-text-cell" />
                </q-td>
              </template>

              <template #body-cell-actions="props">
                <q-td
                  :props="props"
                  class="text-right"
                  :class="getOfferedCellClass(props.row)"
                  auto-width
                >
                  <q-btn
                    flat
                    dense
                    round
                    color="primary"
                    icon="o_edit"
                    aria-label="Edit item"
                    @click="handleEditDraftItem(props.row.id)"
                  />
                  <q-btn
                    flat
                    dense
                    round
                    color="negative"
                    icon="o_delete"
                    aria-label="Delete item"
                    :loading="deletingItemId === props.row.id"
                    @click="handleDeleteDraftItem(props.row.id)"
                  />
                </q-td>
              </template>

              <template #bottom-row>
                <q-tr class="costing-page__totals-row">
                  <q-td
                    v-for="column in visibleColumns"
                    :key="column.name"
                    class="costing-page__totals-cell"
                    :class="getTotalsCellClass(column.name)"
                  >
                    {{ getTotalsValue(column.name) }}
                  </q-td>
                </q-tr>
              </template>
            </q-table>
            <q-card-section v-else class="text-center text-grey-7">
              No items yet.
            </q-card-section>
          </q-card>
        </div>

        <div v-if="selectedFile.status === 'draft'" class="costing-page__submit-actions">
          <q-btn
            v-if="productRows.length"
            color="primary"
            unelevated
            label="Submit order"
            class="q-mt-md"
            :loading="submittingOrder"
            @click="submitDialog = true"
          />
        </div>

        <div
          v-else-if="selectedFile.status === 'customer_submitted' || selectedFile.status === 'in_review'"
          class="costing-page__customer-submitted-section"
        >
          <div class="costing-page__table-section">
            <q-card flat class="floating-surface shadow-1">
              <q-table
                v-if="productRows.length"
                flat
                dense
                row-key="id"
                :rows="productRows"
                :columns="visibleColumns"
                :pagination="{ rowsPerPage: 0 }"
                hide-bottom
                class="costing-page__table"
              >
                <template #body-cell-sl="props">
                  <q-td :props="props" class="costing-page__sl-cell">
                    {{ props.row.sl }}
                  </q-td>
                </template>

                <template #body-cell-image="props">
                  <q-td :props="props" class="costing-page__image-table-cell">
                    <div class="costing-page__image-cell">
                      <q-img
                        v-if="props.row.imageUrl"
                        :src="props.row.imageUrl"
                        fit="contain"
                        class="costing-page__image"
                      />
                      <div v-else class="costing-page__image costing-page__image--placeholder">
                        No image
                      </div>
                    </div>
                  </q-td>
                </template>

                <template #body-cell-quantity="props">
                  <q-td :props="props" class="costing-page__numeric-cell">
                    {{ props.row.quantity }}
                  </q-td>
                </template>

                <template #body-cell-name="props">
                  <q-td :props="props" class="costing-page__name-cell">
                    <span class="costing-page__name-text" :title="props.row.name">
                      {{ props.row.name }}
                    </span>
                  </q-td>
                </template>

                <template #body-cell-websiteUrl="props">
                  <q-td :props="props" class="costing-page__url-cell">
                    <q-btn
                      v-if="props.row.websiteUrl"
                      flat
                      dense
                      no-caps
                      size="sm"
                      color="primary"
                      icon="open_in_new"
                      label="Open link"
                      class="pill-btn slim-btn costing-page__open-link-btn"
                      :href="toExternalUrl(props.row.websiteUrl)"
                      target="_blank"
                      rel="noopener noreferrer"
                    />
                  </q-td>
                </template>

                <template #body-cell-extraInformation1="props">
                  <q-td :props="props">
                    <div v-html="props.value" class="costing-table__rich-text-cell" />
                  </q-td>
                </template>

                <template #body-cell-extraInformation2="props">
                  <q-td :props="props">
                    <div v-html="props.value" class="costing-table__rich-text-cell" />
                  </q-td>
                </template>

                <template #body-cell-offerPriceBdt="props">
                  <q-td :props="props" class="costing-page__numeric-cell costing-page__tone-emerald">
                    {{ props.row.offerPriceBdt }}
                  </q-td>
                </template>

                <template #body-cell-buyerSellingPriceBdt="props">
                  <q-td :props="props" class="costing-page__numeric-cell costing-page__tone-amber">
                    {{ props.row.buyerSellingPriceBdt }}
                  </q-td>
                </template>

                <template #body-cell-customerProfitAmountBdt="props">
                  <q-td :props="props" class="costing-page__numeric-cell costing-page__tone-amber">
                    {{ props.row.customerProfitAmountBdt }}
                  </q-td>
                </template>

                <template #body-cell-customerProfitRateDisplay="props">
                  <q-td :props="props" class="costing-page__numeric-cell">
                    {{ props.row.customerProfitRateDisplay }}
                  </q-td>
                </template>

                <template #body-cell-status="props">
                  <q-td :props="props" class="costing-page__status-cell">
                    <span
                      class="costing-page__status-pill"
                      :class="{
                        'costing-page__status-pill--rejected': props.row.status === 'rejected',
                      }"
                    >
                      {{ props.row.status }}
                    </span>
                  </q-td>
                </template>


                <template #bottom-row>
                  <q-tr class="costing-page__totals-row">
                    <q-td
                      v-for="column in visibleColumns"
                      :key="column.name"
                      class="costing-page__totals-cell"
                      :class="getTotalsCellClass(column.name)"
                    >
                      {{ getTotalsValue(column.name) }}
                    </q-td>
                  </q-tr>
                </template>
              </q-table>
              <q-card-section v-else class="text-center text-grey-7">
                No items yet.
              </q-card-section>
            </q-card>
          </div>
        </div>

        <div
          v-else-if="selectedFile.status === 'offered' || selectedFile.status === 'po_placed'"
          class="costing-page__table-section"
        >
          <q-card v-if="selectedFile.status === 'offered'" flat class="q-mb-md floating-surface shadow-1">
            <q-card-section class="q-py-sm">
              <div class="row items-center q-col-gutter-sm">
                <div style="max-width: 140px;" class="col-auto">
                  <q-input
                    v-model.number="sharedProfitRate"
                    type="number"
                    dense
                    outlined
                    min="0"
                    step="0.01"
                    label="Buyer profit %"
                    class="soft-input"
                  />
                </div>
                <div v-if="isSharedProfitRateDirty" class="col-auto">
                  <q-btn
                    color="primary"
                    no-caps
                    dense
                    unelevated
                    label="Save"
                    class="q-px-md pill-btn"
                    style="min-height: 40px;"
                    :loading="savingProfitAll"
                    @click="handleSaveSharedProfitRate"
                  />
                </div>
              </div>
            </q-card-section>
          </q-card>

          <q-card flat class="floating-surface shadow-1 q-mb-md">
            <q-table
              v-if="productRows.length"
              flat
              dense
              row-key="id"
              :rows="productRows"
              :columns="visibleColumns"
              :row-class="getOfferedRowClass"
              :pagination="{ rowsPerPage: 0 }"
              :table-style="{ maxHeight: '72vh' }"
              hide-bottom
              class="costing-page__table"
            >
              <template #body-cell-sl="props">
                <q-td
                  :props="props"
                  class="costing-page__sl-cell"
                  :class="getOfferedCellClass(props.row)"
                >
                  {{ props.row.sl }}
                </q-td>
              </template>

            <template #body-cell-image="props">
              <q-td
                :props="props"
                class="costing-page__image-table-cell"
                :class="getOfferedCellClass(props.row)"
              >
                <div class="costing-page__image-cell">
                  <q-img
                    v-if="props.row.imageUrl"
                    :src="props.row.imageUrl"
                    fit="contain"
                    class="costing-page__image"
                  />
                  <div v-else class="costing-page__image costing-page__image--placeholder">
                    No image
                  </div>
                </div>
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td
                :props="props"
                class="costing-page__name-cell"
                :class="getOfferedCellClass(props.row)"
              >
                <span class="costing-page__name-text" :title="props.row.name">
                  {{ props.row.name }}
                </span>
              </q-td>
            </template>

            <template #body-cell-websiteUrl="props">
              <q-td
                :props="props"
                class="costing-page__url-cell"
                :class="getOfferedCellClass(props.row)"
              >
                <q-btn
                  v-if="props.row.websiteUrl"
                  flat
                  dense
                  no-caps
                  size="sm"
                  color="primary"
                  icon="open_in_new"
                  label="Open link"
                  class="pill-btn slim-btn costing-page__open-link-btn"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  target="_blank"
                  rel="noopener noreferrer"
                />
              </q-td>
            </template>

            <template #body-cell-extraInformation1="props">
              <q-td :props="props" :class="getOfferedCellClass(props.row)">
                <div v-html="props.value" class="costing-table__rich-text-cell" />
              </q-td>
            </template>

            <template #body-cell-extraInformation2="props">
              <q-td :props="props" :class="getOfferedCellClass(props.row)">
                <div v-html="props.value" class="costing-table__rich-text-cell" />
              </q-td>
            </template>


            <template #body-cell-quantity="props">
              <q-td
                :props="props"
                class="costing-page__numeric-cell"
                :class="getOfferedCellClass(props.row)"
              >
                {{ props.row.quantity }}
              </q-td>
            </template>

            <template #body-cell-offerPriceBdt="props">
              <q-td
                :props="props"
                class="costing-page__numeric-cell costing-page__tone-emerald"
                :class="getOfferedCellClass(props.row)"
              >
                {{ props.row.offerPriceBdt }}
              </q-td>
            </template>

            <template #body-cell-buyerSellingPriceBdt="props">
              <q-td
                :props="props"
                class="costing-page__numeric-cell costing-page__tone-amber"
                :class="getOfferedCellClass(props.row)"
              >
                {{ props.row.buyerSellingPriceBdt }}
              </q-td>
            </template>

            <template #body-cell-customerProfitAmountBdt="props">
              <q-td
                :props="props"
                class="costing-page__numeric-cell costing-page__tone-amber"
                :class="getOfferedCellClass(props.row)"
              >
                {{ props.row.customerProfitAmountBdt }}
              </q-td>
            </template>

            <template #body-cell-customerProfitRateDisplay="props">
              <q-td
                :props="props"
                class="costing-page__numeric-cell"
                :class="getOfferedCellClass(props.row)"
              >
                {{ props.row.customerProfitRateDisplay }}
              </q-td>
            </template>

            <template #body-cell-status="props">
              <q-td
                :props="props"
                class="costing-page__status-cell"
                :class="getOfferedCellClass(props.row)"
              >
                <span
                  class="costing-page__status-pill"
                  :class="{
                    'costing-page__status-pill--rejected': props.row.status === 'rejected',
                  }"
                >
                  {{ props.row.status }}
                </span>
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td
                :props="props"
                class="costing-page__actions-cell"
                :class="getOfferedCellClass(props.row)"
              >
                <template v-if="selectedFile.status === 'offered'">
                  <q-btn
                    unelevated
                    size="sm"
                    dense
                    color="positive"
                    label="Accept"
                    class="costing-page__decision-btn costing-page__decision-btn--accept"
                    :loading="savingDecisionItemId === props.row.id && savingDecisionStatus === 'accepted'"
                    :disable="props.row.status === 'accepted' || savingDecisionItemId === props.row.id"
                    @click="handleDecision(props.row.id, 'accepted')"
                  />
                  <q-btn
                    unelevated
                    size="sm"
                    dense
                    color="negative"
                    label="Reject"
                    class="costing-page__decision-btn costing-page__decision-btn--reject"
                    :loading="savingDecisionItemId === props.row.id && savingDecisionStatus === 'rejected'"
                    :disable="props.row.status === 'rejected' || savingDecisionItemId === props.row.id"
                    @click="handleDecision(props.row.id, 'rejected')"
                  />
                </template>
              </q-td>
            </template>

            <template #bottom-row>
              <q-tr class="costing-page__totals-row">
                <q-td
                  v-for="column in visibleColumns"
                  :key="column.name"
                  class="costing-page__totals-cell"
                  :class="getTotalsCellClass(column.name)"
                >
                  {{ getTotalsValue(column.name) }}
                </q-td>
              </q-tr>
            </template>
            </q-table>
            <q-card-section v-else class="text-center text-grey-7">
              No items yet.
            </q-card-section>
          </q-card>
        </div>

        <div v-else class="costing-page__table-section">
          <q-card flat class="floating-surface shadow-1">
            <q-table
              v-if="productRows.length"
              flat
              dense
              row-key="id"
              :rows="productRows"
              :columns="visibleColumns"
              :pagination="{ rowsPerPage: 0 }"
              hide-bottom
              class="costing-page__table"
            >
            <template #body-cell-sl="props">
              <q-td :props="props" class="costing-page__sl-cell">
                {{ props.row.sl }}
              </q-td>
            </template>

            <template #body-cell-image="props">
              <q-td :props="props" class="costing-page__image-table-cell">
                <div class="costing-page__image-cell">
                  <q-img
                    v-if="props.row.imageUrl"
                    :src="props.row.imageUrl"
                    fit="contain"
                    class="costing-page__image"
                  />
                  <div v-else class="costing-page__image costing-page__image--placeholder">
                    No image
                  </div>
                </div>
              </q-td>
            </template>

            <template #body-cell-quantity="props">
              <q-td :props="props" class="costing-page__numeric-cell">
                {{ props.row.quantity }}
              </q-td>
            </template>

            <template #body-cell-name="props">
              <q-td :props="props" class="costing-page__name-cell">
                <span class="costing-page__name-text" :title="props.row.name">
                  {{ props.row.name }}
                </span>
              </q-td>
            </template>

            <template #body-cell-websiteUrl="props">
              <q-td :props="props" class="costing-page__url-cell">
                <q-btn
                  v-if="props.row.websiteUrl"
                  flat
                  dense
                  no-caps
                  size="sm"
                  color="primary"
                  icon="open_in_new"
                  label="Open link"
                  class="pill-btn slim-btn costing-page__open-link-btn"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  target="_blank"
                  rel="noopener noreferrer"
                />
              </q-td>
            </template>

            <template #body-cell-extraInformation1="props">
              <q-td :props="props">
                <div v-html="props.value" class="costing-table__rich-text-cell" />
              </q-td>
            </template>

            <template #body-cell-extraInformation2="props">
              <q-td :props="props">
                <div v-html="props.value" class="costing-table__rich-text-cell" />
              </q-td>
            </template>


            <template #bottom-row>
              <q-tr class="costing-page__totals-row">
                <q-td
                  v-for="column in visibleColumns"
                  :key="column.name"
                  class="costing-page__totals-cell"
                  :class="getTotalsCellClass(column.name)"
                >
                  {{ getTotalsValue(column.name) }}
                </q-td>
              </q-tr>
            </template>
            </q-table>
            <q-card-section v-else class="text-center text-grey-7">
              No items yet.
            </q-card-section>
          </q-card>
        </div>
      </div>

      <q-dialog v-model="submitDialog" persistent>
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Submit order</div>
          </q-card-section>

          <q-card-section>
            <div class="text-body2">
              Submit this costing file for review?
            </div>
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="submitDialog = false" />
            <q-btn
              color="primary"
              unelevated
              label="Confirm"
              :loading="submittingOrder"
              @click="handleSubmitOrder"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <q-dialog
        v-model="addItemDialogOpen"
        persistent
      >
        <q-card class="costing-page__dialog costing-page__dialog--wide">
          <q-card-section class="costing-item-add-dialog__header row items-center justify-between q-pb-md">
            <div class="row items-center q-gutter-md">
              <q-avatar :icon="editingItemId ? 'o_edit' : 'add_shopping_cart'" color="primary" text-color="white" />
              <div>
                <div class="text-h6 text-weight-bold">{{ editingItemId ? 'Edit Item' : 'Add Item' }}</div>
                <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                  {{ editingItemId ? 'Update product details for this costing item.' : 'Add a new item for this costing file.' }}
                </p>
              </div>
            </div>

            <q-btn
              flat
              dense
              round
              icon="close"
              aria-label="Close"
              @click="addItemDialogOpen = false"
            />
          </q-card-section>

          <q-form @submit.prevent="handleSubmitRequest">
            <q-card-section class="q-gutter-md">
              <!-- Basic Details -->
              <div class="text-subtitle2 text-weight-bold text-primary q-mb-xs">Basic Details</div>
              
              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-8">
                  <q-input
                    v-model="requestForm.websiteUrl"
                    label="Web link"
                    outlined
                    dense
                    :rules="[(value) => !!String(value ?? '').trim() || 'Web link is required.']"
                  >
                    <template #prepend><q-icon name="link" /></template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-4">
                  <q-input
                    v-model.number="requestForm.quantity"
                    label="Quantity"
                    type="number"
                    outlined
                    dense
                    min="1"
                    :rules="[
                      (value) => (value !== null && Number(value) > 0) || 'Quantity must be at least 1.',
                    ]"
                  >
                    <template #prepend><q-icon name="inventory_2" /></template>
                  </q-input>
                </div>
              </div>

              <div class="row q-col-gutter-sm">
                <div class="col-12 col-sm-4">
                  <q-select
                    v-model="requestForm.itemType"
                    :options="itemTypeOptions"
                    label="Type"
                    outlined
                    dense
                    clearable
                    emit-value
                    map-options
                    hint="Pick the closest product type."
                    :rules="[(value) => !!String(value ?? '').trim() || 'Type is required.']"
                  >
                    <template #prepend><q-icon name="category" /></template>
                  </q-select>
                </div>
                <div class="col-12 col-sm-4">
                  <q-input
                    v-model="requestForm.size"
                    label="Size"
                    outlined
                    dense
                  >
                    <template #prepend><q-icon name="straighten" /></template>
                  </q-input>
                </div>
                <div class="col-12 col-sm-4">
                  <q-input
                    v-model="requestForm.color"
                    label="Color"
                    outlined
                    dense
                  >
                    <template #prepend><q-icon name="palette" /></template>
                  </q-input>
                </div>
              </div>

              <!-- Description & Notes -->
              <div class="text-subtitle2 text-weight-bold text-primary q-mt-md q-mb-xs">Description & Notes</div>

              <div class="q-mb-sm">
                <div class="text-caption text-grey-7 q-mb-xs">Extra Information 1</div>
                <q-editor
                  v-model="requestForm.extraInformation1"
                  min-height="5rem"
                  flat
                  bordered
                  :toolbar="[
                    ['bold', 'italic', 'underline'],
                    ['unordered', 'ordered']
                  ]"
                />
              </div>

              <div class="q-mb-sm">
                <div class="text-caption text-grey-7 q-mb-xs">Extra Information 2</div>
                <q-editor
                  v-model="requestForm.extraInformation2"
                  min-height="5rem"
                  flat
                  bordered
                  :toolbar="[
                    ['bold', 'italic', 'underline'],
                    ['unordered', 'ordered']
                  ]"
                />
              </div>
            </q-card-section>

            <q-card-actions align="right" class="q-pa-md">
              <q-btn flat no-caps label="Cancel" @click="addItemDialogOpen = false" />
              <q-btn
                color="primary"
                unelevated
                :label="editingItemId ? 'Save changes' : 'Add item'"
                type="submit"
                no-caps
                class="pill-btn"
                :loading="submittingRequest"
              />

            </q-card-actions>
          </q-form>
        </q-card>
      </q-dialog>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute, useRouter } from 'vue-router'

import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import {
  buildCustomerProductRows,
  summarizeCustomerProductRows,
} from 'src/modules/costingFile/composables/useCostingFileDetailRows'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileItemStatus } from 'src/modules/costingFile/types'
import { showSuccessNotification } from 'src/utils/appFeedback'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const costingFileStore = useCostingFileStore()
const {
  selectedItem: selectedFile,
  costingFileItems: itemForms,
} = storeToRefs(costingFileStore)

const submitDialog = ref(false)
const addItemDialogOpen = ref(false)
const initialLoading = ref(true)
const submittingRequest = ref(false)
const submittingOrder = ref(false)
const deletingItemId = ref<number | null>(null)
const editingItemId = ref<number | null>(null)
const savingDecisionItemId = ref<number | null>(null)

const savingDecisionStatus = ref<CostingFileItemStatus | null>(null)

const formatStatusLabel = (status: string) =>
  status
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())

const statusChipStyle = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending'
  if (value === 'draft') {
    return {
      backgroundColor: '#f1f5f9',
      color: '#475569',
      border: '1px solid #cbd5e1',
    }
  }
  if (value === 'customer_submitted') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
    }
  }
  if (value === 'in_review') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
    }
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
    }
  }
  if (value === 'po_placed') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
    }
  }
  return {
    backgroundColor: '#f1f5f9',
    color: '#475569',
    border: '1px solid #cbd5e1',
  }
}
const statusDotColor = (currentStatus: string | null | undefined) => {
  const value = (currentStatus ?? '').trim().toLowerCase() || 'pending'
  if (value === 'draft') return '#64748b'
  if (value === 'customer_submitted') return '#3f51b5'
  if (value === 'in_review') return '#9a6a24'
  if (value === 'offered') return '#3f67b3'
  if (value === 'po_placed') return '#2f8b5d'
  if (value === 'cancelled') return '#a64c62'
  return '#64748b'
}
const savingProfitAll = ref(false)
const sharedProfitRate = ref<number | null>(null)
const originalSharedProfitRate = ref<number | null>(null)
const isSharedProfitRateDirty = computed(() => {
  return sharedProfitRate.value !== originalSharedProfitRate.value
})

const fileForm = reactive({
  name: '',
  market: '',
})

const requestForm = reactive({
  websiteUrl: '',
  quantity: 1,
  size: '',
  color: '',
  itemType: '' as string | null,
  extraInformation1: '',
  extraInformation2: '',
})

const itemTypeOptions = ['Watch', 'Perfume', 'Others']

const formatWhole = (value: number | null | undefined) =>
  value == null ? '' : String(Math.round(Number(value)))

const formatPercent = (value: number | null | undefined) =>
  value == null ? '' : `${Number(value).toFixed(2)}%`

const canCustomerMaintainDraftItems = computed(() => {
  if (!selectedFile.value || selectedFile.value.status !== 'draft') {
    return false
  }

  return selectedFile.value.customer_group_id === authStore.customerGroupId
})

const productRows = computed(() =>
  buildCustomerProductRows(itemForms.value, sharedProfitRate.value),
)
const productTotals = computed(() => summarizeCustomerProductRows(productRows.value))

const getOfferedRowClass = (row: { status?: string | null }) =>
  row.status === 'rejected' ? 'costing-page__rejected-row' : ''

const getOfferedCellClass = (row: { status?: string | null }) =>
  row.status === 'rejected' ? 'costing-page__rejected-cell' : ''

const allColumns = [
  {
    name: 'sl',
    label: 'SL',
    field: 'sl',
    align: 'center' as const,
    style: 'width: 60px; min-width: 60px;',
    headerStyle: 'width: 60px; min-width: 60px;',
    classes: 'costing-page__sticky-col costing-page__sticky-col--sl',
    headerClasses: 'costing-page__sticky-col costing-page__sticky-col--sl',
  },
  {
    name: 'image',
    label: 'Image',
    field: 'imageUrl',
    align: 'center' as const,
    style: 'width: 108px; min-width: 108px;',
    headerStyle: 'width: 108px; min-width: 108px;',
    classes: 'costing-page__sticky-col costing-page__sticky-col--image',
    headerClasses: 'costing-page__sticky-col costing-page__sticky-col--image',
  },

  {
    name: 'name',
    label: 'Name',
    field: 'name',
    align: 'center' as const,
    style: 'width: 280px; min-width: 280px;',
    headerStyle: 'width: 280px; min-width: 280px; white-space: normal; line-height: 1.15;',
  },
  {
    name: 'itemType',
    label: 'Type',
    field: 'itemType',
    align: 'center' as const,
    style: 'width: 110px; min-width: 110px;',
    headerStyle: 'width: 110px; min-width: 110px;',
  },
  {
    name: 'quantity',
    label: 'Qty',
    field: 'quantity',
    align: 'center' as const,
    style: 'width: 72px; min-width: 72px;',
    headerStyle: 'width: 72px; min-width: 72px; white-space: normal; line-height: 1.15;',
  },
  {
    name: 'websiteUrl',
    label: 'Web link',
    field: 'websiteUrl',
    align: 'center' as const,
    style: 'width: 144px; min-width: 144px; max-width: 144px;',
    headerStyle: 'width: 144px; min-width: 144px; max-width: 144px;',
  },
  {
    name: 'size',
    label: 'Size',
    field: 'size',
    align: 'center' as const,
    style: 'width: 96px; min-width: 96px;',
    headerStyle: 'width: 96px; min-width: 96px;',
  },
  {
    name: 'color',
    label: 'Color',
    field: 'color',
    align: 'center' as const,
    style: 'width: 96px; min-width: 96px;',
    headerStyle: 'width: 96px; min-width: 96px;',
  },
  {
    name: 'extraInformation1',
    label: 'Extra info 1',
    field: 'extraInformation1',
    align: 'center' as const,
    style: 'width: 180px; min-width: 180px;',
    headerStyle: 'width: 180px; min-width: 180px;',
  },
  {
    name: 'extraInformation2',
    label: 'Extra info 2',
    field: 'extraInformation2',
    align: 'center' as const,
    style: 'width: 180px; min-width: 180px;',
    headerStyle: 'width: 180px; min-width: 180px;',
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' as const },
  {
    name: 'offerPriceBdt',
    label: 'Offer price (BDT)',
    field: 'offerPriceBdt',
    align: 'center' as const,
    style: 'width: 98px; min-width: 98px;',
    headerStyle: 'width: 98px; min-width: 98px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-emerald',
    headerClasses: 'costing-page__tone-emerald',
  },
  {
    name: 'buyerSellingPriceBdt',
    label: 'Buyer selling (BDT)',
    field: 'buyerSellingPriceBdt',
    align: 'center' as const,
    style: 'width: 104px; min-width: 104px;',
    headerStyle: 'width: 104px; min-width: 104px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-orange',
    headerClasses: 'costing-page__tone-orange',
  },
  {
    name: 'customerProfitAmountBdt',
    label: 'Profit per item (BDT)',
    field: 'customerProfitAmountBdt',
    align: 'center' as const,
    style: 'width: 104px; min-width: 104px;',
    headerStyle: 'width: 104px; min-width: 104px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-amber',
    headerClasses: 'costing-page__tone-amber',
  },
  {
    name: 'customerProfitRateDisplay',
    label: 'Profit rate',
    field: 'customerProfitRateDisplay',
    align: 'center' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
  },
  { name: 'actions', label: '', field: 'actions', align: 'center' as const },
]

const visibleColumns = computed(() => {
  if (!selectedFile.value) {
    return []
  }

  if (selectedFile.value.status === 'draft') {
    return allColumns.filter((column) =>
      [
        'sl',
        'itemType',
        'websiteUrl',
        'quantity',
        'size',
        'color',
        'extraInformation1',
        'extraInformation2',
        'actions',
      ].includes(column.name),
    )
  }

  if (
    selectedFile.value.status === 'customer_submitted' ||
    selectedFile.value.status === 'in_review'
  ) {
    return allColumns.filter((column) =>
      [
        'sl',
        'itemType',
        'websiteUrl',
        'quantity',
        'size',
        'color',
        'extraInformation1',
        'extraInformation2',
      ].includes(column.name),
    )
  }

  if (selectedFile.value.status === 'offered') {
    return allColumns.filter((column) =>
      [
        'sl',
        'image',
        'name',
        'websiteUrl',
        'quantity',
        'itemType',
        'size',
        'color',
        'extraInformation1',
        'extraInformation2',
        'offerPriceBdt',
        'buyerSellingPriceBdt',
        'customerProfitAmountBdt',
        'customerProfitRateDisplay',
        'status',
        'actions',
      ].includes(column.name),
    )
  }

  if (selectedFile.value.status === 'po_placed') {
    return allColumns.filter((column) =>
      [
        'sl',
        'image',
        'name',
        'websiteUrl',
        'quantity',
        'itemType',
        'size',
        'color',
        'extraInformation1',
        'extraInformation2',
        'offerPriceBdt',
        'buyerSellingPriceBdt',
        'customerProfitAmountBdt',
        'customerProfitRateDisplay',
        'status',
      ].includes(column.name),
    )
  }

  return allColumns.filter((column) =>
    [
      'sl',
      'image',
      'websiteUrl',
      'quantity',
      'itemType',
      'size',
      'color',
      'extraInformation1',
      'extraInformation2',
      'status',
      'offerPriceBdt',
    ].includes(column.name),
  )
})

const getTotalsValue = (columnName: string) => {
  switch (columnName) {
    case 'sl':
      return 'Total'
    case 'name':
      return `${productRows.value.length} Items`
    case 'quantity':
      return formatWhole(productTotals.value.quantity)
    case 'offerPriceBdt':
      return formatWhole(productTotals.value.offerPriceBdt)
    case 'buyerSellingPriceBdt':
      return formatWhole(productTotals.value.buyerSellingPriceBdt)
    case 'customerProfitAmountBdt':
      return formatWhole(productTotals.value.customerProfitAmountBdt)
    case 'customerProfitRateDisplay':
      return formatPercent(productTotals.value.customerProfitRate)
    default:
      return ''
  }
}

const getTotalsCellClass = (columnName: string) => {
  if (columnName === 'offerPriceBdt') {
    return 'costing-page__tone-emerald'
  }

  if (columnName === 'buyerSellingPriceBdt') {
    return 'costing-page__tone-orange'
  }

  if (columnName === 'customerProfitAmountBdt') {
    return 'costing-page__tone-amber'
  }

  return ''
}

const toExternalUrl = (value: string) => (/^https?:\/\//i.test(value) ? value : `https://${value}`)

const syncFileForm = () => {
  fileForm.name = selectedFile.value?.name ?? ''
  fileForm.market = selectedFile.value?.market ?? ''
}

const loadFile = async () => {
  const fileId = Number(route.params.id)
  if (!fileId) return
  await costingFileStore.fetchCostingFileWithItemsForCustomer(fileId)
}

const resetRequestForm = () => {
  requestForm.websiteUrl = ''
  requestForm.quantity = 1
  requestForm.size = ''
  requestForm.color = ''
  requestForm.itemType = null
  requestForm.extraInformation1 = ''
  requestForm.extraInformation2 = ''
}

const cleanEditorHtml = (html: string) => {
  const clean = html.replace(/<[^>]*>/g, '').trim()
  return clean.length > 0 ? html.trim() : null
}

const handleSubmitRequest = async () => {
  if (!selectedFile.value || !canCustomerMaintainDraftItems.value) {
    return
  }

  const websiteUrl = requestForm.websiteUrl.trim()
  const quantity = Number(requestForm.quantity)

  if (!websiteUrl || Number.isNaN(quantity) || quantity <= 0) {
    return
  }

  submittingRequest.value = true
  try {
    let result
    if (editingItemId.value) {
      result = await costingFileStore.updateCostingFileItem({
        id: editingItemId.value,
        websiteUrl,
        quantity: Math.max(1, Math.trunc(quantity)),
        itemType: requestForm.itemType?.trim() || null,
        size: requestForm.size.trim() || null,
        color: requestForm.color.trim() || null,
        extraInformation1: cleanEditorHtml(requestForm.extraInformation1),
        extraInformation2: cleanEditorHtml(requestForm.extraInformation2),
      })
    } else {
      result = await costingFileStore.createCostingFileItem({
        costingFileId: selectedFile.value.id,
        websiteUrl,
        quantity: Math.max(1, Math.trunc(quantity)),
        itemType: requestForm.itemType?.trim() || null,
        size: requestForm.size.trim() || null,
        color: requestForm.color.trim() || null,
        extraInformation1: cleanEditorHtml(requestForm.extraInformation1),
        extraInformation2: cleanEditorHtml(requestForm.extraInformation2),
        status: 'pending',
      })
    }

    if (!result.success) {
      return
    }

    addItemDialogOpen.value = false
  } finally {
    submittingRequest.value = false
  }
}

const handleEditDraftItem = (row: { id: number }) => {
  const item = itemForms.value.find((i) => i.id === row.id)

  if (!item) return

  editingItemId.value = item.id
  requestForm.websiteUrl = item.website_url ?? ''
  requestForm.quantity = item.quantity ?? 1
  requestForm.itemType = item.item_type ?? null
  requestForm.size = item.size ?? ''
  requestForm.color = item.color ?? ''
  requestForm.extraInformation1 = item.extra_information_1 ?? ''
  requestForm.extraInformation2 = item.extra_information_2 ?? ''

  addItemDialogOpen.value = true
}

watch(addItemDialogOpen, (isOpen) => {
  if (!isOpen) {
    resetRequestForm()
    editingItemId.value = null
  }
})

const handleDeleteDraftItem = async (itemId: number) => {
  if (!selectedFile.value || selectedFile.value.status !== 'draft' || !canCustomerMaintainDraftItems.value) {
    return
  }

  deletingItemId.value = itemId
  try {
    const result = await costingFileStore.deleteCostingFileItem({ id: itemId })

    if (!result.success) {
      return
    }
  } finally {
    deletingItemId.value = null
  }
}


const handleDecision = async (id: number, status: CostingFileItemStatus) => {
  savingDecisionItemId.value = id
  savingDecisionStatus.value = status
  try {
    const result = await costingFileStore.updateCostingFileItemStatus({ id, status })

    if (!result.success) {
      return
    }

    showSuccessNotification(`Item ${status}.`)
  } finally {
    savingDecisionItemId.value = null
    savingDecisionStatus.value = null
  }
}

const handleSaveSharedProfitRate = async () => {
  if (!itemForms.value.length || !selectedFile.value) return

  savingProfitAll.value = true
  try {
    const normalized =
      sharedProfitRate.value == null || Number.isNaN(Number(sharedProfitRate.value))
        ? null
        : Number(sharedProfitRate.value)

    const result = await costingFileStore.updateCostingFileItemsCustomerProfit({
      costingFileId: selectedFile.value.id,
      customerProfitRate: normalized,
    })

    if (result.success) {
      originalSharedProfitRate.value = normalized
      sharedProfitRate.value = normalized
      await loadFile()
    }
  } finally {
    savingProfitAll.value = false
  }
}

const handleSubmitOrder = async () => {
  if (!selectedFile.value) {
    return
  }

  submittingOrder.value = true
  try {
    const result = await costingFileStore.updateCostingFileStatus({
      id: selectedFile.value.id,
      status: 'customer_submitted',
    })

    if (!result.success) {
      return
    }

    submitDialog.value = false
    showSuccessNotification('Order submitted.')
  } finally {
    submittingOrder.value = false
  }
}

const openPreview = () => {
  if (
    !selectedFile.value ||
    (selectedFile.value.status !== 'offered' && selectedFile.value.status !== 'po_placed')
  ) {
    return
  }

  const targetRoute = router.resolve({
    name: 'customer-costing-file-preview-page',
    params: { id: String(selectedFile.value.id) },
  })

  window.open(targetRoute.href, '_blank', 'noopener,noreferrer')
}

watch(selectedFile, () => {
  syncFileForm()
}, { immediate: true })

watch(
  () => route.params.id,
  async () => {
    try {
      addItemDialogOpen.value = false
      submitDialog.value = false
      sharedProfitRate.value = null
      originalSharedProfitRate.value = null
      await loadFile()
    } finally {
      initialLoading.value = false
    }
  },
  { immediate: true },
)

watch(
  itemForms,
  (items) => {
    const val = items[0]?.customer_profit_rate ?? null
    const wasDirty = sharedProfitRate.value !== originalSharedProfitRate.value
    originalSharedProfitRate.value = val
    if (!wasDirty) {
      sharedProfitRate.value = val
    }
  },
  { immediate: true, deep: true },
)
</script>

<style scoped>
.costing-page {
  min-width: 0;
}

.costing-page > * {
  min-width: 0;
}

.costing-page__input-section,
.costing-page__table-section {
  display: block;
  min-width: 0;
}

.costing-page__summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 0.75rem;
}

.costing-page__summary-text {
  min-width: 0;
  flex: 1 1 auto;
}

.costing-page__status-chip {
  flex: 0 0 auto;
  text-transform: capitalize;
}

.costing-page__sticky-form {
  position: sticky;
  top: 0;
  z-index: 10;
  padding: 0.75rem 0;
}

.costing-page__file-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto;
  gap: 1rem;
  align-items: start;
  margin-bottom: 0.75rem;
}

.costing-page__request-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 1rem;
  align-items: start;
}

.costing-page__field-block {
  display: grid;
  gap: 0.4rem;
}

.costing-page__field-label {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--bw-theme-ink);
}

.costing-page__required-star {
  color: #c63c4f;
  font-weight: 700;
}

.costing-page__link-preview {
  display: grid;
  gap: 0.6rem;
  padding: 0.85rem;
  border: 1px solid var(--bw-theme-border);
  border-radius: 12px;
  background:
    linear-gradient(180deg, color-mix(in srgb, var(--bw-theme-primary) 4%, white), white);
}

.costing-page__link-preview-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.costing-page__link-preview-title {
  font-size: 0.92rem;
  font-weight: 700;
  color: var(--bw-theme-ink);
}

.costing-page__link-preview-frame {
  width: 100%;
  height: 240px;
  border: 1px solid var(--bw-theme-border);
  border-radius: 10px;
  background: #fff;
}

.costing-page__link-preview-note {
  font-size: 0.8rem;
  color: var(--bw-theme-muted);
}

.costing-page__request-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

.costing-page :deep(.q-btn) {
  border-radius: 8px;
}

.costing-page__table :deep(.q-table th),
.costing-page__table :deep(.q-table td) {
  text-align: center;
  vertical-align: middle;
}

.costing-page__table :deep(.q-table th) {
  white-space: normal;
  line-height: 1.15;
}

.costing-page__table :deep(.costing-page__sticky-col) {
  position: sticky;
  background: var(--bw-theme-surface, #fff);
}

.costing-page__table :deep(td.costing-page__sticky-col) {
  z-index: 2;
}

.costing-page__table :deep(th.costing-page__sticky-col) {
  z-index: 3;
}

.costing-page__table :deep(.costing-page__sticky-col--sl) {
  left: 0;
}

.costing-page__table :deep(.costing-page__sticky-col--image) {
  left: 60px;
}

.costing-page__table :deep(td.costing-page__sticky-col--sl) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.costing-page__table :deep(td.costing-page__sticky-col--image) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.costing-page__table :deep(th.costing-page__sticky-col--sl) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.costing-page__table :deep(th.costing-page__sticky-col--image) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.costing-page__sl-cell {
  width: 60px;
  max-width: 60px;
  white-space: nowrap;
}

.costing-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  text-transform: capitalize;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.costing-page__name-cell {
  width: 280px;
  min-width: 280px;
  max-width: 280px;
}

.costing-page__name-text {
  display: inline-block;
  max-width: 280px;
  overflow: visible;
  text-overflow: clip;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
  line-height: 1.3;
}

.costing-page__table :deep(.costing-page__tone-emerald) {
  background: #f3e5f5 !important;
  color: #6b2f7a !important;
}

.costing-page__table :deep(.costing-page__tone-orange) {
  background: #fff8e1 !important;
  color: #7a5313 !important;
}

.costing-page__table :deep(.costing-page__tone-amber) {
  background: #fff8e1 !important;
  color: #7a5313 !important;
}

.costing-page__table :deep(.costing-page__tone-indigo) {
  background: #e6f4ea !important;
  color: #1f6a43 !important;
}

.costing-page__table :deep(th.costing-page__tone-emerald) {
  font-weight: 700;
}

.costing-page__table :deep(th.costing-page__tone-amber) {
  font-weight: 700;
}

.costing-page__table :deep(th.costing-page__tone-indigo) {
  font-weight: 700;
}

.costing-page__table :deep(th.costing-page__tone-orange) {
  font-weight: 700;
}

.costing-page__table :deep(.costing-page__rejected-cell) {
  background: #fff7f8;
  border-top: 1px solid #efb2bc;
  border-bottom: 1px solid #efb2bc;
}

.costing-page__table--offered :deep(.costing-page__rejected-cell:first-child) {
  border-left: 1px solid #efb2bc;
}

.costing-page__table--offered :deep(.costing-page__rejected-cell:last-child) {
  border-right: 1px solid #efb2bc;
}

.costing-page__actions-cell {
  white-space: nowrap;
  min-height: 40px;
  text-align: center;
}

.costing-page__actions-cell :deep(.q-btn + .q-btn) {
  margin-left: 0.5rem;
}

.costing-page__table--offered :deep(td.costing-page__actions-cell) {
  background: #fff;
}

.costing-page__image-table-cell {
  width: 96px;
  min-width: 96px;
}

.costing-page__image-cell {
  width: 96px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto;
}

.costing-page__image {
  display: block;
  width: 96px;
  height: 96px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--bw-theme-surface);
}

.costing-page__image :deep(.q-img__image) {
  object-fit: contain !important;
  object-position: center;
}

.costing-page__image--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px dashed var(--bw-theme-border);
  color: var(--bw-theme-muted);
  font-size: 0.75rem;
  text-align: center;
  padding: 0.5rem;
}

.costing-page__numeric-cell {
  font-weight: 700;
  font-size: 0.95rem;
  line-height: 1.35;
  text-align: center;
  font-variant-numeric: tabular-nums;
  min-height: 40px;
}

.costing-page__status-cell {
  width: 96px;
  min-width: 96px;
}

.costing-page__status-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 84px;
  padding: 0.3rem 0.55rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--bw-theme-primary) 10%, white);
  color: var(--bw-theme-primary);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: capitalize;
}

.costing-page__status-cell--rejected {
  background: #fdecef;
  box-shadow: inset 0 0 0 1px #f3b7c0;
}

.costing-page__status-pill--rejected {
  background: #fbe3e6;
  color: #a33b49;
}

.costing-page__url-cell {
  width: 144px;
  max-width: 144px;
}

.costing-page__url-text {
  display: inline-block;
  max-width: 144px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
  color: var(--bw-theme-primary);
  text-decoration: none;
}

.costing-page__icon-btn {
  border-radius: 8px;
}

.costing-page__decision-btn {
  border-radius: 8px;
  min-width: 66px;
}

.costing-page__decision-btn--accept {
  background: #ddf4e7 !important;
  color: #1f6a43 !important;
}

.costing-page__decision-btn--reject {
  background: #fbe3e6 !important;
  color: #a33b49 !important;
}

.costing-page__offered-controls {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  justify-content: flex-end;
  margin-bottom: 0.75rem;
  position: sticky;
  top: 0;
  z-index: 7;
  padding: 0.5rem 0;
  background: var(--bw-theme-base, #f4f6f8);
}

.costing-page__shared-profit-input {
  width: 160px;
}

.costing-page__submit-actions {
  display: flex;
  justify-content: flex-end;
}

.costing-page__dialog {
  min-width: min(420px, 92vw);
}

.costing-page__dialog--wide {
  width: min(800px, 95vw);
  max-width: 95vw;
}

.costing-item-add-dialog__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.costing-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
}

.costing-page__table :deep(.q-table__container),
.costing-page__table :deep(.q-table__middle),
.costing-page__table :deep(.q-table__bottom) {
  background: var(--bw-theme-base, #f4f6f8);
}

.costing-page__table :deep(.q-table thead tr th),
.costing-page__table :deep(.q-table tbody tr td) {
  background: #fff;
}

.costing-page__table--offered {
  height: 72vh;
}

.costing-page__table--offered :deep(.q-table__middle) {
  max-height: 72vh;
}

.costing-page__table--offered :deep(.q-table thead tr th) {
  position: sticky;
  z-index: 2;
  background: var(--bw-theme-surface, #fff);
}

.costing-page__table--offered :deep(.q-table thead tr:first-child th) {
  top: 0;
  z-index: 1;
}

.costing-page__table--offered :deep(.q-table thead tr + tr th) {
  top: 48px;
  z-index: 3;
}

.costing-page__table--offered :deep(.q-table td:first-child),
.costing-page__table--offered :deep(.q-table th:first-child) {
  position: sticky;
  left: 0;
}

.costing-page__table--offered :deep(.q-table td:nth-child(2)),
.costing-page__table--offered :deep(.q-table th:nth-child(2)) {
  position: sticky;
  left: 60px;
}

.costing-page__table--offered :deep(.q-table td:first-child) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.costing-page__table--offered :deep(.q-table td:nth-child(2)) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.costing-page__table--offered :deep(.q-table tr:first-child th:first-child) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.costing-page__table--offered :deep(.q-table tr:first-child th:nth-child(2)) {
  z-index: 4;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.costing-page__table--offered :deep(.q-table tbody) {
  scroll-margin-top: 48px;
}

.costing-page__table--offered :deep(.q-table tbody tr td) {
  background: #fff;
  min-height: 40px;
}

.costing-page__table :deep(td.costing-page__tone-orange),
.costing-page__table :deep(th.costing-page__tone-orange) {
  background: #fff8e1 !important;
  color: #7a5313 !important;
}

.costing-page__totals-row {
  background: inherit;
}

.costing-page__totals-cell {
  font-weight: 700;
  text-align: center;
  vertical-align: middle;
}

@media (max-width: 900px) {
  .costing-page__file-grid {
    grid-template-columns: 1fr 1fr;
  }

  .costing-page__file-grid > :nth-child(3) {
    grid-column: 1 / -1;
  }

  .costing-page__request-grid {
    grid-template-columns: minmax(0, 1fr);
  }
}

@media (max-width: 599px) {
  .costing-page__summary {
    flex-direction: column;
    align-items: flex-start;
  }

  .costing-page__file-grid,
  .costing-page__request-grid {
    grid-template-columns: 1fr;
  }

  .costing-page {
    font-size: 0.92rem;
  }

  .costing-page :deep(.q-field__label),
  .costing-page :deep(.q-field__native),
  .costing-page :deep(.q-btn__content),
  .costing-page :deep(.q-table th),
  .costing-page :deep(.q-table td) {
    font-size: 0.82rem;
  }

  .costing-page :deep(.q-icon) {
    font-size: 1rem;
  }

  .costing-page__image-table-cell {
    width: 72px;
    min-width: 72px;
  }

  .costing-page__image-cell {
    width: 72px;
  }

  .costing-page__image {
    width: 72px;
    height: 72px;
  }

  .costing-page__icon-btn {
    min-height: 28px;
    min-width: 28px;
    padding: 0.2rem;
  }
}
</style>
