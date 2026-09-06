<template>
  <div class="grade-toggle row no-wrap">
    <q-btn
      v-for="grade in warehouseGrades"
      :key="grade.slug"
      flat
      dense
      no-caps
      class="col grade-toggle-btn"
      :class="{ 'grade-toggle-btn--selected': modelValue === grade.slug }"
      :style="gradeButtonStyle(grade, modelValue === grade.slug, gradeState(grade.slug))"
      @click="$emit('update:modelValue', grade.slug)"
    >
      <span class="row items-center no-wrap justify-center q-gutter-x-xs">
        <span
          class="grade-dot"
          :class="{
            'grade-dot--listed': gradeState(grade.slug) !== 'unlisted',
            'grade-dot--active': gradeState(grade.slug) === 'active',
          }"
          :style="{ backgroundColor: gradeAccentColor(grade) }"
        />
        <span class="grade-toggle-label">{{ gradeShortLabel(grade) }}</span>
      </span>
      <q-tooltip>{{ grade.label }}</q-tooltip>
    </q-btn>
  </div>
</template>

<script setup lang="ts">
import { STOREFRONT_WAREHOUSE_GRADES } from '../constants/storefrontWarehouseGrades';
import type { ShopStorefrontAdminListing } from '../types';
import {
  gradeListingStateForSlug,
  gradeShortLabel,
  gradeAccentColor,
  gradeButtonStyle,
} from '../utils/storefrontGradeToggle';

const props = defineProps<{
  modelValue: string;
  listingsByGrade: Record<string, ShopStorefrontAdminListing | null>;
}>();

defineEmits<{
  (e: 'update:modelValue', value: string): void;
}>();

const warehouseGrades = STOREFRONT_WAREHOUSE_GRADES;

const gradeState = (slug: string) => gradeListingStateForSlug(props.listingsByGrade, slug);
</script>

<style scoped>
.grade-toggle {
  border-radius: 6px;
  border: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.1));
  overflow: hidden;
  gap: 1px;
  background: rgba(0, 0, 0, 0.02);
  padding: 1px;
}
.grade-toggle-btn {
  min-height: 24px !important;
  min-width: 0;
  padding: 1px 2px !important;
  border: 1px solid transparent;
  border-radius: 4px !important;
  transition:
    background-color 0.15s ease,
    border-color 0.15s ease,
    color 0.15s ease;
}
.grade-toggle-btn--selected {
  box-shadow: 0 1px 4px rgba(15, 23, 42, 0.16);
}
.grade-toggle-label {
  font-size: 9px;
  line-height: 1;
  font-weight: 700;
  letter-spacing: 0.01em;
}
.grade-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  flex-shrink: 0;
  opacity: 0.35;
}
.grade-dot--listed {
  opacity: 0.65;
}
.grade-dot--active {
  opacity: 1;
  box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.85);
}
.grade-toggle-btn--selected .grade-dot {
  opacity: 1;
  box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.9);
}
</style>
