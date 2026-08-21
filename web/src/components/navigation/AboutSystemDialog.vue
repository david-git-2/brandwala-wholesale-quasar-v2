<template>
  <q-dialog :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <q-card class="about-system-dialog" style="width: 620px; max-width: 95vw; border-radius: 14px">
      <!-- Header banner -->
      <div class="about-header q-pa-lg text-white">
        <div class="row items-center justify-between no-wrap">
          <div class="row items-center q-gutter-x-md no-wrap">
            <q-avatar size="48px" class="bg-white text-primary shadow-2">
              <q-icon name="ph ph-buildings" size="26px" />
            </q-avatar>
            <div>
              <div class="row items-center q-gutter-x-xs">
                <span class="text-h6 text-weight-bold">Brandwala Commerce OS</span>
                <q-badge color="white" text-color="primary" class="text-weight-bold text-caption q-ml-xs">v2.0</q-badge>
              </div>
              <div class="text-caption text-blue-1 text-weight-medium">
                Enterprise Wholesale, Supply Chain & Financial ERP
              </div>
            </div>
          </div>
          <q-btn flat round dense icon="ph ph-x" color="white" v-close-popup />
        </div>
      </div>

      <!-- Content -->
      <q-card-section class="q-pa-md q-gutter-y-md">
        <!-- Overview summary -->
        <p class="text-body2 text-grey-8 q-mb-none line-height-relaxed">
          Brandwala is an integrated enterprise operations platform unifying international procurement,
          serialized multi-warehouse inventory, B2B wholesale distribution, retail commerce, and real-time subledger accounting.
        </p>

        <!-- Core Modules Grid -->
        <div class="q-gutter-y-sm">
          <div class="text-overline text-grey-7">Core Capabilities</div>
          
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6" v-for="mod in modules" :key="mod.title">
              <q-card flat bordered class="capability-card q-pa-sm full-height">
                <div class="row items-start q-gutter-x-sm no-wrap">
                  <q-avatar size="32px" :color="mod.avatarBg" :text-color="mod.avatarColor" class="q-mt-xs">
                    <q-icon :name="mod.icon" size="18px" />
                  </q-avatar>
                  <div>
                    <div class="text-subtitle2 text-weight-bold text-grey-9">{{ mod.title }}</div>
                    <div class="text-caption text-grey-7">{{ mod.description }}</div>
                  </div>
                </div>
              </q-card>
            </div>
          </div>
        </div>

        <!-- Tech & Architecture Details -->
        <div class="architecture-box q-pa-sm rounded-borders bg-grey-1 border">
          <div class="row items-center justify-between text-caption text-grey-7">
            <span class="row items-center q-gutter-x-xs">
              <q-icon name="ph ph-database" size="14px" color="primary" />
              <span><strong>Data Engine:</strong> PostgreSQL PL/pgSQL Atomic RPCs & RLS</span>
            </span>
            <span class="row items-center q-gutter-x-xs">
              <q-icon name="ph ph-code" size="14px" color="secondary" />
              <span><strong>Frontend:</strong> Vue 3 + Quasar UI</span>
            </span>
          </div>
        </div>
      </q-card-section>

      <!-- Actions -->
      <q-separator />
      <q-card-actions align="right" class="q-pa-sm bg-grey-1">
        <q-btn flat no-caps label="Close" color="grey-8" v-close-popup class="q-px-md" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const modules = [
  {
    title: 'Procurement & SCM',
    icon: 'ph ph-boat',
    avatarBg: 'blue-1',
    avatarColor: 'primary',
    description: 'Stages 7A–14B shipment pipeline, vendor management & automated landed costing.',
  },
  {
    title: 'WMS & Serialized Stock',
    icon: 'ph ph-barcode',
    avatarBg: 'amber-1',
    avatarColor: 'amber-9',
    description: 'Barcode & tag-level tracking, thrift sorting & grading, multi-warehouse storage.',
  },
  {
    title: 'Wholesale OMS & Billing',
    icon: 'ph ph-receipt',
    avatarBg: 'teal-1',
    avatarColor: 'teal-9',
    description: 'Tiered wholesale invoicing, MOQ rules, customer credit & return reconciliation.',
  },
  {
    title: 'Subledger & Wallets',
    icon: 'ph ph-wallet',
    avatarBg: 'deep-purple-1',
    avatarColor: 'deep-purple-8',
    description: 'Real-time double-entry ledger transactions, customer/vendor balances & investor capital.',
  },
  {
    title: 'Multi-Channel Retail',
    icon: 'ph ph-storefront',
    avatarBg: 'cyan-1',
    avatarColor: 'cyan-9',
    description: 'Retail order fulfillment, deal/meal bundling, member tiers & localized settings.',
  },
  {
    title: 'Multi-Tenant Security',
    icon: 'ph ph-shield-check',
    avatarBg: 'green-1',
    avatarColor: 'green-9',
    description: 'Tenant isolation with granular Role-Based Access Control and secure stakeholder portals.',
  },
];
</script>

<style scoped>
.about-header {
  background: linear-gradient(135deg, #1976d2 0%, #0d47a1 100%);
}

.capability-card {
  border-color: #e0e0e0;
  border-radius: 8px;
  background-color: #ffffff;
  transition: all 0.2s ease;
}

.capability-card:hover {
  border-color: #1976d2;
  box-shadow: 0 2px 8px rgba(25, 118, 210, 0.08);
}

.architecture-box {
  border: 1px dashed #cfd8dc;
}
</style>
