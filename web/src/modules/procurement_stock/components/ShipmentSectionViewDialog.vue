<template>
  <q-dialog :model-value="modelValue" @update:model-value="(val) => emit('update:modelValue', val)">
    <q-card style="width: 480px; max-width: 95vw; border-radius: 12px" class="bg-white">
      <!-- Dialog Header -->
      <div class="row items-center justify-between q-pa-md border-bottom bg-grey-1">
        <div class="row items-center q-gutter-x-sm">
          <q-icon name="ph ph-info" size="20px" color="primary" />
          <div class="text-subtitle1 text-weight-bold text-grey-9">Section / Invoice Details</div>
        </div>
        <q-btn flat round dense icon="ph ph-x" size="sm" color="grey-7" v-close-popup />
      </div>

      <!-- Dialog Body -->
      <div class="q-pa-md column q-gutter-y-sm">
        <!-- Section / Sheet Name -->
        <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
          <div class="text-caption text-weight-medium text-grey-6">Section / Sheet Name</div>
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-2xs">
            {{ sectionData?.name || 'Untitled Section' }}
          </div>
        </div>

        <!-- Invoice Number & Date -->
        <div class="row q-col-gutter-sm">
          <div class="col-12 col-sm-6">
            <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
              <div class="text-caption text-weight-medium text-grey-6">Invoice Number</div>
              <div class="text-subtitle2 font-mono text-weight-bold text-grey-9 q-mt-2xs">
                {{ sectionData?.invoiceNumber || '—' }}
              </div>
            </div>
          </div>

          <div class="col-12 col-sm-6">
            <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
              <div class="text-caption text-weight-medium text-grey-6">Invoice Date</div>
              <div class="text-subtitle2 text-weight-bold text-grey-9 q-mt-2xs">
                {{ sectionData?.invoiceDate || '—' }}
              </div>
            </div>
          </div>
        </div>

        <!-- Notes -->
        <div class="bg-grey-1 q-pa-sm rounded-borders border-grey">
          <div class="text-caption text-weight-medium text-grey-6">Notes / Comments</div>
          <div class="text-body2 text-grey-8 q-mt-2xs" style="white-space: pre-wrap">
            {{ sectionData?.notes || 'No special notes entered for this invoice section.' }}
          </div>
        </div>
      </div>

      <!-- Dialog Footer -->
      <div class="row justify-between items-center q-pa-md border-top bg-grey-1">
        <q-btn
          flat
          no-caps
          color="primary"
          icon="ph ph-pencil-simple"
          label="Edit Details"
          @click="handleEdit"
        />
        <q-btn flat no-caps label="Close" color="grey-7" v-close-popup />
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
export interface SectionViewData {
  id: string;
  name: string;
  invoiceNumber?: string;
  invoiceDate?: string;
  notes?: string;
  dbId?: number;
}

const props = defineProps<{
  modelValue: boolean;
  sectionData?: SectionViewData | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'edit', data: SectionViewData): void;
}>();

const handleEdit = () => {
  if (props.sectionData) {
    emit('edit', props.sectionData);
  }
  emit('update:modelValue', false);
};
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-top {
  border-top: 1px solid #e2e8f0;
}
.border-grey {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.font-mono {
  font-family: monospace;
}
</style>
