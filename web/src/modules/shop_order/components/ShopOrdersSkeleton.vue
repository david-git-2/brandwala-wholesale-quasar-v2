<template>
  <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
    <q-card flat class="floating-surface q-pa-xs flex-shrink-0">
      <div class="row items-center q-gutter-x-xs">
        <q-skeleton type="QInput" height="36px" style="min-width: 220px" />
        <q-skeleton type="QInput" width="180px" height="36px" />
        <q-skeleton type="QInput" width="160px" height="36px" />
        <q-skeleton type="QInput" width="160px" height="36px" />
      </div>
    </q-card>

    <q-card flat class="floating-surface col">
      <q-markup-table flat>
        <thead>
          <tr>
            <th><q-skeleton type="text" width="80px" /></th>
            <th><q-skeleton type="text" width="100px" /></th>
            <th><q-skeleton type="text" width="110px" /></th>
            <th><q-skeleton type="text" width="90px" /></th>
            <th class="text-right"><q-skeleton type="text" width="60px" class="q-ml-auto" /></th>
            <th class="text-center"><q-skeleton type="text" width="80px" class="q-mx-auto" /></th>
            <th class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 8" :key="n">
            <td><q-skeleton type="text" width="70px" /></td>
            <td><q-skeleton type="text" width="110px" /></td>
            <td><q-skeleton type="text" width="100px" /></td>
            <td><q-skeleton type="text" width="80px" /></td>
            <td class="text-right"><q-skeleton type="text" width="30px" class="q-ml-auto" /></td>
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

<style scoped>
.floating-surface {
  background: #ffffff;
  border-radius: 8px;
}
</style>
