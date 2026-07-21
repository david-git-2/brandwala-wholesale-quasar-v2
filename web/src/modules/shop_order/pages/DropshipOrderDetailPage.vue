<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Loading Spinner -->
      <div v-if="loading" class="row justify-center q-py-xl">
        <q-spinner color="primary" size="3em" />
      </div>

      <template v-else>
        <!-- Confirmed Handoff Warning Banner -->
        <q-banner v-if="order?.status === 'confirmed'" class="bg-amber-2 text-amber-10 rounded-borders q-mb-md border-all-1">
          <template #avatar>
            <q-icon name="warning" color="amber-9" size="32px" />
          </template>
          <div class="text-subtitle2 text-weight-bold">
            {{ $t('shop_admin.dropship_handoff_required_banner') }}
          </div>
          <div>
            Click <strong>Add to Dropship Desk</strong> below to hand off this order from the Service Desk to start courier operations.
          </div>
          <template #action>
            <q-btn
              color="primary"
              unelevated
              no-caps
              icon="local_shipping"
              :label="$t('shop_admin.add_to_dropship_desk')"
              :loading="handingOff"
              @click="performHandoff"
            />
          </template>
        </q-banner>

        <!-- Header -->
        <section class="row items-center justify-between q-col-gutter-md">
          <div class="col">
            <div class="row items-center q-gutter-x-sm">
              <q-btn flat round icon="arrow_back" color="grey-7" :to="{ name: 'app-shop-dropship-orders-page' }" />
              <div>
                <div class="text-overline">Dropship Desk / Order Process</div>
                <h1 class="text-h5 q-my-none">Process Order: {{ order?.order_no || 'ORD-DS' }}</h1>
                <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                  Middle Man: <strong class="text-grey-9">{{ order?.customer_group_name || order?.created_by_email || '—' }}</strong>
                </p>
              </div>
            </div>
          </div>
          <div class="col-auto row q-gutter-sm">
            <q-btn outline color="primary" icon="print" label="Print Packing Slip" no-caps @click="printPackingSlip" />
            <q-btn outline color="secondary" icon="qr_code" label="Print Label" no-caps @click="printLabel" />
            <q-btn
              v-if="order?.status === 'delivered'"
              color="positive"
              icon="receipt_long"
              label="Create Dual Invoice"
              no-caps
              @click="openDualInvoiceDialog"
            />
          </div>
        </section>

        <!-- Status Stepper Bar (Gated if confirmed) -->
        <q-card v-if="order?.status !== 'confirmed'" flat bordered class="q-pa-md form-card">
          <div class="row items-center justify-between q-mb-sm">
            <div class="text-subtitle2 text-weight-bold text-grey-8 row items-center">
              <q-icon name="linear_scale" size="20px" class="q-mr-xs text-primary" />
              Shipment Status Workflow
            </div>
            <div class="text-caption text-grey-6">
              Click any state button to change status (backward or forward)
            </div>
          </div>
          <div class="row items-center q-gutter-xs">
            <template
              v-for="(st, idx) in ['processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned']"
              :key="st"
            >
              <q-btn
                :color="order?.status === st ? getStatusColor(st) : isPassedStatus(st) ? 'grey-5' : 'grey-3'"
                :text-color="order?.status === st ? 'white' : isPassedStatus(st) ? 'grey-9' : 'grey-7'"
                :outline="order?.status !== st"
                :unelevated="order?.status === st"
                dense
                no-caps
                class="q-px-md text-caption text-weight-bold"
                :loading="updatingStatus && targetUpdatingStatus === st"
                @click="onUpdateStatus(st)"
              >
                <q-icon
                  v-if="order?.status === st"
                  name="check_circle"
                  size="14px"
                  class="q-mr-xs"
                />
                {{ st.toUpperCase().replace(/_/g, ' ') }}
              </q-btn>
              <q-icon
                v-if="idx < 4"
                name="chevron_right"
                color="grey-5"
                size="18px"
              />
            </template>
          </div>
        </q-card>

        <div class="row q-col-gutter-lg">
          <!-- Main Form Sections -->
          <div class="col-xs-12 col-md-8">
            <div class="q-gutter-y-md">
              <!-- Block A: Courier-Ready Recipient (Editable) -->
              <q-card flat bordered class="form-card">
                <q-card-section class="border-bottom row items-center justify-between">
                  <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                    <q-icon name="person" size="18px" class="q-mr-xs text-primary" />
                    Block A: Recipient Delivery Information
                  </div>
                  <div class="row items-center q-gutter-x-sm">
                    <q-chip dense color="blue-1" text-color="primary" size="sm">Editable at Desk</q-chip>
                  </div>
                </q-card-section>
                <q-card-section>
                  <div class="row q-col-gutter-md">
                    <div class="col-12 col-sm-6">
                      <q-input v-model="form.recipient_name" label="Recipient Name *" outlined dense hide-bottom-space />
                    </div>
                    <div class="col-12 col-sm-6">
                      <q-input
                        v-model="form.recipient_phone"
                        label="Recipient Phone *"
                        outlined
                        dense
                        hide-bottom-space
                        @blur="onRecipientPhoneBlur"
                      />
                    </div>
                    <div class="col-12 col-sm-6">
                      <q-input v-model="form.secondary_phone" label="Secondary Phone" outlined dense hide-bottom-space />
                    </div>
                    <div class="col-12 col-sm-6">
                      <q-select
                        v-model="form.district"
                        outlined
                        dense
                        use-input
                        fill-input
                        hide-selected
                        input-debounce="0"
                        label="District *"
                        :options="districtOptions"
                        option-label="name"
                        option-value="name"
                        emit-value
                        map-options
                        hide-bottom-space
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
                              <q-item-label v-if="scope.opt.bnName" caption>{{ scope.opt.bnName }}</q-item-label>
                            </q-item-section>
                          </q-item>
                        </template>
                      </q-select>
                    </div>
                    <div class="col-12 col-sm-6">
                      <q-select
                        v-model="form.thana"
                        outlined
                        dense
                        use-input
                        fill-input
                        hide-selected
                        input-debounce="0"
                        label="Thana / Upazila *"
                        :options="thanaOptions"
                        option-label="name"
                        option-value="name"
                        emit-value
                        map-options
                        hide-bottom-space
                        @filter="filterThana"
                        @update:model-value="onThanaChange"
                      >
                        <template #no-option>
                          <q-item>
                            <q-item-section class="text-grey">No matching thana/upazila</q-item-section>
                          </q-item>
                        </template>
                        <template #option="scope">
                          <q-item v-bind="scope.itemProps">
                            <q-item-section>
                              <q-item-label>{{ scope.opt.name }}</q-item-label>
                              <q-item-label v-if="scope.opt.bnName" caption>{{ scope.opt.bnName }}</q-item-label>
                            </q-item-section>
                          </q-item>
                        </template>
                      </q-select>
                    </div>
                    <div class="col-12 col-sm-6">
                      <q-select
                        v-model="form.post_code"
                        outlined
                        dense
                        use-input
                        fill-input
                        hide-selected
                        input-debounce="0"
                        label="Post Code / Post Office"
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
                            <q-item-section class="text-grey">Type custom post code or office</q-item-section>
                          </q-item>
                        </template>
                        <template #option="scope">
                          <q-item v-bind="scope.itemProps">
                            <q-item-section>
                              <q-item-label>{{ scope.opt.postOffice }} - {{ scope.opt.postCode }}</q-item-label>
                            </q-item-section>
                          </q-item>
                        </template>
                      </q-select>
                    </div>
                    <div class="col-12">
                      <q-input v-model="form.shipping_address" label="Shipping Address *" outlined dense hide-bottom-space type="textarea" rows="2" />
                    </div>
                  </div>
                </q-card-section>
              </q-card>

              <!-- Block B: Parcel & COD Details -->
              <q-card flat bordered class="form-card">
                <q-card-section class="border-bottom row items-center justify-between">
                  <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                    <q-icon name="inventory_2" size="18px" class="q-mr-xs text-primary" />
                    Block B: Parcel Weight &amp; COD Collection
                  </div>
                </q-card-section>
                <q-card-section>
                  <div class="row q-col-gutter-md">
                    <div class="col-12 col-sm-3">
                      <q-input
                        v-model.number="form.delivery_charge"
                        type="number"
                        label="Delivery Charge (BDT)"
                        outlined
                        dense
                        hide-bottom-space
                        @update:model-value="onDeliveryChargeManualEdit"
                      />
                    </div>
                    <div class="col-12 col-sm-3">
                      <q-select
                        v-model="form.package_weight_band"
                        :options="['under_1kg', '1_2kg', '2_3kg', 'over_3kg']"
                        label="Parcel Weight Band *"
                        outlined
                        dense
                        hide-bottom-space
                      />
                    </div>
                    <div class="col-12 col-sm-3">
                      <q-input
                        v-model.number="form.cod_fee_percent"
                        type="number"
                        label="COD Fee (%)"
                        outlined
                        dense
                        hide-bottom-space
                        :readonly="selectedCourier?.cod_fee_mode !== 'percent_of_collect'"
                        @update:model-value="calculateCodCharge"
                      />
                    </div>
                    <div class="col-12 col-sm-3">
                      <q-input
                        v-model.number="form.cod_charge"
                        type="number"
                        label="Courier COD Fee (BDT)"
                        outlined
                        dense
                        hide-bottom-space
                        hint="Editable; included in collect when not deducted from margin"
                        @update:model-value="recalculateCollectAmount"
                      />
                    </div>
                  </div>
                </q-card-section>
              </q-card>

              <!-- Block C: Merchant Sender Pickup Defaults -->
              <q-card flat bordered class="form-card">
                <q-card-section class="border-bottom row items-center justify-between">
                  <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                    <q-icon name="storefront" size="18px" class="q-mr-xs text-primary" />
                    Block C: Merchant Sender Pickup Info
                  </div>
                </q-card-section>
                <q-card-section>
                  <div class="row q-col-gutter-md">
                    <div class="col-12">
                      <q-select
                        v-model="selectedMerchantId"
                        :options="merchantOptions"
                        emit-value
                        map-options
                        clearable
                        label="Select Merchant Profile *"
                        outlined
                        dense
                        hide-bottom-space
                        @update:model-value="onMerchantSelect"
                      />
                    </div>
                    <div class="col-12 col-sm-6">
                      <q-input v-model="form.sender_name" label="Sender Name *" outlined dense hide-bottom-space />
                    </div>
                    <div class="col-12 col-sm-6">
                      <q-input v-model="form.pickup_phone" label="Sender Pickup Phone *" outlined dense hide-bottom-space />
                    </div>
                    <div class="col-12">
                      <q-input v-model="form.pickup_address" label="Sender Pickup Address *" outlined dense hide-bottom-space type="textarea" rows="2" />
                    </div>
                  </div>
                </q-card-section>
              </q-card>

              <!-- Block D: Delivery & Driver Notes -->
              <q-card flat bordered class="form-card">
                <q-card-section class="border-bottom row items-center justify-between">
                  <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                    <q-icon name="note" size="18px" class="q-mr-xs text-primary" />
                    Block D: Driver Notes &amp; Policy Flags
                  </div>
                </q-card-section>
                <q-card-section>
                  <div class="row q-col-gutter-md">
                    <div class="col-12">
                      <q-toggle v-model="form.allow_open_box" label="Allow Open-Box Inspection by Recipient" color="primary" />
                    </div>
                    <div class="col-12">
                      <q-input v-model="form.delivery_instruction_notes" label="Driver / Special Instructions" outlined dense hide-bottom-space type="textarea" rows="2" />
                    </div>
                  </div>
                </q-card-section>
              </q-card>
            </div>
          </div>

          <!-- Right Side: Block E Courier Tracking & Actions -->
          <div class="col-xs-12 col-md-4">
            <div class="q-gutter-y-md">
              <q-card flat bordered class="form-card">
                <q-card-section class="border-bottom row items-center justify-between">
                  <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                    <q-icon name="local_shipping" size="18px" class="q-mr-xs text-primary" />
                    Block E: Courier &amp; Tracking Assignment
                  </div>
                </q-card-section>
                <q-card-section>
                  <div class="row q-col-gutter-md">
                    <div class="col-12">
                      <q-select
                        v-model="form.courier_service_id"
                        :options="courierOptions"
                        emit-value
                        map-options
                        label="Select Courier Partner *"
                        outlined
                        dense
                        hide-bottom-space
                        @update:model-value="onCourierChange"
                      />
                    </div>
                    <div class="col-12">
                      <q-input v-model="form.courier_awb_number" label="Consignment / AWB Number" outlined dense hide-bottom-space />
                    </div>
                    <div class="col-12">
                      <q-input v-model="form.tracking_url" label="Courier Tracking URL" outlined dense hide-bottom-space />
                    </div>

                    <!-- Return Policy Chip Summary -->
                    <div v-if="selectedCourier" class="col-12">
                      <div class="q-pa-sm bg-blue-50 rounded-borders text-caption text-grey-8" style="border: 1px solid #d0e7ff">
                        <div class="text-weight-bold text-primary q-mb-xs">Selected Courier: {{ selectedCourier.name }}</div>
                        <div>Zone: {{ deliveryZoneLabel }} | Delivery: {{ formatBdt(suggestedDeliveryFee) }}</div>
                        <div>COD Rate: {{ codRateLabel }} | Suggested COD Fee: {{ formatBdt(form.cod_charge) }}</div>
                        <div>Inside Dhaka Return: {{ selectedCourier.inside_dhaka_return_fee }} BDT | Outside: {{ selectedCourier.outside_dhaka_return_fee }} BDT</div>
                        <div>Max Attempts: {{ selectedCourier.delivery_attempt_count }} | Open Box: {{ form.allow_open_box ? 'Yes' : 'No' }}</div>
                      </div>
                    </div>
                  </div>
                </q-card-section>
              </q-card>

              <q-card flat bordered class="form-card">
                <q-card-section class="border-bottom">
                  <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                    <q-icon name="account_balance_wallet" size="18px" class="q-mr-xs text-primary" />
                    Totals &amp; Profit Breakdown
                  </div>
                </q-card-section>
                <q-card-section class="q-gutter-y-xs text-body2">
                  <div class="row justify-between text-grey-7 q-py-xs">
                    <span>Face Items Subtotal</span>
                    <span>{{ formatBdt(recipientSubtotal) }}</span>
                  </div>

                  <div v-if="deliveryChargeVal > 0" class="q-py-xs" style="border-bottom: 1px dashed #e0e0e0">
                    <div class="row justify-between text-grey-7 items-center">
                      <span>Delivery Charge</span>
                      <span>{{ formatBdt(deliveryChargeVal) }}</span>
                    </div>
                    <div class="row justify-end q-mt-xs">
                      <q-toggle
                        v-model="form.deduct_delivery_from_margin"
                        label="Deduct from Profit"
                        dense
                        size="xs"
                        class="text-caption text-grey-6"
                        @update:model-value="onToggleDeduct"
                      />
                    </div>
                  </div>

                  <div v-if="codChargeVal > 0" class="q-py-xs" style="border-bottom: 1px dashed #e0e0e0">
                    <div class="row justify-between text-grey-7 items-center">
                      <span>COD Fee</span>
                      <span>{{ formatBdt(codChargeVal) }}</span>
                    </div>
                    <div class="row justify-end q-mt-xs">
                      <q-toggle
                        v-model="form.deduct_cod_from_margin"
                        label="Deduct from Profit"
                        dense
                        size="xs"
                        class="text-caption text-grey-6"
                        @update:model-value="onToggleDeduct"
                      />
                    </div>
                  </div>

                  <div v-if="printChargeVal > 0" class="q-py-xs" style="border-bottom: 1px dashed #e0e0e0">
                    <div class="row justify-between text-grey-7 items-center">
                      <span>Print Charge</span>
                      <span>{{ formatBdt(printChargeVal) }}</span>
                    </div>
                    <div class="row justify-end q-mt-xs">
                      <q-toggle
                        v-model="form.deduct_print_from_margin"
                        label="Deduct from Profit"
                        dense
                        size="xs"
                        class="text-caption text-grey-6"
                        @update:model-value="onToggleDeduct"
                      />
                    </div>
                  </div>

                  <div v-if="packingChargeVal > 0" class="q-py-xs" style="border-bottom: 1px dashed #e0e0e0">
                    <div class="row justify-between text-grey-7 items-center">
                      <span>Packing Charge</span>
                      <span>{{ formatBdt(packingChargeVal) }}</span>
                    </div>
                    <div class="row justify-end q-mt-xs">
                      <q-toggle
                        v-model="form.deduct_packing_from_margin"
                        label="Deduct from Profit"
                        dense
                        size="xs"
                        class="text-caption text-grey-6"
                        @update:model-value="onToggleDeduct"
                      />
                    </div>
                  </div>

                  <div v-if="discountVal > 0" class="row justify-between text-negative q-py-xs">
                    <span>Discount</span>
                    <span>-{{ formatBdt(discountVal) }}</span>
                  </div>
                  <q-separator class="q-my-sm" />
                  <div class="row justify-between items-baseline">
                    <span class="text-subtitle2 text-weight-bold text-grey-9">Recipient Pay Total</span>
                    <span class="text-h6 text-weight-bold text-primary">{{ formatBdt(recipientGrandTotal) }}</span>
                  </div>
                  <div class="row justify-between text-caption text-grey-6">
                    <span>Middle-Man Cost</span>
                    <span>{{ formatBdt(middlemanTotalCost) }}</span>
                  </div>
                  <div class="row justify-between text-body2 text-weight-bold" :class="estimatedProfit >= 0 ? 'text-positive' : 'text-negative'">
                    <span>Estimated Profit</span>
                    <span>{{ formatBdt(estimatedProfit) }}</span>
                  </div>
                  <q-btn
                    v-if="order"
                    outline
                    color="primary"
                    icon="open_in_new"
                    label="View Order"
                    no-caps
                    class="full-width q-mt-md"
                    :to="{ name: 'app-shop-order-detail-page', params: { tenantSlug: route.params.tenantSlug, id: order.id } }"
                  />
                </q-card-section>
              </q-card>
            </div>
          </div>
        </div>
      </template>

      <!-- Create Dual Invoice Dialog Handoff -->
      <q-dialog v-model="dualInvoiceDialogOpen">
        <q-card style="min-width: 440px; border-radius: 12px">
          <q-card-section class="row items-center justify-between">
            <div class="text-h6 text-weight-bold">Create Dual Invoice</div>
            <q-btn flat round dense icon="close" v-close-popup />
          </q-card-section>
          <q-card-section class="q-gutter-sm text-body2 text-grey-8">
            <p>Generate dual invoices for order <strong>{{ order?.order_no }}</strong>:</p>
            <div class="q-pa-sm bg-grey-2 rounded-borders">
              <div>1. <strong>Accounting Invoice</strong> (Merchant Cost + Margin Split)</div>
              <div>2. <strong>Recipient Invoice</strong> (Customer Face Prices: {{ form.cod_collect_amount }} BDT)</div>
            </div>
            <p class="q-mt-sm text-caption text-grey-6">
              Posting dual invoice will commit books and stamp global_invoice_id on order.
            </p>
          </q-card-section>
          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn color="positive" label="Post Dual Invoice" :loading="creatingInvoice" @click="confirmDualInvoice" />
          </q-card-actions>
        </q-card>
      </q-dialog>
      <!-- Spacer to prevent content blocking by the floating footer -->
      <div v-if="isFormDirty && !loading" style="height: 100px;"></div>

      <!-- Floating Unsaved Changes Footer Bar -->
      <q-slide-transition>
        <div v-if="isFormDirty && !loading" class="fixed-bottom row justify-center q-pb-lg z-top">
          <q-card flat class="bg-grey-10 text-white shadow-24 row items-center justify-between q-py-md q-px-lg" style="width: 90%; max-width: 800px; border-radius: 12px; border-left: 5px solid var(--q-warning); box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4), 0 0 16px rgba(242, 193, 46, 0.25);">
            <div class="row items-center q-gutter-x-md">
              <q-icon name="warning" color="warning" size="32px" class="animate-flash" />
              <div>
                <div class="text-subtitle1 text-weight-bold text-white row items-center">
                  Unsaved Changes in Consignment
                </div>
                <div class="text-caption text-grey-4">You have modified details on this page. Click Save to persist updates.</div>
              </div>
            </div>
            <div class="row q-gutter-sm items-center">
              <q-btn
                flat
                color="white"
                label="Discard"
                no-caps
                @click="discardChanges"
              />
              <q-btn
                color="warning"
                text-color="dark"
                unelevated
                label="Save Changes"
                no-caps
                icon="save"
                :loading="saving"
                class="text-weight-bold"
                @click="saveChanges"
              />
            </div>
          </q-card>
        </div>
      </q-slide-transition>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { dropshipCourierService } from '../services/dropshipCourierService';
import { dropshipMerchantService } from '../services/dropshipMerchantService';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import type { MerchantProfileRow } from '../repositories/dropshipMerchantRepository';
import type { ShopOrder, ShopOrderItem } from '../types';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import { useRecipientProfileStore } from 'src/modules/sales_invoice/stores/recipientProfileStore';
import {
  resolveDeliveryZone,
  suggestDeliveryFee,
  type DeliveryZone,
} from '../services/courierChargeEstimate';

import { useShopOrderStore } from '../stores/shopOrderStore';
import {
  getBDDistricts,
  getBDUpazilas,
  getBDPostcodes,
  type BDLocationOption,
  type BDPostcodeOption,
} from 'src/utils/bdAddressService';

const route = useRoute();
const orderStore = useShopOrderStore();
const recipientProfileStore = useRecipientProfileStore();
const lastLookupPhone = ref('');

const loading = ref(false);
const saving = ref(false);
const handingOff = ref(false);
const updatingStatus = ref(false);
const order = ref<ShopOrder | null>(null);
const orderItems = ref<ShopOrderItem[]>([]);
const couriers = ref<CourierServiceRow[]>([]);
const merchants = ref<MerchantProfileRow[]>([]);
const selectedMerchantId = ref<string | null>(null);
const dualInvoiceDialogOpen = ref(false);

// District, Thana/Upazila & Postcode Options
const rawDistricts = ref<BDLocationOption[]>([]);
const rawThanas = ref<BDLocationOption[]>([]);
const rawPostcodes = ref<(BDPostcodeOption & { displayLabel: string })[]>([]);
const districtOptions = ref<BDLocationOption[]>([]);
const thanaOptions = ref<BDLocationOption[]>([]);
const postcodeOptions = ref<(BDPostcodeOption & { displayLabel: string })[]>([]);

const performHandoff = async () => {
  if (!order.value) return;
  handingOff.value = true;
  try {
    const res = await orderStore.processDropshipOrder(order.value.id);
    if (res.success) {
      await loadData();
    }
  } finally {
    handingOff.value = false;
  }
};

const originalBlockB = reactive({
  delivery_charge: 0,
  package_weight_band: 'under_1kg',
  cod_fee_percent: 0,
  cod_charge: 0,
});
const isBlockBDirty = computed(() => {
  return form.delivery_charge !== originalBlockB.delivery_charge ||
         form.package_weight_band !== originalBlockB.package_weight_band ||
         form.cod_fee_percent !== originalBlockB.cod_fee_percent ||
         form.cod_charge !== originalBlockB.cod_charge;
});

// Block A: Recipient
const originalBlockA = reactive({
  recipient_name: '',
  recipient_phone: '',
  secondary_phone: '',
  district: '',
  thana: '',
  post_code: '',
  shipping_address: '',
});
const isBlockADirty = computed(() => {
  return form.recipient_name !== originalBlockA.recipient_name ||
         form.recipient_phone !== originalBlockA.recipient_phone ||
         form.secondary_phone !== originalBlockA.secondary_phone ||
         form.district !== originalBlockA.district ||
         form.thana !== originalBlockA.thana ||
         form.post_code !== originalBlockA.post_code ||
         form.shipping_address !== originalBlockA.shipping_address;
});

// Block C: Merchant Sender
const originalBlockC = reactive({
  sender_name: '',
  pickup_phone: '',
  pickup_address: '',
  merchant_id: null as string | null,
});
const isBlockCDirty = computed(() => {
  return form.sender_name !== originalBlockC.sender_name ||
         form.pickup_phone !== originalBlockC.pickup_phone ||
         form.pickup_address !== originalBlockC.pickup_address ||
         selectedMerchantId.value !== originalBlockC.merchant_id;
});

// Block D: Notes & Flags
const originalBlockD = reactive({
  allow_open_box: false,
  delivery_instruction_notes: '',
});
const isBlockDDirty = computed(() => {
  return form.allow_open_box !== originalBlockD.allow_open_box ||
         form.delivery_instruction_notes !== originalBlockD.delivery_instruction_notes;
});

// Block E: Courier Assignment
const originalBlockE = reactive({
  courier_service_id: null as string | null,
  courier_awb_number: '',
  tracking_url: '',
});
const isBlockEDirty = computed(() => {
  return form.courier_service_id !== originalBlockE.courier_service_id ||
         form.courier_awb_number !== originalBlockE.courier_awb_number ||
         form.tracking_url !== originalBlockE.tracking_url;
});

// Central save/dirty checks
const isFormDirty = computed(() => {
  return isBlockADirty.value ||
         isBlockBDirty.value ||
         isBlockCDirty.value ||
         isBlockDDirty.value ||
         isBlockEDirty.value;
});

const discardChanges = () => {
  form.recipient_name = originalBlockA.recipient_name;
  form.recipient_phone = originalBlockA.recipient_phone;
  form.secondary_phone = originalBlockA.secondary_phone;
  form.district = originalBlockA.district;
  form.thana = originalBlockA.thana;
  form.post_code = originalBlockA.post_code;
  form.shipping_address = originalBlockA.shipping_address;

  form.delivery_charge = originalBlockB.delivery_charge;
  form.package_weight_band = originalBlockB.package_weight_band;
  form.cod_fee_percent = originalBlockB.cod_fee_percent;
  form.cod_charge = originalBlockB.cod_charge;

  selectedMerchantId.value = originalBlockC.merchant_id;
  form.sender_name = originalBlockC.sender_name;
  form.pickup_phone = originalBlockC.pickup_phone;
  form.pickup_address = originalBlockC.pickup_address;

  form.allow_open_box = originalBlockD.allow_open_box;
  form.delivery_instruction_notes = originalBlockD.delivery_instruction_notes;

  form.courier_service_id = originalBlockE.courier_service_id;
  form.courier_awb_number = originalBlockE.courier_awb_number;
  form.tracking_url = originalBlockE.tracking_url;
};


const form = reactive({
  recipient_name: '',
  recipient_phone: '',
  secondary_phone: '',
  district: 'Dhaka',
  thana: '',
  post_code: '',
  shipping_address: '',
  cod_collect_amount: 0,
  delivery_charge: 0,
  cod_charge: 0,
  cod_fee_percent: 0,
  package_weight_band: 'under_1kg',
  sender_name: '',
  pickup_phone: '',
  pickup_address: '',
  allow_open_box: false,
  delivery_instruction_notes: '',
  courier_service_id: null as string | null,
  courier_awb_number: '',
  tracking_url: '',
  deduct_delivery_from_margin: false,
  deduct_cod_from_margin: false,
  deduct_print_from_margin: false,
  deduct_packing_from_margin: false,
});

const updateThanaList = async (distName: string) => {
  if (!distName) {
    rawThanas.value = await getBDUpazilas();
  } else {
    rawThanas.value = await getBDUpazilas(distName);
  }
  thanaOptions.value = rawThanas.value;
  await updatePostcodeList(distName, form.thana);
};

const updatePostcodeList = async (distName: string, thanaName: string) => {
  if (!distName) {
    rawPostcodes.value = [];
    postcodeOptions.value = [];
    return;
  }
  const fetched = await getBDPostcodes(distName, thanaName);
  const mapped = fetched.map((p) => ({
    ...p,
    displayLabel: `${p.postOffice} - ${p.postCode}`,
  }));

  // If there's a current form.post_code, make sure it is represented in the options so it displays correctly
  if (form.post_code && !mapped.some((m) => m.postCode === form.post_code)) {
    mapped.push({
      id: 0,
      districtId: 0,
      postOffice: form.post_code,
      postCode: form.post_code,
      displayLabel: form.post_code,
    });
  }

  rawPostcodes.value = mapped;
  postcodeOptions.value = mapped;
};

const filterDistrict = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    if (!needle) {
      districtOptions.value = rawDistricts.value;
    } else {
      districtOptions.value = rawDistricts.value.filter(
        (d) =>
          d.name.toLowerCase().includes(needle) ||
          d.bnName.toLowerCase().includes(needle)
      );
    }
  });
};

const filterThana = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    if (!needle) {
      thanaOptions.value = rawThanas.value;
    } else {
      thanaOptions.value = rawThanas.value.filter(
        (t) =>
          t.name.toLowerCase().includes(needle) ||
          t.bnName.toLowerCase().includes(needle)
      );
    }
  });
};

const filterPostcode = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    const needle = val.toLowerCase().trim();
    if (!needle) {
      postcodeOptions.value = rawPostcodes.value;
    } else {
      postcodeOptions.value = rawPostcodes.value.filter(
        (p) =>
          p.postCode.toLowerCase().includes(needle) ||
          p.postOffice.toLowerCase().includes(needle)
      );
    }
  });
};

const createPostcode = (val: string, done: (item: any) => void) => {
  const custom = {
    id: 0,
    districtId: 0,
    postOffice: val,
    postCode: val,
    displayLabel: val,
  };
  done(custom);
};

const onDistrictChange = async (newDistName: string) => {
  form.thana = '';
  form.post_code = '';
  await updateThanaList(newDistName);
  applySuggestedCharges();
};

const onCourierChange = () => {
  applySuggestedCharges();
};

const deliveryZone = computed<DeliveryZone>(() => resolveDeliveryZone(form.district));

const deliveryZoneLabel = computed(() =>
  deliveryZone.value === 'inside_dhaka' ? 'Inside Dhaka' : 'Outside Dhaka',
);

const selectedCourier = computed(() =>
  couriers.value.find((c) => c.id === form.courier_service_id),
);

const suggestedDeliveryFee = computed(() => {
  if (!selectedCourier.value) return 0;
  return suggestDeliveryFee(selectedCourier.value, deliveryZone.value);
});

const codRateLabel = computed(() => {
  const courier = selectedCourier.value;
  if (!courier) return '—';
  if (courier.cod_fee_mode === 'percent_of_collect') return `${courier.cod_fee_percent}% of collect`;
  if (courier.cod_fee_mode === 'flat') return `${courier.cod_fee_flat_amount} BDT flat`;
  if (courier.cod_fee_mode === 'tiered_manual') return 'Tiered / manual';
  return 'None';
});

const formatBdt = (amount: number) => `${Number(amount || 0).toFixed(2)} BDT`;

const recipientSubtotal = computed(() =>
  orderItems.value.reduce(
    (sum, item) => sum + (item.customer_sell_price_amount ?? 0) * item.quantity,
    0,
  ),
);

const accountingSubtotal = computed(() =>
  orderItems.value.reduce((sum, item) => {
    const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
    return sum + price * item.quantity;
  }, 0),
);

const deliveryChargeVal = computed(() => Number(form.delivery_charge || 0));
const codChargeVal = computed(() => Number(form.cod_charge || 0));
const printChargeVal = computed(() => Number(order.value?.print_charge_amount || 0));
const packingChargeVal = computed(() => Number(order.value?.packing_charge_amount || 0));
const discountVal = computed(() => Number(order.value?.discount_amount || 0));

const deductCodFromMargin = computed(() => !!form.deduct_cod_from_margin);
const deductDeliveryFromMargin = computed(() => !!form.deduct_delivery_from_margin);
const deductPrintFromMargin = computed(() => !!form.deduct_print_from_margin);
const deductPackingFromMargin = computed(() => !!form.deduct_packing_from_margin);

const recipientGrandTotal = computed(() =>
  recipientSubtotal.value
    + (deductDeliveryFromMargin.value ? 0 : deliveryChargeVal.value)
    + (deductPrintFromMargin.value ? 0 : printChargeVal.value)
    + (deductPackingFromMargin.value ? 0 : packingChargeVal.value)
    + (deductCodFromMargin.value ? 0 : codChargeVal.value)
    - discountVal.value,
);

const middlemanTotalCost = computed(() =>
  accountingSubtotal.value
    + deliveryChargeVal.value
    + printChargeVal.value
    + packingChargeVal.value
    + (deductCodFromMargin.value ? codChargeVal.value : 0),
);

const estimatedProfit = computed(() => recipientGrandTotal.value - middlemanTotalCost.value);

const recalculateCollectAmount = () => {
  form.cod_collect_amount = recipientSubtotal.value
    + (deductDeliveryFromMargin.value ? 0 : form.delivery_charge)
    + (deductPrintFromMargin.value ? 0 : printChargeVal.value)
    + (deductPackingFromMargin.value ? 0 : packingChargeVal.value)
    + (deductCodFromMargin.value ? 0 : form.cod_charge)
    - discountVal.value;
};

const calculateCodCharge = () => {
  if (order.value?.is_prepaid_snapshot) {
    form.cod_charge = 0;
    return;
  }
  const courier = selectedCourier.value;
  if (!courier) return;

  if (courier.cod_fee_mode === 'percent_of_collect') {
    const collectBase = recipientSubtotal.value
      + (deductDeliveryFromMargin.value ? 0 : Number(form.delivery_charge || 0));
    if (collectBase <= 0) {
      form.cod_charge = 0;
    } else {
      form.cod_charge = Math.round(collectBase * Number(form.cod_fee_percent || 0) / 100 * 100) / 100;
    }
  } else if (courier.cod_fee_mode === 'flat') {
    form.cod_charge = Number(courier.cod_fee_flat_amount || 0);
  } else {
    form.cod_charge = 0;
  }

  recalculateCollectAmount();
};

const onToggleDeduct = async () => {
  if (!order.value) return;
  try {
    calculateCodCharge();

    const { error } = await supabase
      .from('shop_orders')
      .update({
        deduct_delivery_from_margin: form.deduct_delivery_from_margin,
        deduct_cod_from_margin: form.deduct_cod_from_margin,
        deduct_print_from_margin: form.deduct_print_from_margin,
        deduct_packing_from_margin: form.deduct_packing_from_margin,
        cod_collect_amount: form.cod_collect_amount,
      })
      .eq('id', order.value.id);

    if (error) throw error;
    showSuccessNotification('Order charge preferences updated');
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to update charge preferences');
  }
};

const applySuggestedCharges = () => {
  const courier = selectedCourier.value;
  if (!courier) return;

  const zone = deliveryZone.value;
  form.delivery_charge = suggestDeliveryFee(courier, zone);
  form.cod_fee_percent = Number(courier.cod_fee_percent || 0);

  calculateCodCharge();
};

const onDeliveryChargeManualEdit = () => {
  calculateCodCharge();
};

const onThanaChange = async (newThanaName: string) => {
  form.post_code = '';
  await updatePostcodeList(form.district, newThanaName);
};

const courierOptions = computed(() =>
  couriers.value.map((c) => ({ label: c.name, value: c.id }))
);

const merchantOptions = computed(() =>
  merchants.value.map((m) => ({
    label: `${m.merchant_name}${m.store_name ? ' (' + m.store_name + ')' : ''} - ${m.phone_primary}`,
    value: m.id,
  }))
);

const onMerchantSelect = (merchantId: string | null) => {
  if (!merchantId) return;
  const merchant = merchants.value.find((m) => m.id === merchantId);
  if (merchant) {
    form.sender_name = merchant.merchant_name;
    form.pickup_phone = merchant.phone_primary;
    form.pickup_address = merchant.pickup_address;
  }
};

const loadData = async () => {
  const id = Number(route.params.id);
  if (!id) return;

  loading.value = true;
  try {
    const [orderRes, courierRes, merchantRes] = await Promise.all([
      shopOrderRepository.getShopOrderById(id),
      dropshipCourierService.fetchCouriers(),
      dropshipMerchantService.fetchMerchants(),
    ]);

    order.value = orderRes.order;
    orderItems.value = orderRes.items;
    if (courierRes.success) {
      couriers.value = courierRes.data;
    }
    if (merchantRes.success) {
      merchants.value = merchantRes.data;
    }

    const o = orderRes.order as any;
    form.recipient_name = o.recipient_name || '';
    form.recipient_phone = o.recipient_phone || '';
    form.secondary_phone = o.recipient_phone_secondary || '';
    form.district = o.shipping_district || 'Dhaka';
    form.thana = o.shipping_thana || '';

    // Extract postcode and clean address line
    let baseAddress = o.shipping_address || '';
    let extractedPostcode = '';
    const pcMatch = baseAddress.match(/Post\s*Code:\s*([^\n,]+)/i);
    if (pcMatch) {
      extractedPostcode = pcMatch[1].trim();
    }
    baseAddress = baseAddress.replace(/\n?(?:Thana|District|Post\s*Code):.*$/gi, '').trim();

    form.post_code = o.shipping_post_code || o.post_code || extractedPostcode || '';
    form.shipping_address = baseAddress;

    form.cod_collect_amount = o.cod_collect_amount ?? o.total_amount ?? 0;
    form.delivery_charge = o.delivery_charge_amount ?? o.courier_cost_amount ?? 0;
    form.cod_charge = o.cod_charge_amount ?? 0;
    form.package_weight_band = o.package_weight_band || 'under_1kg';

    const activeCourier = courierRes.success ? courierRes.data.find((c: any) => c.id === o.courier_service_id) : null;
    form.cod_fee_percent = activeCourier ? Number(activeCourier.cod_fee_percent || 0) : 0;

    form.deduct_delivery_from_margin = !!o.deduct_delivery_from_margin;
    form.deduct_cod_from_margin = o.deduct_cod_from_margin !== undefined ? !!o.deduct_cod_from_margin : !!activeCourier?.deduct_cod_from_margin_default;
    form.deduct_print_from_margin = !!o.deduct_print_from_margin;
    form.deduct_packing_from_margin = !!o.deduct_packing_from_margin;

    originalBlockB.delivery_charge = form.delivery_charge;
    originalBlockB.package_weight_band = form.package_weight_band;
    originalBlockB.cod_fee_percent = form.cod_fee_percent;
    originalBlockB.cod_charge = form.cod_charge;
    form.sender_name = o.sender_name || o.default_sender_name || '';
    form.pickup_phone = o.pickup_phone || o.default_pickup_phone || '';
    form.pickup_address = o.pickup_address || o.default_pickup_address || '';
    form.allow_open_box = !!o.allow_open_box;
    form.delivery_instruction_notes = o.delivery_instruction_notes || o.driver_notes || '';
    form.courier_service_id = o.courier_service_id || null;
    form.courier_awb_number = o.courier_awb_number || '';
    form.tracking_url = o.tracking_url || '';

    // Load BD location data for dropdowns
    rawDistricts.value = await getBDDistricts();
    districtOptions.value = rawDistricts.value;
    await updateThanaList(form.district);
    await updatePostcodeList(form.district, form.thana);

    // Auto-match merchant if sender details match an existing merchant profile
    const matchedMerchant = merchants.value.find(
      (m) => m.merchant_name === form.sender_name || m.phone_primary === form.pickup_phone
    );
    if (matchedMerchant) {
      selectedMerchantId.value = matchedMerchant.id;
    }

    // Populate original state references for block dirty checking
    originalBlockA.recipient_name = form.recipient_name;
    originalBlockA.recipient_phone = form.recipient_phone;
    originalBlockA.secondary_phone = form.secondary_phone;
    originalBlockA.district = form.district;
    originalBlockA.thana = form.thana;
    originalBlockA.post_code = form.post_code;
    originalBlockA.shipping_address = form.shipping_address;

    originalBlockC.sender_name = form.sender_name;
    originalBlockC.pickup_phone = form.pickup_phone;
    originalBlockC.pickup_address = form.pickup_address;
    originalBlockC.merchant_id = selectedMerchantId.value;

    originalBlockD.allow_open_box = form.allow_open_box;
    originalBlockD.delivery_instruction_notes = form.delivery_instruction_notes;

    originalBlockE.courier_service_id = form.courier_service_id;
    originalBlockE.courier_awb_number = form.courier_awb_number;
    originalBlockE.tracking_url = form.tracking_url;
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to load order details');
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  void loadData();
});

const onRecipientPhoneBlur = async () => {
  const phone = form.recipient_phone.replace(/\D/g, '');
  const tenantId = order.value?.tenant_id;
  if (!tenantId || !/^01\d{9}$/.test(phone)) return;
  if (phone === lastLookupPhone.value) return;
  lastLookupPhone.value = phone;

  const profile = await recipientProfileStore.getByPhone(tenantId, phone);
  if (!profile) return;

  if (!form.recipient_name.trim()) form.recipient_name = profile.name || '';
  if (!form.secondary_phone.trim() && profile.secondary_phone) {
    form.secondary_phone = profile.secondary_phone;
  }

  let baseAddress = profile.address || '';
  let extractedPostcode = '';
  const pcMatch = baseAddress.match(/Post\s*Code:\s*([^\n,]+)/i);
  if (pcMatch) {
    extractedPostcode = pcMatch[1]?.trim() || '';
  }
  baseAddress = baseAddress.replace(/\n?(?:Thana|District|Post\s*Code):.*$/gi, '').trim();

  if (!form.shipping_address.trim() && baseAddress) {
    form.shipping_address = baseAddress;
  }
  if (profile.district) {
    form.district = profile.district;
    await updateThanaList(profile.district);
  }
  if (profile.thana) {
    form.thana = profile.thana;
    await updatePostcodeList(form.district, profile.thana);
  }
  if (extractedPostcode) {
    form.post_code = extractedPostcode;
    await updatePostcodeList(form.district, form.thana);
  }
};

const saveChanges = async () => {
  if (!order.value) return;

  saving.value = true;
  try {
    let finalAddress = form.shipping_address.trim();
    const parts = [
      form.thana ? `Thana: ${form.thana}` : '',
      form.district ? `District: ${form.district}` : '',
      form.post_code ? `Post Code: ${form.post_code}` : '',
    ].filter(Boolean);
    if (parts.length > 0) {
      finalAddress = `${finalAddress}\n${parts.join(', ')}`;
    }

    const { error: dbError } = await supabase.rpc('update_dropship_consignment', {
      p_order_id: order.value.id,
      p_cod_collect_amount: form.cod_collect_amount,
      p_package_weight_band: form.package_weight_band,
      p_item_category: null,
      p_parcel_description: null,
      p_courier_order_ref: order.value.order_no,
      p_delivery_zone: resolveDeliveryZone(form.district),
      p_sender_name: form.sender_name,
      p_pickup_phone: form.pickup_phone,
      p_pickup_address: form.pickup_address,
      p_payout_account_type: 'bank',
      p_payout_account_info: null,
      p_allow_open_box: form.allow_open_box,
      p_delivery_instruction_notes: form.delivery_instruction_notes,
      p_courier_service_id: form.courier_service_id,
      p_courier_tracking_number: form.courier_awb_number,
      p_courier_awb_number: form.courier_awb_number,
      p_courier_consignment_id: null,
      p_tracking_url: form.tracking_url,
      p_courier_cost_amount: form.delivery_charge,
      p_recipient_name: form.recipient_name,
      p_recipient_phone: form.recipient_phone,
      p_recipient_phone_secondary: form.secondary_phone || null,
      p_shipping_address: finalAddress,
      p_shipping_district: form.district || null,
      p_shipping_thana: form.thana || null,
      p_delivery_charge_amount: form.delivery_charge,
      p_cod_charge_amount: form.cod_charge,
    });

    if (dbError) throw dbError;

    // Also update order deduct settings
    const { error: chargesError } = await supabase
      .from('shop_orders')
      .update({
        deduct_delivery_from_margin: form.deduct_delivery_from_margin,
        deduct_cod_from_margin: form.deduct_cod_from_margin,
        deduct_print_from_margin: form.deduct_print_from_margin,
        deduct_packing_from_margin: form.deduct_packing_from_margin,
      })
      .eq('id', order.value.id);
    if (chargesError) throw chargesError;

    showSuccessNotification('Consignment details saved successfully!');
    await loadData();
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to save consignment');
  } finally {
    saving.value = false;
  }
};

const targetUpdatingStatus = ref<string | null>(null);

const statusOrder = ['processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned'];
const isPassedStatus = (st: string) => {
  if (!order.value?.status) return false;
  const currentIdx = statusOrder.indexOf(order.value.status);
  const targetIdx = statusOrder.indexOf(st);
  return targetIdx !== -1 && targetIdx < currentIdx;
};

const onUpdateStatus = async (status: string) => {
  if (!order.value || order.value.status === status) return;

  updatingStatus.value = true;
  targetUpdatingStatus.value = status;
  try {
    let resData: any = null;
    if (status === 'returned') {
      const { data, error } = await supabase.rpc('mark_dropship_order_returned', {
        p_order_id: order.value.id,
        p_actual_return_charge: selectedCourier.value?.inside_dhaka_return_fee ?? 30,
        p_deduct_from_middle_man: true,
        p_reason: 'Refused on delivery',
      });
      if (error) throw error;
      resData = data;
    } else {
      const { data, error } = await supabase.rpc('advance_dropship_order_status', {
        p_order_id: order.value.id,
        p_target_status: status,
      });
      if (error) throw error;
      resData = data;
    }

    if (resData && typeof resData === 'object' && resData.success === false) {
      throw new Error(resData.error || 'Failed to update status');
    }

    showSuccessNotification(`Status updated to ${status.replace(/_/g, ' ')}`);
    await loadData();
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to update status');
  } finally {
    updatingStatus.value = false;
    targetUpdatingStatus.value = null;
  }
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'processing': return 'orange-8';
    case 'ready_for_pickup': return 'blue-7';
    case 'shipped': return 'purple-7';
    case 'delivered': return 'positive';
    case 'returned': return 'negative';
    default: return 'grey';
  }
};

const printPackingSlip = () => {
  window.print();
};

const printLabel = () => {
  window.print();
};

const creatingInvoice = ref(false);

const openDualInvoiceDialog = () => {
  dualInvoiceDialogOpen.value = true;
};

const confirmDualInvoice = async () => {
  if (!order.value) return;

  creatingInvoice.value = true;
  try {
    const { data, error } = await supabase.rpc('create_dual_invoice_from_dropship_order', {
      p_order_id: order.value.id,
      p_invoice_no: null,
      p_billing_profile_id: null,
      p_note: `Dual invoice created from dropship order #${order.value.order_no}`,
    });

    if (error) throw error;

    const res = data as any;
    showSuccessNotification(`Dual invoice #${res.invoice_no || ''} created successfully!`);
    dualInvoiceDialogOpen.value = false;
    await loadData();
  } catch (err: any) {
    showErrorNotification(err.message || 'Failed to create dual invoice');
  } finally {
    creatingInvoice.value = false;
  }
};
</script>

<style scoped>
@keyframes pulse-glow {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.8;
    transform: scale(1.08);
  }
}
.animate-flash {
  animation: pulse-glow 2s infinite ease-in-out;
}
</style>
