<template>
  <div class="q-gutter-y-md">
    <!-- Catalog: workflow bar + items table + staff actions -->
    <template v-if="variant === 'catalog'">
      <q-card flat bordered class="catalog-progress-bar q-pa-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col-grow">
            <div class="row items-center q-gutter-xs workflow-row">
              <template v-for="n in 5" :key="n">
                <q-skeleton type="rect" width="88px" height="28px" class="rounded-borders" />
                <q-icon
                  v-if="n < 5"
                  name="ph ph-caret-right"
                  color="grey-3"
                  size="16px"
                />
              </template>
            </div>
          </div>
          <div class="col-auto row items-center q-gutter-x-xs no-wrap">
            <q-skeleton type="text" width="120px" height="14px" class="gt-xs" />
            <q-skeleton type="QBtn" width="72px" height="32px" />
            <q-skeleton type="QBtn" width="32px" height="32px" />
          </div>
        </div>
      </q-card>

      <q-card flat bordered class="catalog-items-skeleton">
        <div class="catalog-items-skeleton__header row items-center q-px-md q-py-sm border-bottom">
          <q-skeleton
            v-for="n in 6"
            :key="n"
            type="text"
            :width="catalogHeaderWidths[n - 1]"
            height="14px"
            class="catalog-items-skeleton__header-cell"
          />
        </div>

        <div
          v-for="row in 4"
          :key="row"
          class="catalog-items-skeleton__row row items-center q-px-md q-py-sm border-bottom"
        >
          <q-skeleton type="text" width="24px" height="16px" class="catalog-items-skeleton__cell--sl" />
          <q-skeleton type="rect" width="48px" height="48px" class="rounded-borders catalog-items-skeleton__cell--image" />
          <q-skeleton type="text" width="72%" height="18px" class="catalog-items-skeleton__cell--name" />
          <q-skeleton type="text" width="56px" height="16px" class="catalog-items-skeleton__cell--qty gt-sm" />
          <q-skeleton type="text" width="64px" height="16px" class="catalog-items-skeleton__cell--price gt-sm" />
          <q-skeleton type="text" width="72px" height="16px" class="catalog-items-skeleton__cell--offer gt-md" />
        </div>
      </q-card>

      <q-card flat bordered class="catalog-staff-actions-skeleton q-pa-md">
        <div class="row items-center justify-between q-col-gutter-sm">
          <q-skeleton type="QBtn" width="132px" height="40px" />
          <div class="row items-center q-gutter-sm justify-end">
            <q-skeleton type="text" width="140px" height="14px" class="gt-xs" />
            <q-skeleton type="QBtn" width="168px" height="40px" />
          </div>
        </div>
      </q-card>
    </template>

    <!-- Fixed / other: status workflow + 8/4 columns -->
    <template v-else>
      <q-card flat bordered class="q-pa-sm">
        <div class="row items-center q-gutter-xs workflow-row">
          <template v-for="n in 4" :key="n">
            <q-skeleton type="rect" width="96px" height="28px" class="rounded-borders" />
            <q-icon
              v-if="n < 4"
              name="chevron_right"
              color="grey-3"
              size="18px"
            />
          </template>
          <q-separator vertical class="q-mx-sm" />
          <q-skeleton type="rect" width="88px" height="28px" class="rounded-borders" />
        </div>
      </q-card>

      <div class="row q-col-gutter-lg">
        <div class="col-xs-12 col-md-8">
          <q-card flat bordered class="details-card">
            <q-card-section class="q-px-lg q-py-md border-bottom row items-center justify-between">
              <q-skeleton type="text" width="120px" height="24px" />
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
                  </div>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card>

          <div class="q-mt-md row items-center justify-between">
            <q-skeleton type="QBtn" width="132px" height="40px" />
            <div class="row q-gutter-md">
              <q-skeleton type="QBtn" width="148px" height="40px" />
              <q-skeleton type="QBtn" width="132px" height="40px" />
            </div>
          </div>
        </div>

        <div class="col-xs-12 col-md-4">
          <div class="column q-gutter-md">
            <q-card flat bordered class="details-card">
              <q-card-section class="q-px-lg q-py-md border-bottom">
                <q-skeleton type="text" width="130px" height="24px" />
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
    variant: 'catalog',
  },
);

const catalogHeaderWidths = ['24px', '48px', '120px', '56px', '64px', '72px'];
</script>

<style scoped>
.details-card,
.catalog-progress-bar,
.catalog-items-skeleton,
.catalog-staff-actions-skeleton {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.catalog-items-skeleton {
  min-height: 360px;
}

.catalog-items-skeleton__header,
.catalog-items-skeleton__row {
  gap: 12px;
}

.catalog-items-skeleton__header-cell,
.catalog-items-skeleton__cell--sl {
  flex: 0 0 auto;
}

.catalog-items-skeleton__cell--image {
  flex: 0 0 48px;
}

.catalog-items-skeleton__cell--name {
  flex: 1 1 auto;
  min-width: 0;
}

.catalog-items-skeleton__cell--qty,
.catalog-items-skeleton__cell--price,
.catalog-items-skeleton__cell--offer {
  flex: 0 0 auto;
}

.workflow-row {
  flex-wrap: wrap;
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}
</style>
