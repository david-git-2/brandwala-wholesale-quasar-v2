<template>
  <q-page class="bw-page theme-app">
    <section class="bw-page__stack costing-page">
      <section class="costing-page__header">
        <div class="costing-page__heading">
          <div class="text-overline">Costing File</div>
          <h1 class="text-h5 q-my-none">Costing file details</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">{{ subtitle }}</p>
        </div>

        <div class="costing-page__toolbar">
          <q-select
            v-model="statusForm"
            :options="fileStatuses"
            label="File status"
            outlined
            dense
            :disable="!selectedFile || savingStatus"
            :loading="savingStatus"
            @update:model-value="handleSaveStatus"
          />
          <q-btn outline color="primary" label="Add item" :disable="!selectedFile" />
        </div>
      </section>

      <section v-if="selectedFile?.status === 'draft'" class="costing-page__draft-state">
        <div class="text-subtitle1">Items not added yet</div>
        <p class="text-body2 text-grey-7 q-mb-none">
          Add items now or wait for the customer to add items before continuing this costing file.
        </p>
      </section>

      <section v-else-if="selectedFile?.status === 'customer_submitted'" class="bw-page__stack">
        <div>
          <div class="text-subtitle1">Submitted items</div>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Review the items submitted by the customer before moving this costing file forward.
          </p>
        </div>

        <q-table
          flat
          bordered
          row-key="id"
          :rows="productRows"
          :columns="productColumns"
          :pagination="{ rowsPerPage: 0 }"
          :loading="loadingItems"
          hide-bottom
          class="costing-page__table"
        >
          <template #body-cell-sl="props">
            <q-td :props="props" class="costing-page__sl-cell">
              {{ props.row.sl }}
            </q-td>
          </template>

          <template #body-cell-image="props">
            <q-td :props="props">
              <div class="costing-page__image-cell">
                <q-img
                  v-if="props.row.imageUrl"
                  :src="props.row.imageUrl"
                  fit="cover"
                  class="costing-page__image"
                />
                <div v-else class="costing-page__image costing-page__image--placeholder">
                  No image
                </div>
              </div>
            </q-td>
          </template>

          <template #body-cell-websiteUrl="props">
            <q-td :props="props" class="costing-page__link-cell">
              <a
                :href="props.row.websiteUrl"
                :title="props.row.websiteUrl"
                class="costing-page__link"
                target="_blank"
                rel="noopener noreferrer"
              >
                {{ props.row.websiteUrl }}
              </a>
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props" class="costing-page__name-cell">
              <span class="costing-page__name-text" :title="props.row.name">
                {{ props.row.name }}
              </span>
            </q-td>
          </template>

          <template #body-cell-priceInWebGbp="props">
            <q-td :props="props" class="costing-page__numeric-cell">
              <div class="costing-page__inline-edit-cell">
                <button
                  type="button"
                  class="costing-page__inline-edit-trigger"
                  :disabled="savingFieldKey === `priceInWebGbp:${props.row.id}`"
                  @click="primeItemFieldEditor(props.row.id, 'priceInWebGbp', props.row.priceInWebGbpValue)"
                >
                  {{ props.row.priceInWebGbp }}
                </button>

                <q-popup-edit
                  v-model="itemFieldDrafts[`priceInWebGbp:${props.row.id}`]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateNullableNumber"
                  @before-show="primeItemFieldEditor(props.row.id, 'priceInWebGbp', props.row.priceInWebGbpValue)"
                  @save="saveItemField(props.row.id, 'priceInWebGbp', $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="0"
                    step="0.01"
                    label="Web price (GBP)"
                    hint="Leave empty to clear."
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-productWeight="props">
            <q-td :props="props" class="costing-page__weight-cell costing-page__numeric-cell">
              <div class="costing-page__inline-edit-cell">
                <button
                  type="button"
                  class="costing-page__inline-edit-trigger"
                  :disabled="savingFieldKey === `productWeight:${props.row.id}`"
                  @click="primeItemFieldEditor(props.row.id, 'productWeight', props.row.productWeightValue)"
                >
                  {{ props.row.productWeight }}
                </button>

                <q-popup-edit
                  v-model="itemFieldDrafts[`productWeight:${props.row.id}`]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateNullableNumber"
                  @before-show="primeItemFieldEditor(props.row.id, 'productWeight', props.row.productWeightValue)"
                  @save="saveItemField(props.row.id, 'productWeight', $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="0"
                    step="1"
                    label="Product wt"
                    hint="Leave empty to clear."
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-packageWeight="props">
            <q-td :props="props" class="costing-page__weight-cell costing-page__numeric-cell">
              <div class="costing-page__inline-edit-cell">
                <button
                  type="button"
                  class="costing-page__inline-edit-trigger"
                  :disabled="savingFieldKey === `packageWeight:${props.row.id}`"
                  @click="primeItemFieldEditor(props.row.id, 'packageWeight', props.row.packageWeightValue)"
                >
                  {{ props.row.packageWeight }}
                </button>

                <q-popup-edit
                  v-model="itemFieldDrafts[`packageWeight:${props.row.id}`]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateNullableNumber"
                  @before-show="primeItemFieldEditor(props.row.id, 'packageWeight', props.row.packageWeightValue)"
                  @save="saveItemField(props.row.id, 'packageWeight', $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="0"
                    step="1"
                    label="Package wt"
                    hint="Leave empty to clear."
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-quantity="props">
            <q-td :props="props" class="costing-page__numeric-cell">
              <div class="costing-page__quantity-cell">
                <button
                  type="button"
                  class="costing-page__quantity-trigger"
                  :disabled="savingQuantityItemId === props.row.id"
                  @click="primeQuantityEditor(props.row.id, props.row.quantity)"
                >
                  {{ props.row.quantity }}
                </button>

                <q-popup-edit
                  v-model="quantityDrafts[props.row.id]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateQuantity"
                  @before-show="primeQuantityEditor(props.row.id, props.row.quantity)"
                  @save="saveQuantity(props.row.id, $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="1"
                    step="1"
                    label="Quantity"
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" auto-width>
              <q-btn
                flat
                dense
                color="primary"
                icon="edit"
                round
                aria-label="Edit item"
                :disable="savingItemId === props.row.id"
                @click="openEditDialog(props.row.id)"
              />
            </q-td>
          </template>
        </q-table>
      </section>

      <section
        v-else-if="selectedFile?.status === 'in_review' || selectedFile?.status === 'offered'"
        class="costing-page__pricing-section"
      >
        <div>
          <div class="text-subtitle1">Pricing inputs</div>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Enter pricing values for this costing file.
          </p>
        </div>

        <div class="costing-page__pricing-grid">
          <div class="costing-page__field">
            <div class="costing-page__field-label">Cargo rate 1 KG</div>
            <q-input v-model.number="pricingForm.cargoRate1Kg" type="number" outlined dense class="costing-page__pricing-input" />
          </div>
          <div class="costing-page__field">
            <div class="costing-page__field-label">Cargo rate 2 KG</div>
            <q-input v-model.number="pricingForm.cargoRate2Kg" type="number" outlined dense class="costing-page__pricing-input" />
          </div>
          <div class="costing-page__field">
            <div class="costing-page__field-label">Conversion rate</div>
            <q-input v-model.number="pricingForm.conversionRate" type="number" outlined dense class="costing-page__pricing-input" />
          </div>
          <div class="costing-page__field">
            <div class="costing-page__field-label">Admin profit rate</div>
            <q-input v-model.number="pricingForm.adminProfitRate" type="number" outlined dense class="costing-page__pricing-input" />
          </div>
          <div class="costing-page__field costing-page__field--action">
            <div class="costing-page__field-label costing-page__field-label--ghost">Action</div>
            <q-btn
              color="primary"
              unelevated
              label="Save pricing"
              :loading="savingPricing"
              :disable="!selectedFile"
              @click="handleSavePricing"
            />
          </div>
        </div>

        <div class="costing-page__pricing-actions">
          <q-btn-toggle
            v-model="reviewTableMode"
            unelevated
            no-caps
            toggle-color="primary"
            color="white"
            text-color="primary"
            :options="[
              { label: 'Detailed', value: 'detailed' },
              { label: 'Compact', value: 'compact' },
            ]"
          />
        </div>

        <q-table
          flat
          bordered
          row-key="id"
          :rows="reviewRows"
          :columns="visibleReviewColumns"
          :pagination="{ rowsPerPage: 0 }"
          :loading="loadingItems"
          hide-bottom
          class="costing-page__table"
        >
          <template #body-cell-sl="props">
            <q-td :props="props" class="costing-page__sl-cell">
              {{ props.row.sl }}
            </q-td>
          </template>

          <template #body-cell-image="props">
            <q-td :props="props">
              <div class="costing-page__image-cell">
                <q-img
                  v-if="props.row.imageUrl"
                  :src="props.row.imageUrl"
                  fit="cover"
                  class="costing-page__image"
                />
                <div v-else class="costing-page__image costing-page__image--placeholder">
                  No image
                </div>
              </div>
            </q-td>
          </template>

          <template #body-cell-websiteUrl="props">
            <q-td :props="props" class="costing-page__link-cell">
              <a
                :href="props.row.websiteUrl"
                :title="props.row.websiteUrl"
                class="costing-page__link"
                target="_blank"
                rel="noopener noreferrer"
              >
                {{ props.row.websiteUrl }}
              </a>
            </q-td>
          </template>

          <template #body-cell-name="props">
            <q-td :props="props" class="costing-page__name-cell">
              <span class="costing-page__name-text" :title="props.row.name">
                {{ props.row.name }}
              </span>
            </q-td>
          </template>

          <template #body-cell-priceInWebGbp="props">
            <q-td :props="props" class="costing-page__numeric-cell">
              <div class="costing-page__inline-edit-cell">
                <button
                  type="button"
                  class="costing-page__inline-edit-trigger"
                  :disabled="savingFieldKey === `priceInWebGbp:${props.row.id}`"
                  @click="primeItemFieldEditor(props.row.id, 'priceInWebGbp', props.row.priceInWebGbpValue)"
                >
                  {{ props.row.priceInWebGbp }}
                </button>

                <q-popup-edit
                  v-model="itemFieldDrafts[`priceInWebGbp:${props.row.id}`]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateNullableNumber"
                  @before-show="primeItemFieldEditor(props.row.id, 'priceInWebGbp', props.row.priceInWebGbpValue)"
                  @save="saveItemField(props.row.id, 'priceInWebGbp', $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="0"
                    step="0.01"
                    label="Web price (GBP)"
                    hint="Leave empty to clear."
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-productWeight="props">
            <q-td :props="props" class="costing-page__weight-cell costing-page__numeric-cell">
              <div class="costing-page__inline-edit-cell">
                <button
                  type="button"
                  class="costing-page__inline-edit-trigger"
                  :disabled="savingFieldKey === `productWeight:${props.row.id}`"
                  @click="primeItemFieldEditor(props.row.id, 'productWeight', props.row.productWeightValue)"
                >
                  {{ props.row.productWeight }}
                </button>

                <q-popup-edit
                  v-model="itemFieldDrafts[`productWeight:${props.row.id}`]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateNullableNumber"
                  @before-show="primeItemFieldEditor(props.row.id, 'productWeight', props.row.productWeightValue)"
                  @save="saveItemField(props.row.id, 'productWeight', $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="0"
                    step="1"
                    label="Product wt"
                    hint="Leave empty to clear."
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-packageWeight="props">
            <q-td :props="props" class="costing-page__weight-cell costing-page__numeric-cell">
              <div class="costing-page__inline-edit-cell">
                <button
                  type="button"
                  class="costing-page__inline-edit-trigger"
                  :disabled="savingFieldKey === `packageWeight:${props.row.id}`"
                  @click="primeItemFieldEditor(props.row.id, 'packageWeight', props.row.packageWeightValue)"
                >
                  {{ props.row.packageWeight }}
                </button>

                <q-popup-edit
                  v-model="itemFieldDrafts[`packageWeight:${props.row.id}`]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateNullableNumber"
                  @before-show="primeItemFieldEditor(props.row.id, 'packageWeight', props.row.packageWeightValue)"
                  @save="saveItemField(props.row.id, 'packageWeight', $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="0"
                    step="1"
                    label="Package wt"
                    hint="Leave empty to clear."
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-deliveryPriceGbp="props">
            <q-td :props="props" class="costing-page__numeric-cell">
              <div class="costing-page__inline-edit-cell">
                <button
                  type="button"
                  class="costing-page__inline-edit-trigger"
                  :disabled="savingFieldKey === `deliveryPriceGbp:${props.row.id}`"
                  @click="primeItemFieldEditor(props.row.id, 'deliveryPriceGbp', props.row.deliveryPriceGbpValue)"
                >
                  {{ props.row.deliveryPriceGbp }}
                </button>

                <q-popup-edit
                  v-model="itemFieldDrafts[`deliveryPriceGbp:${props.row.id}`]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateNullableNumber"
                  @before-show="primeItemFieldEditor(props.row.id, 'deliveryPriceGbp', props.row.deliveryPriceGbpValue)"
                  @save="saveItemField(props.row.id, 'deliveryPriceGbp', $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="0"
                    step="0.01"
                    label="Delivery price (GBP)"
                    hint="Leave empty to clear."
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-quantity="props">
            <q-td :props="props" class="costing-page__numeric-cell">
              <div class="costing-page__quantity-cell">
                <button
                  type="button"
                  class="costing-page__quantity-trigger"
                  :disabled="savingQuantityItemId === props.row.id"
                  @click="primeQuantityEditor(props.row.id, props.row.quantity)"
                >
                  {{ props.row.quantity }}
                </button>

                <q-popup-edit
                  v-model="quantityDrafts[props.row.id]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateQuantity"
                  @before-show="primeQuantityEditor(props.row.id, props.row.quantity)"
                  @save="saveQuantity(props.row.id, $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="1"
                    step="1"
                    label="Quantity"
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-offerPriceBdt="props">
            <q-td :props="props" class="costing-page__numeric-cell">
              <div class="costing-page__offer-cell">
                <button
                  type="button"
                  class="costing-page__offer-trigger"
                  :disabled="savingOfferItemId === props.row.id"
                  @click="primeOfferEditor(props.row.id, props.row.offerPriceBdtValue)"
                >
                  {{ props.row.offerPriceBdt }}
                  <span
                    v-if="props.row.offerPriceOverrideBdt != null"
                    class="costing-page__offer-badge"
                  >
                    Manual
                  </span>
                </button>

                <q-popup-edit
                  v-model="offerDrafts[props.row.id]"
                  buttons
                  label-set="Save"
                  label-cancel="Cancel"
                  :validate="validateOfferPrice"
                  @before-show="primeOfferEditor(props.row.id, props.row.offerPriceBdtValue)"
                  @save="saveOfferPrice(props.row.id, $event)"
                  v-slot="scope"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    dense
                    autofocus
                    outlined
                    min="0"
                    label="Offer price (BDT)"
                    hint="Leave empty to use the calculated offer price."
                  />
                </q-popup-edit>
              </div>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" auto-width>
              <q-btn
                flat
                dense
                color="negative"
                icon="delete"
                round
                aria-label="Delete item"
                :loading="deletingReviewItemId === props.row.id"
                :disable="selectedFile?.status !== 'in_review' || deletingReviewItemId === props.row.id"
                @click="openDeleteReviewItemDialog(props.row.id)"
              />
            </q-td>
          </template>
        </q-table>
      </section>

      <q-dialog v-model="deleteReviewItemDialogOpen" persistent>
        <q-card style="min-width: 360px">
          <q-card-section>
            <div class="text-h6">Delete item</div>
          </q-card-section>

          <q-card-section>
            Delete this costing item from the review table?
          </q-card-section>

          <q-card-actions align="right">
            <q-btn flat label="Cancel" @click="deleteReviewItemDialogOpen = false" />
            <q-btn
              color="negative"
              unelevated
              label="Delete"
              :loading="deletingReviewItemId !== null"
              @click="confirmDeleteReviewItem"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <AdminCostingFileItemEditDialog
        v-model="editDialogOpen"
        :item="editingItem"
        :loading="savingItemId === editingItem?.id"
        @save="handleSaveEnrichment"
      />
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useRoute } from 'vue-router'

import AdminCostingFileItemEditDialog from 'src/modules/costingFile/components/AdminCostingFileItemEditDialog.vue'
import { useCostingFileStore } from 'src/modules/costingFile/stores/costingFileStore'
import type { CostingFileItem, CostingFileStatus } from 'src/modules/costingFile/types'
import { calculateCostingItem } from 'src/modules/costingFile/utils/costingCalculations'

const route = useRoute()
const costingFileStore = useCostingFileStore()
const {
  selectedItem: selectedFile,
  costingFileItems,
  itemLoading: loadingItems,
} = storeToRefs(costingFileStore)

const savingStatus = ref(false)
const savingItemId = ref<number | null>(null)
const savingPricing = ref(false)
const savingOfferItemId = ref<number | null>(null)
const savingQuantityItemId = ref<number | null>(null)
const savingFieldKey = ref<string | null>(null)
const deletingReviewItemId = ref<number | null>(null)
const deleteReviewItemDialogOpen = ref(false)
const reviewItemPendingDeleteId = ref<number | null>(null)
const statusForm = ref<CostingFileStatus>('draft')
const editDialogOpen = ref(false)
const editingItemId = ref<number | null>(null)
const reviewTableMode = ref<'detailed' | 'compact'>('detailed')
const offerDrafts = reactive<Record<number, number | null>>({})
const quantityDrafts = reactive<Record<number, number | null>>({})
const itemFieldDrafts = reactive<Record<string, number | null>>({})
const pricingForm = reactive({
  cargoRate1Kg: null as number | null,
  cargoRate2Kg: null as number | null,
  conversionRate: null as number | null,
  adminProfitRate: null as number | null,
})

const fileStatuses: CostingFileStatus[] = ['draft', 'customer_submitted', 'in_review', 'offered', 'completed', 'cancelled']

const subtitle = computed(() =>
  selectedFile.value ? `${selectedFile.value.name} items and pricing.` : 'Loading costing file details.'
)

const editingItem = computed<CostingFileItem | null>(
  () => costingFileItems.value.find((item) => item.id === editingItemId.value) ?? null,
)

const productRows = computed(() =>
  costingFileItems.value.map((item, index) => ({
    id: item.id,
    sl: index + 1,
    imageUrl: item.image_url,
    websiteUrl: item.website_url,
    name: item.name ?? '-',
    priceInWebGbpValue: item.price_in_web_gbp,
    priceInWebGbp: item.price_in_web_gbp == null ? '-' : Number(item.price_in_web_gbp).toFixed(2),
    productWeightValue: item.product_weight,
    productWeight: item.product_weight == null ? '-' : item.product_weight,
    packageWeightValue: item.package_weight,
    packageWeight: item.package_weight == null ? '-' : item.package_weight,
    quantity: item.quantity,
  })),
)

const productColumns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'left' as const, style: 'width: 48px; min-width: 48px;', headerStyle: 'width: 48px; min-width: 48px;' },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'left' as const, style: 'width: 108px; min-width: 108px;', headerStyle: 'width: 108px; min-width: 108px;' },
  { name: 'websiteUrl', label: 'Web link', field: 'websiteUrl', align: 'left' as const, style: 'width: 144px; min-width: 144px; max-width: 144px;', headerStyle: 'width: 144px; min-width: 144px; max-width: 144px;' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const, style: 'width: 280px; min-width: 280px; max-width: 280px;', headerStyle: 'width: 280px; min-width: 280px; max-width: 280px;' },
  {
    name: 'priceInWebGbp',
    label: 'Web price (GBP)',
    field: 'priceInWebGbp',
    align: 'left' as const,
    style: 'width: 110px; min-width: 110px;',
    headerStyle: 'width: 110px; min-width: 110px;',
    classes: 'costing-page__tone-indigo',
    headerClasses: 'costing-page__tone-indigo',
  },
  { name: 'productWeight', label: 'Product wt', field: 'productWeight', align: 'left' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
  { name: 'packageWeight', label: 'Package wt', field: 'packageWeight', align: 'left' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'left' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
  { name: 'actions', label: '', field: 'actions', align: 'right' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
]

const formatGbp = (value: number | null | undefined) => (value == null ? '-' : Number(value).toFixed(2))
const formatBdt = (value: number | null | undefined) => (value == null ? '-' : String(value))

const reviewRows = computed(() =>
  costingFileItems.value.map((item, index) => {
    const calculated = calculateCostingItem(
      {
        cargoRate1Kg: pricingForm.cargoRate1Kg,
        cargoRate2Kg: pricingForm.cargoRate2Kg,
        conversionRate: pricingForm.conversionRate,
        adminProfitRate: pricingForm.adminProfitRate,
        offerPriceOverrideBdt: item.offer_price_override_bdt,
      },
      {
        productWeight: item.product_weight,
        packageWeight: item.package_weight,
        priceInWebGbp: item.price_in_web_gbp,
        deliveryPriceGbp: item.delivery_price_gbp,
        customerProfitRate: item.customer_profit_rate,
      },
    )
    const profitAmount = calculated.offerPriceBdt - calculated.costingPriceBdt
    const profitRate =
      calculated.costingPriceBdt > 0
        ? `${((profitAmount / calculated.costingPriceBdt) * 100).toFixed(2)}%`
        : '-'
    const quantity = Number(item.quantity ?? 0)
    const totalCostBdt = calculated.costingPriceBdt * quantity
    const totalOfferPriceBdt = calculated.offerPriceBdt * quantity
    const totalProfitBdt = totalOfferPriceBdt - totalCostBdt
    const averageProfitRate =
      totalCostBdt > 0 ? `${((totalProfitBdt / totalCostBdt) * 100).toFixed(2)}%` : '-'

    return {
      id: item.id,
      sl: index + 1,
      imageUrl: item.image_url,
      websiteUrl: item.website_url,
      quantity,
      name: item.name ?? '-',
      productWeight: item.product_weight ?? '-',
      productWeightValue: item.product_weight,
      packageWeight: item.package_weight ?? '-',
      packageWeightValue: item.package_weight,
      totalWeight: calculated.totalWeight,
      priceInWebGbpValue: item.price_in_web_gbp,
      priceInWebGbp: formatGbp(item.price_in_web_gbp),
      deliveryPriceGbpValue: item.delivery_price_gbp,
      deliveryPriceGbp: formatGbp(item.delivery_price_gbp),
      auxiliaryPriceGbp: formatGbp(calculated.auxiliaryPriceGbp),
      purchasePriceGbp: formatGbp(calculated.itemPriceGbp),
      cargoRateGbp: formatGbp(calculated.cargoRate),
      costingPriceGbp: formatGbp(calculated.costingPriceGbp),
      costingPriceBdt: formatBdt(calculated.costingPriceBdt),
      offerPriceBdtValue: calculated.offerPriceBdt,
      offerPriceBdt: formatBdt(calculated.offerPriceBdt),
      offerPriceOverrideBdt: item.offer_price_override_bdt,
      profitRate,
      profitAmount: formatBdt(profitAmount),
      totalCostBdt: formatBdt(totalCostBdt),
      totalOfferPriceBdt: formatBdt(totalOfferPriceBdt),
      totalProfitBdt: formatBdt(totalProfitBdt),
      averageProfitRate,
    }
  }),
)

const reviewColumns = [
  { name: 'sl', label: 'SL', field: 'sl', align: 'left' as const, style: 'width: 48px; min-width: 48px;', headerStyle: 'width: 48px; min-width: 48px;' },
  { name: 'image', label: 'Image', field: 'imageUrl', align: 'left' as const, style: 'width: 108px; min-width: 108px;', headerStyle: 'width: 108px; min-width: 108px;' },
  { name: 'websiteUrl', label: 'Web URL', field: 'websiteUrl', align: 'left' as const, style: 'width: 144px; min-width: 144px; max-width: 144px;', headerStyle: 'width: 144px; min-width: 144px; max-width: 144px;' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'left' as const, style: 'width: 56px; min-width: 56px;', headerStyle: 'width: 56px; min-width: 56px;' },
  { name: 'name', label: 'Name', field: 'name', align: 'left' as const, style: 'width: 280px; min-width: 280px; max-width: 280px;', headerStyle: 'width: 280px; min-width: 280px; max-width: 280px;' },
  { name: 'productWeight', label: 'Product wt', field: 'productWeight', align: 'left' as const, style: 'width: 60px; min-width: 60px;', headerStyle: 'width: 60px; min-width: 60px; white-space: normal; line-height: 1.15;' },
  { name: 'packageWeight', label: 'Package wt', field: 'packageWeight', align: 'left' as const, style: 'width: 60px; min-width: 60px;', headerStyle: 'width: 60px; min-width: 60px; white-space: normal; line-height: 1.15;' },
  { name: 'totalWeight', label: 'Total wt', field: 'totalWeight', align: 'left' as const, style: 'width: 60px; min-width: 60px;', headerStyle: 'width: 60px; min-width: 60px; white-space: normal; line-height: 1.15;' },
  {
    name: 'priceInWebGbp',
    label: 'Web price (GBP)',
    field: 'priceInWebGbp',
    align: 'left' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-indigo',
    headerClasses: 'costing-page__tone-indigo',
  },
  { name: 'deliveryPriceGbp', label: 'Delivery price (GBP)', field: 'deliveryPriceGbp', align: 'left' as const, style: 'width: 92px; min-width: 92px;', headerStyle: 'width: 92px; min-width: 92px; white-space: normal; line-height: 1.15;' },
  { name: 'auxiliaryPriceGbp', label: 'Auxiliary price (GBP)', field: 'auxiliaryPriceGbp', align: 'left' as const, style: 'width: 92px; min-width: 92px;', headerStyle: 'width: 92px; min-width: 92px; white-space: normal; line-height: 1.15;' },
  { name: 'purchasePriceGbp', label: 'Purchase price (GBP)', field: 'purchasePriceGbp', align: 'left' as const, style: 'width: 92px; min-width: 92px;', headerStyle: 'width: 92px; min-width: 92px; white-space: normal; line-height: 1.15;' },
  { name: 'cargoRateGbp', label: 'Cargo per KG (GBP)', field: 'cargoRateGbp', align: 'left' as const, style: 'width: 92px; min-width: 92px;', headerStyle: 'width: 92px; min-width: 92px; white-space: normal; line-height: 1.15;' },
  {
    name: 'costingPriceGbp',
    label: 'Cost (GBP)',
    field: 'costingPriceGbp',
    align: 'left' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-indigo',
    headerClasses: 'costing-page__tone-indigo',
  },
  {
    name: 'costingPriceBdt',
    label: 'Cost (BDT)',
    field: 'costingPriceBdt',
    align: 'left' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-amber',
    headerClasses: 'costing-page__tone-amber',
  },
  {
    name: 'offerPriceBdt',
    label: 'Offer price (BDT)',
    field: 'offerPriceBdt',
    align: 'left' as const,
    style: 'width: 88px; min-width: 88px;',
    headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-emerald',
    headerClasses: 'costing-page__tone-emerald',
  },
  {
    name: 'totalCostBdt',
    label: 'Total cost (BDT)',
    field: 'totalCostBdt',
    align: 'left' as const,
    style: 'width: 94px; min-width: 94px;',
    headerStyle: 'width: 94px; min-width: 94px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-amber',
    headerClasses: 'costing-page__tone-amber',
  },
  {
    name: 'totalOfferPriceBdt',
    label: 'Total offer (BDT)',
    field: 'totalOfferPriceBdt',
    align: 'left' as const,
    style: 'width: 96px; min-width: 96px;',
    headerStyle: 'width: 96px; min-width: 96px; white-space: normal; line-height: 1.15;',
    classes: 'costing-page__tone-emerald',
    headerClasses: 'costing-page__tone-emerald',
  },
  { name: 'profitRate', label: 'Profit rate', field: 'profitRate', align: 'left' as const, style: 'width: 74px; min-width: 74px;', headerStyle: 'width: 74px; min-width: 74px; white-space: normal; line-height: 1.15;' },
  { name: 'profitAmount', label: 'Profit amount (BDT)', field: 'profitAmount', align: 'left' as const, style: 'width: 92px; min-width: 92px;', headerStyle: 'width: 92px; min-width: 92px; white-space: normal; line-height: 1.15;' },
  { name: 'totalProfitBdt', label: 'Total profit (BDT)', field: 'totalProfitBdt', align: 'left' as const, style: 'width: 96px; min-width: 96px;', headerStyle: 'width: 96px; min-width: 96px; white-space: normal; line-height: 1.15;' },
  { name: 'averageProfitRate', label: 'Avg profit rate', field: 'averageProfitRate', align: 'left' as const, style: 'width: 88px; min-width: 88px;', headerStyle: 'width: 88px; min-width: 88px; white-space: normal; line-height: 1.15;' },
  { name: 'actions', label: '', field: 'actions', align: 'right' as const, style: 'width: 72px; min-width: 72px;', headerStyle: 'width: 72px; min-width: 72px;' },
]

const compactReviewColumnNames = [
  'sl',
  'image',
  'name',
  'priceInWebGbp',
  'costingPriceGbp',
  'costingPriceBdt',
  'offerPriceBdt',
  'profitRate',
  'profitAmount',
  'actions',
] as const

const visibleReviewColumns = computed(() => {
  const columns =
    reviewTableMode.value === 'compact'
      ? reviewColumns.filter((column) => compactReviewColumnNames.includes(column.name as (typeof compactReviewColumnNames)[number]))
      : reviewColumns

  if (selectedFile.value?.status === 'in_review') {
    return columns
  }

  return columns.filter((column) => column.name !== 'actions')
})

const loadFile = async () => {
  const fileId = Number(route.params.id)
  if (!fileId) return

  await costingFileStore.fetchCostingFileWithItems(fileId)
}

const handleSaveStatus = async (value: CostingFileStatus | null = statusForm.value) => {
  if (!selectedFile.value || !value || value === selectedFile.value.status) return

  savingStatus.value = true
  try {
    statusForm.value = value
    const result = await costingFileStore.updateCostingFileStatus({ id: selectedFile.value.id, status: value })

    if (!result.success) {
      statusForm.value = selectedFile.value.status
    }
  } finally {
    savingStatus.value = false
  }
}

const openEditDialog = (itemId: number) => {
  editingItemId.value = itemId
  editDialogOpen.value = true
}

const primeOfferEditor = (itemId: number, fallbackValue: number | null) => {
  if (offerDrafts[itemId] !== undefined) return

  const item = costingFileItems.value.find((entry) => entry.id === itemId)
  offerDrafts[itemId] = item?.offer_price_override_bdt ?? fallbackValue ?? null
}

const primeQuantityEditor = (itemId: number, fallbackValue: number | string) => {
  if (quantityDrafts[itemId] !== undefined) return

  const item = costingFileItems.value.find((entry) => entry.id === itemId)
  quantityDrafts[itemId] = item?.quantity ?? Number(fallbackValue)
}

const itemFieldKey = (
  itemId: number,
  field: 'productWeight' | 'packageWeight' | 'priceInWebGbp' | 'deliveryPriceGbp',
) => `${field}:${itemId}`

const primeItemFieldEditor = (
  itemId: number,
  field: 'productWeight' | 'packageWeight' | 'priceInWebGbp' | 'deliveryPriceGbp',
  fallbackValue: number | null,
) => {
  const key = itemFieldKey(itemId, field)
  if (itemFieldDrafts[key] !== undefined) return

  const item = costingFileItems.value.find((entry) => entry.id === itemId)
  if (field === 'productWeight') itemFieldDrafts[key] = item?.product_weight ?? fallbackValue ?? null
  if (field === 'packageWeight') itemFieldDrafts[key] = item?.package_weight ?? fallbackValue ?? null
  if (field === 'priceInWebGbp') itemFieldDrafts[key] = item?.price_in_web_gbp ?? fallbackValue ?? null
  if (field === 'deliveryPriceGbp') itemFieldDrafts[key] = item?.delivery_price_gbp ?? fallbackValue ?? null
}

const validateQuantity = (value: number | string | null) => {
  const normalized = Number(value)
  return Number.isInteger(normalized) && normalized >= 1
}

const validateNullableNumber = (value: number | null) => value == null || value >= 0

const saveQuantity = async (itemId: number, value: number | string | null) => {
  const normalized = Number(value)
  if (!Number.isInteger(normalized) || normalized < 1) return

  savingQuantityItemId.value = itemId
  try {
    await costingFileStore.updateCostingFileItem({
      id: itemId,
      quantity: normalized,
    })
  } finally {
    savingQuantityItemId.value = null
    delete quantityDrafts[itemId]
  }
}

const saveItemField = async (
  itemId: number,
  field: 'productWeight' | 'packageWeight' | 'priceInWebGbp' | 'deliveryPriceGbp',
  value: number | null,
) => {
  const key = itemFieldKey(itemId, field)
  savingFieldKey.value = key
  try {
    await costingFileStore.updateCostingFileItem({
      id: itemId,
      [field]: value == null ? null : Number(value),
    })
  } finally {
    savingFieldKey.value = null
    delete itemFieldDrafts[key]
  }
}

const validateOfferPrice = (value: number | null) => value == null || value >= 0

const saveOfferPrice = async (itemId: number, value: number | null) => {
  savingOfferItemId.value = itemId
  try {
    await costingFileStore.updateCostingFileItemOffer({
      id: itemId,
      offerPriceOverrideBdt: value == null ? null : Number(value),
    })
  } finally {
    savingOfferItemId.value = null
    delete offerDrafts[itemId]
  }
}

const handleSaveEnrichment = async (payload: {
  id: number
  name: string | null
  productWeight: number | null
  packageWeight: number | null
  imageUrl: string | null
  priceInWebGbp: number | null
  deliveryPriceGbp: number | null
}) => {
  savingItemId.value = payload.id
  try {
    const result = await costingFileStore.updateCostingFileItem({
      id: payload.id,
      name: payload.name,
      productWeight: payload.productWeight,
      packageWeight: payload.packageWeight,
      imageUrl: payload.imageUrl,
      priceInWebGbp: payload.priceInWebGbp,
      deliveryPriceGbp: payload.deliveryPriceGbp,
    })

    if (result.success) {
      editDialogOpen.value = false
    }
  } finally {
    savingItemId.value = null
  }
}

const openDeleteReviewItemDialog = (itemId: number) => {
  if (selectedFile.value?.status !== 'in_review') {
    return
  }

  reviewItemPendingDeleteId.value = itemId
  deleteReviewItemDialogOpen.value = true
}

const confirmDeleteReviewItem = async () => {
  const itemId = reviewItemPendingDeleteId.value

  if (selectedFile.value?.status !== 'in_review' || itemId == null) {
    return
  }

  if (selectedFile.value?.status !== 'in_review') {
    return
  }

  deletingReviewItemId.value = itemId
  try {
    await costingFileStore.deleteCostingFileItem({ id: itemId })
    deleteReviewItemDialogOpen.value = false
    reviewItemPendingDeleteId.value = null
  } finally {
    deletingReviewItemId.value = null
  }
}

const handleSavePricing = async () => {
  if (!selectedFile.value) return

  savingPricing.value = true
  try {
    await costingFileStore.updateCostingFilePricing({
      id: selectedFile.value.id,
      cargoRate1Kg: pricingForm.cargoRate1Kg,
      cargoRate2Kg: pricingForm.cargoRate2Kg,
      conversionRate: pricingForm.conversionRate,
      adminProfitRate: pricingForm.adminProfitRate,
    })
  } finally {
    savingPricing.value = false
  }
}

watch(
  selectedFile,
  (file) => {
    if (file) {
      statusForm.value = file.status
      pricingForm.cargoRate1Kg = file.cargo_rate_1kg
      pricingForm.cargoRate2Kg = file.cargo_rate_2kg
      pricingForm.conversionRate = file.conversion_rate
      pricingForm.adminProfitRate = file.admin_profit_rate
    }
  },
  { immediate: true },
)

watch(editDialogOpen, (isOpen) => {
  if (!isOpen) {
    editingItemId.value = null
  }
})

onMounted(async () => {
  await loadFile()
})
</script>

<style scoped>
.costing-page {
  display: grid;
  gap: 1.25rem;
}

.costing-page > * {
  min-width: 0;
}

.costing-page__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.costing-page__heading {
  min-width: 0;
  flex: 1 1 auto;
}

.costing-page__toolbar {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.75rem;
  flex: 0 0 auto;
}

.costing-page__toolbar :deep(.q-field) {
  min-width: 220px;
}

.costing-page__draft-state {
  display: grid;
  gap: 0.5rem;
  padding: 1rem 0;
  border-top: 1px solid var(--bw-theme-border);
}

.costing-page__pricing-section {
  display: grid;
  gap: 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--bw-theme-border);
}

.costing-page__pricing-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 1rem;
  align-items: end;
}

.costing-page__field {
  display: grid;
  gap: 0.4rem;
}

.costing-page__field--action {
  align-self: end;
}

.costing-page__field-label {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--bw-theme-ink);
}

.costing-page__pricing-input {
  max-width: 140px;
}

.costing-page__field-label--ghost {
  opacity: 0;
  user-select: none;
}

.costing-page__pricing-actions {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.costing-page__table {
  min-width: 0;
  max-width: 100%;
  overflow-x: auto;
}

.costing-page__table :deep(.q-table th),
.costing-page__table :deep(.q-table td) {
  text-align: center;
  vertical-align: middle;
}

.costing-page__sl-cell {
  width: 3ch;
  max-width: 3ch;
  white-space: nowrap;
}

.costing-page__image-cell {
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

.costing-page__link-cell {
  width: 144px;
  max-width: 144px;
}

.costing-page__link {
  display: inline-block;
  max-width: 144px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--bw-theme-primary);
  text-decoration: none;
}

.costing-page__name-cell {
  width: 280px;
  max-width: 280px;
}

.costing-page__name-text {
  display: inline-block;
  max-width: 280px;
  white-space: normal;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.costing-page__weight-cell {
  width: 72px;
  max-width: 72px;
  white-space: nowrap;
}

.costing-page__numeric-cell {
  font-weight: 700;
  font-size: 0.95rem;
  line-height: 1.35;
  text-align: center;
  font-variant-numeric: tabular-nums;
}

.costing-page__offer-cell {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 40px;
  width: 100%;
}

.costing-page__quantity-cell {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 40px;
  width: 100%;
}

.costing-page__quantity-trigger {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  border: 0;
  padding: 0;
  background: transparent;
  color: var(--bw-theme-ink);
  cursor: pointer;
  font: inherit;
  font-weight: 700;
  font-size: 0.95rem;
  font-variant-numeric: tabular-nums;
  text-align: center;
}

.costing-page__quantity-trigger:disabled {
  cursor: wait;
  opacity: 0.7;
}

.costing-page__inline-edit-cell {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  min-height: 40px;
}

.costing-page__inline-edit-trigger {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  border: 0;
  padding: 0;
  background: transparent;
  color: inherit;
  cursor: pointer;
  font: inherit;
  font-weight: 700;
  font-size: 0.95rem;
  font-variant-numeric: tabular-nums;
  text-align: center;
}

.costing-page__inline-edit-trigger:disabled {
  cursor: wait;
  opacity: 0.7;
}

.costing-page__offer-trigger {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border: 0;
  padding: 0;
  background: transparent;
  color: var(--bw-theme-primary);
  cursor: pointer;
  font: inherit;
  font-weight: 700;
  font-size: 0.95rem;
  font-variant-numeric: tabular-nums;
  justify-content: center;
  text-align: center;
}

.costing-page__offer-trigger:disabled {
  cursor: wait;
  opacity: 0.7;
}

.costing-page__offer-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.15rem 0.4rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--bw-theme-primary) 12%, white);
  color: var(--bw-theme-primary);
  font-size: 0.7rem;
  font-weight: 600;
  letter-spacing: 0.02em;
}

.costing-page :deep(.costing-page__tone-indigo) {
  background: #eceffd;
  color: #34408f;
}

.costing-page :deep(.costing-page__tone-amber) {
  background: #fbefc4;
  color: #7a5313;
}

.costing-page :deep(.costing-page__tone-emerald) {
  background: #ddf4e7;
  color: #1f6a43;
}

.costing-page :deep(th.costing-page__tone-indigo),
.costing-page :deep(th.costing-page__tone-amber),
.costing-page :deep(th.costing-page__tone-emerald) {
  font-weight: 700;
}

.costing-page :deep(.q-table th:nth-child(4)),
.costing-page :deep(.q-table td:nth-child(4)) {
  width: 56px;
  max-width: 56px;
  white-space: nowrap;
}

@media (max-width: 900px) {
  .costing-page__header {
    flex-direction: column;
  }

  .costing-page__toolbar {
    justify-content: stretch;
  }

  .costing-page__toolbar > * {
    width: 100%;
  }

  .costing-page__pricing-grid {
    grid-template-columns: 1fr;
  }

  .costing-page__field-label--ghost {
    display: none;
  }

  .costing-page__pricing-actions > * {
    width: 100%;
  }
}

@media (max-width: 599px) {
  .costing-page__image-cell {
    width: 72px;
  }

  .costing-page__image {
    width: 72px;
    height: 72px;
  }
}
</style>
