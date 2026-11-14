<template>
  <div
    class="recipient-list-panel column no-wrap col min-height-0"
    :class="{ 'recipient-list-panel--fill': fillHeight }"
  >
    <div class="recipient-toolbar row items-center no-wrap q-gutter-sm q-mb-sm">
      <q-input
        v-model="recipientSearchText"
        outlined
        dense
        hide-bottom-space
        placeholder="Search by recipient name, phone, district, or address..."
        class="search-box col"
      >
        <template #prepend>
          <q-icon name="ph ph-magnifying-glass" size="18px" class="text-grey-5" />
        </template>
        <template #append v-if="recipientSearchText">
          <q-icon
            name="ph ph-x"
            size="16px"
            class="cursor-pointer text-grey-5"
            @click="recipientSearchText = ''"
          />
        </template>
      </q-input>

      <q-select
        v-if="isParentTenant && childTenantOptions.length > 1"
        v-model="selectedChildTenantId"
        :options="childTenantOptions"
        option-value="value"
        option-label="label"
        emit-value
        map-options
        outlined
        dense
        options-dense
        hide-bottom-space
        class="col-auto dense-tenant-select"
        style="min-width: 170px"
        aria-label="Filter by child tenant"
      >
        <template #prepend>
          <q-icon name="ph ph-buildings" size="16px" class="text-grey-6" />
        </template>
      </q-select>

      <q-btn
        flat
        round
        dense
        icon="ph ph-arrow-clockwise"
        color="grey-7"
        class="col-auto"
        :ripple="false"
        :loading="recipientStore.loading"
        @click="loadRecipients"
      >
        <q-tooltip>Refresh</q-tooltip>
      </q-btn>

      <q-btn
        unelevated
        color="primary"
        icon="ph ph-plus"
        label="Create Recipient"
        no-caps
        dense
        class="action-btn text-weight-bold col-auto q-px-sm"
        :ripple="false"
        @click="openCreateRecipientDialog"
      />
    </div>

    <TfEntityListShell v-if="recipientStore.loading && !recipientItems.length" root-class="col">
      <TfEntityListRow v-for="n in 6" :key="n" skeleton />
    </TfEntityListShell>

    <div
      v-else-if="!recipientItems.length"
      class="column items-center justify-center q-pa-xl text-center col tf-entity-list-card"
    >
      <q-avatar size="56px" color="grey-3" text-color="grey-9" class="q-mb-md">
        <q-icon name="ph ph-identification-badge" size="28px" />
      </q-avatar>
      <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">No Recipient Profiles Found</div>
      <p class="text-caption text-grey-6 q-mb-md" style="max-width: 380px">
        Manage saved delivery addresses and end-customer profiles for retail and dropship invoices.
      </p>
      <q-btn
        unelevated
        color="primary"
        icon="ph ph-plus"
        label="Create Recipient"
        no-caps
        dense
        class="action-btn text-weight-bold q-px-md"
        :ripple="false"
        @click="openCreateRecipientDialog"
      />
    </div>

    <div
      v-else-if="!filteredRecipientItems.length"
      class="column items-center justify-center text-center text-grey-7 q-py-xl col tf-entity-list-card"
    >
      <q-icon name="ph ph-funnel" size="36px" class="q-mb-xs text-grey-4" />
      <div class="text-subtitle2 text-weight-medium text-slate-800">No recipient profiles found</div>
      <div class="text-caption text-grey-6 q-mt-xs">
        Try searching with a different keyword or select all child tenants.
      </div>
    </div>

    <TfEntityListShell v-else root-class="col">
      <TfEntityListRow
        v-for="row in filteredRecipientItems"
        :key="row.id"
        @click="openRecipientDrawer(row)"
      >
        <template #avatar>{{ getInitials(row.name) }}</template>
        <template #title>
          <span class="tf-entity-list-item__name">{{ row.name }}</span>
          <span v-if="isParentTenant && row.tenant_name" class="tenant-tag q-ml-xs">
            <q-icon name="ph ph-buildings" size="12px" class="q-mr-2xs" />
            {{ row.tenant_name }}
          </span>
        </template>
        <template #meta>{{ recipientBrowseMeta(row) }}</template>
      </TfEntityListRow>
    </TfEntityListShell>

    <RecipientDetailDrawer
      v-model="recipientDrawerOpen"
      :recipient="selectedRecipient"
      :is-parent-tenant="isParentTenant"
      @deleted="onDrawerRecipientDeleted"
    />

    <q-dialog v-model="recipientDialogOpen" persistent>
      <q-card style="min-width: 480px; border-radius: 12px">
        <q-card-section class="row items-center q-pb-none">
          <div>
            <div class="text-subtitle1 text-weight-bold">Create Recipient Profile</div>
            <div class="text-caption text-grey-6">Fill in courier-ready delivery details below</div>
          </div>
          <q-space />
          <q-btn v-close-popup icon="ph ph-x" flat round dense aria-label="Close" :ripple="false" />
        </q-card-section>

        <q-form @submit.prevent="onRecipientFormSubmit">
          <q-card-section class="q-gutter-sm">
            <q-input
              v-model="recipientForm.name"
              label="Recipient Name *"
              outlined
              dense
              class="soft-input"
              lazy-rules
              :rules="[(val) => (val && val.trim().length > 0) || 'Name is required']"
            />
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model="recipientForm.phone"
                  label="Primary Phone *"
                  outlined
                  dense
                  class="soft-input"
                  lazy-rules
                  :rules="[(val) => (val && val.trim().length > 0) || 'Phone is required']"
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model="recipientForm.secondary_phone"
                  label="Secondary Phone"
                  outlined
                  dense
                  class="soft-input"
                />
              </div>
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model="recipientForm.district"
                  label="District *"
                  outlined
                  dense
                  class="soft-input"
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model="recipientForm.thana"
                  label="Thana / Upazila *"
                  outlined
                  dense
                  class="soft-input"
                />
              </div>
            </div>
            <q-input
              v-model="recipientForm.address"
              label="Delivery Address *"
              outlined
              dense
              type="textarea"
              rows="3"
              class="soft-input"
              lazy-rules
              :rules="[(val) => (val && val.trim().length > 0) || 'Address is required']"
            />
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat no-caps label="Cancel" v-close-popup class="action-btn" :ripple="false" />
            <q-btn
              color="primary"
              no-caps
              unelevated
              label="Create Profile"
              :loading="recipientStore.saving"
              type="submit"
              class="action-btn px-md text-weight-medium"
              :ripple="false"
            />
          </q-card-actions>
        </q-form>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useInvoiceWorkspace } from 'src/modules/sales_invoice/composables/useInvoiceWorkspace';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useRecipientProfileStore } from 'src/modules/sales_invoice/stores/recipientProfileStore';
import type { RecipientProfile } from 'src/types/recipientProfile';
import RecipientDetailDrawer from './RecipientDetailDrawer.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import { getInitials } from 'src/modules/sales_invoice/utils/invoiceListDisplay';

withDefaults(
  defineProps<{
    fillHeight?: boolean;
  }>(),
  { fillHeight: true },
);

const authStore = useAuthStore();
const tenantStore = useTenantStore();
const recipientStore = useRecipientProfileStore();
const { isParentTenant } = useInvoiceWorkspace();

const tenantId = computed(() => authStore.tenantId as number);

const recipientSearchText = ref('');
const recipientDialogOpen = ref(false);
const recipientDrawerOpen = ref(false);
const selectedRecipient = ref<RecipientProfile | null>(null);
const selectedChildTenantId = ref<number | null>(null);

const recipientForm = reactive({
  name: '',
  phone: '',
  secondary_phone: '',
  district: 'Dhaka',
  thana: 'Uttara',
  address: '',
});

const recipientItems = computed(() => recipientStore.items);

const childTenantOptions = computed(() => {
  const map = new Map<number, string>();
  for (const item of recipientItems.value) {
    if (item.tenant_id && item.tenant_name) {
      map.set(item.tenant_id, item.tenant_name);
    }
  }
  for (const t of tenantStore.items) {
    if (t.parent_id === tenantId.value) {
      map.set(t.id, t.name);
    }
  }
  const options: { label: string; value: number | null }[] = [
    { label: 'All Child Tenants', value: null },
  ];
  for (const [id, name] of map.entries()) {
    options.push({ label: name, value: id });
  }
  return options;
});

const filteredRecipientItems = computed(() => {
  const search = recipientSearchText.value.trim().toLowerCase();
  return recipientItems.value.filter((row) => {
    if (selectedChildTenantId.value !== null && row.tenant_id !== selectedChildTenantId.value) {
      return false;
    }
    if (!search) return true;
    return [
      row.name,
      row.phone,
      row.address,
      row.district || '',
      row.thana || '',
      row.secondary_phone || '',
      row.tenant_name || '',
    ].some((val) => val.toLowerCase().includes(search));
  });
});

const recipientBrowseMeta = (row: RecipientProfile) => {
  const parts: string[] = [];
  if (row.phone) parts.push(row.phone);
  if (row.secondary_phone) parts.push(`Alt: ${row.secondary_phone}`);
  const locale = [row.district, row.thana].filter(Boolean).join(', ');
  if (locale) parts.push(locale);
  if (row.address) parts.push(row.address);
  return parts.join(' · ');
};

const loadRecipients = async () => {
  if (!tenantId.value) return;
  await recipientStore.fetchRecipientProfiles(tenantId.value, isParentTenant.value);
};

watch(
  () => [tenantId.value, isParentTenant.value] as const,
  ([newTenantId]) => {
    if (newTenantId) void loadRecipients();
  },
);

onMounted(() => {
  void loadRecipients();
});

const openCreateRecipientDialog = () => {
  recipientForm.name = '';
  recipientForm.phone = '';
  recipientForm.secondary_phone = '';
  recipientForm.district = 'Dhaka';
  recipientForm.thana = 'Uttara';
  recipientForm.address = '';
  recipientDialogOpen.value = true;
};

const openRecipientDrawer = (recipient: RecipientProfile) => {
  selectedRecipient.value = recipient;
  recipientDrawerOpen.value = true;
};

const onDrawerRecipientDeleted = () => {
  recipientDrawerOpen.value = false;
  selectedRecipient.value = null;
};

const onRecipientFormSubmit = async () => {
  if (!tenantId.value) return;

  const payload = {
    tenant_id: tenantId.value,
    name: recipientForm.name.trim(),
    phone: recipientForm.phone.trim(),
    address: recipientForm.address.trim(),
    secondary_phone: recipientForm.secondary_phone.trim() || null,
    district: recipientForm.district.trim() || null,
    thana: recipientForm.thana.trim() || null,
  };

  const res = await recipientStore.upsertByPhone(payload);
  if (res.success) {
    recipientDialogOpen.value = false;
  }
};
</script>

<style scoped lang="scss">
@import 'src/css/tf-entity-list.scss';

.recipient-list-panel {
  flex: 1 1 auto;
}

.recipient-list-panel--fill {
  height: 100%;
  min-height: 0;
}

.recipient-toolbar {
  flex-shrink: 0;
}

.action-btn {
  border-radius: 8px !important;
}

.search-box {
  min-width: 0;
}

.search-box :deep(.q-field__control) {
  border-radius: 8px;
}

.tenant-tag {
  display: inline-flex;
  align-items: center;
  padding: 1.5px 6px;
  border-radius: 4px;
  background: #f1f5f9;
  color: #334155;
  font-size: 11px;
  font-weight: 500;
}

body.body--dark .tenant-tag {
  background: #2a2a2a;
  color: #94a3b8;
}

.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}

.dense-tenant-select :deep(.q-field__control) {
  border-radius: 8px;
}
</style>