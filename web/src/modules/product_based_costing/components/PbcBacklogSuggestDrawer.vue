<template>
  <q-drawer
    v-model="isOpen"
    side="right"
    overlay
    elevated
    :width="480"
    class="pbc-backlog-drawer bg-white"
  >
    <div class="column full-height">
      <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
        <div>
          <div class="text-subtitle1 text-weight-bold row items-center">
            <q-icon name="ph ph-tray" class="q-mr-xs text-primary" size="20px" />
            {{ $t('product_based_costing.still_needed_title') }}
          </div>
          <div class="text-caption text-grey-7">
            {{ $t('product_based_costing.still_needed_subtitle') }}
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense @click="isOpen = false" />
      </div>

      <q-separator />

      <div class="col scroll q-pa-md">
        <div v-if="loading" class="q-gutter-y-md">
          <q-card v-for="n in 3" :key="n" flat bordered class="q-pa-sm">
            <q-skeleton type="text" width="60%" />
            <q-skeleton type="text" width="40%" />
          </q-card>
        </div>

        <div
          v-else-if="items.length === 0 && alreadyOnFileItems.length === 0"
          class="text-center text-grey-6 q-pa-xl"
        >
          <q-icon name="ph ph-check-circle" size="48px" class="q-mb-sm text-grey-4" />
          <div class="text-body1 text-weight-medium">
            {{ $t('product_based_costing.nothing_left_to_add') }}
          </div>
        </div>

        <template v-else>
          <template v-if="items.length">
            <div class="text-caption text-weight-medium text-grey-7 q-mb-xs">
              {{ $t('product_based_costing.not_on_file_yet') }}
            </div>
            <div class="row items-center justify-between q-mb-sm">
              <q-checkbox
                v-model="allSelected"
                :label="$t('product_based_costing.select_all')"
                dense
                class="text-weight-medium"
              />
              <span class="text-caption text-grey-7">{{
                $t('product_based_costing.selected_of_total', {
                  selected: selectedIds.length,
                  total: items.length,
                })
              }}</span>
            </div>

            <div class="q-gutter-y-sm q-mb-md">
              <q-card
                v-for="item in items"
                :key="item.id"
                flat
                bordered
                class="backlog-item-card cursor-pointer"
                :class="{ 'bg-blue-1 border-primary': selectedIds.includes(item.id) }"
                @click="toggleSelect(item.id)"
              >
                <q-card-section class="q-pa-sm row items-center q-col-gutter-sm">
                  <div class="col-auto" @click.stop>
                    <q-checkbox
                      :model-value="selectedIds.includes(item.id)"
                      dense
                      @update:model-value="toggleSelect(item.id)"
                    />
                  </div>

                  <div class="col-auto">
                    <q-avatar square size="42px" class="bg-grey-2 rounded-borders">
                      <img v-if="item.image_url" :src="item.image_url" :alt="item.name" />
                      <q-icon v-else name="ph ph-package" color="grey-6" />
                    </q-avatar>
                  </div>

                  <div class="col">
                    <div class="text-subtitle2 text-weight-bold ellipsis">{{ item.name }}</div>
                    <div class="row items-center q-gutter-x-xs text-caption text-grey-7">
                      <span v-if="item.barcode">BC: {{ item.barcode }}</span>
                      <span v-if="item.barcode && item.price_gbp">•</span>
                      <span v-if="item.price_gbp">£{{ item.price_gbp }}</span>
                    </div>
                  </div>

                  <div class="col-auto text-right">
                    <q-badge color="orange-9" class="text-weight-bold q-px-sm q-py-xs">
                      {{ $t('product_based_costing.qty_badge', { qty: item.open_quantity }) }}
                    </q-badge>
                  </div>
                </q-card-section>
              </q-card>
            </div>
          </template>

          <template v-if="alreadyOnFileItems.length">
            <div class="text-caption text-weight-medium text-grey-7 q-mb-sm">
              {{ $t('product_based_costing.already_on_file') }}
            </div>
            <div class="q-gutter-y-sm">
              <q-card
                v-for="item in alreadyOnFileItems"
                :key="item.id"
                flat
                bordered
                class="backlog-item-card backlog-item-card--on-file"
              >
                <q-card-section class="q-pa-sm row items-center q-col-gutter-sm">
                  <div class="col-auto">
                    <q-avatar square size="42px" class="bg-grey-2 rounded-borders">
                      <img v-if="item.image_url" :src="item.image_url" :alt="item.name" />
                      <q-icon v-else name="ph ph-package" color="grey-6" />
                    </q-avatar>
                  </div>

                  <div class="col">
                    <div class="text-subtitle2 text-weight-bold ellipsis">{{ item.name }}</div>
                    <div class="row items-center q-gutter-x-xs text-caption text-grey-7">
                      <span v-if="item.barcode">BC: {{ item.barcode }}</span>
                      <span v-if="item.barcode && item.price_gbp">•</span>
                      <span v-if="item.price_gbp">£{{ item.price_gbp }}</span>
                    </div>
                  </div>

                  <div class="col-auto text-right">
                    <q-badge outline color="grey-7" class="q-px-sm q-py-xs">
                      {{ $t('product_based_costing.on_this_file') }}
                    </q-badge>
                  </div>
                </q-card-section>
              </q-card>
            </div>
          </template>
        </template>
      </div>

      <q-separator />

      <div v-if="items.length > 0" class="q-pa-md bg-grey-1 row items-center justify-between">
        <q-btn
          flat
          dense
          no-caps
          :label="$t('product_based_costing.add_all')"
          color="primary"
          :loading="adding"
          @click="onAddAll"
        />
        <q-btn
          unelevated
          no-caps
          color="primary"
          :label="$t('product_based_costing.add_selected', { count: selectedIds.length })"
          :disable="selectedIds.length === 0"
          :loading="adding"
          @click="onAddSelected"
        />
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';

export interface BacklogItem {
  id: number;
  tenant_id: number;
  billing_profile_id: number;
  product_id: number;
  open_quantity: number;
  name: string;
  image_url: string | null;
  barcode: string | null;
  product_code: string | null;
  price_gbp: number | null;
  product_weight: number | null;
  package_weight: number | null;
  note: string | null;
}

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    items: BacklogItem[];
    alreadyOnFileItems?: BacklogItem[];
    loading?: boolean;
    adding?: boolean;
  }>(),
  {
    alreadyOnFileItems: () => [],
    loading: false,
    adding: false,
  },
);

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'add', backlogIds: number[]): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val),
});

const selectedIds = ref<number[]>([]);

watch(
  () => props.items,
  (newItems) => {
    selectedIds.value = newItems.map((i) => i.id);
  },
  { immediate: true },
);

const allSelected = computed({
  get: () => props.items.length > 0 && selectedIds.value.length === props.items.length,
  set: (val: boolean) => {
    if (val) {
      selectedIds.value = props.items.map((i) => i.id);
    } else {
      selectedIds.value = [];
    }
  },
});

function toggleSelect(id: number) {
  const idx = selectedIds.value.indexOf(id);
  if (idx > -1) {
    selectedIds.value.splice(idx, 1);
  } else {
    selectedIds.value.push(id);
  }
}

function onAddSelected() {
  if (selectedIds.value.length === 0) return;
  emit('add', [...selectedIds.value]);
}

function onAddAll() {
  const all = props.items.map((i) => i.id);
  if (all.length === 0) return;
  emit('add', all);
}
</script>

<style scoped>
.backlog-item-card {
  transition: all 0.2s ease;
}
.backlog-item-card:not(.backlog-item-card--on-file):hover {
  border-color: var(--q-primary);
}
.backlog-item-card--on-file {
  opacity: 0.72;
}
</style>
