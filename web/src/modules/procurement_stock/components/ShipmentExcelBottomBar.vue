<template>
  <div class="shipment-items-bottom-section excel-bottom-bar shrink-0 row items-center no-wrap">
    <!-- Left: Navigation Scroll Arrows ( |<  <  >  >| ) -->
    <div class="row items-center no-wrap excel-left-nav">
      <button class="excel-icon-btn" title="First Sheet" @click="scrollToTab('start')">
        <q-icon name="ph ph-caret-line-left" size="15px" />
      </button>
      <button class="excel-icon-btn" title="Previous Sheet" @click="scrollTabs(-100)">
        <q-icon name="ph ph-caret-left" size="15px" />
      </button>
      <button class="excel-icon-btn" title="Next Sheet" @click="scrollTabs(100)">
        <q-icon name="ph ph-caret-right" size="15px" />
      </button>
      <button class="excel-icon-btn" title="Last Sheet" @click="scrollToTab('end')">
        <q-icon name="ph ph-caret-line-right" size="15px" />
      </button>
    </div>

    <!-- Sheet Tabs Container -->
    <div ref="tabsContainerRef" class="excel-tabs-scroll-container row items-center no-wrap">
      <div
        v-for="sheet in sheets"
        :key="sheet.id"
        class="excel-tab-item row items-center no-wrap cursor-pointer"
        :class="{ 'excel-tab-item--active': activeSheetId === sheet.id }"
        @click="emit('update:activeSheetId', sheet.id)"
      >
        <span class="excel-tab-label">{{ sheet.name }}</span>

        <!-- Right Click Context Menu -->
        <q-menu context-menu>
          <q-list dense style="min-width: 200px" class="q-py-xs">
            <q-item clickable v-ripple @click="emit('view-section', sheet)">
              <q-item-section avatar style="min-width: 28px">
                <q-icon name="ph ph-info" size="16px" color="primary" />
              </q-item-section>
              <q-item-section class="text-caption text-weight-medium">View Details</q-item-section>
            </q-item>

            <q-item clickable v-ripple @click="emit('edit-section', sheet)">
              <q-item-section avatar style="min-width: 28px">
                <q-icon name="ph ph-pencil-simple" size="16px" color="grey-8" />
              </q-item-section>
              <q-item-section class="text-caption text-weight-medium">Edit Details</q-item-section>
            </q-item>

            <q-separator class="q-my-xs" />

            <q-item
              clickable
              v-ripple
              :disable="sheets.length <= 1"
              class="text-negative"
              @click="emit('remove-sheet', sheet.id)"
            >
              <q-item-section avatar style="min-width: 28px">
                <q-icon name="ph ph-trash" size="16px" color="negative" />
              </q-item-section>
              <q-item-section class="text-caption text-weight-medium">Delete Section</q-item-section>
            </q-item>
          </q-list>
        </q-menu>
      </div>
    </div>

    <!-- Plus Button for Add New Section / Invoice Sheet -->
    <button class="excel-icon-btn excel-plus-btn q-mr-sm" title="Add Section / Invoice" @click="emit('add-section')">
      <q-icon name="ph ph-plus" size="16px" />
    </button>

    <!-- Splitter / Divider Bar -->
    <div class="excel-splitter-bar" />

    <!-- Right Side Horizontal Scrollbar Track & Thumb -->
    <div class="excel-scrollbar-wrapper col row items-center no-wrap">
      <!-- Scrollbar Left End Arrow -->
      <button class="excel-scroll-arrow-btn" @click="emit('scroll-step', -120)">
        <q-icon name="ph ph-caret-left" size="13px" />
      </button>

      <!-- Scrollbar Track & Thumb -->
      <div
        ref="scrollTrackRef"
        class="excel-scroll-track col cursor-pointer"
        @click="onTrackClick"
      >
        <div
          class="excel-scroll-thumb"
          :style="{ width: scrollThumbWidth + '%', left: scrollThumbLeft + '%' }"
          @mousedown="startThumbDrag"
        />
      </div>

      <!-- Scrollbar Right End Arrow -->
      <button class="excel-scroll-arrow-btn" @click="emit('scroll-step', 120)">
        <q-icon name="ph ph-caret-right" size="13px" />
      </button>

      <div class="excel-end-cap" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

export interface SheetTabItem {
  id: string;
  name: string;
  dbId?: number;
  invoiceNumber?: string;
  invoiceDate?: string;
  notes?: string;
}

const props = defineProps<{
  sheets: SheetTabItem[];
  activeSheetId: string;
  scrollThumbWidth: number;
  scrollThumbLeft: number;
}>();

const emit = defineEmits<{
  (e: 'update:activeSheetId', val: string): void;
  (e: 'add-section'): void;
  (e: 'view-section', sheet: SheetTabItem): void;
  (e: 'edit-section', sheet: SheetTabItem): void;
  (e: 'remove-sheet', id: string): void;
  (e: 'scroll-step', delta: number): void;
  (e: 'track-click', fraction: number): void;
  (e: 'thumb-drag-start', event: MouseEvent): void;
}>();

const tabsContainerRef = ref<HTMLElement | null>(null);
const scrollTrackRef = ref<HTMLElement | null>(null);

const scrollTabs = (offset: number) => {
  if (tabsContainerRef.value) {
    tabsContainerRef.value.scrollBy({ left: offset, behavior: 'smooth' });
  }
};

const scrollToTab = (pos: 'start' | 'end') => {
  if (tabsContainerRef.value) {
    tabsContainerRef.value.scrollTo({
      left: pos === 'start' ? 0 : tabsContainerRef.value.scrollWidth,
      behavior: 'smooth',
    });
  }
};

const onTrackClick = (e: MouseEvent) => {
  const track = scrollTrackRef.value;
  if (!track) return;
  const rect = track.getBoundingClientRect();
  const clickX = e.clientX - rect.left;
  const fraction = Math.max(0, Math.min(1, clickX / rect.width));
  emit('track-click', fraction);
};

const startThumbDrag = (e: MouseEvent) => {
  emit('thumb-drag-start', e);
};

defineExpose({
  scrollToTab,
  scrollTrackRef,
});
</script>

<style scoped>
.excel-bottom-bar {
  height: 34px;
  min-height: 34px;
  background-color: #f1f5f9;
  color: #334155;
  border-top: 2px solid #cbd5e1;
  user-select: none;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  font-size: 12px;
}

.excel-left-nav {
  padding: 0 4px;
}

.excel-icon-btn {
  background: transparent;
  border: none;
  color: #475569;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.15s ease;
  padding: 0;
}

.excel-icon-btn:hover {
  background-color: #e2e8f0;
  color: #0f172a;
}

.excel-tabs-scroll-container {
  overflow-x: auto;
  scrollbar-width: none;
  max-width: 650px;
  padding: 0 4px;
}
.excel-tabs-scroll-container::-webkit-scrollbar {
  display: none;
}

.excel-tab-item {
  height: 30px;
  padding: 0 14px;
  color: #475569;
  background: #e2e8f0;
  margin-right: 2px;
  border-radius: 4px 4px 0 0;
  border-top: 1px solid #cbd5e1;
  border-left: 1px solid #cbd5e1;
  border-right: 1px solid #cbd5e1;
  font-weight: 600;
  font-size: 12px;
  transition: all 0.15s ease;
}

.excel-tab-item:hover {
  background-color: #ffffff;
  color: #0f172a;
}

.excel-tab-item--active {
  background-color: #ffffff !important;
  color: #059669 !important;
  font-weight: 700;
  border-top: 2.5px solid #059669;
  box-shadow: 0 -2px 4px rgba(0, 0, 0, 0.06);
}

.excel-plus-btn {
  color: #059669;
  font-weight: bold;
}

.excel-plus-btn:hover {
  background-color: #d1fae5;
  color: #047857;
}

.excel-splitter-bar {
  width: 3px;
  height: 18px;
  background-color: #94a3b8;
  margin: 0 8px;
  border-radius: 2px;
}

.excel-scrollbar-wrapper {
  background-color: #e2e8f0;
  height: 20px;
  width: 220px;
  max-width: 260px;
  margin-left: auto;
  margin-right: 10px;
  border-radius: 4px;
  border: 1px solid #cbd5e1;
  padding: 0 2px;
}

.excel-scroll-arrow-btn {
  background: transparent;
  border: none;
  color: #475569;
  width: 16px;
  height: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  padding: 0;
}

.excel-scroll-arrow-btn:hover {
  background-color: #cbd5e1;
  color: #0f172a;
}

.excel-scroll-track {
  height: 12px;
  background-color: #cbd5e1;
  border-radius: 3px;
  position: relative;
  margin: 0 4px;
}

.excel-scroll-thumb {
  height: 12px;
  background-color: #64748b;
  border-radius: 3px;
  position: absolute;
  top: 0;
  cursor: grab;
  transition: background-color 0.15s ease;
}

.excel-scroll-thumb:hover,
.excel-scroll-thumb:active {
  background-color: #334155;
}

.excel-end-cap {
  width: 2px;
}
</style>
