<template>
  <div class="bill-adjustment-note-bar q-mt-md q-pa-md rounded-borders bg-grey-1 no-print">
    <div class="row items-center q-col-gutter-md q-mb-sm">
      <div class="col-12 col-sm-auto">
        <q-btn-toggle
          v-model="kind"
          spread
          no-caps
          unelevated
          dense
          toggle-color="primary"
          :options="kindOptions"
        />
      </div>
      <div class="col-12 col-sm-auto text-body2">
        <template v-if="noteTotalLabels.length">
          <span v-for="(item, idx) in noteTotalLabels" :key="item.code">
            <template v-if="idx > 0"> · </template>
            Note total ({{ item.code }}):
            <strong class="font-mono">{{ item.label }}</strong>
          </span>
        </template>
        <template v-else>
          Note total:
          <strong class="font-mono">—</strong>
        </template>
      </div>
    </div>

    <q-banner
      v-if="balanceEffect.title"
      dense
      rounded
      class="q-mb-sm"
      :class="{
        'bg-positive-1 text-positive-10': balanceEffect.direction === 'decrease',
        'bg-orange-1 text-orange-10': balanceEffect.direction === 'increase',
        'bg-grey-2': balanceEffect.direction === 'neutral',
      }"
    >
      <div class="text-weight-medium">{{ balanceEffect.title }}</div>
      <div v-if="balanceEffect.detail" class="text-caption q-mt-xs">{{ balanceEffect.detail }}</div>
    </q-banner>

    <q-input
      v-model="reason"
      outlined
      dense
      class="q-mb-sm"
      label="Reason"
      type="textarea"
      autogrow
    />

    <div class="row justify-end q-gutter-sm">
      <q-btn flat no-caps label="Cancel" @click="emit('cancel')" />
      <q-btn
        unelevated
        no-caps
        color="primary"
        label="Issue note"
        :loading="loading"
        :disable="!!submitDisabledReason"
        @click="emit('submit')"
      >
        <q-tooltip v-if="submitDisabledReason">{{ submitDisabledReason }}</q-tooltip>
      </q-btn>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { Database } from 'src/types/database.types';

type BillDocumentKind = Database['public']['Enums']['bill_document_kind'];

type BalanceEffect = {
  direction: 'increase' | 'decrease' | 'neutral';
  title: string;
  detail: string;
};

type NoteTotalLabel = { code: string; label: string };

defineProps<{
  noteTotalLabels: NoteTotalLabel[];
  balanceEffect: BalanceEffect;
  submitDisabledReason: string | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  cancel: [];
  submit: [];
}>();

const kind = defineModel<BillDocumentKind>('kind', { required: true });
const reason = defineModel<string>('reason', { required: true });

const kindOptions: Array<{ label: string; value: BillDocumentKind }> = [
  { label: 'Credit note', value: 'credit_note' },
  { label: 'Debit note', value: 'debit_note' },
];
</script>
