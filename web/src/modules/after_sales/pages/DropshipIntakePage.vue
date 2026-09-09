<template>
  <q-page class="bw-page dropship-intake-page">
    <section class="bw-page__stack intake-stack">
      <q-card flat bordered class="q-pa-md q-gutter-y-md">
        <q-input
          v-model="orderSearch"
          dense
          outlined
          label="Search order no or recipient phone"
          debounce="300"
          @update:model-value="onSearchOrders"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>

        <q-list v-if="orderResults.length" bordered separator class="rounded-borders">
          <q-item
            v-for="order in orderResults"
            :key="order.id"
            clickable
            :active="selectedOrder?.id === order.id"
            active-class="intake-order-active"
            @click="selectOrder(order)"
          >
            <q-item-section>
              <q-item-label>{{ order.order_no }}</q-item-label>
              <q-item-label caption>
                {{ order.recipient_name }} · {{ order.recipient_phone }} · {{ order.merchant_name }}
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-list>

        <template v-if="selectedOrder">
          <q-select
            v-model="intakeSource"
            :options="intakeSourceOptions"
            outlined
            dense
            emit-value
            map-options
            label="Intake source"
          />
          <q-select
            v-model="reportedTo"
            :options="reportedToOptions"
            outlined
            dense
            emit-value
            map-options
            label="Reported to"
          />
          <q-input v-model="reporterName" outlined dense label="Reporter name" />
          <q-input v-model="reporterPhone" outlined dense label="Reporter phone" />
          <q-select
            v-model="reasonCode"
            :options="reasonOptions"
            outlined
            dense
            emit-value
            map-options
            label="Reason"
          />
          <q-input
            v-model="intakeNote"
            type="textarea"
            autogrow
            outlined
            dense
            label="Intake note"
            :rules="[(val) => !!val?.trim() || 'Note is required']"
          />
        </template>
      </q-card>

      <div class="bw-inline-actions" style="justify-content: flex-end">
        <q-btn flat no-caps label="Cancel" style="border-radius: 8px" @click="goToHub" />
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Create case"
          style="border-radius: 8px"
          :disable="!canSubmit"
          :loading="submitting"
          @click="onSubmit"
        />
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { afterSalesRepositoryStub } from '../repositories/afterSalesRepository.stub';
import type { MockDropshipOrder, AfterSalesReasonCode, DropshipIntakeSource, DropshipReportedTo } from '../types/afterSales.types';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

usePageBreadcrumbs(() => {
  const tenantSlug =
    tenantStore.selectedTenant?.slug ||
    authStore.selectedTenant?.slug ||
    (route.params.tenantSlug as string | undefined);
  const hubPath = tenantSlug ? `/${tenantSlug}/app/after-sales` : '/app/after-sales';

  return [
    {
      label: tenantStore.selectedTenant?.name || authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    { label: 'After Sales Service', to: hubPath },
    { label: 'Log dropship complaint' },
  ];
});

const orderSearch = ref('');
const orderResults = ref<MockDropshipOrder[]>([]);
const selectedOrder = ref<MockDropshipOrder | null>(null);
const intakeSource = ref<DropshipIntakeSource>('phone');
const reportedTo = ref<DropshipReportedTo>('company');
const reporterName = ref('');
const reporterPhone = ref('');
const reasonCode = ref<AfterSalesReasonCode>('doa');
const intakeNote = ref('');
const submitting = ref(false);

const intakeSourceOptions = [
  { label: 'Phone', value: 'phone' },
  { label: 'WhatsApp', value: 'whatsapp' },
  { label: 'In person', value: 'in_person' },
  { label: 'Email', value: 'email' },
  { label: 'Other', value: 'other' },
];

const reportedToOptions = [
  { label: 'Company', value: 'company' },
  { label: 'Merchant', value: 'merchant' },
];

const reasonOptions = [
  { label: 'DOA', value: 'doa' },
  { label: 'Wrong item', value: 'wrong_item' },
  { label: 'Warranty', value: 'warranty' },
  { label: 'Other', value: 'other' },
];

const canSubmit = computed(
  () => !!selectedOrder.value && !!intakeNote.value.trim(),
);

const onSearchOrders = (query: string | number | null) => {
  orderResults.value = afterSalesRepositoryStub.searchDropshipOrders(String(query ?? ''));
};

const selectOrder = (order: MockDropshipOrder) => {
  selectedOrder.value = order;
  reporterName.value = order.recipient_name;
  reporterPhone.value = order.recipient_phone;
};

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const goToHub = () => {
  void router.push(`${getTenantPrefix()}/app/after-sales`);
};

onMounted(() => {
  onSearchOrders('');
  const orderIdRaw = route.query.orderId;
  const orderId = typeof orderIdRaw === 'string' ? Number(orderIdRaw) : null;
  if (orderId) {
    const order = afterSalesRepositoryStub.getDropshipOrderById(orderId);
    if (order) {
      selectOrder(order);
      orderSearch.value = order.order_no;
    }
  }
});

watch(orderSearch, (val) => onSearchOrders(val));

const onSubmit = async () => {
  const order = selectedOrder.value;
  const tenant = tenantStore.selectedTenant;
  if (!order || !tenant) return;

  submitting.value = true;
  try {
    const parentId = tenant.parent_id ?? tenant.id;
    const created = await afterSalesRepositoryStub.createDropshipCase({
      parent_tenant_id: parentId,
      operating_tenant_id: tenant.id,
      operating_tenant_name: tenant.name,
      shop_order_id: order.id,
      shop_order_no: order.order_no,
      merchant_billing_profile_id: order.merchant_billing_profile_id,
      customer_name: order.merchant_name,
      intake_source: intakeSource.value,
      reported_to: reportedTo.value,
      reporter_name: reporterName.value,
      reporter_phone: reporterPhone.value,
      reason_code: reasonCode.value,
      intake_note: intakeNote.value.trim(),
    });

    showSuccessNotification(`Case ${created.case_no} logged (mock).`);
    void router.push(`${getTenantPrefix()}/app/after-sales/${created.id}`);
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Could not create case.');
  } finally {
    submitting.value = false;
  }
};
</script>

<style scoped>
.intake-stack {
  max-width: 720px;
}

.intake-order-active {
  background: color-mix(in srgb, var(--bw-theme-primary) 10%, var(--bw-theme-surface));
}
</style>
