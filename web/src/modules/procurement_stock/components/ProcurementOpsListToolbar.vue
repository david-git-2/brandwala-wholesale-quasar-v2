<template>
  <q-card flat bordered class="q-pa-xs flex-shrink-0 procurement-ops-toolbar">
    <div
      class="row items-center q-col-gutter-x-xs q-px-xs procurement-ops-toolbar__primary no-wrap"
      :class="{ 'procurement-ops-toolbar__primary--inline-pills': inlinePills && $slots.pills }"
    >
      <div
        v-if="inlinePills && $slots.pills"
        class="col min-width-0 procurement-ops-toolbar__pills procurement-ops-toolbar__pills--inline"
      >
        <slot name="pills" />
      </div>

      <div
        class="row items-center q-col-gutter-x-xs flex-shrink-0 procurement-ops-toolbar__actions"
        :class="{ 'col-grow': !inlinePills }"
      >
        <q-btn
          v-if="iconSearch && !searchFieldOpen"
          flat
          round
          dense
          icon="ph ph-magnifying-glass"
          class="text-slate-500 flex-shrink-0"
          aria-label="Search"
          @click="openSearchField"
        >
          <q-tooltip>{{ searchPlaceholder }}</q-tooltip>
        </q-btn>
        <q-input
          v-else
          ref="searchInputRef"
          :model-value="search"
          outlined
          dense
          debounce="300"
          clearable
          style="min-width: 220px"
          class="dense-search-input procurement-ops-toolbar__search"
          :class="{ 'col-grow': !inlinePills }"
          :placeholder="searchPlaceholder"
          @update:model-value="onSearchInput"
          @blur="onSearchBlur"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="16px" class="text-slate-400" />
          </template>
        </q-input>
        <slot name="toolbar-extra" />
        <q-btn
          flat
          round
          dense
          icon="ph ph-funnel"
          class="text-slate-500 flex-shrink-0"
          @click="emit('open-filters')"
        >
          <q-badge v-if="filterCount > 0" color="primary" rounded floating>
            {{ filterCount }}
          </q-badge>
          <q-tooltip>Filter options</q-tooltip>
        </q-btn>
        <slot name="trailing" />
      </div>
    </div>

    <div
      v-if="$slots.pills && !inlinePills"
      class="row items-center q-mt-xs q-px-xs procurement-ops-toolbar__pills"
    >
      <slot name="pills" />
    </div>

    <div
      v-if="inlinePills && $slots['pills-secondary']"
      class="row items-center q-mt-xs q-px-xs procurement-ops-toolbar__pills procurement-ops-toolbar__pills--secondary"
    >
      <slot name="pills-secondary" />
    </div>

    <div v-if="$slots.chips" class="row items-center q-mt-xs q-px-xs q-gutter-xs wrap procurement-ops-toolbar__chips">
      <slot name="chips" />
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { nextTick, ref, watch } from 'vue';
import type { QInput } from 'quasar';

const props = withDefaults(
  defineProps<{
    search: string | null | undefined;
    searchPlaceholder?: string;
    filterCount?: number;
    /** Show a search icon first; expand to input on click (shipment list). */
    iconSearch?: boolean;
    /** Status tabs on the same row as search and actions. */
    inlinePills?: boolean;
  }>(),
  {
    searchPlaceholder: 'Search…',
    filterCount: 0,
    iconSearch: false,
    inlinePills: false,
  },
);

const emit = defineEmits<{
  'update:search': [value: string | null | undefined];
  'open-filters': [];
}>();

const searchFieldOpen = ref(!props.iconSearch);
const searchInputRef = ref<QInput | null>(null);

watch(
  () => props.search,
  (value) => {
    if (props.iconSearch && (value ?? '').trim()) {
      searchFieldOpen.value = true;
    }
  },
);

const openSearchField = () => {
  searchFieldOpen.value = true;
  void nextTick(() => {
    searchInputRef.value?.focus();
  });
};

const onSearchInput = (value: string | number | null) => {
  emit('update:search', value == null ? value : String(value));
};

const onSearchBlur = () => {
  if (!props.iconSearch) return;
  if (!(props.search ?? '').trim()) {
    searchFieldOpen.value = false;
  }
};
</script>

<style scoped>
.procurement-ops-toolbar {
  background: var(--tf-neutral-surface, #ffffff);
  border-radius: var(--tf-radius-sm, 8px);
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
}

.procurement-ops-toolbar__primary {
  flex-wrap: nowrap;
  min-width: 0;
}

.procurement-ops-toolbar__search {
  min-width: 0;
  max-width: 100%;
}

.procurement-ops-toolbar__pills {
  min-width: 0;
  overflow-x: auto;
  overflow-y: hidden;
  flex-wrap: nowrap;
  scrollbar-width: thin;
}

.procurement-ops-toolbar__pills--inline {
  flex: 1 1 auto;
  margin-right: 4px;
}

.procurement-ops-toolbar__primary--inline-pills .procurement-ops-toolbar__actions {
  margin-left: auto;
}

.procurement-ops-toolbar__actions {
  min-width: 0;
  flex-wrap: nowrap;
}

.procurement-ops-toolbar__pills--inline + .procurement-ops-toolbar__actions .procurement-ops-toolbar__search {
  flex: 0 1 220px;
  max-width: 280px;
}

.text-slate-400 {
  color: var(--tf-neutral-chrome, #64748b);
}

</style>
