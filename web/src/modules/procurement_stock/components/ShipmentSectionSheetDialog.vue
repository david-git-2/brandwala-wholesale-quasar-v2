<template>
  <!-- Add / Edit Section / Invoice Sheet Dialog -->
  <q-dialog :model-value="modelValue" persistent @update:model-value="(val) => emit('update:modelValue', val)">
    <q-card style="width: 520px; max-width: 95vw; border-radius: 12px" class="bg-white">
      <q-form @submit="handleSave">
        <!-- Dialog Header -->
        <div class="row items-center justify-between q-pa-md border-bottom bg-grey-1">
          <div class="row items-center q-gutter-x-sm">
            <q-icon name="ph ph-receipt" size="20px" color="primary" />
            <div class="text-subtitle1 text-weight-bold text-grey-9">
              {{ isEditing ? 'Edit Section / Invoice Details' : 'New Section / Invoice Sheet' }}
            </div>
          </div>
          <q-btn flat round dense icon="ph ph-x" size="sm" color="grey-7" v-close-popup />
        </div>

        <!-- Dialog Body -->
        <div class="q-pa-md column q-gutter-y-sm">
          <!-- Section Name -->
          <q-input
            v-model="form.title"
            label="Section / Sheet Name *"
            outlined
            dense
            placeholder="e.g. Silk Dresses / Batch A"
            :rules="[(val) => !!val?.trim() || 'Section name is required']"
            autofocus
          >
            <template #prepend>
              <q-icon name="ph ph-folder" size="18px" color="grey-6" />
            </template>
          </q-input>

          <!-- Invoice Number & Date -->
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.invoiceNumber"
                label="Invoice Number"
                outlined
                dense
                placeholder="e.g. INV-2026-088"
              >
                <template #prepend>
                  <q-icon name="ph ph-hash" size="18px" color="grey-6" />
                </template>
              </q-input>
            </div>

            <div class="col-12 col-sm-6">
              <q-input
                v-model="form.invoiceDate"
                label="Invoice Date"
                outlined
                dense
                readonly
                clearable
              >
                <template #prepend>
                  <q-icon name="ph ph-calendar" size="18px" color="grey-6" />
                </template>
                <template #append>
                  <q-icon name="ph ph-calendar-plus" class="cursor-pointer" size="18px">
                    <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                      <q-date v-model="form.invoiceDate" mask="YYYY-MM-DD">
                        <div class="row items-center justify-end">
                          <q-btn v-close-popup label="Done" color="primary" flat />
                        </div>
                      </q-date>
                    </q-popup-proxy>
                  </q-icon>
                </template>
              </q-input>
            </div>
          </div>

          <!-- Notes -->
          <q-input
            v-model="form.notes"
            label="Notes / Comments"
            outlined
            dense
            type="textarea"
            rows="2"
            placeholder="Packing details, custom invoice instructions..."
          />
        </div>

        <!-- Dialog Actions -->
        <div class="row justify-end q-pa-md border-top bg-grey-1 q-gutter-x-sm">
          <q-btn flat no-caps label="Cancel" color="grey-7" v-close-popup />
          <q-btn
            type="submit"
            unelevated
            no-caps
            :label="isEditing ? 'Save Changes' : 'Create Sheet'"
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-md"
            style="border-radius: 8px"
          />
        </div>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { reactive, watch } from 'vue';

export interface SectionFormData {
  id?: string;
  dbId?: number;
  title: string;
  invoiceNumber: string;
  invoiceDate: string;
  notes: string;
}

const props = defineProps<{
  modelValue: boolean;
  isEditing: boolean;
  initialData?: SectionFormData | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
  (e: 'save', data: SectionFormData): void;
}>();

const form = reactive<SectionFormData>({
  title: '',
  invoiceNumber: '',
  invoiceDate: '',
  notes: '',
});

watch(
  () => props.initialData,
  (val) => {
    if (val) {
      form.id = val.id;
      form.dbId = val.dbId;
      form.title = val.title || '';
      form.invoiceNumber = val.invoiceNumber || '';
      form.invoiceDate = val.invoiceDate || '';
      form.notes = val.notes || '';
    } else {
      form.id = undefined;
      form.dbId = undefined;
      form.title = '';
      form.invoiceNumber = '';
      form.invoiceDate = '';
      form.notes = '';
    }
  },
  { immediate: true },
);

const handleSave = () => {
  const trimmed = form.title.trim();
  if (!trimmed) return;
  emit('save', {
    id: form.id,
    dbId: form.dbId,
    title: trimmed,
    invoiceNumber: form.invoiceNumber,
    invoiceDate: form.invoiceDate,
    notes: form.notes,
  });
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
</style>
