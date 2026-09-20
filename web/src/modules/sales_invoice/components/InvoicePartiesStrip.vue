<script setup lang="ts">
import { computed } from 'vue';
import type { InvoiceBrand } from '../repositories/invoiceRepository';
import type { BillingProfile } from '../repositories/billingProfileRepository';

type BillingProfileWithTenant = BillingProfile & {
  tenant?: { id: number; name: string; slug: string } | null;
};

const props = defineProps<{
  mode: 'edit' | 'read';
  brandOptions?: InvoiceBrand[];
  brandsLoading?: boolean;
  billingProfileOptions?: BillingProfileWithTenant[];
  billingProfilesLoading?: boolean;
  billToName?: string | null;
  billToEmail?: string | null;
  billToPhone?: string | null;
  shipToName?: string | null;
  shipToPhone?: string | null;
  shipToAddress?: string | null;
  showShipTo?: boolean;
  canEditShipTo?: boolean;
  editingRecipient?: boolean;
  dropshipHint?: boolean;
  recipientForm?: {
    recipient_name: string;
    recipient_phone: string;
    recipient_address: string;
  };
}>();

const selectedBrandId = defineModel<number | null>('selectedBrandId');
const selectedBillingProfileId = defineModel<number | null>('selectedBillingProfileId');

const emit = defineEmits<{
  (e: 'filter-billing-profiles', val: string, update: (fn: () => void) => void): void;
  (e: 'toggle-edit-recipient'): void;
  (e: 'recipient-blur'): void;
}>();

const selectedBrand = computed(
  () => props.brandOptions?.find((b) => b.id === selectedBrandId?.value) ?? null,
);

const selectedBillingProfile = computed(
  () =>
    props.billingProfileOptions?.find((p) => p.id === selectedBillingProfileId?.value) ?? null,
);
</script>

<template>
  <div class="invoice-desk-parties">
    <div v-if="mode === 'edit'" class="invoice-desk-card">
      <div class="invoice-desk-section-label">From (brand)</div>
      <q-select
        v-model="selectedBrandId"
        :options="brandOptions || []"
        option-value="id"
        option-label="name"
        emit-value
        map-options
        outlined
        dense
        hide-bottom-space
        label="Invoice brand *"
        :loading="brandsLoading"
        :disable="brandsLoading"
      >
        <template #option="scope">
          <q-item v-bind="scope.itemProps" class="q-py-xs">
            <q-item-section>
              <q-item-label class="text-weight-medium">{{ scope.opt.name }}</q-item-label>
              <q-item-label v-if="scope.opt.address" caption class="text-grey-6 ellipsis">
                {{ scope.opt.address }}
              </q-item-label>
            </q-item-section>
          </q-item>
        </template>
      </q-select>
      <template v-if="selectedBrand">
        <div class="invoice-desk-party__name">{{ selectedBrand.name }}</div>
        <div v-if="selectedBrand.address" class="invoice-desk-party__line">{{ selectedBrand.address }}</div>
      </template>
    </div>

    <div class="invoice-desk-card">
      <div class="invoice-desk-section-label">Bill to</div>
      <template v-if="mode === 'edit'">
        <q-select
          v-model="selectedBillingProfileId"
          :options="billingProfileOptions || []"
          option-value="id"
          option-label="name"
          emit-value
          map-options
          outlined
          dense
          clearable
          use-input
          input-debounce="150"
          hide-bottom-space
          label="Billing profile (customer) *"
          class="q-mt-xs"
          :loading="billingProfilesLoading"
          :disable="billingProfilesLoading"
          @filter="(val, update) => emit('filter-billing-profiles', val, update)"
        >
          <template #no-option>
            <q-item>
              <q-item-section class="text-grey-6 text-caption text-center q-py-sm">
                No billing profiles found
              </q-item-section>
            </q-item>
          </template>
          <template #option="scope">
            <q-item v-bind="scope.itemProps" class="q-py-xs">
              <q-item-section>
                <div class="row items-center justify-between no-wrap">
                  <q-item-label class="text-weight-medium">{{ scope.opt.name }}</q-item-label>
                  <q-badge
                    v-if="scope.opt.tenant?.name"
                    color="grey-2"
                    text-color="grey-8"
                    class="text-caption text-weight-medium q-ml-xs"
                  >
                    {{ scope.opt.tenant.name }}
                  </q-badge>
                </div>
                <q-item-label caption class="text-grey-6 ellipsis">
                  {{ scope.opt.phone || scope.opt.email || scope.opt.address || 'No details' }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </template>
        </q-select>
        <template v-if="selectedBillingProfile">
          <div class="invoice-desk-party__name">{{ selectedBillingProfile.name }}</div>
          <div v-if="selectedBillingProfile.phone" class="invoice-desk-party__line">
            {{ selectedBillingProfile.phone }}
          </div>
          <div v-if="selectedBillingProfile.email" class="invoice-desk-party__line">
            {{ selectedBillingProfile.email }}
          </div>
          <div v-if="selectedBillingProfile.address" class="invoice-desk-party__line">
            {{ selectedBillingProfile.address }}
          </div>
        </template>
      </template>
      <template v-else>
        <div class="invoice-desk-party__name">{{ billToName || '—' }}</div>
        <div v-if="billToEmail" class="invoice-desk-party__line">{{ billToEmail }}</div>
        <div v-if="billToPhone" class="invoice-desk-party__line">{{ billToPhone }}</div>
        <div v-if="dropshipHint" class="invoice-desk-party__line q-mt-sm">
          Cash-in is remittance after delivery, not COD on this bill.
        </div>
      </template>
    </div>

    <div v-if="showShipTo" class="invoice-desk-card">
      <div class="row items-center justify-between">
        <div class="invoice-desk-section-label q-mb-none">Ship to</div>
        <q-btn
          v-if="canEditShipTo"
          flat
          dense
          no-caps
          color="primary"
          size="sm"
          :label="editingRecipient ? 'Done' : 'Edit'"
          @click="emit('toggle-edit-recipient')"
        />
      </div>
      <div v-if="editingRecipient && canEditShipTo && recipientForm" class="q-gutter-y-xs q-mt-xs">
        <q-input
          v-model="recipientForm!.recipient_name"
          label="Name"
          dense
          outlined
          hide-bottom-space
          @blur="emit('recipient-blur')"
        />
        <q-input
          v-model="recipientForm!.recipient_phone"
          label="Phone"
          dense
          outlined
          hide-bottom-space
          @blur="emit('recipient-blur')"
        />
        <q-input
          v-model="recipientForm!.recipient_address"
          label="Address"
          type="textarea"
          rows="2"
          dense
          outlined
          @blur="emit('recipient-blur')"
        />
      </div>
      <template v-else>
        <div class="invoice-desk-party__name">{{ shipToName || '—' }}</div>
        <div v-if="shipToPhone" class="invoice-desk-party__line">{{ shipToPhone }}</div>
        <div v-if="shipToAddress" class="invoice-desk-party__line">{{ shipToAddress }}</div>
      </template>
    </div>
  </div>
</template>

<style scoped lang="scss">
@import '../styles/invoice-desk.scss';
</style>
