<template>
  <q-page class="invoice-overview-page page-fixed-layout q-pa-md">
    <div class="overview-container column no-wrap full-height">
      <!-- 1. Top Unified Toolbar: Brand, Billing Profile, Recipient Profile, Invoices List & Search Box -->
      <div class="overview-toolbar floating-surface shadow-1 q-pa-sm q-mb-md">
        <div class="row items-center justify-between q-col-gutter-sm no-wrap">
          <!-- Left: Top Action Buttons -->
          <div class="col-auto row items-center q-gutter-sm">
            <!-- Button 1: Brands -->
            <q-btn
              unelevated
              color="primary"
              icon="ph ph-paint-brush"
              label="Brands"
              no-caps
              class="action-btn text-weight-bold"
              @click="goToBrands"
            />

            <!-- Button 2: Customers -->
            <q-btn
              unelevated
              color="purple-7"
              icon="ph ph-users"
              label="Customers"
              no-caps
              class="action-btn text-weight-bold"
              @click="goToCustomers"
            />
          </div>

          <!-- Right: Outlined Rounded Search Box -->
          <div class="col-auto row items-center q-gutter-sm">
            <q-input
              v-model="searchQuery"
              outlined
              rounded
              dense
              placeholder="Search invoices, buyers, items..."
              class="search-box"
              @keyup.enter="onSearch"
            >
              <template #prepend>
                <q-icon
                  name="ph ph-magnifying-glass"
                  size="18px"
                  class="text-grey-6 cursor-pointer"
                  @click="onSearch"
                />
              </template>
              <template #append v-if="searchQuery">
                <q-icon
                  name="ph ph-x-circle"
                  size="16px"
                  class="cursor-pointer text-grey-5"
                  @click="searchQuery = ''"
                />
              </template>
            </q-input>
          </div>
        </div>
      </div>

      <!-- 2. Main Grid: 4 Normal Standard Size Hub Cards -->
      <div class="row q-col-gutter-sm">
        <!-- Card 1: Wholesale Invoice -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card
            flat
            bordered
            class="hub-type-card cursor-pointer floating-surface q-pa-md column justify-between full-height"
          >
            <!-- Click Menu Popup -->
            <q-menu fit anchor="bottom middle" self="top middle" class="hub-menu-popup shadow-2">
              <q-list dense style="min-width: 200px" class="q-py-xs">
                <q-item clickable v-close-popup class="rounded-borders q-mx-xs" @click="goToCreateWholesale">
                  <q-item-section avatar min-width="28px">
                    <q-icon name="ph ph-plus-circle" color="purple-7" size="18px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-caption">Create Wholesale</q-item-label>
                  </q-item-section>
                </q-item>

                <q-item clickable v-close-popup class="rounded-borders q-mx-xs" @click="goToInvoicesList('wholesale')">
                  <q-item-section avatar min-width="28px">
                    <q-icon name="ph ph-list-dashes" color="grey-8" size="18px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-caption">Wholesale List</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>

            <!-- Card Content -->
            <div>
              <div class="row items-center justify-between q-mb-sm">
                <div class="hub-icon-badge bg-purple-1 text-purple-9">
                  <q-icon name="ph ph-briefcase" size="24px" />
                </div>
                <q-chip dense square color="purple-1" text-color="purple-9" class="text-xxs text-weight-bold q-ma-none">
                  B2B
                </q-chip>
              </div>

              <div class="text-subtitle1 text-weight-bolder text-grey-9">Wholesale</div>
              <p class="text-caption text-grey-7 text-xs q-mt-xs q-mb-none">
                Bulk order billing for verified shops &amp; distributors.
              </p>
            </div>

            <!-- Footer Hint -->
            <div class="row items-center justify-between border-top q-pt-xs q-mt-sm text-purple-9 text-caption text-weight-bold">
              <span class="text-xxs">Create / List</span>
              <q-icon name="ph ph-caret-down" size="14px" />
            </div>
          </q-card>
        </div>

        <!-- Card 2: Retail Invoice -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card
            flat
            bordered
            class="hub-type-card cursor-pointer floating-surface q-pa-md column justify-between full-height"
          >
            <!-- Click Menu Popup -->
            <q-menu fit anchor="bottom middle" self="top middle" class="hub-menu-popup shadow-2">
              <q-list dense style="min-width: 200px" class="q-py-xs">
                <q-item clickable v-close-popup class="rounded-borders q-mx-xs" @click="openCreateRetailDialog('account')">
                  <q-item-section avatar min-width="28px">
                    <q-icon name="ph ph-plus-circle" color="blue-7" size="18px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-caption">Create Retail</q-item-label>
                  </q-item-section>
                </q-item>
                <q-item clickable v-close-popup class="rounded-borders q-mx-xs" @click="goToInvoicesList('retail')">
                  <q-item-section avatar min-width="28px">
                    <q-icon name="ph ph-list-dashes" color="grey-8" size="18px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-caption">Retail List</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>

            <!-- Card Content -->
            <div>
              <div class="row items-center justify-between q-mb-sm">
                <div class="hub-icon-badge bg-blue-1 text-blue-9">
                  <q-icon name="ph ph-tote" size="24px" />
                </div>
                <q-chip dense square color="blue-1" text-color="blue-9" class="text-xxs text-weight-bold q-ma-none">
                  Profile
                </q-chip>
              </div>

              <div class="text-subtitle1 text-weight-bolder text-grey-9">Retail Invoice</div>
              <p class="text-caption text-grey-7 text-xs q-mt-xs q-mb-none">
                Sales linked to customer profiles with credit tracking.
              </p>
            </div>

            <!-- Footer Hint -->
            <div class="row items-center justify-between border-top q-pt-xs q-mt-sm text-blue-9 text-caption text-weight-bold">
              <span class="text-xxs">Create / List</span>
              <q-icon name="ph ph-caret-down" size="14px" />
            </div>
          </q-card>
        </div>

        <!-- Card 3: Walk-in Direct -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card
            flat
            bordered
            class="hub-type-card cursor-pointer floating-surface q-pa-md column justify-between full-height"
          >
            <!-- Click Menu Popup -->
            <q-menu fit anchor="bottom middle" self="top middle" class="hub-menu-popup shadow-2">
              <q-list dense style="min-width: 200px" class="q-py-xs">
                <q-item clickable v-close-popup class="rounded-borders q-mx-xs" @click="openCreateRetailDialog('direct')">
                  <q-item-section avatar min-width="28px">
                    <q-icon name="ph ph-plus-circle" color="positive" size="18px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-caption">Quick POS Sale</q-item-label>
                  </q-item-section>
                </q-item>
                <q-item clickable v-close-popup class="rounded-borders q-mx-xs" @click="goToInvoicesList('retail')">
                  <q-item-section avatar min-width="28px">
                    <q-icon name="ph ph-list-dashes" color="grey-8" size="18px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-caption">Walk-in List</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>

            <!-- Card Content -->
            <div>
              <div class="row items-center justify-between q-mb-sm">
                <div class="hub-icon-badge" style="background: rgba(34, 197, 94, 0.12); color: #22c55e">
                  <q-icon name="ph ph-lightning" size="24px" />
                </div>
                <q-chip dense square color="green-1" text-color="positive" class="text-xxs text-weight-bold q-ma-none">
                  Instant POS
                </q-chip>
              </div>

              <div class="text-subtitle1 text-weight-bolder text-grey-9">Walk-in Direct</div>
              <p class="text-caption text-grey-7 text-xs q-mt-xs q-mb-none">
                Counter sales without profile — instant cash &amp; receipt.
              </p>
            </div>

            <!-- Footer Hint -->
            <div class="row items-center justify-between border-top q-pt-xs q-mt-sm text-positive text-caption text-weight-bold">
              <span class="text-xxs">Create / List</span>
              <q-icon name="ph ph-caret-down" size="14px" />
            </div>
          </q-card>
        </div>

        <!-- Card 4: Dropship Invoice -->
        <div class="col-12 col-sm-6 col-md-3">
          <q-card
            flat
            bordered
            class="hub-type-card cursor-pointer floating-surface q-pa-md column justify-between full-height"
          >
            <!-- Click Menu Popup -->
            <q-menu fit anchor="bottom middle" self="top middle" class="hub-menu-popup shadow-2">
              <q-list dense style="min-width: 200px" class="q-py-xs">
                <q-item clickable v-close-popup class="rounded-borders q-mx-xs" @click="createDropshipDialog = true">
                  <q-item-section avatar min-width="28px">
                    <q-icon name="ph ph-plus-circle" color="orange-8" size="18px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-caption">Create Dropship</q-item-label>
                  </q-item-section>
                </q-item>
                <q-item clickable v-close-popup class="rounded-borders q-mx-xs" @click="goToInvoicesList('dropship')">
                  <q-item-section avatar min-width="28px">
                    <q-icon name="ph ph-list-dashes" color="grey-8" size="18px" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-weight-bold text-caption">Dropship List</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>

            <!-- Card Content -->
            <div>
              <div class="row items-center justify-between q-mb-sm">
                <div class="hub-icon-badge bg-orange-1 text-orange-9">
                  <q-icon name="ph ph-truck" size="24px" />
                </div>
                <q-chip dense square color="orange-1" text-color="orange-9" class="text-xxs text-weight-bold q-ma-none">
                  Delivery
                </q-chip>
              </div>

              <div class="text-subtitle1 text-weight-bolder text-grey-9">Dropship</div>
              <p class="text-caption text-grey-7 text-xs q-mt-xs q-mb-none">
                Reseller fulfillment with recipient details &amp; courier setup.
              </p>
            </div>

            <!-- Footer Hint -->
            <div class="row items-center justify-between border-top q-pt-xs q-mt-sm text-orange-9 text-caption text-weight-bold">
              <span class="text-xxs">Create / List</span>
              <q-icon name="ph ph-caret-down" size="14px" />
            </div>
          </q-card>
        </div>
      </div>
    </div>

    <!-- Dialogs -->
    <CreateGlobalInvoiceDialog
      v-model="createWholesaleDialog"
      :parent-tenant-id="effectiveTenantId"
      @created="onInvoiceCreated"
    />
    <CreateRetailInvoiceDialog
      v-model="createRetailDialog"
      :parent-tenant-id="effectiveTenantId"
      :initial-mode="retailInitialMode"
      @created="onInvoiceCreated"
    />
    <CreateDropshipInvoiceDialog
      v-model="createDropshipDialog"
      :parent-tenant-id="effectiveTenantId"
      @created="onInvoiceCreated"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import CreateGlobalInvoiceDialog from '../components/CreateGlobalInvoiceDialog.vue';
import CreateRetailInvoiceDialog from '../components/CreateRetailInvoiceDialog.vue';
import CreateDropshipInvoiceDialog from '../components/CreateDropshipInvoiceDialog.vue';
import type { GlobalInvoiceCreated } from '../types';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const tenantStore = useTenantStore();

const searchQuery = ref('');

const effectiveTenantId = computed(() => {
  const current =
    tenantStore.selectedTenant ??
    tenantStore.items.find((tenant) => tenant.id === authStore.tenantId) ??
    null;
  if (!current) return authStore.tenantId;
  return current.id;
});

const createWholesaleDialog = ref(false);
const createRetailDialog = ref(false);
const createDropshipDialog = ref(false);
const retailInitialMode = ref<'account' | 'direct'>('account');

const openCreateRetailDialog = (mode: 'account' | 'direct') => {
  retailInitialMode.value = mode;
  createRetailDialog.value = true;
};

const getTenantPrefix = () => {
  const slug = route.params.tenantSlug;
  return typeof slug === 'string' && slug ? `/${slug}` : '';
};

const goToBrands = () => {
  void router.push(`${getTenantPrefix()}/app/sales/invoices/brands`);
};

const goToCustomers = () => {
  void router.push(`${getTenantPrefix()}/app/customers`);
};

const goToCreateWholesale = () => {
  void router.push({
    name: 'app-global-invoices-create-wholesale',
    params: {
      tenantSlug: authStore.tenantSlug || '',
    },
  });
};

const goToInvoicesList = (type?: string) => {
  void router.push({
    path: `${getTenantPrefix()}/app/sales/invoices/list`,
    ...(type ? { query: { type } } : {}),
  });
};


const onSearch = () => {
  if (!searchQuery.value.trim()) {
    goToInvoicesList();
    return;
  }
  void router.push({
    path: `${getTenantPrefix()}/app/sales/invoices/list`,
    query: { search: searchQuery.value.trim() },
  });
};

const onInvoiceCreated = (invoice: GlobalInvoiceCreated) => {
  void router.push({
    name: 'app-global-invoice-details-page',
    params: {
      tenantSlug: authStore.tenantSlug,
      id: invoice.id,
    },
  });
};
</script>

<style scoped>
.invoice-overview-page {
  background: var(--bw-brand-base, #eef0f4);
  height: calc(100vh - 55px);
  overflow: hidden;
}

.overview-container {
  height: 100%;
}

.overview-toolbar {
  border-radius: 8px;
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.8);
}

.action-btn {
  border-radius: 8px !important;
}

.search-box {
  width: 280px;
}

.scroll-container {
  min-height: 0;
  flex: 1 1 0%;
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: 1px solid rgba(226, 232, 240, 0.8);
  box-shadow: 0 4px 12px -2px rgba(51, 65, 85, 0.05);
}

.hub-type-card {
  border-radius: 8px;
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.9);
  transition: all 0.2s ease-in-out;
}

.hub-type-card:hover {
  transform: translateY(-3px);
  border-color: rgba(59, 130, 246, 0.45);
  box-shadow: 0 16px 32px -6px rgba(51, 65, 85, 0.12), 0 8px 16px -4px rgba(51, 65, 85, 0.06);
}

.hub-icon-badge {
  width: 44px;
  height: 44px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.hub-menu-popup {
  border-radius: 8px;
  border: 1px solid rgba(226, 232, 240, 0.9);
}

.border-top {
  border-top: 1px solid rgba(226, 232, 240, 0.8);
}

.text-xxs {
  font-size: 11px;
  line-height: 14px;
}

/* Dark mode adjustments */
body.body--dark .invoice-overview-page {
  background: #171717;
}

body.body--dark .floating-surface,
body.body--dark .overview-toolbar,
body.body--dark .hub-type-card {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

body.body--dark .border-top,
body.body--dark .hub-menu-popup {
  border-color: #2e2e2e;
}
</style>

