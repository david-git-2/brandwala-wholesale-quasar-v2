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
              :to="{ name: 'app-shop-shops-page', params: { tenantSlug } }"
            />
            <div>
              <div class="text-overline text-primary">{{ $t('shop_admin.shop_and_order') }}</div>
              <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('navigation.shops') }}</h1>
            </div>
          </div>
        </div>
        <div class="col-auto row items-center q-gutter-x-sm">
          <LearnMoreHelpBtn guide-id="shop_management" tab="workflows" />
          <q-btn
            color="primary"
            unelevated
            no-caps
            class="pill-btn"
            icon="ph ph-plus"
            :label="$t('shop_admin.new_shop')"
            @click="openCreate"
          />
        </div>
      </section>

      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-12 col-sm-5 row items-center q-gutter-sm">
            <q-input
              v-model="search"
              clearable
              debounce="350"
              dense
              outlined
              class="full-width"
              :placeholder="$t('shop_admin.search_shops_placeholder')"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" />
              </template>
            </q-input>
          </div>
          <div class="col-auto">
            <q-btn-toggle
              v-model="activeFilter"
              dense
              no-caps
              rounded
              unelevated
              toggle-color="primary"
              :options="filterOptions"
            />
          </div>
        </div>
      </q-card>

      <q-banner v-if="isError" class="text-white bg-negative" rounded>
        {{ error?.message || 'An error occurred while fetching shops.' }}
      </q-banner>

      <div v-if="isLoading" class="q-gutter-y-md">
        <q-card v-for="n in 3" :key="n" flat bordered class="q-pa-md">
          <div class="row items-center justify-between q-mb-sm">
            <q-skeleton type="text" width="40%" height="24px" />
            <q-skeleton type="QBadge" width="80px" height="24px" />
          </div>
          <q-skeleton type="text" width="20%" class="q-mb-sm" />
          <q-separator class="q-my-sm" />
          <div class="row items-center justify-between">
            <q-skeleton type="text" width="30%" />
            <q-skeleton type="QAvatar" size="28px" />
          </div>
        </q-card>
      </div>

      <div v-else>
        <q-card v-if="!shops || shops.length === 0" flat bordered class="q-pa-xl text-center text-grey-6">
          <q-icon name="ph ph-storefront" size="48px" class="q-mb-sm block" />
          {{ $t('shop_admin.no_shops_found') }}
          <br />
          <q-btn
            class="q-mt-md"
            color="primary"
            :label="$t('shop_admin.create_first_shop')"
            unelevated
            @click="openCreate"
          />
        </q-card>

        <div v-else class="q-gutter-y-sm">
          <q-card
            v-for="shop in shops"
            :key="shop.id"
            flat
            bordered
            class="shop-card cursor-pointer"
            @click="goToSetup(shop.id)"
          >
            <q-card-section class="row items-center no-wrap">
              <div class="col">
                <div class="row items-center q-gutter-x-sm">
                  <div class="text-subtitle1 text-weight-bold">{{ shop.name }}</div>
                  <q-chip
                    dense
                    size="sm"
                    :color="shopTypeColor(shop.shop_type)"
                    text-color="white"
                  >
                    {{ shopTypeLabel(shop.shop_type) }}
                  </q-chip>
                  <q-chip
                    dense
                    size="sm"
                    :color="shop.is_active ? 'positive' : 'grey-4'"
                    :text-color="shop.is_active ? 'white' : 'grey-8'"
                  >
                    {{ shop.is_active ? $t('shop_admin.public') : $t('shop_admin.draft') }}
                  </q-chip>
                </div>
              </div>
              <q-btn
                flat
                round
                dense
                icon="ph ph-dots-three-vertical"
                color="grey-7"
                @click.stop
              >
                <q-menu auto-close>
                  <q-list style="min-width: 140px">
                    <q-item clickable @click="confirmDeleteShop(shop)">
                      <q-item-section avatar min-width="24px">
                        <q-icon name="ph ph-trash" color="negative" size="18px" />
                      </q-item-section>
                      <q-item-section class="text-negative">{{ $t('shop_admin.delete') }}</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-btn>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>

    <ShopFormDialog
      v-model="dialogOpen"
      :tenant-id="tenantId"
      :saving="isSaving"
      :save-error="dialogError"
      @save="onSave"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import LearnMoreHelpBtn from 'src/modules/help/components/LearnMoreHelpBtn.vue';
import ShopFormDialog from 'src/modules/shop_order/components/ShopFormDialog.vue';
import { useShopListQuery } from '../composables/useShopQuery';
import { useSaveShopMutation, useDeleteShopMutation } from '../composables/useShopMutations';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';
import type { Shop, ShopType, CreateShopPayload } from 'src/modules/shop_order/types';

const $q = useQuasar();
const authStore = useAuthStore();
const router = useRouter();
const { t } = useI18n();

const tenantId = computed(() => authStore.tenantId as number);
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const search = ref<string>('');
const activeFilter = ref<boolean | null>(null);

const queryParams = computed(() => ({
  tenantId: tenantId.value,
  search: search.value || null,
  active: activeFilter.value,
}));

const { data: shops, isLoading, isError, error } = useShopListQuery(queryParams);
const { mutate: saveShopMutation, isPending: isSaving } = useSaveShopMutation();
const { mutate: deleteShopMutation } = useDeleteShopMutation();

const filterOptions = computed(() => [
  { value: null, label: t('shop_admin.all') },
  { value: true, label: t('shop_admin.public') },
  { value: false, label: t('shop_admin.draft') },
]);

const dialogOpen = ref(false);
const dialogError = ref<string | null>(null);

const openCreate = () => {
  dialogError.value = null;
  dialogOpen.value = true;
};

const goToSetup = (shopId: number) => {
  void router.push({
    name: 'app-shop-settings-page',
    params: { tenantSlug: tenantSlug.value, shopId: String(shopId) },
  });
};

const confirmDeleteShop = (shop: Shop) => {
  $q.dialog({
    title: t('shop_admin.delete_shop_title'),
    message: t('shop_admin.delete_shop_confirm_msg', { name: shop.name }),
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
      { shopId: shop.id, tenantId: tenantId.value },
      {
        onSuccess: () => {
          showSuccessNotification(t('shop_admin.delete_shop_success'));
        },
        onError: (err: Error) => {
          showErrorNotification(err.message || t('shop_admin.delete_shop_failed'));
        },
      },
    );
  });
};

const onSave = (payload: CreateShopPayload) => {
  dialogError.value = null;
  saveShopMutation(payload, {
    onSuccess: (shop) => {
      dialogOpen.value = false;
      goToSetup(shop.id);
    },
    onError: (err: Error) => {
      dialogError.value = err.message || t('shop_admin.shop_setup_save_failed');
    },
  });
};

const shopTypeLabel = (type: ShopType) => {
  const map: Record<ShopType, string> = {
    vendor_catalog: t('shop_admin.create_type_catalog'),
    fixed_price: t('shop_admin.create_type_stock'),
    dropship: t('shop_admin.create_type_dropship'),
  };
  return map[type] ?? type;
};

const shopTypeColor = (type: ShopType) =>
  ({
    vendor_catalog: 'indigo',
    fixed_price: 'teal',
    dropship: 'deep-orange',
  })[type] ?? 'grey';
</script>
