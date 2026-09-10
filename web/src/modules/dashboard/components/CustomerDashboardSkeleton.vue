<template>
  <div class="q-gutter-y-md">
    <q-skeleton type="text" width="55%" height="48px" class="q-mx-auto q-mb-md" />
    <div class="row justify-center q-col-gutter-lg q-mb-md">
      <div v-for="n in 2" :key="`stat-${n}`" class="col-auto text-center">
        <q-skeleton type="text" width="56px" height="28px" class="q-mx-auto q-mb-xs" />
        <q-skeleton type="text" width="88px" height="14px" class="q-mx-auto" />
      </div>
    </div>

    <div>
      <q-skeleton type="text" width="120px" height="22px" class="q-mx-auto q-mb-md" />
      <div class="row q-col-gutter-md">
        <div v-for="n in 3" :key="`shop-${n}`" class="col-12 col-sm-6 col-md-3">
          <q-skeleton type="rect" height="88px" class="rounded-borders" />
        </div>
      </div>
    </div>

    <div>
      <q-skeleton type="text" width="120px" height="22px" class="q-mx-auto q-mb-md" />
      <q-card flat bordered class="q-pa-md q-mb-md">
        <div class="row q-col-gutter-sm q-mb-sm">
        <div v-for="n in 3" :key="n" class="col-4">
          <q-skeleton type="text" width="70%" height="14px" class="q-mb-xs" />
          <q-skeleton type="text" width="36%" height="22px" />
        </div>
      </div>
        <q-skeleton type="rect" height="8px" class="rounded-borders" />
      </q-card>
      <q-skeleton type="rect" height="120px" class="rounded-borders" />
    </div>

    <div class="row q-col-gutter-md">
      <div class="col-12 col-md-5">
        <q-card flat bordered class="q-pa-md">
          <q-skeleton type="text" width="72px" height="12px" class="q-mb-sm" />
          <div class="row items-center q-gutter-sm">
            <q-skeleton type="QAvatar" size="44px" />
            <div class="col">
              <q-skeleton type="text" width="70%" height="18px" />
            </div>
            <q-skeleton type="QBtn" width="72px" height="36px" />
          </div>
        </q-card>
      </div>
      <div class="col-12 col-md-7">
        <q-skeleton type="text" width="90px" height="12px" class="q-mb-sm" />
        <q-skeleton type="QInput" height="40px" />
      </div>
    </div>

    <div>
      <q-skeleton type="text" width="120px" height="22px" class="q-mb-xs" />
      <q-skeleton type="text" width="200px" height="14px" class="q-mb-md" />
      <div class="row q-col-gutter-md">
        <div v-for="n in 3" :key="n" class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="q-pa-md" style="min-height: 148px">
            <div class="row items-center q-gutter-sm q-mb-md">
              <q-skeleton type="QAvatar" size="42px" />
              <div class="col">
                <q-skeleton type="text" width="70%" height="18px" class="q-mb-xs" />
                <q-skeleton type="text" width="40%" height="14px" />
              </div>
            </div>
            <q-skeleton type="text" width="50%" height="16px" />
          </q-card>
        </div>
      </div>
    </div>
  </div>
</template>
