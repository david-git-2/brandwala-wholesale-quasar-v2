<template>
  <div class="q-gutter-y-md">
    <!-- Catalog: centered shell -->
    <template v-if="variant === 'catalog'">
      <div class="row justify-center">
        <div class="catalog-order-shell column q-gutter-y-md">
          <q-card flat bordered class="catalog-progress-bar q-pa-sm">
            <div class="column q-gutter-y-xs">
              <div class="row items-center justify-between no-wrap q-gutter-x-sm">
                <div class="column col">
                  <q-skeleton type="text" width="120px" height="20px" />
                  <q-skeleton type="text" width="90px" height="14px" class="q-mt-xs" />
                </div>
                <q-skeleton type="text" width="64px" height="18px" />
              </div>
              <q-skeleton type="rect" height="6px" class="rounded-borders" />
            </div>
          </q-card>

          <div class="row items-center justify-between q-col-gutter-sm">
            <q-skeleton type="text" width="160px" height="24px" />
            <q-skeleton type="text" width="100px" height="16px" class="gt-sm" />
          </div>

          <q-card
            v-for="n in 2"
            :key="n"
            flat
            bordered
            class="item-card-skeleton"
          >
            <q-card-section class="q-pa-md column q-gutter-y-md">
              <div class="row items-start q-gutter-x-md">
                <q-skeleton type="rect" width="80px" height="80px" class="rounded-borders" />
                <div class="col column q-gutter-y-sm">
                  <q-skeleton type="text" width="85%" height="22px" />
                  <div class="row q-gutter-x-sm">
                    <q-skeleton type="rect" width="64px" height="24px" class="rounded-borders" />
                    <q-skeleton type="rect" width="88px" height="24px" class="rounded-borders" />
                  </div>
                </div>
              </div>

              <q-skeleton type="rect" height="56px" class="rounded-borders" />
              <q-skeleton type="rect" height="72px" class="rounded-borders" />

              <div class="row items-center justify-between q-pt-sm border-top">
                <q-skeleton type="text" width="72px" height="16px" />
                <q-skeleton type="text" width="96px" height="24px" />
              </div>
            </q-card-section>
          </q-card>

          <q-card flat bordered class="details-card">
            <q-card-section class="q-px-lg q-py-md border-bottom">
              <q-skeleton type="text" width="140px" height="24px" />
            </q-card-section>
            <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
              <q-skeleton type="text" width="50%" height="20px" />
              <q-skeleton type="text" width="40%" height="18px" />
              <q-skeleton type="rect" height="64px" class="rounded-borders q-mt-sm" />
            </q-card-section>
          </q-card>

          <q-card flat bordered class="order-action-bar-skeleton">
            <q-card-section class="q-pa-md column q-gutter-y-sm">
              <div class="row items-center justify-between">
                <q-skeleton type="text" width="108px" height="18px" />
                <q-skeleton type="rect" width="88px" height="22px" class="rounded-borders" />
              </div>
              <q-skeleton type="rect" height="8px" class="rounded-borders" />
              <q-skeleton type="QBtn" height="48px" class="full-width" />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </template>

    <!-- Dropship / other: header + 8/4 columns -->
    <template v-else>
      <q-skeleton type="text" width="280px" height="14px" class="q-mb-sm" />

      <q-card flat bordered class="q-pa-sm bg-grey-1">
        <div class="row items-center justify-center no-wrap q-gutter-x-xs">
          <q-skeleton type="rect" class="col" height="28px" style="border-radius: 999px" />
          <q-icon name="ph ph-caret-right" color="grey-3" size="16px" />
          <q-skeleton type="rect" width="120px" height="28px" style="border-radius: 16px" />
        </div>
      </q-card>

      <div class="row q-col-gutter-lg">
        <div class="col-xs-12 col-md-8">
          <q-card flat bordered class="details-card">
            <q-card-section class="q-px-lg q-py-md border-bottom row items-center justify-between">
              <q-skeleton type="text" width="150px" height="24px" />
              <q-skeleton type="text" width="110px" height="16px" />
            </q-card-section>
            <q-list separator>
              <q-item v-for="i in 2" :key="i" class="q-py-md q-px-lg">
                <q-item-section avatar>
                  <q-skeleton type="QAvatar" size="50px" rounded />
                </q-item-section>
                <q-item-section>
                  <q-skeleton type="text" width="60%" height="20px" />
                  <q-skeleton type="text" width="40%" height="16px" class="q-mt-xs" />
                </q-item-section>
                <q-item-section side class="column items-end justify-center q-gutter-y-sm">
                  <div class="column items-end">
                    <q-skeleton type="text" width="72px" height="12px" />
                    <q-skeleton type="text" width="88px" height="18px" class="q-mt-xs" />
                    <q-skeleton type="text" width="96px" height="14px" class="q-mt-xs" />
                  </div>
                  <div class="column items-end">
                    <q-skeleton type="text" width="80px" height="12px" />
                    <q-skeleton type="text" width="92px" height="18px" class="q-mt-xs" />
                    <q-skeleton type="text" width="104px" height="14px" class="q-mt-xs" />
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card>
        </div>

        <div class="col-xs-12 col-md-4">
          <div class="column q-gutter-md">
            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <q-skeleton type="text" width="120px" height="24px" />
              </q-card-section>
              <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
                <div v-for="i in 4" :key="i" class="row justify-between">
                  <q-skeleton type="text" width="40%" height="20px" />
                  <q-skeleton type="text" width="30%" height="20px" />
                </div>
                <q-separator class="q-my-sm" />
                <div class="row justify-between items-baseline">
                  <q-skeleton type="text" width="50%" height="24px" />
                  <q-skeleton type="text" width="30%" height="28px" />
                </div>
              </q-card-section>
            </q-card>

            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <q-skeleton type="text" width="140px" height="24px" />
              </q-card-section>
              <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
                <q-skeleton type="text" width="50%" height="20px" />
                <q-skeleton type="text" width="40%" height="18px" />
                <q-skeleton type="rect" height="64px" class="rounded-borders q-mt-sm" />
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    variant?: 'catalog' | 'dropship';
  }>(),
  {
    variant: 'dropship',
  },
);
</script>

<style scoped>
.catalog-order-shell {
  width: 100%;
  max-width: 640px;
  margin: 0 auto;
}

@media (min-width: 600px) {
  .catalog-order-shell {
    max-width: 720px;
  }
}

.details-card,
.item-card-skeleton,
.order-action-bar-skeleton,
.catalog-progress-bar {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.item-card-skeleton {
  border-radius: 12px;
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.border-top {
  border-top: 1px solid rgba(34, 56, 101, 0.08);
}
</style>
