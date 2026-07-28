<script setup lang="ts">
const props = defineProps<{
  form: {
    allow_open_box: boolean;
    delivery_instruction_notes: string;
  };
}>();

const emit = defineEmits<{
  (e: 'update:form-field', key: string, val: any): void;
}>();

const updateField = (key: string, val: any) => {
  emit('update:form-field', key, val);
};
</script>

<template>
  <q-card flat bordered class="form-card">
    <q-card-section class="border-bottom row items-center justify-between">
      <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
        <q-icon name="ph ph-note" size="18px" class="q-mr-xs text-primary" />
        Block D: Driver Notes &amp; Policy Flags
      </div>
    </q-card-section>
    <q-card-section>
      <div class="row q-col-gutter-md">
        <div class="col-12">
          <q-toggle
            :model-value="props.form.allow_open_box"
            label="Allow Open-Box Inspection by Recipient"
            color="primary"
            @update:model-value="(val) => updateField('allow_open_box', val)"
          />
        </div>
        <div class="col-12">
          <q-input
            :model-value="props.form.delivery_instruction_notes"
            label="Driver / Special Instructions"
            outlined
            dense
            hide-bottom-space
            type="textarea"
            rows="2"
            @update:model-value="(val) => updateField('delivery_instruction_notes', val)"
          />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>
