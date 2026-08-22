<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section>
        <div class="text-overline text-primary">{{ $t('shop_admin.shop_and_order') }}</div>
        <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('navigation.shops') }}</h1>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
          {{ $t('shop_admin.shop_setup_hub_caption') }}
        </p>
      </section>

      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-4">
          <q-card
            flat
            bordered
            class="cursor-pointer full-height"
            @click="go('app-shop-shops-list-page')"
          >
            <q-card-section>
              <q-icon name="ph ph-storefront" size="28px" color="primary" />
              <div class="text-subtitle1 text-weight-bold q-mt-sm">
                {{ $t('navigation.shops') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.shop_hub_shops_caption') }}
              </div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-4">
          <q-card
            flat
            bordered
            class="cursor-pointer full-height"
            @click="go('app-shop-categories-page')"
          >
            <q-card-section>
              <q-icon name="ph ph-squares-four" size="28px" color="primary" />
              <div class="text-subtitle1 text-weight-bold q-mt-sm">
                {{ $t('navigation.categories') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.shop_hub_categories_caption') }}
              </div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-4">
          <q-card
            flat
            bordered
            class="cursor-pointer full-height"
            @click="go('app-customers')"
          >
            <q-card-section>
              <q-icon name="ph ph-users-three" size="28px" color="primary" />
              <div class="text-subtitle1 text-weight-bold q-mt-sm">
                {{ $t('navigation.customer_groups') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.shop_hub_groups_caption') }}
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const router = useRouter();
const authStore = useAuthStore();

function go(name: string) {
  void router.push({
    name,
    params: { tenantSlug: authStore.selectedTenant?.slug },
  });
}
</script>

<script lang="ts">
export default {
  name: 'ShopSetupHubPage',
};
</script>
