<template>
  <div class="q-gutter-y-md">
    <!-- Hero Skeleton -->
    <q-card flat bordered class="q-pa-md q-pa-sm-lg q-pa-md-xl">
      <div class="row items-center justify-between q-col-gutter-md">
        <div class="col-12 col-md-7">
          <q-skeleton type="text" width="120px" height="14px" class="q-mb-xs" />
          <q-skeleton type="text" width="280px" height="36px" class="q-mb-sm" />
          <q-skeleton type="text" width="200px" height="18px" class="q-mb-md" />
          <q-skeleton type="QInput" height="40px" style="max-width: 540px;" />
        </div>
        <div class="col-12 col-md-5 text-right gt-sm">
          <q-skeleton type="rect" width="140px" height="140px" class="q-ml-auto rounded-borders" />
        </div>
      </div>
    </q-card>

    <!-- Stat Cards Skeleton -->
    <div class="row q-col-gutter-md">
      <div v-for="n in 3" :key="n" class="col-12 col-sm-4">
        <q-card flat bordered class="q-pa-md">
          <div class="row items-center justify-between no-wrap">
            <div class="full-width">
              <q-skeleton type="text" width="80px" height="14px" class="q-mb-xs" />
              <q-skeleton type="text" width="60px" height="28px" />
            </div>
            <q-skeleton type="QAvatar" size="44px" />
          </div>
        </q-card>
      </div>
    </div>

    <!-- Shops Grid Skeleton -->
    <div>
      <div class="q-mb-md">
        <q-skeleton type="text" width="160px" height="22px" class="q-mb-xs" />
        <q-skeleton type="text" width="220px" height="14px" />
      </div>
      <div class="row q-col-gutter-md">
        <div v-for="n in 3" :key="n" class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="q-pa-md" style="min-height: 160px;">
            <q-skeleton type="text" width="70%" height="20px" class="q-mb-md" />
            <div class="row q-col-gutter-sm">
              <div v-for="c in 2" :key="c" class="col-6">
                <q-card flat bordered class="q-pa-sm text-center">
                  <q-skeleton type="QAvatar" size="38px" class="q-mx-auto q-mb-xs" />
                  <q-skeleton type="text" width="80%" class="q-mx-auto" />
                </q-card>
              </div>
            </div>
          </q-card>
        </div>
      </div>
    </div>

    <!-- Workspace Hub & Recent Activity Skeleton -->
    <div class="row q-col-gutter-md q-col-gutter-md-lg">
      <div class="col-12 col-md-6">
        <q-skeleton type="text" width="140px" height="22px" class="q-mb-md" />
        <div class="row q-col-gutter-md">
          <div v-for="n in 4" :key="n" class="col-12 col-sm-6">
            <q-card flat bordered class="q-pa-md">
              <div class="row items-center no-wrap q-gutter-x-sm">
                <q-skeleton type="QAvatar" size="40px" />
                <div class="full-width">
                  <q-skeleton type="text" width="70%" height="18px" class="q-mb-xs" />
                  <q-skeleton type="text" width="90%" height="14px" />
                </div>
              </div>
            </q-card>
          </div>
        </div>
      </div>

      <div class="col-12 col-md-6">
        <div class="row items-center justify-between q-mb-md">
          <q-skeleton type="text" width="130px" height="22px" />
          <q-skeleton type="QBtn" width="90px" height="24px" />
        </div>
        <q-card flat bordered class="q-pa-sm">
          <div v-for="n in 3" :key="n" class="q-py-sm">
            <div class="row items-center justify-between">
              <div>
                <q-skeleton type="text" width="100px" height="18px" class="q-mb-xs" />
                <q-skeleton type="text" width="80px" height="14px" />
              </div>
              <div class="text-right">
                <q-skeleton type="text" width="70px" height="18px" class="q-mb-xs q-ml-auto" />
                <q-skeleton type="text" width="90px" height="14px" class="q-ml-auto" />
              </div>
              <q-skeleton type="QBadge" width="70px" height="22px" />
            </div>
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>
