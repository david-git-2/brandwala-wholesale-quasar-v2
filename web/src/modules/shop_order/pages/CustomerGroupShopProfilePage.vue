<template>
  <q-page class="bw-page">
    <section class="bw-page__stack" style="max-width: 800px">
      <!-- Header -->
      <section class="row items-center q-col-gutter-md">
        <div class="col-auto">
          <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
        </div>
        <div class="col">
          <div class="text-overline">Customer Access</div>
          <h1 class="text-h5 q-my-none">Default Shop Profile</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Configure default shop capability rules for this customer group.
          </p>
        </div>
      </section>

      <!-- Error banner -->
      <q-banner v-if="store.error" class="text-white bg-negative" rounded>
        {{ store.error }}
        <template #action>
          <q-btn flat color="white" label="Dismiss" @click="store.clearError()" />
        </template>
      </q-banner>

      <!-- Loading state -->
      <q-card v-if="store.loadingProfile" flat bordered>
        <q-card-section class="text-center q-pa-xl text-grey-7">
          <q-spinner size="32px" color="primary" class="q-mr-sm" />
          Loading profile settings…
        </q-card-section>
      </q-card>

      <!-- Config Form -->
      <q-card v-else flat bordered>
        <q-card-section class="q-gutter-y-md">
          <div class="text-subtitle2 text-grey-8">Profile Master Switch</div>
          <q-list bordered separator class="rounded-borders">
            <q-item tag="label" v-ripple>
              <q-item-section>
                <q-item-label>Profile Active</q-item-label>
                <q-item-label caption
                  >If disabled, all shops are immediately inaccessible to members of this
                  group.</q-item-label
                >
              </q-item-section>
              <q-item-section avatar>
                <q-toggle v-model="form.is_active" color="primary" />
              </q-item-section>
            </q-item>
          </q-list>

          <div class="text-subtitle2 text-grey-8 q-mt-lg">Default Permissions</div>
          <q-list bordered separator class="rounded-borders">
            <!-- Browse -->
            <q-item tag="label" v-ripple>
              <q-item-section>
                <q-item-label>Browse Shop Catalog</q-item-label>
                <q-item-label caption
                  >Allows group members to view the shop and its products.</q-item-label
                >
              </q-item-section>
              <q-item-section avatar>
                <q-toggle v-model="form.default_can_browse" color="primary" />
              </q-item-section>
            </q-item>

            <!-- See Price -->
            <q-item tag="label" v-ripple>
              <q-item-section>
                <q-item-label>See Unit Prices</q-item-label>
                <q-item-label caption>Display catalog prices to members.</q-item-label>
              </q-item-section>
              <q-item-section avatar>
                <q-toggle v-model="form.default_see_price" color="primary" />
              </q-item-section>
            </q-item>

            <!-- View Qty -->
            <q-item tag="label" v-ripple>
              <q-item-section>
                <q-item-label>View Stock Quantities</q-item-label>
                <q-item-label caption
                  >Show exact stock quantities when the shop displays stock.</q-item-label
                >
              </q-item-section>
              <q-item-section avatar>
                <q-toggle v-model="form.default_can_view_quantity" color="primary" />
              </q-item-section>
            </q-item>

            <!-- Add to Cart -->
            <q-item tag="label" v-ripple>
              <q-item-section>
                <q-item-label>Add to Cart</q-item-label>
                <q-item-label caption>Allows adding items to the checkout cart.</q-item-label>
              </q-item-section>
              <q-item-section avatar>
                <q-toggle v-model="form.default_can_add_to_cart" color="primary" />
              </q-item-section>
            </q-item>

            <!-- Place Order -->
            <q-item tag="label" v-ripple>
              <q-item-section>
                <q-item-label>Place / Submit Order</q-item-label>
                <q-item-label caption
                  >Allows checking out and placing orders or procurement intents.</q-item-label
                >
              </q-item-section>
              <q-item-section avatar>
                <q-toggle v-model="form.default_can_place_order" color="primary" />
              </q-item-section>
            </q-item>

            <!-- Negotiate -->
            <q-item tag="label" v-ripple>
              <q-item-section>
                <q-item-label>Can Negotiate</q-item-label>
                <q-item-label caption
                  >Permits making counter-offers on negotiable shops.</q-item-label
                >
              </q-item-section>
              <q-item-section avatar>
                <q-toggle v-model="form.default_can_negotiate" color="primary" />
              </q-item-section>
            </q-item>

            <!-- Dropship Price -->
            <q-item tag="label" v-ripple>
              <q-item-section>
                <q-item-label>Set Dropship Price</q-item-label>
                <q-item-label caption
                  >Allows manual overrides on line-level dropship sell prices above the
                  minimum.</q-item-label
                >
              </q-item-section>
              <q-item-section avatar>
                <q-toggle v-model="form.default_can_set_dropship_price" color="primary" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card-section>

        <!-- Actions -->
        <q-card-actions align="right" class="q-pa-md border-top">
          <q-btn flat label="Cancel" color="grey-7" @click="goBack" />
          <q-btn
            unelevated
            label="Save Changes"
            color="primary"
            :loading="store.saving"
            @click="onSave"
          />
        </q-card-actions>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useShopPermissionsStore } from '../stores/shopPermissionsStore';
import type { UpsertProfilePayload } from '../types';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const store = useShopPermissionsStore();

const tenantId = computed(() => authStore.tenantId as number);
const groupId = computed(() => Number(route.params.groupId));
const tenantSlug = computed(() => authStore.selectedTenant?.slug ?? '');

const form = ref<UpsertProfilePayload>({
  tenant_id: 0,
  customer_group_id: 0,
  is_active: true,
  default_can_browse: true,
  default_see_price: false,
  default_can_add_to_cart: true,
  default_can_place_order: true,
  default_can_negotiate: false,
  default_can_view_quantity: true,
  default_can_set_dropship_price: false,
});

const load = async () => {
  if (!tenantId.value || !groupId.value) return;
  form.value.tenant_id = tenantId.value;
  form.value.customer_group_id = groupId.value;

  const res = await store.fetchProfile(tenantId.value, groupId.value);
  if (res.success && store.activeProfile) {
    const p = store.activeProfile;
    form.value.is_active = p.is_active;
    form.value.default_can_browse = p.default_can_browse;
    form.value.default_see_price = p.default_see_price;
    form.value.default_can_add_to_cart = p.default_can_add_to_cart;
    form.value.default_can_place_order = p.default_can_place_order;
    form.value.default_can_negotiate = p.default_can_negotiate;
    form.value.default_can_view_quantity = p.default_can_view_quantity;
    form.value.default_can_set_dropship_price = p.default_can_set_dropship_price;
  }
};

const onSave = async () => {
  const res = await store.saveProfile(form.value);
  if (res.success) {
    goBack();
  }
};

const goBack = () => {
  void router.push({
    name: 'app-shop-customer-groups-page',
    params: { tenantSlug: tenantSlug.value },
  });
};

onMounted(load);
</script>
