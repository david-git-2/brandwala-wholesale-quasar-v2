<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card style="min-width: 420px; border-radius: 12px">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">
          {{
            selectedMemberRole === 'viewer'
              ? 'Add Viewer'
              : selectedMemberRole === 'investor'
                ? 'Add Investor'
                : selectedMemberRole === 'admin'
                  ? 'Add Admin'
                  : 'Add Staff'
          }}
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-py-md q-gutter-md">
        <q-input
          v-model="email"
          label="Email"
          type="email"
          outlined
          dense
          class="soft-input"
        />
        <q-select
          v-model="role"
          outlined
          dense
          label="Role"
          :options="memberRoleOptions"
          emit-value
          map-options
          class="soft-input"
        />

        <q-select
          v-if="role === 'investor'"
          v-model="investorId"
          outlined
          dense
          label="Link Investor Profile"
          emit-value
          map-options
          :options="investorOptions"
          class="soft-input"
        />

        <div class="row items-center justify-between">
          <div class="text-subtitle2 text-grey-8">Status</div>
          <q-toggle
            v-model="isActive"
            :label="isActive ? 'Active' : 'Inactive'"
            color="positive"
            keep-color
          />
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat no-caps label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          unelevated
          class="pill-btn"
          no-caps
          label="Save"
          @click="handleSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { TenantMembershipRole } from 'src/modules/membership/types';

const props = defineProps<{
  modelValue: boolean;
  selectedMemberRole: TenantMembershipRole;
  investorOptions: { label: string; value: number }[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (
    e: 'save',
    payload: {
      email: string;
      role: TenantMembershipRole;
      isActive: boolean;
      investorId: number | null;
    },
  ): void;
}>();

const email = ref('');
const role = ref<TenantMembershipRole>('staff');
const isActive = ref(true);
const investorId = ref<number | null>(null);

const memberRoleOptions = [
  { label: 'Admin', value: 'admin' },
  { label: 'Staff', value: 'staff' },
  { label: 'Viewer', value: 'viewer' },
  { label: 'Investor', value: 'investor' },
];

watch(
  () => props.modelValue,
  (val) => {
    if (val) {
      email.value = '';
      role.value = props.selectedMemberRole;
      isActive.value = true;
      investorId.value = null;
    }
  },
);

const handleSave = () => {
  emit('save', {
    email: email.value,
    role: role.value,
    isActive: isActive.value,
    investorId: investorId.value,
  });
};
</script>
