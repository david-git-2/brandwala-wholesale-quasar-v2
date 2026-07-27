<template>
  <div class="q-gutter-y-md">
    <!-- Toolbar & Search Card -->
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <!-- Search bar -->
        <div class="col-xs-12 col-sm-8 col-md-6 row no-wrap q-gutter-sm">
          <q-input
            v-model="searchModel"
            filled
            dense
            type="text"
            class="soft-input col"
            :placeholder="$t('shop.search_placeholder')"
            clearable
            @keydown.enter="$emit('search')"
            @clear="$emit('search')"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
          <q-btn
            unelevated
            no-caps
            color="primary"
            :label="$t('shop.search')"
            class="pill-btn"
            @click="$emit('search')"
          />
        </div>

        <!-- Filter toggles & Active category indicator badge -->
        <div
          v-if="!$q.screen.xs || category"
          class="col-xs-12 col-sm-4 col-md-6 text-right row items-center justify-end q-gutter-sm"
        >
          <q-badge v-if="category" color="primary" outline class="q-pa-xs">
            Category: {{ category }}
          </q-badge>
          <q-btn
            v-if="!$q.screen.xs"
            flat
            round
            dense
            color="primary"
            icon="ph ph-funnel-simple"
            @click="$emit('open-filter')"
          >
            <q-badge v-if="activeFilterCount > 0" color="primary" floating rounded>
              {{ activeFilterCount }}
            </q-badge>
            <q-tooltip>{{ $t('shop.filters') }}</q-tooltip>
          </q-btn>
        </div>
      </div>
    </q-card>

    <!-- Active Filters Chips -->
    <div v-if="hasActiveFilters" class="row items-center q-gutter-xs active-filters-section">
      <span class="text-caption text-weight-medium text-grey-7 q-mr-xs">
        {{ $t('shop.active_filters') }}
      </span>
      <q-chip
        v-if="searchModel"
        removable
        outline
        color="primary"
        text-color="primary"
        size="sm"
        class="q-ma-xs"
        @remove="searchModel = ''"
      >
        Search: "{{ searchModel }}"
      </q-chip>
      <q-chip
        v-if="brand"
        removable
        outline
        color="primary"
        text-color="primary"
        size="sm"
        class="q-ma-xs"
        @remove="$emit('update:brand', null)"
      >
        {{ $t('shop.brand_filter', { name: brand }) }}
      </q-chip>
      <q-chip
        v-if="category"
        removable
        outline
        color="primary"
        text-color="primary"
        size="sm"
        class="q-ma-xs"
        @remove="$emit('update:category', null)"
      >
        {{ $t('shop.category_filter', { name: category }) }}
      </q-chip>
      <q-btn
        flat
        dense
        no-caps
        color="primary"
        :label="$t('shop.clear_all')"
        size="sm"
        class="q-px-sm q-ml-xs text-weight-bold"
        @click="$emit('reset-filters')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  search: string;
  brand: string | null;
  category: string | null;
  activeFilterCount: number;
  hasActiveFilters: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:search', val: string): void;
  (e: 'update:brand', val: string | null): void;
  (e: 'update:category', val: string | null): void;
  (e: 'search'): void;
  (e: 'open-filter'): void;
  (e: 'reset-filters'): void;
}>();

const searchModel = computed({
  get: () => props.search,
  set: (val: string) => emit('update:search', val || ''),
});
</script>

<style scoped>
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 82%, transparent);
}
</style>
