<template>
  <q-page class="bw-page">
    <div class="bw-page__stack" v-if="orderStore.loading">
      <div class="column items-center justify-center q-pa-xl">
        <q-spinner color="primary" size="40px" />
        <div class="text-grey-6 q-mt-sm">{{ $t('shop_admin.loading_order_details') }}</div>
      </div>
    </div>

    <div class="bw-page__stack" v-else-if="orderStore.currentOrder">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">{{ $t('shop_admin.staff_order_desk') }}</div>
              <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('shop_admin.order_management') }}</h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Manage and negotiate Order
                <span class="text-weight-bold">{{ orderStore.currentOrder.order_no }}</span>
              </p>
            </div>
          </div>
        </div>
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-chip
            dense
            square
            clickable
            :style="statusChipStyle(orderStore.currentOrder.status)"
            class="q-px-md q-py-sm text-weight-bold q-ma-none text-uppercase text-caption cursor-pointer"
          >
            <span
              class="status-chip-dot"
              :style="{ backgroundColor: statusDotColor(orderStore.currentOrder.status) }"
            />
            {{ orderStore.currentOrder.status }}
            <q-icon name="arrow_drop_down" class="q-ml-xs" size="16px" />
            <q-menu>
              <q-list dense style="min-width: 150px">
                <q-item
                  v-for="st in availableStatuses"
                  :key="st"
                  clickable
                  v-close-popup
                  :active="st === orderStore.currentOrder.status"
                  @click="changeOrderStatus(st)"
                >
                  <q-item-section avatar style="min-width: 20px">
                    <span
                      class="status-chip-dot"
                      :style="{ backgroundColor: statusDotColor(st) }"
                    />
                  </q-item-section>
                  <q-item-section class="text-capitalize text-weight-medium">
                    {{ st }}
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-chip>
        </div>
      </section>

      <!-- Main Columns -->
      <div class="row q-col-gutter-lg">
        <!-- Items & Actions Panel (8 cols) -->
        <div class="col-xs-12 col-md-8">
          <q-card flat bordered class="details-card">
            <q-card-section class="q-px-lg q-py-md border-bottom row items-center justify-between">
              <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.order_lines') }}</div>
              <div
                class="text-caption text-grey-6"
                v-if="orderStore.currentOrder.is_negotiable_snapshot"
              >
                {{ $t('shop_admin.negotiation_round') }} {{ orderStore.currentOrder.negotiate_round }}
              </div>
            </q-card-section>

            <q-list separator>
              <q-item v-for="item in orderItems" :key="item.id" class="q-py-md q-px-lg">
                <q-item-section avatar>
                  <q-avatar size="50px" rounded class="bg-grey-2">
                    <q-img v-if="item.image_url" :src="item.image_url" />
                    <q-icon v-else name="image" size="24px" color="grey-4" />
                  </q-avatar>
                </q-item-section>

                <q-item-section>
                  <div class="text-body1 text-weight-bold text-grey-9">{{ item.name }}</div>
                  <div class="text-caption text-grey-6">{{ $t('shop_admin.quantity') }}: {{ item.quantity }}</div>
                  <div
                    class="text-caption text-amber-9 text-weight-bold"
                    v-if="item.customer_offer_amount"
                  >
                    {{ $t('shop_admin.customer_offer') }} {{ currencySymbol }}{{ Number(item.customer_offer_amount).toFixed(2) }}
                  </div>
                </q-item-section>

                <q-item-section side class="column items-end justify-center">
                  <!-- Pricing display -->
                  <template v-if="orderStore.currentOrder.shop_type_snapshot === 'dropship'">
                    <div class="column text-right q-mb-xs">
                      <span class="text-caption text-grey-6" style="font-size: 10px;">{{ $t('shop_admin.middle_man_cost') }}</span>
                      <span class="text-body2 text-weight-medium text-grey-8">
                        {{ currencySymbol }}{{ (item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0).toFixed(2) }} {{ $t('shop.each') }}
                      </span>
                      <span class="text-caption text-grey-6" style="font-size: 10px;">
                        Total: {{ currencySymbol }}{{ ((item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0) * item.quantity).toFixed(2) }}
                      </span>
                    </div>
                    <div class="column text-right">
                      <span class="text-caption text-grey-6" style="font-size: 10px;">{{ $t('shop_admin.recipient_price') }}</span>
                      <span class="text-body2 text-weight-bold text-primary">
                        {{ currencySymbol }}{{ (item.customer_sell_price_amount ?? 0).toFixed(2) }} {{ $t('shop.each') }}
                      </span>
                      <span class="text-caption text-weight-bold text-primary" style="font-size: 11px;">
                        Total: {{ currencySymbol }}{{ ((item.customer_sell_price_amount ?? 0) * item.quantity).toFixed(2) }}
                      </span>
                    </div>
                  </template>
                  <template v-else>
                    <div class="column text-right">
                      <span class="text-caption text-grey-6">{{ $t('shop_admin.catalog_sell_price') }}</span>
                      <span class="text-body2 text-weight-bold text-grey-8">
                        {{ currencySymbol }}{{
                          (item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0).toFixed(2)
                        }}
                      </span>
                    </div>
                  </template>

                  <!-- Offer editing if in editable negotiation/price status -->
                  <div v-if="canAction" class="q-mt-sm row items-center q-gutter-x-sm">
                    <span class="text-caption text-grey-7">{{ $t('shop_admin.staff_price') }}</span>
                    <q-input
                      v-model.number="item.staff_offer_amount"
                      type="number"
                      outlined
                      dense
                      class="counter-input"
                      :prefix="currencySymbol"
                      style="width: 100px"
                    />
                  </div>
                  <div
                    v-else-if="item.final_price_amount"
                    class="q-mt-xs text-weight-bold text-primary"
                  >
                    {{ $t('shop_admin.final_price') }} {{ currencySymbol }}{{ Number(item.final_price_amount).toFixed(2) }}
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card>

          <!-- Action Buttons Panel -->
          <div class="q-mt-md row items-center justify-between">
            <div>
              <q-btn
                v-if="orderStore.currentOrder.status !== 'fulfilled'"
                outline
                color="negative"
                no-caps
                icon="delete"
                :label="$t('shop_admin.delete_order')"
                class="pill-btn text-weight-bold q-px-lg q-py-sm"
                :loading="orderStore.saving"
                @click="confirmDeleteOrder"
              />
            </div>

            <div class="row q-gutter-md justify-end">
              <div v-if="canAction" class="row q-gutter-md justify-end">
                <q-btn
                  outline
                  color="primary"
                  no-caps
                  :label="$t('shop_admin.save_price_counter')"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="submitStaffPricing"
                />
                <q-btn
                  color="green-7"
                  unelevated
                  no-caps
                  :label="$t('shop_admin.confirm_order')"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="confirmOrder"
                />
              </div>

              <div v-if="canFulfill" class="row q-gutter-md justify-end">
                <q-btn
                  v-if="orderStore.currentOrder.shop_type_snapshot === 'vendor_catalog'"
                  color="indigo-7"
                  unelevated
                  no-caps
                  :label="$t('shop_admin.place_for_procurement')"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="placeForProcurement"
                />
                <q-btn
                  v-else-if="orderStore.currentOrder.shop_type_snapshot === 'dropship'"
                  color="primary"
                  unelevated
                  no-caps
                  icon="local_shipping"
                  :label="$t('shop_admin.add_to_dropship_desk')"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="addToDropshipDesk"
                />
                <q-btn
                  v-else
                  color="teal-7"
                  unelevated
                  no-caps
                  :label="$t('shop_admin.fulfill_to_invoice')"
                  class="pill-btn text-weight-bold q-px-lg q-py-sm"
                  :loading="orderStore.saving"
                  @click="fulfillToInvoice"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Sidebar (4 cols) -->
        <div class="col-xs-12 col-md-4">
          <div class="column q-gutter-md">
            <!-- Summary Card -->
            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.order_context') }}</div>
              </q-card-section>

              <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
                <div class="row justify-between">
                  <span class="text-grey-6">{{ $t('shop_admin.order_no') }}</span>
                  <span class="text-weight-bold text-grey-8">{{
                    orderStore.currentOrder.order_no
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">{{ $t('shop_admin.date') }}</span>
                  <span class="text-grey-8">{{
                    formatDate(orderStore.currentOrder.created_at)
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">{{ $t('shop_admin.shop_type_label') }}</span>
                  <span class="text-grey-8 text-capitalize">{{
                    orderStore.currentOrder.shop_type_snapshot
                  }}</span>
                </div>
                <div class="row justify-between" v-if="orderStore.currentOrder.shop_type_snapshot !== 'dropship'">
                  <span class="text-grey-6">{{ $t('shop_admin.order_mode_label') }}</span>
                  <span class="text-grey-8 text-capitalize">{{
                    orderStore.currentOrder.order_mode_snapshot
                  }}</span>
                </div>
                <div class="row justify-between">
                  <span class="text-grey-6">{{ $t('shop_admin.negotiable') }}</span>
                  <span class="text-grey-8">{{
                    orderStore.currentOrder.is_negotiable_snapshot ? $t('shop_admin.yes') : $t('shop_admin.no')
                  }}</span>
                </div>
                <div class="row justify-between" v-if="orderStore.currentOrder.global_invoice_id">
                  <span class="text-grey-6">Invoice:</span>
                  <router-link
                    :to="{
                      name: 'app-global-invoice-details-page',
                      params: {
                        tenantSlug: route.params.tenantSlug || '',
                        id: orderStore.currentOrder.global_invoice_id,
                      },
                    }"
                    class="text-weight-bold text-primary"
                  >
                    View Invoice
                  </router-link>
                </div>
                <div class="row justify-between" v-if="orderStore.currentOrder.status === 'placed'">
                  <span class="text-grey-6">Procurement:</span>
                  <span class="text-weight-bold text-indigo-7">Placed (Shipment Pull)</span>
                </div>

                <q-separator class="q-my-sm" />

                <!-- Dropship detailed context preview -->
                <template v-if="orderStore.currentOrder.shop_type_snapshot === 'dropship'">
                  <div class="row justify-between text-body2 text-grey-7 q-mb-xs">
                    <span>Seller (Middle-man):</span>
                    <span class="text-weight-bold text-grey-8">{{ orderStore.currentOrder.customer_group_name }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7 q-mb-xs">
                    <span>{{ $t('shop_admin.payment_mode') }}</span>
                    <q-badge
                      :color="orderStore.currentOrder.is_prepaid_snapshot ? 'positive' : 'warning'"
                      text-color="white"
                      class="q-py-xs q-px-sm"
                    >
                      {{
                        orderStore.currentOrder.is_prepaid_snapshot
                          ? $t('shop_admin.payment_prepaid')
                          : $t('shop_admin.payment_cod')
                      }}
                    </q-badge>
                  </div>

                  <q-separator class="q-my-xs" />

                  <div class="row justify-between text-body2 text-grey-7">
                    <span>{{ $t('shop.items_subtotal') }}</span>
                    <span>{{ currencySymbol }}{{ recipientSubtotal.toFixed(2) }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7" v-if="deliveryChargeVal > 0">
                    <span>{{ $t('shop.delivery_charge') }}</span>
                    <span>{{ currencySymbol }}{{ deliveryChargeVal.toFixed(2) }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7" v-if="codChargeVal > 0">
                    <span>{{ $t('shop.cod_fee', { pct: codFeePctLabel }) }}</span>
                    <span>{{ currencySymbol }}{{ codChargeVal.toFixed(2) }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7" v-if="printChargeVal > 0">
                    <span>{{ $t('shop.print_charge') }}</span>
                    <span>{{ currencySymbol }}{{ printChargeVal.toFixed(2) }}</span>
                  </div>
                  
                  <div class="row justify-between text-body2 text-grey-7" v-if="packingChargeVal > 0">
                    <span>{{ $t('shop.packing_charge') }}</span>
                    <span>{{ currencySymbol }}{{ packingChargeVal.toFixed(2) }}</span>
                  </div>

                  <div class="row justify-between text-body2 text-negative" v-if="discountVal > 0">
                    <span>{{ $t('shop_admin.discount') }}</span>
                    <span>-{{ currencySymbol }}{{ discountVal.toFixed(2) }}</span>
                  </div>

                  <q-separator class="q-my-sm" />

                  <div class="row justify-between items-baseline q-mb-xs">
                    <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop.recipient_pay_total') }}</span>
                    <span class="text-h6 text-weight-bold text-primary">
                      {{ currencySymbol }}{{ recipientGrandTotal.toFixed(2) }}
                    </span>
                  </div>

                  <div class="row justify-between text-caption text-grey-6">
                    <span>{{ $t('shop_admin.middle_man_cost') }}</span>
                    <span>{{ currencySymbol }}{{ middlemanTotalCost.toFixed(2) }}</span>
                  </div>

                  <div class="row justify-between text-body2 text-weight-bold text-positive q-mt-xs">
                    <span>Middle-man Payout</span>
                    <span>{{ currencySymbol }}{{ estimatedProfit.toFixed(2) }}</span>
                  </div>

                  <div class="row justify-center q-mt-md" v-if="orderStore.currentOrder.status !== 'fulfilled' && orderStore.currentOrder.status !== 'cancelled'">
                    <q-btn
                      outline
                      color="primary"
                      icon="edit"
                      label="Edit Charges"
                      size="sm"
                      class="full-width pill-btn"
                      @click="openChargesDialog"
                    />
                  </div>
                </template>
                <template v-else>
                  <div class="row justify-between items-baseline">
                    <span class="text-subtitle1 text-weight-bold text-grey-9">Current Value</span>
                    <span class="text-h6 text-weight-bold text-primary">
                      {{ currencySymbol }}{{ orderTotal.toFixed(2) }}
                    </span>
                  </div>
                </template>
              </q-card-section>
            </q-card>

            <!-- Customer Info -->
            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <div class="text-subtitle1 text-weight-bold text-grey-9">
                  {{ $t('shop_admin.shipping_details') }}
                </div>
              </q-card-section>

              <q-card-section class="q-px-lg q-py-md text-body2 text-grey-8">
                <div class="row items-center justify-between">
                  <div class="text-weight-bold text-grey-9">
                    {{ orderStore.currentOrder.recipient_name }}
                  </div>
                  <q-btn
                    flat
                    round
                    dense
                    icon="content_copy"
                    size="xs"
                    color="grey-7"
                    @click="copyToClipboard(orderStore.currentOrder.recipient_name, 'Name')"
                  >
                    <q-tooltip>Copy Name</q-tooltip>
                  </q-btn>
                </div>

                <div class="row items-center justify-between q-mt-xs">
                  <div>{{ orderStore.currentOrder.recipient_phone }}</div>
                  <q-btn
                    flat
                    round
                    dense
                    icon="content_copy"
                    size="xs"
                    color="grey-7"
                    @click="copyToClipboard(orderStore.currentOrder.recipient_phone, 'Phone')"
                  >
                    <q-tooltip>Copy Phone</q-tooltip>
                  </q-btn>
                </div>

                <div class="q-mt-sm text-grey-6 bg-grey-1 q-pa-sm rounded-borders relative-position">
                  <div style="white-space: pre-wrap; padding-right: 24px;">{{ orderStore.currentOrder.shipping_address }}</div>
                  <q-btn
                    flat
                    round
                    dense
                    icon="content_copy"
                    size="xs"
                    color="grey-7"
                    class="absolute-top-right q-ma-xs"
                    @click="copyToClipboard(orderStore.currentOrder.shipping_address, 'Address')"
                  >
                    <q-tooltip>Copy Address</q-tooltip>
                  </q-btn>
                </div>

                <div class="q-mt-sm">
                  <q-btn
                    outline
                    dense
                    size="sm"
                    color="primary"
                    icon="content_copy"
                    label="Copy All Details"
                    class="full-width pill-btn"
                    @click="copyAllShippingDetails"
                  />
                </div>
                
                <div
                  v-if="orderStore.currentOrder.delivery_instructions"
                  class="q-mt-sm q-pa-sm bg-blue-50 text-blue-9 text-caption rounded-borders"
                  style="border: 1px solid #90caf9;"
                >
                  <div class="text-weight-bold">{{ $t('shop_admin.delivery_instructions_notes') }}</div>
                  <div style="white-space: pre-wrap">{{ orderStore.currentOrder.delivery_instructions }}</div>
                </div>

                <div class="q-mt-md text-caption text-grey-5">
                  Ordered by: {{ orderStore.currentOrder.created_by_email }}
                </div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>

      <!-- Edit Charges Dialog -->
      <q-dialog v-model="chargesDialogOpen" persistent>
        <q-card style="min-width: 350px; border-radius: 14px;">
          <q-card-section class="row items-center border-bottom q-py-md">
            <div class="text-h6 text-weight-bold">Edit Charges</div>
            <q-space />
            <q-btn icon="close" flat round dense v-close-popup />
          </q-card-section>

          <q-card-section class="q-pa-lg q-gutter-y-md">
            <!-- Delivery -->
            <div class="row items-center q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="chargesForm.delivery_charge_amount"
                  type="number"
                  label="Delivery Charge"
                  outlined
                  dense
                  :prefix="currencySymbol"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-toggle
                  v-model="chargesForm.deduct_delivery_from_margin"
                  label="Deduct from Profit"
                  dense
                />
              </div>
            </div>

            <!-- COD -->
            <div class="row items-center q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="chargesForm.cod_charge_amount"
                  type="number"
                  label="COD Charge"
                  outlined
                  dense
                  :prefix="currencySymbol"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-toggle
                  v-model="chargesForm.deduct_cod_from_margin"
                  label="Deduct from Profit"
                  dense
                />
              </div>
            </div>

            <!-- Print -->
            <div class="row items-center q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="chargesForm.print_charge_amount"
                  type="number"
                  label="Print Charge"
                  outlined
                  dense
                  :prefix="currencySymbol"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-toggle
                  v-model="chargesForm.deduct_print_from_margin"
                  label="Deduct from Profit"
                  dense
                />
              </div>
            </div>

            <!-- Packing -->
            <div class="row items-center q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="chargesForm.packing_charge_amount"
                  type="number"
                  label="Packaging Charge"
                  outlined
                  dense
                  :prefix="currencySymbol"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-toggle
                  v-model="chargesForm.deduct_packing_from_margin"
                  label="Deduct from Profit"
                  dense
                />
              </div>
            </div>
          </q-card-section>

          <q-card-actions align="right" class="q-px-lg q-pb-md">
            <q-btn flat label="Cancel" color="grey-7" v-close-popup />
            <q-btn
              unelevated
              label="Save"
              color="primary"
              :loading="savingCharges"
              @click="saveCharges"
              class="pill-btn q-px-md"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { date, useQuasar, copyToClipboard as quasarCopyToClipboard } from 'quasar';
import { useThriftCurrencyStore } from 'src/modules/thrift/currency/stores/thriftCurrencyStore';
import { supabase } from 'src/boot/supabase';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const orderStore = useShopOrderStore();
const currencyStore = useThriftCurrencyStore();
const $q = useQuasar();

const statusDotColor = (currentStatus: string) => {
  const val = (currentStatus || '').toLowerCase();
  switch (val) {
    case 'draft':
      return '#6b7280';
    case 'submitted':
      return '#2563eb';
    case 'negotiating':
      return '#d97706';
    case 'priced':
      return '#0891b2';
    case 'confirmed':
      return '#16a34a';
    case 'placed':
      return '#4f46e5';
    case 'fulfilled':
      return '#0d9488';
    case 'processing':
      return '#8b5cf6';
    case 'shipped':
      return '#0284c7';
    case 'delivered':
      return '#15803d';
    case 'payment_received':
      return '#059669';
    case 'cancelled':
      return '#dc2626';
    default:
      return '#6b7280';
  }
};

const statusChipStyle = (currentStatus: string) => {
  const val = (currentStatus || '').toLowerCase();
  switch (val) {
    case 'draft':
      return {
        backgroundColor: '#f3f4f6',
        color: '#374151',
        border: '1px solid #e5e7eb',
        borderRadius: '6px',
      };
    case 'submitted':
      return {
        backgroundColor: '#eff6ff',
        color: '#1d4ed8',
        border: '1px solid #bfdbfe',
        borderRadius: '6px',
      };
    case 'negotiating':
      return {
        backgroundColor: '#fffbe6',
        color: '#d97706',
        border: '1px solid #ffe58f',
        borderRadius: '6px',
      };
    case 'priced':
      return {
        backgroundColor: '#ecfeff',
        color: '#0e7490',
        border: '1px solid #a5f3fc',
        borderRadius: '6px',
      };
    case 'confirmed':
      return {
        backgroundColor: '#f0fdf4',
        color: '#15803d',
        border: '1px solid #bbf7d0',
        borderRadius: '6px',
      };
    case 'placed':
      return {
        backgroundColor: '#eef2ff',
        color: '#4338ca',
        border: '1px solid #c7d2fe',
        borderRadius: '6px',
      };
    case 'fulfilled':
      return {
        backgroundColor: '#f0fdfa',
        color: '#0f766e',
        border: '1px solid #99f6e4',
        borderRadius: '6px',
      };
    case 'processing':
      return {
        backgroundColor: '#f5f3ff',
        color: '#6d28d9',
        border: '1px solid #ddd6fe',
        borderRadius: '6px',
      };
    case 'shipped':
      return {
        backgroundColor: '#f0f9ff',
        color: '#0369a1',
        border: '1px solid #bae6fd',
        borderRadius: '6px',
      };
    case 'delivered':
      return {
        backgroundColor: '#f0fdf4',
        color: '#15803d',
        border: '1px solid #bbf7d0',
        borderRadius: '6px',
      };
    case 'payment_received':
      return {
        backgroundColor: '#ecfdf5',
        color: '#047857',
        border: '1px solid #a7f3d0',
        borderRadius: '6px',
      };
    case 'cancelled':
      return {
        backgroundColor: '#fef2f2',
        color: '#b91c1c',
        border: '1px solid #fecaca',
        borderRadius: '6px',
      };
    default:
      return {
        backgroundColor: '#f9fafb',
        color: '#1f2937',
        border: '1px solid #e5e7eb',
        borderRadius: '6px',
      };
  }
};

const availableStatuses = computed(() => {
  if (orderStore.currentOrder?.shop_type_snapshot === 'dropship') {
    return [
      'submitted',
      'confirmed',
      'processing',
      'ready_for_pickup',
      'shipped',
      'delivered',
      'returned',
      'payment_received',
      'cancelled',
    ];
  }
  return [
    'draft',
    'submitted',
    'negotiating',
    'priced',
    'confirmed',
    'placed',
    'fulfilled',
    'cancelled',
  ];
});
const changingStatus = ref(false);

const changeOrderStatus = async (newStatus: string) => {
  if (!orderId.value || !orderStore.currentOrder) return;
  if (orderStore.currentOrder.status === newStatus) return;

  changingStatus.value = true;
  try {
    const { error } = await supabase
      .from('shop_orders')
      .update({ status: newStatus })
      .eq('id', orderId.value);

    if (error) {
      $q.notify({
        type: 'negative',
        message: error.message || 'Failed to update order status',
      });
    } else {
      $q.notify({
        type: 'positive',
        message: `Order status changed to ${newStatus.toUpperCase()}`,
      });
      await orderStore.fetchOrderDetails(orderId.value);
    }
  } finally {
    changingStatus.value = false;
  }
};

const copyToClipboard = (text: string | null | undefined, label: string) => {
  if (!text) return;
  quasarCopyToClipboard(text)
    .then(() => {
      $q.notify({
        type: 'positive',
        message: `${label} copied to clipboard`,
        timeout: 1500,
      });
    })
    .catch(() => {
      $q.notify({
        type: 'negative',
        message: `Failed to copy ${label.toLowerCase()}`,
        timeout: 1500,
      });
    });
};

const copyAllShippingDetails = () => {
  const o = orderStore.currentOrder;
  if (!o) return;
  const parts = [];
  if (o.recipient_name) parts.push(`Name: ${o.recipient_name}`);
  if (o.recipient_phone) parts.push(`Phone: ${o.recipient_phone}`);
  if (o.shipping_address) parts.push(`Address: ${o.shipping_address}`);
  if (o.delivery_instructions) parts.push(`Instructions: ${o.delivery_instructions}`);

  copyToClipboard(parts.join('\n'), 'Shipping details');
};

const orderItems = ref<any[]>([]);
const shopSellCurrencyId = ref<number | null>(null);

const orderId = computed(() => Number(route.params.id));

const currencySymbol = computed(() => {
  if (shopSellCurrencyId.value) {
    const curr = currencyStore.currencyById(shopSellCurrencyId.value);
    if (curr?.symbol) return curr.symbol;
  }
  return '£';
});

onMounted(async () => {
  await currencyStore.loadCurrencies();
  if (orderId.value) {
    const res = await orderStore.fetchOrderDetails(orderId.value);
    if (res.success && res.data) {
      orderItems.value = JSON.parse(JSON.stringify(res.data.items));

      // Fetch shop sell currency
      const shopId = res.data.order?.shop_id;
      if (shopId) {
        const { data: shopData } = await supabase
          .from('shops')
          .select('sell_currency_id')
          .eq('id', shopId)
          .single();
        if (shopData?.sell_currency_id) {
          shopSellCurrencyId.value = shopData.sell_currency_id;
        }
      }
    }
  }
});

const canAction = computed(() => {
  const o = orderStore.currentOrder;
  return o && (o.status === 'submitted' || o.status === 'negotiating' || o.status === 'priced');
});

const canFulfill = computed(() => {
  const o = orderStore.currentOrder;
  return o && o.status === 'confirmed';
});

const placeForProcurement = async () => {
  if (orderId.value) {
    const res = await orderStore.placeOrderForProcurement(orderId.value);
    if (res.success) {
      const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
      if (detailsRes.success && detailsRes.data) {
        orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
      }
    }
  }
};

const fulfillToInvoice = async () => {
  if (orderId.value) {
    const res = await orderStore.fulfillOrderToInvoice(orderId.value);
    if (res.success) {
      const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
      if (detailsRes.success && detailsRes.data) {
        orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
      }
    }
  }
};

const addToDropshipDesk = async () => {
  if (orderId.value) {
    const res = await orderStore.processDropshipOrder(orderId.value);
    if (res.success) {
      void router.push({
        name: 'app-shop-dropship-order-detail-page',
        params: {
          tenantSlug: route.params.tenantSlug,
          id: orderId.value,
        },
      });
    }
  }
};


const codFeePctLabel = computed(() => {
  const sub = recipientSubtotal.value;
  if (!sub) return 0;
  return Number(((codChargeVal.value / sub) * 100).toFixed(1));
});

const confirmDeleteOrder = () => {
  $q.dialog({
    title: t('shop_admin.delete_order'),
    message:
      'Are you sure you want to delete this order? This action is permanent and cannot be undone.',
    persistent: true,
    ok: {
      label: t('shop_admin.delete'),
      color: 'negative',
      flat: true,
    },
    cancel: {
      label: t('shop_admin.cancel'),
      flat: true,
    },
  }).onOk(() => {
    void (async () => {
      if (orderId.value) {
        const res = await orderStore.deleteShopOrder(orderId.value);
        if (res.success) {
          void router.push({
            name: 'app-shop-orders-page',
            params: { tenantSlug: route.params.tenantSlug },
          });
        }
      }
    })();
  });
};

const getDisplayUnitPrice = (item: any) => {
  return (
    item.final_price_amount ??
    item.staff_offer_amount ??
    item.customer_offer_amount ??
    item.unit_sell_price_amount ??
    item.unit_list_price_amount ??
    0
  );
};

const orderTotal = computed(() => {
  return orderItems.value.reduce((sum, item) => sum + getDisplayUnitPrice(item) * item.quantity, 0);
});

// Dropship calculations
const recipientSubtotal = computed(() => {
  return orderItems.value.reduce((sum, item) => sum + (item.customer_sell_price_amount ?? 0) * item.quantity, 0);
});

const accountingSubtotal = computed(() => {
  return orderItems.value.reduce((sum, item) => {
    const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
    return sum + price * item.quantity;
  }, 0);
});

const codChargeVal = computed(() => Number(orderStore.currentOrder?.cod_charge_amount || 0));
const deliveryChargeVal = computed(() => Number(orderStore.currentOrder?.delivery_charge_amount || 0));
const printChargeVal = computed(() => Number(orderStore.currentOrder?.print_charge_amount || 0));
const packingChargeVal = computed(() => Number(orderStore.currentOrder?.packing_charge_amount || 0));
const discountVal = computed(() => Number(orderStore.currentOrder?.discount_amount || 0));
const deductCodFromMargin = computed(() => !!orderStore.currentOrder?.deduct_cod_from_margin);
const deductDeliveryFromMargin = computed(() => !!orderStore.currentOrder?.deduct_delivery_from_margin);
const deductPrintFromMargin = computed(() => !!orderStore.currentOrder?.deduct_print_from_margin);
const deductPackingFromMargin = computed(() => !!orderStore.currentOrder?.deduct_packing_from_margin);

const recipientGrandTotal = computed(() => {
  return recipientSubtotal.value
    + (deductDeliveryFromMargin.value ? 0 : deliveryChargeVal.value)
    + (deductPrintFromMargin.value ? 0 : printChargeVal.value)
    + (deductPackingFromMargin.value ? 0 : packingChargeVal.value)
    + (deductCodFromMargin.value ? 0 : codChargeVal.value)
    - discountVal.value;
});

const middlemanTotalCost = computed(() => {
  return accountingSubtotal.value
    + deliveryChargeVal.value
    + printChargeVal.value
    + packingChargeVal.value
    + (deductCodFromMargin.value ? codChargeVal.value : 0);
});

const estimatedProfit = computed(() => {
  return recipientGrandTotal.value - middlemanTotalCost.value;
});

const submitStaffPricing = async () => {
  const payload = orderItems.value.map((item) => ({
    id: item.id,
    staff_offer_amount: Number(item.staff_offer_amount || 0),
    staff_offer_currency_id:
      item.staff_offer_currency_id ||
      item.unit_sell_price_currency_id ||
      item.unit_list_price_currency_id,
  }));

  const o = orderStore.currentOrder;
  let res;
  if (o?.status === 'submitted') {
    res = await orderStore.priceOrder(orderId.value, payload);
  } else {
    res = await orderStore.sendStaffCounter(orderId.value, payload);
  }

  if (res.success) {
    const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
    if (detailsRes.success && detailsRes.data) {
      orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
    }
  }
};

const confirmOrder = async () => {
  const res = await orderStore.confirmOrder(orderId.value);
  if (res.success) {
    const detailsRes = await orderStore.fetchOrderDetails(orderId.value);
    if (detailsRes.success && detailsRes.data) {
      orderItems.value = JSON.parse(JSON.stringify(detailsRes.data.items));
    }
  }
};

const goBack = () => {
  const slug = route.params.tenantSlug;
  const tenantSlug = typeof slug === 'string' && slug ? `/${slug}` : '';
  void router.push(`${tenantSlug}/app/shop/orders`);
};

const formatDate = (dateStr: string) => {
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const chargesDialogOpen = ref(false);
const savingCharges = ref(false);
const chargesForm = ref({
  delivery_charge_amount: 0,
  deduct_delivery_from_margin: false,
  cod_charge_amount: 0,
  deduct_cod_from_margin: false,
  print_charge_amount: 0,
  deduct_print_from_margin: false,
  packing_charge_amount: 0,
  deduct_packing_from_margin: false,
});

const openChargesDialog = () => {
  const o = orderStore.currentOrder;
  if (o) {
    chargesForm.value = {
      delivery_charge_amount: Number(o.delivery_charge_amount || 0),
      deduct_delivery_from_margin: !!o.deduct_delivery_from_margin,
      cod_charge_amount: Number(o.cod_charge_amount || 0),
      deduct_cod_from_margin: !!o.deduct_cod_from_margin,
      print_charge_amount: Number(o.print_charge_amount || 0),
      deduct_print_from_margin: !!o.deduct_print_from_margin,
      packing_charge_amount: Number(o.packing_charge_amount || 0),
      deduct_packing_from_margin: !!o.deduct_packing_from_margin,
    };
    chargesDialogOpen.value = true;
  }
};

const saveCharges = async () => {
  if (!orderId.value) return;
  savingCharges.value = true;
  try {
    const res = await orderStore.updateOrderCharges(orderId.value, chargesForm.value);
    if (res.success) {
      chargesDialogOpen.value = false;
    }
  } finally {
    savingCharges.value = false;
  }
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'negotiating':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'confirmed':
      return 'green-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
};
</script>

<script lang="ts">
export default {
  name: 'StaffOrderDetailPage',
};
</script>

<style scoped>
.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.pill-btn {
  border-radius: 30px;
}

.status-badge {
  border-radius: 8px;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.counter-input :deep(.q-field__control) {
  border-radius: 8px;
}
</style>
