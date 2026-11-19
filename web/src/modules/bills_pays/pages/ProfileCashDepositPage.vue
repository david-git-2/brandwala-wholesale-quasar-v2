<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="profileLoading" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else-if="profileLoadError" class="col flex flex-center column q-gutter-sm">
      <span class="text-negative">{{ profileLoadError }}</span>
      <TfBtn variant="secondary" label="Go back" @click="goBack" />
    </div>

    <template v-else>
      <div class="profile-cash-page__toolbar row items-center justify-between q-mb-sm shrink-0">
        <div class="text-h6 text-weight-bold">Deposit</div>
        <div class="row items-center q-gutter-sm">
          <TfBtn variant="secondary" label="Cancel" @click="goBack" />
          <TfBtn
            variant="primary"
            icon="ph ph-arrow-down-left"
            label="Deposit"
            :loading="movementMutation.isPending.value"
            :disable="Boolean(submitDisabledReason)"
            data-test="profile-cash-deposit-submit"
            @click="onSubmit"
          />
        </div>
      </div>

      <div class="col overflow-auto profile-cash-page__body">
        <div class="profile-cash-page__stack column q-gutter-y-md">
            <q-card flat bordered class="q-pa-md profile-cash-page__target">
              <div class="text-caption text-weight-bold text-uppercase text-grey-7">
                Deposit to profile
              </div>
              <div class="text-subtitle1 text-weight-bold q-mt-xs">{{ partyName }}</div>
              <div class="text-caption text-grey-7 q-mt-xs">
                Money is credited to this party&apos;s cashbook at the location you choose below.
              </div>
            </q-card>

            <ProfileCashMovementLegPicker
              v-model:currency-code="profileLegCurrency"
              v-model:amount="dummyAmount"
              v-model:location-point-id="profileLegLocationPointId"
              v-model:bundle-id="profileLegBundleId"
              v-model:books-rate="profileLegBooksRate"
              v-model:deposit-requires-bundle-pick="profileLegDepositRequiresBundlePick"
              :books-tenant-id="booksTenantId"
              :operating-tenant-id="operatingTenantId"
              :profile-id="profileId"
              kind="deposit"
              :enabled="pageReady"
              hide-amount
              compact-toolbar
            >
              <template #toolbar-trailing>
                <BillDialogField label="Payment date">
                  <q-input
                    v-model="paymentDate"
                    outlined
                    dense
                    mask="####-##-##"
                    placeholder="YYYY-MM-DD"
                    hide-bottom-space
                    data-test="profile-cash-deposit-date"
                  >
                    <template #append>
                      <q-icon name="ph ph-calendar" class="cursor-pointer">
                        <q-popup-proxy transition-show="scale" transition-hide="scale">
                          <q-date v-model="paymentDate" mask="YYYY-MM-DD" />
                        </q-popup-proxy>
                      </q-icon>
                    </template>
                  </q-input>
                </BillDialogField>
              </template>
            </ProfileCashMovementLegPicker>

            <ProfileDepositLinesEditor
              v-model:lines="depositLines"
              layout="page"
              :currency-code="profileLegCurrency"
              :method-options="resolvedMethodOptions"
              :bd-bank-options="bdBankOptions"
              :loading-payment-meta="loadingPaymentMeta"
              :show-errors="submitAttempted"
              :total-amount="depositLinesTotal"
              :can-add-line="canAddDepositLine"
              @add-line="(methodCode) => addDepositLine(methodCode)"
              @remove-line="removeDepositLine"
            />

          <ProfileCashDepositSummary
            layout="footer"
            :party-name="partyName"
            :location-label="locationLabel"
            :currency-code="profileLegCurrency"
            :bundle-label="bundleLabel"
            :line-count="depositLines.length"
            :total-amount="depositLinesTotal"
            :loading="movementMutation.isPending.value"
            :disabled-reason="submitDisabledReason"
            @confirm="onSubmit"
          />
        </div>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import BillDialogField from '../components/BillDialogField.vue';
import ProfileCashMovementLegPicker from 'src/modules/people/components/ProfileCashMovementLegPicker.vue';
import ProfileDepositLinesEditor from '../components/ProfileDepositLinesEditor.vue';
import ProfileCashDepositSummary from '../components/ProfileCashDepositSummary.vue';
import { useProfileCashMovementPage } from 'src/modules/people/composables/useProfileCashMovementPage';
import { useProfileCashDepositPageForm } from '../composables/useProfileCashDepositPageForm';

const dummyAmount = ref(0);

const {
  operatingTenantId,
  booksTenantId,
  profileId,
  profileLoading,
  profileLoadError,
  partyName,
  pageReady,
  goBack,
  movementMutation,
  submitMovement,
} = useProfileCashMovementPage('deposit');

const profileIdRef = computed(() => profileId.value);
const booksTenantIdRef = computed(() => booksTenantId.value);

const {
  loadingPaymentMeta,
  resolvedMethodOptions,
  profileLegCurrency,
  profileLegLocationPointId,
  profileLegBundleId,
  profileLegBooksRate,
  profileLegDepositRequiresBundlePick,
  paymentDate,
  depositLines,
  addDepositLine,
  removeDepositLine,
  trimDepositLines,
  depositLinesTotal,
  canAddDepositLine,
  bdBankOptions,
  submitDisabledReason,
  locationLabel,
  bundleLabel,
  buildSubmitPayload,
  submitAttempted,
} = useProfileCashDepositPageForm({
  pageReady,
  profileId: profileIdRef,
  booksTenantId: booksTenantIdRef,
});

const onSubmit = () => {
  submitAttempted.value = true;
  if (submitDisabledReason.value) return;
  submitMovement(buildSubmitPayload(), {
    onPartialDeposit: (postedCount) => {
      trimDepositLines(postedCount);
    },
  });
};

</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.profile-cash-page__body {
  width: 100%;
}

.profile-cash-page__stack {
  width: 100%;
  max-width: none;
  margin: 0 auto;
  padding-bottom: 16px;
}

.profile-cash-page__target {
  background: var(--tf-neutral-surface, #fff);
  border-color: var(--tf-neutral-border, #e7e1d8);
}
</style>