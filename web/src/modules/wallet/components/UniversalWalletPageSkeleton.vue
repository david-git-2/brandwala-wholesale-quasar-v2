<template>
  <div class="q-gutter-y-md">
    <!-- Header Skeleton -->
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <q-skeleton type="text" width="100px" height="14px" class="q-mb-xs" />
        <q-skeleton type="text" width="220px" height="32px" class="q-mb-xs" />
        <q-skeleton type="text" width="400px" height="14px" />
      </div>
      <div class="col-auto">
        <q-skeleton type="QBadge" width="140px" height="28px" />
      </div>
    </section>

    <!-- Entity Tabs Skeleton -->
    <q-card flat bordered class="q-pa-xs">
      <div class="row items-center q-gutter-x-sm q-pa-xs">
        <div v-for="n in 4" :key="n" class="row items-center q-gutter-x-sm q-pa-sm" style="min-width: 140px">
          <q-skeleton type="QAvatar" size="32px" />
          <div class="column">
            <q-skeleton type="text" width="70px" height="14px" />
            <q-skeleton type="text" width="90px" height="10px" />
          </div>
        </div>
      </div>
    </q-card>

    <!-- Entity Selector Skeleton -->
    <q-card flat bordered class="q-pa-md">
      <div class="row items-center justify-between q-col-gutter-md">
        <div class="col-xs-12 col-sm-6 col-md-5">
          <q-skeleton type="text" width="120px" height="12px" class="q-mb-xs" />
          <q-skeleton type="QInput" height="40px" />
        </div>
        <div class="col-xs-12 col-sm-6 col-md-7">
          <q-skeleton type="rect" height="48px" class="rounded-borders" />
        </div>
      </div>
    </q-card>

    <!-- Universal Wallet Core Skeleton -->
    <UniversalWalletSkeleton />
  </div>
</template>

<script setup lang="ts">
import UniversalWalletSkeleton from './skeletons/UniversalWalletSkeleton.vue';
</script>
