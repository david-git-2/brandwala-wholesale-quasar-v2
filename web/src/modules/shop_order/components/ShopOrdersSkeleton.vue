<template>
  <div class="q-gutter-y-md">
    <!-- Header Skeleton -->
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <q-skeleton type="text" width="100px" height="14px" class="q-mb-xs" />
        <q-skeleton type="text" width="200px" height="32px" class="q-mb-xs" />
        <q-skeleton type="text" width="280px" height="16px" />
      </div>
      <div class="col-auto">
        <q-skeleton type="QBtn" width="160px" height="36px" />
      </div>
    </section>

    <!-- Toolbar Filters Skeleton -->
    <div class="column q-gutter-y-md">
      <div class="row items-center q-mb-xs">
        <div class="col-12 row q-gutter-xs">
          <q-skeleton type="QBtn" width="80px" height="32px" />
          <q-skeleton type="QBtn" width="100px" height="32px" />
          <q-skeleton type="QBtn" width="90px" height="32px" />
        </div>
      </div>
      <section class="row items-center q-col-gutter-md">
        <div class="col-12 col-sm-5">
          <q-skeleton type="QInput" height="40px" />
        </div>
        <div class="col-auto">
          <q-skeleton type="QInput" width="160px" height="40px" />
        </div>
      </section>
    </div>

    <!-- Table Skeleton -->
    <q-card flat bordered>
      <q-markup-table flat>
        <thead>
          <tr>
            <th><q-skeleton type="text" width="80px" /></th>
            <th><q-skeleton type="text" width="100px" /></th>
            <th><q-skeleton type="text" width="110px" /></th>
            <th><q-skeleton type="text" width="90px" /></th>
            <th class="text-right"><q-skeleton type="text" width="60px" class="q-ml-auto" /></th>
            <th class="text-right"><q-skeleton type="text" width="70px" class="q-ml-auto" /></th>
            <th class="text-center"><q-skeleton type="text" width="80px" class="q-mx-auto" /></th>
            <th class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 6" :key="n">
            <td><q-skeleton type="text" width="70px" /></td>
            <td><q-skeleton type="text" width="110px" /></td>
            <td><q-skeleton type="text" width="100px" /></td>
            <td><q-skeleton type="text" width="80px" /></td>
            <td class="text-right"><q-skeleton type="text" width="30px" class="q-ml-auto" /></td>
            <td class="text-right"><q-skeleton type="text" width="70px" class="q-ml-auto" /></td>
            <td class="text-center"><q-skeleton type="QBadge" width="80px" height="24px" class="q-mx-auto" /></td>
            <td class="text-right"><q-skeleton type="QBtn" width="32px" height="32px" class="q-ml-auto" /></td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// Skeleton loader component for Shop Orders page
</script>
