<template>
  <q-page class="q-pa-md thrift-settings-page">
    <div class="bw-page__stack">
      <!-- Header -->
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm">
              <div class="row items-center q-gutter-sm">
                <q-btn flat round dense icon="arrow_back" color="primary" @click="goBack" />
                <div>
                  <div class="text-h6 text-weight-bold">Thrift Stock Settings</div>
                  <div class="text-caption text-grey-8">Configure defaults for fast stock uploads and SKU auto-generation</div>
                </div>
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <PageInitialLoader v-if="pageLoading" />

      <!-- Settings Card -->
      <q-card v-else flat class="floating-surface shadow-1 q-pa-md" style="max-width: 600px;">
        <q-card-section class="q-pt-none">
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md">Quick Upload Defaults</div>
          
          <q-form @submit="saveSettings" class="q-gutter-md">
            <div>
              <label class="text-caption text-weight-medium text-grey-8">Default Shipment *</label>
              <q-select
                v-model="form.default_shipment_id"
                outlined
                dense
                :options="shipments"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                class="soft-input q-mt-xs"
                :rules="[val => !!val || 'Required']"
                @update:model-value="onShipmentChange"
              />
            </div>

            <div>
              <label class="text-caption text-weight-medium text-grey-8">Default Box Number/Name</label>
              <q-select
                v-model="form.default_box_id"
                outlined
                dense
                :options="filteredBoxes"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                class="soft-input q-mt-xs"
                clearable
                placeholder="No default box (optional)"
              />
            </div>

            <div>
              <label class="text-caption text-weight-medium text-grey-8">Default Origin Purchase Price (Foreign Currency) *</label>
              <q-input
                v-model.number="form.default_origin_purchase_price"
                type="number"
                step="0.01"
                outlined
                dense
                class="soft-input q-mt-xs"
                prefix="Price:"
                :rules="[val => val >= 0 || 'Cannot be negative']"
              />
            </div>

            <div class="row justify-end q-mt-lg">
              <q-btn
                type="submit"
                color="primary"
                no-caps
                class="pill-btn px-md"
                label="Save Defaults"
                :loading="saving"
              />
            </div>
          </q-form>
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftStore } from 'src/modules/thrift/stores/thriftStore';
import { useQuasar } from 'quasar';
import { supabase } from 'src/boot/supabase';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';

const $q = useQuasar();
const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const thriftStore = useThriftStore();

const saving = ref(false);
const pageLoading = ref(true);
const shipments = ref<Array<{ id: number; name: string }>>([]);

const form = ref({
  default_shipment_id: null as number | null,
  default_box_id: null as number | null,
  default_purchase_price: 0,
  default_origin_purchase_price: 0,
});

const filteredBoxes = computed(() => {
  if (!form.value.default_shipment_id) return [];
  return thriftStore.boxes.filter(b => b.shipment_id === form.value.default_shipment_id);
});

function onShipmentChange() {
  form.value.default_box_id = null;
}

function goBack() {
  const tenantSlug = route.params.tenantSlug || authStore.tenantSlug;
  const slugStr = Array.isArray(tenantSlug) ? tenantSlug[0] : (tenantSlug || '');
  void router.push(slugStr ? `/${slugStr}/app/thrift/stocks` : '/app/thrift/stocks');
}

async function loadShipments() {
  if (!authStore.tenantId) return;
  const { data } = await supabase
    .from('thrift_shipments')
    .select('id, name')
    .eq('tenant_id', authStore.tenantId)
    .order('name', { ascending: true });
  shipments.value = (data || []) as Array<{ id: number; name: string }>;
}

async function loadSettings() {
  if (!authStore.tenantId) return;
  try {
    const { data, error } = await supabase
      .from('thrift_stock_settings')
      .select('*')
      .eq('tenant_id', authStore.tenantId)
      .maybeSingle();

    if (error) throw error;
    if (data) {
      form.value = {
        default_shipment_id: data.default_shipment_id,
        default_box_id: data.default_box_id,
        default_purchase_price: Number(data.default_purchase_price),
        default_origin_purchase_price: Number(data.default_origin_purchase_price || 0),
      };
    }
  } catch (err: unknown) {
    console.error('Failed to load settings:', err);
  }
}

async function saveSettings() {
  if (!authStore.tenantId) return;
  saving.value = true;
  try {
    const payload = {
      tenant_id: authStore.tenantId,
      default_shipment_id: form.value.default_shipment_id,
      default_box_id: form.value.default_box_id,
      default_purchase_price: form.value.default_purchase_price,
      default_origin_purchase_price: form.value.default_origin_purchase_price,
    };

    const { error } = await supabase
      .from('thrift_stock_settings')
      .upsert(payload);

    if (error) throw error;

    $q.notify({
      type: 'positive',
      message: 'Defaults saved successfully',
    });
    goBack();
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: (err as Error).message || 'Saving failed',
    });
  } finally {
    saving.value = false;
  }
}

onMounted(async () => {
  if (authStore.tenantId) {
    pageLoading.value = true;
    try {
      await Promise.all([
        loadShipments(),
        thriftStore.loadModuleData(authStore.tenantId),
        loadSettings(),
      ]);
    } finally {
      pageLoading.value = false;
    }
  } else {
    pageLoading.value = false;
  }
});
</script>

<style scoped>
.thrift-settings-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.pill-btn {
  border-radius: 999px;
}

.px-md {
  padding-left: 16px;
  padding-right: 16px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
