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
        <div class="text-h6 text-weight-bold">Withdraw</div>
        <div class="row items-center q-gutter-sm">
          <TfBtn variant="secondary" label="Cancel" @click="goBack" />
          <TfBtn
            variant="primary"
            icon="ph ph-arrow-up-right"
            label="Withdraw"
            :loading="movementMutation.isPending.value"
            :disable="Boolean(submitDisabledReason)"
            data-test="profile-cash-withdraw-submit"
            @click="onSubmit"
          />
        </div>
      </div>

      <div class="col overflow-auto profile-cash-page__body">
        <div class="profile-cash-page__single column q-gutter-y-md">
          <q-card flat bordered class="q-pa-md profile-cash-page__target">
            <div class="text-caption text-weight-bold text-uppercase text-grey-7">
              Withdraw from profile
            </div>
            <div class="text-subtitle1 text-weight-bold q-mt-xs">{{ partyName }}</div>
          </q-card>

          <ProfileCashMovementLegPicker
            v-model:currency-code="profileLegCurrency"
            v-model:amount="amount"
            v-model:location-point-id="profileLegLocationPointId"
            v-model:bundle-id="profileLegBundleId"
            v-model:books-rate="profileLegBooksRate"
            v-model:deposit-requires-bundle-pick="profileLegDepositRequiresBundlePick"
            :books-tenant-id="booksTenantId"
            :operating-tenant-id="operatingTenantId"
            :profile-id="profileId"
            kind="withdrawal"
            :enabled="pageReady"
          />

          <q-card flat bordered class="q-pa-md column q-gutter-y-md profile-cash-page__details">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-sm-6">
                <BillDialogField label="Payment date">
                  <q-input
                    v-model="paymentDate"
                    outlined
                    dense
                    mask="####-##-##"
                    placeholder="YYYY-MM-DD"
                    hide-bottom-space
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
              </div>
              <div class="col-12 col-sm-6">
                <BillDialogField label="Method">
                  <q-select
                    v-model="methodCode"
                    :options="resolvedMethodOptions"
                    emit-value
                    map-options
                    outlined
                    dense
                    hide-bottom-space
                  />
                </BillDialogField>
              </div>
            </div>
            <div v-if="submitDisabledReason && submitAttempted" class="text-caption text-negative">
              {{ submitDisabledReason }}
            </div>
          </q-card>
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
import { useProfileCashMovementPage } from 'src/modules/people/composables/useProfileCashMovementPage';
import { useProfileCashWithdrawPageForm } from '../composables/useProfileCashWithdrawPageForm';

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
} = useProfileCashMovementPage('withdrawal');

const profileIdRef = computed(() => profileId.value);
const booksTenantIdRef = computed(() => booksTenantId.value);

const {
  resolvedMethodOptions,
  profileLegCurrency,
  profileLegLocationPointId,
  profileLegBundleId,
  profileLegBooksRate,
  profileLegDepositRequiresBundlePick,
  amount,
  paymentDate,
  methodCode,
  submitDisabledReason,
  buildSubmitPayload,
  submitAttempted,
} = useProfileCashWithdrawPageForm({
  pageReady,
  profileId: profileIdRef,
  booksTenantId: booksTenantIdRef,
});

const onSubmit = () => {
  submitAttempted.value = true;
  if (submitDisabledReason.value) return;
  submitMovement(buildSubmitPayload());
};

</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.profile-cash-page__single {
  max-width: 720px;
  margin: 0 auto;
}
.profile-cash-page__target,
.profile-cash-page__details {
  background: var(--tf-neutral-surface, #fff);
  border-color: var(--tf-neutral-border, #e7e1d8);
}
</style>