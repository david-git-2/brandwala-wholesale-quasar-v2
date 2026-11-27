<template>
  <FilterSidebar
    :model-value="modelValue"
    title="Order instructions"
    width="min(420px, 92vw)"
    :resizable="false"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="text-caption text-grey-7 q-mb-sm">
      Notes for your admin — pick an instruction, then add text.
    </div>

    <div class="column q-gutter-y-sm">
      <div>
        <div class="text-caption text-grey-7 q-mb-xs">Instruction</div>
        <div
          v-if="instructionChips.length"
          class="row q-gutter-xs pp-request-instructions-dialog__chip-row"
        >
          <q-chip
            v-for="chip in instructionChips"
            :key="chip.value"
            clickable
            dense
            :color="selectedStore === chip.value ? 'primary' : undefined"
            :text-color="selectedStore === chip.value ? 'white' : undefined"
            :outline="selectedStore !== chip.value"
            :class="{
              'pp-request-instructions-dialog__chip--filled':
                selectedStore !== chip.value && hasInstructionContent(chip.value),
            }"
            @click="selectInstructionTarget(chip.value)"
          >
            {{ chip.label }}
          </q-chip>
        </div>
        <p v-else class="text-caption text-grey-6 q-mb-none">
          Add items with URLs first to unlock store-specific instructions.
        </p>
      </div>
      <q-input
        v-model="draftText"
        outlined
        dense
        hide-bottom-space
        type="textarea"
        autogrow
        label="Instruction text"
        :rows="6"
        autofocus
      />
    </div>

    <template #footer>
      <div class="row justify-end q-gutter-sm">
        <TfBtn variant="tertiary" size="md" label="Cancel" @click="$emit('update:modelValue', false)" />
        <TfBtn
          variant="primary"
          size="md"
          label="Save"
          :loading="loading"
          @click="submit"
        />
      </div>
    </template>
  </FilterSidebar>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { PpBucketInstruction } from '../../types/ppPurchaseRequest';
import { mergeBucketInstructionEntry, PP_BUCKET_INSTRUCTION_GENERAL } from '../../utils/ppBucketInstructions';

const props = defineProps<{
  modelValue: boolean;
  initialInstructions?: PpBucketInstruction[] | null;
  storeHosts: string[];
  initialSelectedStore?: string | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [instructions: PpBucketInstruction[]];
}>();

const entries = ref<PpBucketInstruction[]>([]);
const selectedStore = ref<string>(PP_BUCKET_INSTRUCTION_GENERAL);
const draftText = ref('');

type InstructionChip = { label: string; value: string };

const instructionChips = computed((): InstructionChip[] => {
  const chips: InstructionChip[] = [{ label: 'General', value: PP_BUCKET_INSTRUCTION_GENERAL }];
  for (const host of props.storeHosts) {
    chips.push({ label: host, value: host });
  }
  return chips;
});

const hasInstructionContent = (store: string) =>
  entries.value.some((e) => e.store === store && e.description.trim().length > 0);

const loadDraftForStore = (store: string) => {
  draftText.value = entries.value.find((e) => e.store === store)?.description ?? '';
};

const persistCurrentDraft = () => {
  const store = selectedStore.value;
  const text = draftText.value.trim();
  if (!store) return;
  if (text) {
    entries.value = mergeBucketInstructionEntry(
      entries.value.filter((e) => e.store !== store),
      store,
      text,
    );
  } else {
    entries.value = entries.value.filter((e) => e.store !== store);
  }
};

const selectInstructionTarget = (store: string) => {
  if (store === selectedStore.value) return;
  persistCurrentDraft();
  selectedStore.value = store;
  loadDraftForStore(store);
};

const resolveInitialStore = () => {
  const preferred = props.initialSelectedStore?.trim().toLowerCase();
  if (preferred && instructionChips.value.some((c) => c.value === preferred)) {
    return preferred;
  }
  return PP_BUCKET_INSTRUCTION_GENERAL;
};

const syncFromProps = () => {
  entries.value = [...(props.initialInstructions ?? [])];
  selectedStore.value = resolveInitialStore();
  loadDraftForStore(selectedStore.value);
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) syncFromProps();
  },
);

const submit = () => {
  persistCurrentDraft();
  emit('submit', [...entries.value]);
};
</script>

<style scoped>
.pp-request-instructions-dialog__chip-row {
  flex-wrap: wrap;
}

.pp-request-instructions-dialog__chip--filled {
  font-weight: 600;
  border-color: var(--q-primary);
}
</style>