<script setup lang="ts">
</script>

<template>
  <div class="q-gutter-y-md">
    <!-- Header Skeleton -->
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-skeleton type="QBtn" size="36px" />
          <div class="q-gutter-y-xs">
            <q-skeleton type="text" width="90px" height="14px" />
            <q-skeleton type="text" width="220px" height="28px" />
            <q-skeleton type="text" width="160px" height="16px" />
          </div>
        </div>
      </div>
      <div class="col-auto row q-gutter-sm items-center">
        <q-skeleton type="QBtn" width="150px" height="36px" />
        <q-skeleton type="QBtn" width="160px" height="36px" />
      </div>
    </section>

    <!-- Status Strip Skeleton -->
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center q-gutter-x-md">
        <q-skeleton type="QBtn" width="100px" height="28px" v-for="i in 5" :key="i" />
      </div>
    </q-card>

    <div class="row q-col-gutter-lg">
      <div class="col-xs-12 col-md-8">
        <div class="q-gutter-y-md">
          <q-card flat bordered v-for="i in 4" :key="i" class="q-pa-md">
            <q-skeleton type="text" width="40%" height="24px" class="q-mb-md" />
            <div class="row q-col-gutter-md">
              <div class="col-6" v-for="j in 4" :key="j">
                <q-skeleton type="QInput" height="40px" />
              </div>
            </div>
          </q-card>
        </div>
      </div>
      <div class="col-xs-12 col-md-4">
        <div class="q-gutter-y-md">
          <q-card flat bordered v-for="i in 2" :key="i" class="q-pa-md">
            <q-skeleton type="text" width="50%" height="24px" class="q-mb-md" />
            <q-skeleton type="rect" height="120px" />
          </q-card>
        </div>
      </div>
    </div>
  </div>
</template>
