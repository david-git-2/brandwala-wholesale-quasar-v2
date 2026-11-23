<template>
  <q-card
    flat
    bordered
    class="profile-cash-deposit-summary"
    :class="{ 'profile-cash-deposit-summary--footer': layout === 'footer' }"
  >
    <template v-if="layout === 'footer'">
      <q-card-section class="profile-cash-deposit-summary__footer row items-center q-col-gutter-md wrap">
        <div class="col-12 col-sm-auto">
          <div class="text-subtitle2 text-weight-bold">Deposit summary</div>
          <div class="text-caption text-grey-7">{{ partyName }}</div>
        </div>
        <div class="col row q-gutter-md items-center wrap profile-cash-deposit-summary__stats">
          <div class="profile-cash-deposit-summary__stat">
            <span class="profile-cash-deposit-summary__stat-label">Location</span>
            <span class="profile-cash-deposit-summary__stat-value">{{ locationLabel || '—' }}</span>
          </div>
          <div class="profile-cash-deposit-summary__stat">
            <span class="profile-cash-deposit-summary__stat-label">Currency</span>
            <span class="profile-cash-deposit-summary__stat-value">{{ currencyCode }}</span>
          </div>
          <div v-if="bundleLabel" class="profile-cash-deposit-summary__stat">
            <span class="profile-cash-deposit-summary__stat-label">Bundle</span>
            <span class="profile-cash-deposit-summary__stat-value">{{ bundleLabel }}</span>
          </div>
          <div class="profile-cash-deposit-summary__stat">
            <span class="profile-cash-deposit-summary__stat-label">Lines</span>
            <span class="profile-cash-deposit-summary__stat-value">{{ lineCount }}</span>
          </div>
          <div class="profile-cash-deposit-summary__stat profile-cash-deposit-summary__stat--total">
            <span class="profile-cash-deposit-summary__stat-label">Total</span>
            <span class="profile-cash-deposit-summary__stat-value text-weight-bold">
              {{ formatAmountBdt(totalAmount) }} {{ currencyCode }}
            </span>
          </div>
        </div>
        <div class="col-12 col-sm-auto column items-stretch profile-cash-deposit-summary__actions">
          <TfBtn
            variant="primary"
            icon="ph ph-check"
            label="Confirm deposit"
            :loading="loading"
            :disable="Boolean(disabledReason)"
            @click="emit('confirm')"
          />
          <div v-if="disabledReason" class="text-caption text-grey-7 q-mt-xs text-center">
            {{ disabledReason }}
          </div>
        </div>
      </q-card-section>
    </template>

    <template v-else>
      <q-card-section>
        <div class="text-subtitle2 text-weight-bold">Deposit summary</div>
        <div class="text-caption text-grey-7 q-mt-xs">{{ partyName }}</div>
      </q-card-section>
      <q-separator />
      <q-card-section class="column q-gutter-y-sm">
        <div class="row items-center justify-between">
          <span class="text-caption text-grey-7">Location</span>
          <span class="text-body2 text-weight-medium">{{ locationLabel || '—' }}</span>
        </div>
        <div class="row items-center justify-between">
          <span class="text-caption text-grey-7">Currency</span>
          <span class="text-body2 text-weight-medium">{{ currencyCode }}</span>
        </div>
        <div v-if="bundleLabel" class="row items-center justify-between">
          <span class="text-caption text-grey-7">Bundle</span>
          <span class="text-body2 text-weight-medium">{{ bundleLabel }}</span>
        </div>
        <div class="row items-center justify-between">
          <span class="text-caption text-grey-7">Payment lines</span>
          <span class="text-body2 text-weight-medium">{{ lineCount }}</span>
        </div>
        <div class="row items-center justify-between q-pt-sm">
          <span class="text-subtitle2 text-weight-bold">Total</span>
          <span class="text-subtitle2 text-weight-bold">
            {{ formatAmountBdt(totalAmount) }} {{ currencyCode }}
          </span>
        </div>
      </q-card-section>
      <q-card-section class="q-pt-none">
        <TfBtn
          variant="primary"
          class="full-width"
          icon="ph ph-check"
          label="Confirm deposit"
          :loading="loading"
          :disable="Boolean(disabledReason)"
          @click="emit('confirm')"
        />
        <div v-if="disabledReason" class="text-caption text-grey-7 q-mt-sm text-center">
          {{ disabledReason }}
        </div>
      </q-card-section>
    </template>
  </q-card>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import { formatAmountBdt } from 'src/utils/currency';

withDefaults(
  defineProps<{
    partyName: string;
    locationLabel?: string | null;
    currencyCode: string;
    bundleLabel?: string | null;
    lineCount: number;
    totalAmount: number;
    loading?: boolean;
    disabledReason?: string | null;
    layout?: 'card' | 'footer';
  }>(),
  {
    layout: 'card',
  },
);

const emit = defineEmits<{
  confirm: [];
}>();
</script>

<style scoped>
.profile-cash-deposit-summary {
  background: var(--tf-neutral-surface, #fff);
  border-color: var(--tf-neutral-border, #e7e1d8);
}

.profile-cash-deposit-summary--footer {
  position: sticky;
  bottom: 0;
  z-index: 2;
  box-shadow: 0 -4px 12px rgba(15, 23, 42, 0.06);
}

.profile-cash-deposit-summary__stats {
  flex: 1 1 auto;
  min-width: 0;
}

.profile-cash-deposit-summary__stat {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 72px;
}

.profile-cash-deposit-summary__stat-label {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-muted, #64748b);
}

.profile-cash-deposit-summary__stat-value {
  font-size: 14px;
  color: var(--tf-neutral-ink, #0f172a);
}

.profile-cash-deposit-summary__stat--total .profile-cash-deposit-summary__stat-value {
  font-size: 15px;
}

.profile-cash-deposit-summary__actions {
  min-width: 160px;
}

body.body--dark .profile-cash-deposit-summary--footer {
  box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.25);
}
</style>