<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section>
        <div class="text-overline text-primary">{{ $t('shop_admin.shop_and_order') }}</div>
        <h1 class="text-h5 text-weight-bold q-my-none">{{ $t('navigation.shipping') }}</h1>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
          {{ $t('shop_admin.shipping_hub_caption') }}
        </p>
      </section>

      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-4">
          <q-card
            flat
            bordered
            class="cursor-pointer full-height"
            @click="go('app-shop-dropship-couriers-page')"
          >
            <q-card-section>
              <q-icon name="ph ph-truck" size="28px" color="primary" />
              <div class="text-subtitle1 text-weight-bold q-mt-sm">
                {{ $t('shop_admin.shipping_couriers') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.shipping_couriers_caption') }}
              </div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-4">
          <q-card
            flat
            bordered
            class="cursor-pointer full-height"
            @click="go('app-shop-dropship-finance-hub-page')"
          >
            <q-card-section>
              <q-icon name="ph ph-bank" size="28px" color="primary" />
              <div class="text-subtitle1 text-weight-bold q-mt-sm">
                {{ $t('shop_admin.shipping_remittance') }}
              </div>
              <div class="text-caption text-grey-7">
                {{ $t('shop_admin.shipping_remittance_caption') }}
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
  name: 'ShopShippingHubPage',
};
</script>
