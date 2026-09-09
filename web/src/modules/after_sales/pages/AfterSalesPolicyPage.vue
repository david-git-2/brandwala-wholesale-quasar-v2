<template>
  <q-page class="bw-page after-sales-policy-page">
    <section class="bw-page__stack">
      <q-banner v-if="!isParentWorkspace" rounded class="after-sales-note-banner">
        Managed by parent company. You can view policy here but cannot edit it.
      </q-banner>

      <div v-if="isLoading" class="policy-skeleton">
        <q-skeleton type="rect" height="88px" class="rounded-borders" />
        <q-skeleton type="rect" height="420px" class="rounded-borders" />
      </div>

      <template v-else-if="localPolicy">
        <q-card flat bordered class="q-pa-md">
          <div class="row q-col-gutter-md">
            <div class="col-12 col-md-6">
              <q-input
                v-model="localPolicy.name"
                outlined
                dense
                label="Policy name"
                :readonly="!isParentWorkspace"
              />
            </div>
            <div class="col-12 col-md-4">
              <q-select
                v-model="localPolicy.program"
                :options="programOptions"
                outlined
                dense
                emit-value
                map-options
                label="Program type"
                :readonly="!isCreateMode || !isParentWorkspace"
                :disable="!isCreateMode || !isParentWorkspace"
              />
            </div>
            <div class="col-12 col-md-2 flex items-center">
              <q-toggle
                v-model="localPolicy.is_active"
                label="Active"
                :disable="!isParentWorkspace"
              />
            </div>
          </div>
        </q-card>

        <AfterSalesPolicyProgramCard
          :program="localPolicy"
          :readonly="!isParentWorkspace"
          @update:program="onPolicyUpdate"
        />

        <div v-if="isParentWorkspace" class="bw-inline-actions" style="justify-content: flex-end">
          <q-btn flat no-caps label="Cancel" style="border-radius: 8px" @click="goToList" />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-floppy-disk"
            :label="isCreateMode ? 'Create policy' : 'Save policy'"
            style="border-radius: 8px"
            :loading="saveMutation.isPending.value"
            :disable="!localPolicy.name.trim()"
            @click="onSave"
          />
        </div>
      </template>

      <q-banner v-else rounded class="after-sales-warn-banner">
        Policy not found.
      </q-banner>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useInvoiceWorkspace } from 'src/modules/sales_invoice/composables/useInvoiceWorkspace';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback';
import AfterSalesPolicyProgramCard from '../components/AfterSalesPolicyProgramCard.vue';
import {
  useAfterSalesPolicyQuery,
  useSaveAfterSalesPolicyMutation,
} from '../composables/useAfterSalesCaseMutations';
import { createBlankAfterSalesPolicy } from '../fixtures/mockAfterSales';
import type { AfterSalesPolicyProgram, AfterSalesProgram } from '../types/afterSales.types';

const props = defineProps<{
  policyId?: string | null;
  createMode?: boolean;
}>();

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const tenantStore = useTenantStore();
const { isParentTenant: isParentWorkspace } = useInvoiceWorkspace();

const isCreateMode = computed(() => props.createMode === true || route.name === 'app-after-sales-policy-new');

const parentTenantId = computed(() => {
  const tenant = tenantStore.selectedTenant;
  if (!tenant) return null;
  return tenant.parent_id ?? tenant.id;
});

const resolvedPolicyId = computed(() => {
  if (isCreateMode.value) return null;
  return props.policyId ?? (route.params.policyId as string | undefined) ?? null;
});

const policyQuery = useAfterSalesPolicyQuery(resolvedPolicyId);
const saveMutation = useSaveAfterSalesPolicyMutation(parentTenantId);

const localPolicy = ref<AfterSalesPolicyProgram | null>(null);

const isLoading = computed(() => !isCreateMode.value && policyQuery.isLoading.value);

const pageTitle = computed(() => {
  if (isCreateMode.value) return 'Create return policy';
  return localPolicy.value?.name || 'Return policy';
});

usePageBreadcrumbs(() => {
  const tenantSlug =
    tenantStore.selectedTenant?.slug ||
    authStore.selectedTenant?.slug ||
    (route.params.tenantSlug as string | undefined);
  const hubPath = tenantSlug ? `/${tenantSlug}/app/after-sales` : '/app/after-sales';
  const listPath = tenantSlug ? `/${tenantSlug}/app/after-sales/policy` : '/app/after-sales/policy';

  return [
    {
      label: tenantStore.selectedTenant?.name || authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    { label: 'After Sales Service', to: hubPath },
    { label: 'Return policies', to: listPath },
    { label: isCreateMode.value ? 'Create policy' : pageTitle.value },
  ];
});

const programOptions: { label: string; value: AfterSalesProgram }[] = [
  { label: 'Return credit', value: 'return_credit' },
  { label: 'DOA', value: 'doa' },
  { label: 'Replacement', value: 'replacement' },
  { label: 'Warranty', value: 'warranty' },
];

watch(
  [isCreateMode, parentTenantId, () => policyQuery.data.value],
  () => {
    if (isCreateMode.value) {
      if (!parentTenantId.value) return;
      localPolicy.value = createBlankAfterSalesPolicy(parentTenantId.value);
      return;
    }

    const data = policyQuery.data.value;
    if (!data) {
      localPolicy.value = null;
      return;
    }

    localPolicy.value = {
      ...data,
      allowed_outcomes: [...data.allowed_outcomes],
    };
  },
  { immediate: true },
);

const onPolicyUpdate = (value: AfterSalesPolicyProgram) => {
  localPolicy.value = value;
};

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const goToList = () => {
  void router.push(`${getTenantPrefix()}/app/after-sales/policy`);
};

const onSave = async () => {
  if (!localPolicy.value) return;

  try {
    const saved = await saveMutation.mutateAsync({
      ...localPolicy.value,
      name: localPolicy.value.name.trim(),
      allowed_outcomes: [...localPolicy.value.allowed_outcomes],
    });
    showSuccessNotification(
      isCreateMode.value ? 'Return policy created (mock session).' : 'Return policy saved (mock session).',
    );
    void router.replace(`${getTenantPrefix()}/app/after-sales/policy/${saved.id}`);
  } catch (e) {
    showWarningDialog(e instanceof Error ? e.message : 'Save failed.');
  }
};
</script>

<style scoped>
.after-sales-note-banner {
  background: color-mix(in srgb, var(--bw-theme-muted) 12%, var(--bw-theme-surface));
  color: var(--bw-theme-ink);
  border: 1px solid var(--bw-theme-border);
}

.after-sales-warn-banner {
  background: color-mix(in srgb, var(--q-warning) 14%, var(--bw-theme-surface));
  color: var(--bw-theme-ink);
  border: 1px solid var(--bw-theme-border);
}

.policy-skeleton {
  display: grid;
  gap: 1rem;
}
</style>
