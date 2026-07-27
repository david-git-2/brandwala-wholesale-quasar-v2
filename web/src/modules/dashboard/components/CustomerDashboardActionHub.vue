<template>
  <div>
    <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-sm q-mb-md-md">{{ $t('customer_dashboard.shortcuts_title') }}</div>
    <div class="row q-col-gutter-md">
      <div class="col-12 col-sm-6">
        <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="$emit('go-browse')">
          <q-item class="q-pa-none">
            <q-item-section avatar>
              <q-avatar color="blue-1" text-color="blue-7" icon="ph ph-storefront" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shortcut_catalogs_title') }}</q-item-label>
              <q-item-label caption class="text-grey-6">{{ $t('customer_dashboard.shortcut_catalogs_sub') }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-card>
      </div>

      <div class="col-12 col-sm-6">
        <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="$emit('go-orders')">
          <q-item class="q-pa-none">
            <q-item-section avatar>
              <q-avatar color="green-1" text-color="green-7" icon="ph ph-receipt" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shortcut_orders_title') }}</q-item-label>
              <q-item-label caption class="text-grey-6">{{ $t('customer_dashboard.shortcut_orders_sub') }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-card>
      </div>

      <div class="col-12 col-sm-6">
        <q-card
          flat
          bordered
          class="action-card cursor-pointer card-hover q-pa-md"
          @click="$emit('view-latest-order')"
        >
          <q-item class="q-pa-none">
            <q-item-section avatar>
              <q-avatar color="amber-1" text-color="amber-9" icon="ph ph-clock-counter-clockwise" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shortcut_latest_order_title') }}</q-item-label>
              <q-item-label caption class="text-grey-6">
                {{ latestOrderLabel }}
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-card>
      </div>

      <div class="col-12 col-sm-6">
        <q-card flat bordered class="action-card cursor-pointer card-hover q-pa-md" @click="$emit('go-documentation')">
          <q-item class="q-pa-none">
            <q-item-section avatar>
              <q-avatar color="purple-1" text-color="purple-7" icon="ph ph-question" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-subtitle2 text-weight-bold text-grey-9">{{ $t('customer_dashboard.shortcut_help_title') }}</q-item-label>
              <q-item-label caption class="text-grey-6">{{ $t('customer_dashboard.shortcut_help_sub') }}</q-item-label>
            </q-item-section>
          </q-item>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  latestOrderLabel: string;
}>();

defineEmits<{
  (e: 'go-browse'): void;
  (e: 'go-orders'): void;
  (e: 'view-latest-order'): void;
  (e: 'go-documentation'): void;
}>();
</script>

<style scoped>
.action-card {
  border-radius: 12px;
  background: var(--bw-theme-surface, #ffffff);
  border: 1px solid var(--bw-theme-border, #e0e0e0);
}

.card-hover {
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease, border-color 0.2s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: var(--bw-theme-shadow, 0 4px 12px rgba(0, 0, 0, 0.05));
  border-color: var(--q-primary);
}
</style>
