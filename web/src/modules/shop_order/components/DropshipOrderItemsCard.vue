<script setup lang="ts">
import type { ShopOrderItem } from '../types';

defineProps<{
  orderItems: ShopOrderItem[];
  formatBdt: (amount: number) => string;
}>();
</script>

<template>
  <q-card flat bordered class="form-card">
    <q-card-section class="border-bottom row items-center justify-between">
      <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
        <q-icon name="ph ph-shopping-bag" size="18px" class="q-mr-xs text-primary" />
        Ordered Items
      </div>
      <q-chip dense color="grey-2" text-color="grey-9" size="sm">
        {{ orderItems.length }} {{ orderItems.length === 1 ? 'item' : 'items' }}
      </q-chip>
    </q-card-section>
    <q-card-section class="q-pa-none">
      <div v-if="orderItems.length === 0" class="text-center text-grey-6 q-pa-md text-caption">
        No items in this order.
      </div>
      <q-markup-table v-else flat borderless class="soft-table text-caption">
        <thead>
          <tr>
            <th style="width: 48px"></th>
            <th class="text-left">Item Name</th>
            <th class="text-left">SKU</th>
            <th class="text-center">Qty</th>
            <th class="text-right">Customer Price</th>
            <th class="text-right">Cost</th>
            <th class="text-right">Subtotal</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in orderItems" :key="item.id" class="hover-row">
            <td>
              <q-img
                v-if="item.image_url"
                :src="item.image_url"
                style="width: 36px; height: 36px; border-radius: 4px"
                fit="cover"
              />
              <div
                v-else
                class="bg-grey-3 row flex-center rounded-borders"
                style="width: 36px; height: 36px"
              >
                <q-icon name="ph ph-package" size="18px" color="grey-6" />
              </div>
            </td>
            <td>
              <div class="text-weight-bold text-grey-9">{{ item.name }}</div>
            </td>
            <td>
              <q-chip dense outline size="xs" color="grey-7" class="q-ma-none">
                {{ item.sku || '—' }}
              </q-chip>
            </td>
            <td class="text-center text-weight-medium">
              {{ item.quantity }}
            </td>
            <td class="text-right text-weight-medium">
              {{ formatBdt(item.customer_sell_price_amount ?? item.final_price_amount ?? 0) }}
            </td>
            <td class="text-right text-grey-7">
              {{ formatBdt(item.unit_sell_price_amount ?? 0) }}
            </td>
            <td class="text-right text-weight-bold text-grey-9">
              {{ formatBdt((item.customer_sell_price_amount ?? item.final_price_amount ?? 0) * item.quantity) }}
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card-section>
  </q-card>
</template>
