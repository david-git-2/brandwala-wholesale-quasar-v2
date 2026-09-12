<template>
  <div class="q-gutter-y-md">
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-skeleton type="QBtn" size="32px" flat />
          <div>
            <q-skeleton type="text" width="100px" height="14px" class="q-mb-xs" />
            <q-skeleton type="text" width="220px" height="32px" />
          </div>
        </div>
      </div>
      <div class="col-auto">
        <q-skeleton type="QBtn" width="120px" height="36px" />
      </div>
    </section>

    <div class="row q-col-gutter-lg">
      <div class="col-xs-12 col-md-8 q-gutter-y-md">
        <q-card flat bordered class="floating-surface q-pa-md">
          <div class="row items-center justify-between q-mb-md">
            <q-skeleton type="text" width="140px" height="24px" />
            <q-skeleton type="text" width="80px" height="18px" />
          </div>
          <template v-for="n in 3" :key="n">
            <div class="row items-center justify-between q-py-sm">
              <div class="row items-center q-gutter-x-md col">
                <q-skeleton type="rect" width="60px" height="60px" class="rounded-borders" />
                <div class="col">
                  <q-skeleton type="text" width="60%" height="20px" class="q-mb-xs" />
                  <q-skeleton type="text" width="40%" height="14px" />
                </div>
              </div>
              <div class="col-auto row items-center q-gutter-x-md">
                <q-skeleton type="QInput" width="80px" height="32px" />
                <q-skeleton type="text" width="70px" height="20px" />
              </div>
            </div>
            <q-separator v-if="n < 3" />
          </template>
        </q-card>
      </div>

      <div class="col-xs-12 col-md-4">
        <q-card flat bordered class="floating-surface q-pa-md">
          <q-skeleton type="text" width="120px" height="20px" class="q-mb-md" />
          <div v-for="n in 4" :key="n" class="row justify-between q-mb-sm">
            <q-skeleton type="text" width="35%" height="16px" />
            <q-skeleton type="text" width="25%" height="16px" />
          </div>
          <q-skeleton type="rect" height="1px" class="q-my-md" />
          <div class="row justify-between items-center q-mb-lg">
            <q-skeleton type="text" width="40%" height="22px" />
            <q-skeleton type="text" width="30%" height="26px" />
          </div>
          <q-skeleton type="QBtn" width="100%" height="40px" />
        </q-card>
      </div>
    </div>
  </div>
</template>
