<template>
  <div class="q-gutter-y-md">
    <!-- Generator Form Skeleton Card -->
    <q-card flat bordered class="q-pa-md">
      <q-skeleton type="text" width="160px" height="20px" class="q-mb-md" />
      <div class="row q-col-gutter-md items-end">
        <div class="col-12 col-sm-6">
          <q-skeleton type="text" width="90%" height="16px" />
          <q-skeleton type="text" width="70%" height="16px" class="q-mt-xs" />
        </div>
        <div class="col-12 col-sm-3">
          <q-skeleton type="QInput" height="40px" />
        </div>
        <div class="col-12 col-sm-3">
          <q-skeleton type="QBtn" width="100%" height="40px" />
        </div>
      </div>
    </q-card>

    <!-- Toolbar Card Skeleton -->
    <q-card flat bordered class="q-pa-sm">
      <div class="row q-col-gutter-sm items-center">
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="36px" />
        </div>
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="36px" />
        </div>
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="36px" />
        </div>
      </div>
    </q-card>

    <!-- Data Table Skeleton -->
    <q-markup-table flat bordered>
      <thead>
        <tr>
          <th style="width: 40px"><q-skeleton type="QCheckbox" /></th>
          <th><q-skeleton type="text" width="100px" /></th>
          <th class="text-center"><q-skeleton type="text" width="70px" class="q-mx-auto" /></th>
          <th class="text-center"><q-skeleton type="text" width="70px" class="q-mx-auto" /></th>
          <th><q-skeleton type="text" width="120px" /></th>
          <th><q-skeleton type="text" width="140px" /></th>
          <th class="text-center"><q-skeleton type="text" width="60px" class="q-mx-auto" /></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="n in 8" :key="n">
          <td><q-skeleton type="QCheckbox" /></td>
          <td><q-skeleton type="text" width="120px" /></td>
          <td class="text-center"><q-skeleton type="QBadge" width="75px" height="22px" class="q-mx-auto" /></td>
          <td class="text-center"><q-skeleton type="QBadge" width="50px" height="22px" class="q-mx-auto" /></td>
          <td><q-skeleton type="text" width="110px" /></td>
          <td><q-skeleton type="text" width="130px" /></td>
          <td class="text-center"><q-skeleton type="QBtn" width="32px" height="32px" class="q-mx-auto" /></td>
        </tr>
      </tbody>
    </q-markup-table>
  </div>
</template>

<script setup lang="ts">
// Skeleton component for ThriftBarcodePage
</script>
