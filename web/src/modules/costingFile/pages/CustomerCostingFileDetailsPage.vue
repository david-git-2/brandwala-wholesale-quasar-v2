<template>
  <q-page class="bw-page theme-shop">
    <section class="bw-page__stack costing-page">
      <section>
        <h1 class="text-h5 q-my-none">Costing file details</h1>
      </section>

      <div v-if="selectedFile">
        <div class="costing-page__summary">
          <p class="costing-page__summary-text q-my-none text-body2 text-grey-7">
            {{ selectedFile.name }} | {{ selectedFile.market || 'Not set' }}
          </p>
          <q-chip
            dense
            square
            color="primary"
            text-color="white"
            class="costing-page__status-chip"
          >
            {{ selectedFile.status }}
          </q-chip>
        </div>

        <div v-if="selectedFile.status === 'draft'" class="costing-page__input-section">
          <q-banner v-if="!canCustomerMaintainDraftItems" rounded class="bg-blue-1 text-blue-10">
            Item details are maintained by staff/admin for this file.
          </q-banner>
          <div v-else class="costing-page__request-actions">
            <q-btn
              color="primary"
              unelevated
              label="Add item"
              @click="addItemDialogOpen = true"
            />
          </div>
        </div>

        <div v-if="selectedFile.status === 'draft'" class="costing-page__table-section">
          <q-table
            v-if="productRows.length"
            flat
            bordered
            row-key="id"
            :rows="productRows"
            :columns="visibleColumns"
            :pagination="{ rowsPerPage: 0 }"
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
                <q-img
                  v-if="props.row.imageUrl"
                  :src="props.row.imageUrl"
                  fit="cover"
                  class="costing-page__image"
                />
                <div v-else class="costing-page__image costing-page__image--placeholder">
                  No image
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
                <a
                  class="costing-page__url-text"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  :title="props.row.websiteUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ props.row.websiteUrl }}
                </a>
              </q-td>
            </template>

            <template #body-cell-actions="props">
              <q-td
                :props="props"
                class="costing-page__actions-cell"
                :class="getOfferedCellClass(props.row)"
              >
                <q-btn
                  v-if="canCustomerMaintainDraftItems"
                  flat
                  dense
                  round
                  color="negative"
                  icon="delete"
                  aria-label="Delete item"
                  :loading="deletingItemId === props.row.id"
                  :disable="deletingItemId === props.row.id"
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
          <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
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
            <q-table
              v-if="productRows.length"
              flat
              bordered
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
                  <q-img
                    v-if="props.row.imageUrl"
                    :src="props.row.imageUrl"
                    fit="cover"
                    class="costing-page__image"
                  />
                  <div v-else class="costing-page__image costing-page__image--placeholder">
                    No image
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
                  <a
                    class="costing-page__url-text"
                    :href="toExternalUrl(props.row.websiteUrl)"
                    :title="props.row.websiteUrl"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                  {{ props.row.websiteUrl }}
                </a>
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
            <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
          </div>
        </div>

        <div v-else-if="selectedFile.status === 'offered'" class="costing-page__table-section">
          <div class="costing-page__offered-controls">
            <q-input
              v-model.number="sharedProfitRate"
              type="number"
              dense
              outlined
              min="0"
              step="0.01"
              label="Buyer profit %"
              class="costing-page__shared-profit-input"
            />
            <q-btn
              unelevated
              color="primary"
              label="Save buyer profit"
              :loading="savingProfitAll"
              :disable="savingProfitAll"
              @click="handleSaveSharedProfitRate"
            />
            <q-btn
              outline
              color="primary"
              label="Preview"
              @click="openPreview"
            />
          </div>

          <q-table
            v-if="productRows.length"
            flat
            bordered
            dense
            row-key="id"
            :rows="productRows"
            :columns="visibleColumns"
            :row-class="getOfferedRowClass"
            :pagination="{ rowsPerPage: 0 }"
            hide-bottom
            class="costing-page__table costing-page__table--offered"
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
                <q-img
                  v-if="props.row.imageUrl"
                  :src="props.row.imageUrl"
                  fit="cover"
                  class="costing-page__image"
                />
                <div v-else class="costing-page__image costing-page__image--placeholder">
                  No image
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
                <a
                  class="costing-page__url-text"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  :title="props.row.websiteUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ props.row.websiteUrl }}
                </a>
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
          <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
        </div>

        <div v-else class="costing-page__table-section">
          <q-table
            v-if="productRows.length"
            flat
            bordered
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
                <q-img
                  v-if="props.row.imageUrl"
                  :src="props.row.imageUrl"
                  fit="cover"
                  class="costing-page__image"
                />
                <div v-else class="costing-page__image costing-page__image--placeholder">
                  No image
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
                <a
                  class="costing-page__url-text"
                  :href="toExternalUrl(props.row.websiteUrl)"
                  :title="props.row.websiteUrl"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{ props.row.websiteUrl }}
                </a>
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
          <p v-else class="q-my-none text-body2 text-grey-7">No items yet.</p>
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
        <q-card class="costing-page__dialog">
          <q-card-section>
            <div class="text-h6">Add item</div>
            <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
              Add a new item for this costing file.
            </p>
          </q-card-section>

          <q-form @submit.prevent="handleSubmitRequest">
            <q-card-section class="costing-page__request-grid">
              <div class="costing-page__field-block">
                <div class="costing-page__field-label">
                  Web link <span class="costing-page__required-star">*</span>
                </div>
                <q-input
                  v-model="requestForm.websiteUrl"
                  outlined
                  dense
                  :rules="[(value) => !!String(value ?? '').trim() || 'Web link is required.']"
                />
              </div>



              <div class="costing-page__field-block">
                <div class="costing-page__field-label">Quantity</div>
                <q-input
                  v-model.number="requestForm.quantity"
                  type="number"
                  outlined
                  dense
                  min="1"
                  :rules="[
                    (value) => (value !== null && Number(value) > 0) || 'Quantity must be at least 1.',
                  ]"
                />
              </div>
              <div class="costing-page__field-block">
                <div class="costing-page__field-label">Size</div>
                <q-input
                  v-model="requestForm.size"
                  outlined
                  dense
                />
              </div>
              <div class="costing-page__field-block">
                <div class="costing-page__field-label">Color</div>
                <q-input
                  v-model="requestForm.color"
                  outlined
                  dense
                />
              </div>
              <div class="costing-page__field-block">
                <div class="costing-page__field-label">
                  Type <span class="costing-page__required-star">*</span>
                </div>
                <q-select
                  v-model="requestForm.itemType"
                  :options="itemTypeOptions"
                  outlined
                  dense
                  clearable
                  emit-value
                  map-options
                  hint="Pick the closest product type."
                  :rules="[(value) => !!String(value ?? '').trim() || 'Type is required.']"
                />
              </div>
              <div class="costing-page__field-block">
                <div class="costing-page__field-label">Extra information 1</div>
                <q-input
                  v-model="requestForm.extraInformation1"
                  type="textarea"
                  autogrow
                  outlined
                  dense
                />
              </div>
              <div class="costing-page__field-block">
                <div class="costing-page__field-label">Extra information 2</div>
                <q-input
                  v-model="requestForm.extraInformation2"
                  type="textarea"
                  autogrow
                  outlined
                  dense
                />
              </div>
            </q-card-section>

            <q-card-actions align="right">
              <q-btn flat label="Cancel" @click="addItemDialogOpen = false" />
              <q-btn
                color="primary"
                unelevated
                label="Add item"
                type="submit"
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
const submittingRequest = ref(false)
const submittingOrder = ref(false)
const deletingItemId = ref<number | null>(null)
const savingDecisionItemId = ref<number | null>(null)
const savingDecisionStatus = ref<CostingFileItemStatus | null>(null)
const savingProfitAll = ref(false)
const sharedProfitRate = ref<number | null>(null)

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

const normalizeEmail = (value: string | null | undefined) => value?.trim().toLowerCase() ?? ''

const canCustomerMaintainDraftItems = computed(() => {
  if (!selectedFile.value || selectedFile.value.status !== 'draft') {
    return false
  }

  return normalizeEmail(selectedFile.value.created_by_email) === normalizeEmail(authStore.user?.email)
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
    style: 'width: 48px; min-width: 48px;',
    headerStyle: 'width: 48px; min-width: 48px;',
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

  if (selectedFile.value.status === 'customer_submitted') {
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

  if (selectedFile.value.status === 'in_review') {
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
    const result = await costingFileStore.createCostingFileItem({
      costingFileId: selectedFile.value.id,
      websiteUrl,
      quantity: Math.max(1, Math.trunc(quantity)),
      itemType: requestForm.itemType?.trim() || null,
      size: requestForm.size.trim() || null,
      color: requestForm.color.trim() || null,
      extraInformation1: requestForm.extraInformation1.trim() || null,
      extraInformation2: requestForm.extraInformation2.trim() || null,
      status: 'pending',
    })

    if (!result.success) {
      return
    }

    resetRequestForm()
    addItemDialogOpen.value = false
  } finally {
    submittingRequest.value = false
  }
}

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

    if (!result.success) {
      return
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
  if (!selectedFile.value || selectedFile.value.status !== 'offered') {
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
    addItemDialogOpen.value = false
    submitDialog.value = false
    await loadFile()
  },
  { immediate: true },
)

watch(
  itemForms,
  (items) => {
    sharedProfitRate.value = items[0]?.customer_profit_rate ?? null
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
  left: 48px;
}

.costing-page__sl-cell {
  width: 3ch;
  max-width: 3ch;
  white-space: nowrap;
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

.costing-page__table--offered :deep(.costing-page__tone-emerald) {
  background: #f3e5f5;
  color: #6b2f7a;
}

.costing-page__table--offered :deep(.costing-page__tone-orange) {
  background: #fff8e1;
  color: #7a5313;
}

.costing-page__table--offered :deep(.costing-page__tone-amber) {
  background: #fff8e1;
  color: #7a5313;
}

.costing-page__table--offered :deep(.costing-page__tone-indigo) {
  background: #e6f4ea;
  color: #1f6a43;
}

.costing-page__table--offered :deep(th.costing-page__tone-emerald) {
  font-weight: 700;
}

.costing-page__table--offered :deep(th.costing-page__tone-amber) {
  font-weight: 700;
}

.costing-page__table--offered :deep(th.costing-page__tone-indigo) {
  font-weight: 700;
}

.costing-page__table--offered :deep(th.costing-page__tone-orange) {
  font-weight: 700;
}

.costing-page__table--offered :deep(.costing-page__rejected-cell) {
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
}

.costing-page__image-table-cell {
  width: 96px;
}

.costing-page__image {
  width: 96px;
  height: 96px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--bw-theme-surface);
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

.costing-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
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
