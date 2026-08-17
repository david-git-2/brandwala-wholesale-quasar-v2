<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn
              flat
              dense
              round
              icon="ph ph-arrow-left"
              color="grey-7"
              :to="{ name: 'app-shop-shops-list-page', params: { tenantSlug } }"
            />
            <div>
              <div class="text-overline text-primary">{{ $t('navigation.shops') }}</div>
              <h1 class="text-h5 text-weight-bold q-my-none">
                {{ shop?.name || $t('shop_admin.shop_setup_title') }}
              </h1>
              <p class="text-caption text-grey-7 q-mb-none">
                {{ $t('shop_admin.shop_setup_subtitle') }}
              </p>
            </div>
          </div>
        </div>
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn
            flat
            no-caps
            color="negative"
            icon="ph ph-trash"
            :label="$t('shop_admin.delete')"
            :loading="isDeleting"
            :disable="!shop || isDeleting"
            @click="confirmDelete"
          />
          <q-btn
            v-if="activeTab === 'setup'"
            color="primary"
            unelevated
            no-caps
            :label="$t('shop_admin.save')"
            :loading="isSaving"
            :disable="!shop"
            @click="onSave"
          />
        </div>
      </section>

      <q-banner v-if="isError" class="text-white bg-negative" rounded>
        {{ error?.message || $t('shop_admin.shop_setup_load_failed') }}
      </q-banner>

      <ShopSettingsSkeleton v-if="isLoading" is-loading />

      <template v-else-if="shop">
        <q-tabs
          v-model="activeTab"
          dense
          no-caps
          align="left"
          active-color="primary"
          indicator-color="primary"
          class="text-grey-8"
          narrow-indicator
          outside-arrows
          mobile-arrows
        >
          <q-tab name="setup" icon="ph ph-gear" :label="$t('shop_admin.shop_tab_setup')" />
          <q-tab
            v-if="showAccessTab"
            name="access"
            icon="ph ph-shield"
            :label="$t('shop_admin.shop_tab_access')"
          />
          <q-tab
            v-if="showListingsTab"
            name="listings"
            icon="ph ph-tag"
            :label="$t('shop_admin.shop_tab_listings')"
          />
        </q-tabs>

        <q-tab-panels v-model="activeTab" animated keep-alive class="bg-transparent">
          <q-tab-panel name="setup" class="q-pa-none q-pt-md">
            <DropshipShopReadinessCard
              v-if="shop.shop_type === 'dropship'"
              class="q-mb-md"
              :shop-id="shop.id"
              :tenant-slug="tenantSlug"
            />
            <ShopSettingsForm ref="formRef" :shop="shop" />
          </q-tab-panel>

          <q-tab-panel v-if="showAccessTab" name="access" class="q-pa-none q-pt-md">
            <ShopAccessMatrixPage embedded />
          </q-tab-panel>

          <q-tab-panel v-if="showListingsTab" name="listings" class="q-pa-none q-pt-md">
            <ShopPricingPage embedded />
          </q-tab-panel>
        </q-tab-panels>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, defineAsyncComponent, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import ShopSettingsForm from 'src/modules/shop_order/components/ShopSettingsForm.vue';
import ShopSettingsSkeleton from 'src/modules/shop_order/components/ShopSettingsSkeleton.vue';
import DropshipShopReadinessCard from 'src/modules/shop_order/components/DropshipShopReadinessCard.vue';
import { useShopDetailQuery } from '../composables/useShopQuery';
import { useSaveShopMutation, useDeleteShopMutation } from '../composables/useShopMutations';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import type { UpdateShopPayload } from 'src/modules/shop_order/types';

const ShopAccessMatrixPage = defineAsyncComponent(
  () => import('src/modules/shop_order/pages/ShopAccessMatrixPage.vue'),
);
const ShopPricingPage = defineAsyncComponent(
  () => import('src/modules/shop_order/pages/ShopPricingPage.vue'),
);

type ShopDetailTab = 'setup' | 'access' | 'listings';

const route = useRoute();
const router = useRouter();
const $q = useQuasar();
const { t } = useI18n();
const authStore = useAuthStore();
const { hasModuleAccess } = useModulePermissions();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');
const shopId = computed(() => Number(route.params.shopId));

const { data: shop, isLoading, isError, error } = useShopDetailQuery(tenantId, shopId);
const { mutate: saveShopMutation, isPending: isSaving } = useSaveShopMutation();
const { mutate: deleteShopMutation, isPending: isDeleting } = useDeleteShopMutation();

const formRef = ref<{ buildPayload: () => UpdateShopPayload | null } | null>(null);

const showAccessTab = computed(() => hasModuleAccess('shop_permissions'));
const showListingsTab = computed(
  () => shop.value?.shop_type !== 'vendor_catalog' && hasModuleAccess('shop_pricing'),
);

const isValidTab = (tab: string): tab is ShopDetailTab => {
  if (tab === 'setup') return true;
  if (tab === 'access') return showAccessTab.value;
  if (tab === 'listings') return showListingsTab.value;
  return false;
};

const activeTab = computed({
  get(): ShopDetailTab {
    const tab = typeof route.query.tab === 'string' ? route.query.tab : 'setup';
    return isValidTab(tab) ? tab : 'setup';
  },
  set(tab: ShopDetailTab) {
    void router.replace({
      params: route.params,
      query: { ...route.query, tab },
    });
  },
});

const onSave = () => {
  const payload = formRef.value?.buildPayload();
  if (!payload) return;
  saveShopMutation(payload, {
    onSuccess: () => {
      showSuccessNotification(t('shop_admin.shop_setup_saved'));
    },
    onError: (err: Error) => {
      showErrorNotification(err.message || t('shop_admin.shop_setup_save_failed'));
    },
  });
};

const confirmDelete = () => {
  const name = shop.value?.name ?? '';
  $q.dialog({
    title: t('shop_admin.delete_shop_title'),
    message: t('shop_admin.delete_shop_confirm_msg', { name }),
    cancel: {
      label: t('shop_admin.cancel'),
      flat: true,
      color: 'grey-7',
    },
    ok: {
      label: t('shop_admin.delete'),
      unelevated: true,
      color: 'negative',
    },
    persistent: true,
  }).onOk(() => {
    deleteShopMutation(
      { shopId: shopId.value, tenantId: tenantId.value },
      {
        onSuccess: () => {
          showSuccessNotification(t('shop_admin.delete_shop_success'));
          void router.push({
            name: 'app-shop-shops-list-page',
            params: { tenantSlug: tenantSlug.value },
          });
        },
        onError: (err: Error) => {
          showErrorNotification(err.message || t('shop_admin.delete_shop_failed'));
        },
      },
    );
  });
};
</script>
