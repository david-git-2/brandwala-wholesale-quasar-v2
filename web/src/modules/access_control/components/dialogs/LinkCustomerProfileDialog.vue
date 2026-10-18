<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <q-card flat bordered style="min-width: 360px">
      <q-card-section class="text-subtitle1 text-weight-bold">
        Link billing profile
        <span v-if="groupName" class="text-weight-regular text-grey-7"> — {{ groupName }}</span>
      </q-card-section>

      <q-card-section class="q-pt-none q-gutter-sm">
        <q-select
          v-model="selectedProfileId"
          :options="unassociatedProfileOptions"
          label="Profile"
          outlined
          dense
          hide-bottom-space
          emit-value
          map-options
          :disable="saving"
        />
        <q-btn
          flat
          dense
          no-caps
          color="primary"
          label="Create new profile"
          @click="$emit('create-profile')"
        />
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          unelevated
          no-caps
          color="primary"
          label="Link"
          :loading="saving"
          :disable="selectedProfileId == null"
          @click="onSubmit"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';

const props = defineProps<{
  modelValue: boolean;
  groupName?: string | null;
  unassociatedProfileOptions: { label: string; value: number }[];
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'create-profile'): void;
  (e: 'submit', profileId: number): void;
}>();

const selectedProfileId = ref<number | null>(null);

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      selectedProfileId.value = null;
    }
  },
);

function onSubmit() {
  if (selectedProfileId.value == null) {
    return;
  }
  emit('submit', selectedProfileId.value);
}
</script>
