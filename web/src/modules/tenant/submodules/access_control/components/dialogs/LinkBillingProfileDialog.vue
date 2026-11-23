<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 400px; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">Link Billing Profile</div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-py-md">
        <div class="text-caption text-grey-7 q-mb-md">
          Select a billing profile to associate with customer group: <strong>{{ groupName }}</strong>
        </div>

        <template v-if="unassociatedProfileOptions.length > 0">
          <q-select
            v-model="profileToLink"
            :options="unassociatedProfileOptions"
            label="Billing Profile"
            outlined
            dense
            emit-value
            map-options
            class="soft-input"
            :rules="[(v) => !!v || 'Please select a profile']"
          />
        </template>

        <template v-else>
          <div class="text-center q-pa-md text-grey-7">
            <div class="q-mb-md">No billing profiles are available to link.</div>
            <q-btn
              color="primary"
              no-caps
              unelevated
              class="pill-btn"
              icon="ph ph-plus"
              label="Create Billing Profile"
              @click="$emit('createProfile')"
            />
          </div>
        </template>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          v-if="unassociatedProfileOptions.length > 0"
          color="primary"
          unelevated
          class="pill-btn"
          no-caps
          label="Link"
          :loading="saving"
          :disable="!profileToLink"
          @click="handleLink"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';

const props = defineProps<{
  modelValue: boolean;
  groupName?: string | undefined;
  unassociatedProfileOptions: { label: string; value: number }[];
  saving: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'createProfile'): void;
  (e: 'submit', profileId: number): void;
}>();

const profileToLink = ref<number | null>(null);

watch(
  () => props.modelValue,
  (val) => {
    if (val) {
      profileToLink.value = null;
    }
  },
);

const handleLink = () => {
  if (profileToLink.value) {
    emit('submit', profileToLink.value);
  }
};
</script>
