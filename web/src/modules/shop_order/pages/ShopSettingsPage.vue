<template>
  <q-page class="bw-page q-pa-md">
    <section class="bw-page__stack">
      <div class="shop-settings-header row items-center justify-between q-col-gutter-sm q-mb-sm">
        <h1 class="shop-settings-header__title col min-width-0">{{ pageTitle }}</h1>
        <div class="col-auto row items-center q-gutter-sm no-wrap">
          <q-btn
            v-if="shop?.slug"
            flat
            dense
            no-caps
            outline
            color="primary"
            icon="ph ph-copy"
            :label="$t('shop_admin.shop_catalog_url_copy')"
            data-test="shop-catalog-url-copy"
            @click="copyShopUrl"
          />
          <q-btn
            v-if="shop && activeTab === 'setup'"
            color="primary"
            unelevated
            no-caps
            style="border-radius: 8px"
            :label="$t('shop_admin.save')"
            :loading="isSaving"
            @click="onSave"
          />
        </div>
      </div>

      <q-banner v-if="isError" class="text-white bg-negative" rounded>
        {{ error?.message || $t('shop_admin.shop_setup_load_failed') }}
      </q-banner>

      <ShopSettingsSkeleton v-if="isLoading" is-loading />

      <template v-else-if="shop">
        <q-card flat bordered class="shop-settings-tabs-card">
          <q-tabs
            v-model="activeTab"
            inline-label
            dense
            no-caps
            align="left"
            active-color="primary"
            indicator-color="primary"
            class="shop-settings-tabs text-grey-8"
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
        </q-card>

        <q-tab-panels v-model="activeTab" animated class="bg-transparent">
          <q-tab-panel name="setup" class="q-pa-none q-pt-md">
            <DropshipShopReadinessCard
              v-if="shop.shop_type === 'dropship'"
              class="q-mb-md"
              :shop-id="shop.id"
              :tenant-slug="tenantSlug"
            />
            <ShopSettingsForm ref="formRef" :shop="shop" />

            <q-card flat class="shop-danger-zone q-mt-md">
              <q-card-section>
                <div class="text-subtitle2 text-weight-bold text-negative">
                  {{ $t('shop_admin.danger_zone_title') }}
                </div>
                <p class="text-body2 text-grey-8 q-mt-xs q-mb-none">
                  {{ $t('shop_admin.danger_zone_delete_caption') }}
                </p>
                <p class="text-caption text-grey-7 q-mt-sm q-mb-md">
                  {{ $t('shop_admin.delete_shop_confirm_msg', { name: shop.name }) }}
                </p>

                <div class="row q-col-gutter-md">
                  <div class="col-12 col-md-6">
                    <q-input
                      v-model="deleteKeyword"
                      outlined
                      dense
                      autocomplete="off"
                      :label="$t('shop_admin.danger_zone_type_delete')"
                      data-test="shop-delete-keyword"
                    />
                  </div>
                  <div class="col-12 col-md-6">
                    <q-input
                      v-model="deleteShopName"
                      outlined
                      dense
                      autocomplete="off"
                      :label="$t('shop_admin.danger_zone_type_shop_name', { name: shop.name })"
                      data-test="shop-delete-name"
                    />
                  </div>
                </div>

                <div class="row justify-end q-mt-md">
                  <q-btn
                    color="negative"
                    unelevated
                    no-caps
                    icon="ph ph-trash"
                    :label="$t('shop_admin.danger_zone_delete_btn')"
                    :loading="isDeleting"
                    :disable="!canDeleteShop || isDeleting"
                    data-test="shop-delete-submit"
                    @click="deleteShop"
                  />
                </div>
              </q-card-section>
            </q-card>
          </q-tab-panel>

          <q-tab-panel v-if="showAccessTab" name="access" class="q-pa-none q-pt-md">
            <ShopAccessMatrixPage v-if="activeTab === 'access'" embedded :shop="shop" />
          </q-tab-panel>

          <q-tab-panel v-if="showListingsTab" name="listings" class="q-pa-none q-pt-md">
            <ShopPricingPage v-if="activeTab === 'listings'" embedded :shop="shop" />
          </q-tab-panel>
        </q-tab-panels>
      </template>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { computed, defineAsyncComponent, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { copyToClipboard } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import ShopSettingsForm from 'src/modules/shop_order/components/ShopSettingsForm.vue';
import ShopSettingsSkeleton from 'src/modules/shop_order/components/ShopSettingsSkeleton.vue';
import DropshipShopReadinessCard from 'src/modules/shop_order/components/DropshipShopReadinessCard.vue';
import { useShopDetailQuery } from '../composables/useShopQuery';
import { useSaveShopMutation, useDeleteShopMutation } from '../composables/useShopMutations';
import { shopCatalogPath } from '../utils/catalogShop';
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
const { t } = useI18n();
const authStore = useAuthStore();
const { hasModuleAccess } = useModulePermissions();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');
const shopId = computed(() => Number(route.params.shopId));

const { data: shop, isLoading, isError, error } = useShopDetailQuery(tenantId, shopId);
const pageTitle = computed(
  () => shop.value?.name || t('shop_admin.shop_setup_title'),
);
const { mutate: saveShopMutation, isPending: isSaving } = useSaveShopMutation();
const { mutate: deleteShopMutation, isPending: isDeleting } = useDeleteShopMutation();

const formRef = ref<{ buildPayload: () => UpdateShopPayload | null } | null>(null);
const deleteKeyword = ref('');
const deleteShopName = ref('');

watch(shopId, () => {
  deleteKeyword.value = '';
  deleteShopName.value = '';
});

const canDeleteShop = computed(() => {
  const name = shop.value?.name?.trim() ?? '';
  return deleteKeyword.value.trim() === 'DELETE' && deleteShopName.value.trim() === name && name.length > 0;
});

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

const copyShopUrl = async () => {
  if (!shop.value?.slug) return;
  const origin = typeof window === 'undefined' ? '' : window.location.origin;
  const url = `${origin}${shopCatalogPath(tenantSlug.value, shop.value.slug).path}`;
  try {
    await copyToClipboard(url);
    showSuccessNotification(t('shop_admin.shop_catalog_url_copied'));
  } catch {
    showErrorNotification(t('shop_admin.shop_catalog_url_copy_failed'));
  }
};

const deleteShop = () => {
  if (!canDeleteShop.value || !shop.value) return;

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
};
</script>

<style scoped>
.shop-settings-header__title {
  margin: 0;
  font-size: clamp(1rem, 1.4vw, 1.2rem);
  font-weight: 700;
  line-height: 1.25;
  color: var(--bw-theme-ink, #171412);
}

.shop-settings-tabs-card {
  border-radius: 8px;
  overflow: hidden;
}

.shop-settings-tabs :deep(.q-tab__icon) {
  font-size: 18px;
}

.shop-danger-zone {
  background: #fff5f5;
  border-radius: 8px;
  border: 1px solid rgba(239, 68, 68, 0.25);
  box-shadow: none;
}

body.body--dark .shop-danger-zone {
  background: rgba(127, 29, 29, 0.12);
  border-color: rgba(248, 113, 113, 0.28);
}
</style>
