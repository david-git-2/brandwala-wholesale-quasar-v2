<template>
  <q-page class="shops-page q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <!-- Compact Unified Table/View Toolbar -->
      <q-card flat class="floating-surface q-pa-xs flex-shrink-0">
        <div class="row items-center justify-between q-col-gutter-xs">
          <!-- Left: Search & Filter Pills -->
          <div class="col-12 col-sm-auto row items-center q-gutter-x-xs">
            <q-input
              v-model="search"
              clearable
              debounce="350"
              dense
              outlined
              rounded
              style="min-width: 240px"
              :placeholder="$t('shop_admin.search_shops_placeholder')"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" class="text-grey-6" />
              </template>
            </q-input>

            <q-btn-toggle
              v-model="activeFilter"
              dense
              no-caps
              rounded
              unelevated
              toggle-color="primary"
              color="grey-2"
              text-color="grey-8"
              :options="filterOptions"
            />
          </div>

          <!-- Right: Primary Action -->
          <div class="col-auto row items-center q-gutter-x-xs">
            <q-btn
              color="primary"
              unelevated
              no-caps
              dense
              class="rounded-sq-btn text-weight-bold q-px-sm"
              icon="ph ph-plus"
              :label="$t('shop_admin.new_shop')"
              @click="openCreate"
            />
          </div>
        </div>
      </q-card>

      <!-- Scrollable Content Container -->
      <div class="col scroll q-py-xs">
        <q-banner v-if="isError" class="text-white bg-negative q-mb-md" rounded>
          {{ error?.message || 'An error occurred while fetching shops.' }}
        </q-banner>

        <div v-if="isLoading" class="shops-list-wrap col">
          <q-card flat class="floating-surface q-pa-none full-height column no-wrap">
            <q-list separator>
              <q-item v-for="n in 4" :key="n" class="q-py-sm">
                <q-item-section avatar>
                  <q-skeleton type="QAvatar" size="36px" />
                </q-item-section>
                <q-item-section>
                  <q-skeleton type="text" width="30%" height="18px" class="q-mb-xs" />
                  <q-skeleton type="QBadge" width="70px" height="20px" />
                </q-item-section>
              </q-item>
            </q-list>
          </q-card>
        </div>

        <div v-else class="shops-list-wrap col">
          <div
            v-if="!shops || shops.length === 0"
            class="column items-center justify-center text-center text-grey-6 q-pa-xl floating-surface col"
          >
            <q-icon name="ph ph-storefront" size="48px" class="q-mb-sm block text-grey-4" />
            <div class="text-subtitle1 text-weight-medium">{{ $t('shop_admin.no_shops_found') }}</div>
            <p class="text-caption text-grey-6 q-mt-xs">Get started by creating your first wholesale or retail shop.</p>
            <q-btn
              class="q-mt-sm rounded-sq-btn text-weight-bold q-px-sm"
              color="primary"
              :label="$t('shop_admin.create_first_shop')"
              unelevated
              no-caps
              icon="ph ph-plus"
              @click="openCreate"
            />
          </div>

          <q-card v-else flat class="floating-surface q-pa-none full-height column no-wrap">
            <q-list separator class="col scroll">
              <q-item
                v-for="shop in shops"
                :key="shop.id"
                clickable
                v-ripple
                class="q-py-sm"
                @click="goToSetup(shop.id)"
              >
                <q-item-section avatar>
                  <q-avatar size="36px" color="grey-2" text-color="primary" icon="ph ph-storefront" />
                </q-item-section>

                <q-item-section>
                  <div class="row items-center q-gutter-x-sm no-wrap">
                    <span class="text-subtitle2 text-weight-bold text-grey-9 ellipsis">{{ shop.name }}</span>
                    <q-badge
                      :color="shop.is_active ? 'positive' : 'grey-5'"
                      class="text-uppercase text-bold"
                      style="font-size: 10px; padding: 2px 6px; border-radius: 4px"
                    >
                      {{ shop.is_active ? $t('shop_admin.public') : $t('shop_admin.draft') }}
                    </q-badge>
                  </div>
                  <div class="row items-center q-gutter-x-xs q-mt-xs">
                    <q-chip
                      dense
                      square
                      outline
                      size="sm"
                      :color="shopTypeColor(shop.shop_type)"
                      class="text-capitalize text-weight-medium"
                    >
                      {{ shopTypeLabel(shop.shop_type) }}
                    </q-chip>
                  </div>
                </q-item-section>

                <q-item-section side>
                  <q-btn
                    flat
                    round
                    dense
                    icon="ph ph-dots-three-vertical"
                    color="grey-7"
                    @click.stop
                  >
                    <q-menu auto-close style="min-width: 150px">
                      <q-list dense class="q-py-xs">
                        <q-item clickable @click="goToSetup(shop.id)">
                          <q-item-section avatar class="q-pr-none" style="min-width: 28px">
                            <q-icon name="ph ph-gear" size="xs" color="grey-7" />
                          </q-item-section>
                          <q-item-section>Shop Setup</q-item-section>
                        </q-item>

                        <q-separator class="q-my-xs" />

                        <q-item clickable class="text-negative" @click="confirmDeleteShop(shop)">
                          <q-item-section avatar class="q-pr-none" style="min-width: 28px">
                            <q-icon name="ph ph-trash" size="xs" color="negative" />
                          </q-item-section>
                          <q-item-section>Delete</q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-btn>
                </q-item-section>
              </q-item>
            </q-list>
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
    vendor_catalog: 'indigo-7',
    fixed_price: 'teal-7',
    dropship: 'deep-orange-7',
  })[type] ?? 'grey-7';
</script>

<style scoped>
.shops-list-wrap {
  min-height: 0;
}

.floating-surface {
  background: #ffffff;
  border-radius: 8px;
  border: none;
  box-shadow: none;
}

body.body--dark .floating-surface {
  background: #1c1c1c;
}
</style>
