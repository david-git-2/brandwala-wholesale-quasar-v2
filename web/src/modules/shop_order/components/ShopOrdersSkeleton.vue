<template>
  <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
    <q-card flat bordered class="q-pa-xs flex-shrink-0">
      <div class="row items-center q-gutter-x-xs">
        <q-skeleton type="QInput" height="36px" style="min-width: 220px" class="col-grow col-sm-auto" />
        <q-skeleton type="QInput" width="190px" height="36px" class="col-grow col-sm-auto" />
        <q-skeleton type="QInput" width="160px" height="36px" class="col-grow col-sm-auto" />
        <q-skeleton type="QInput" width="160px" height="36px" class="col-grow col-sm-auto" />
      </div>
    </q-card>

    <q-card flat bordered class="col overflow-hidden">
      <q-markup-table flat>
        <thead>
          <tr>
            <th><q-skeleton type="text" width="90px" /></th>
            <th><q-skeleton type="text" width="100px" /></th>
            <th><q-skeleton type="text" width="120px" /></th>
            <th><q-skeleton type="text" width="110px" /></th>
            <th><q-skeleton type="text" width="90px" /></th>
            <th class="text-right"><q-skeleton type="text" width="40px" class="q-ml-auto" /></th>
            <th class="text-center"><q-skeleton type="text" width="70px" class="q-mx-auto" /></th>
            <th class="text-center"><q-skeleton type="text" width="90px" class="q-mx-auto" /></th>
            <th class="text-right"><q-skeleton type="text" width="30px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 8" :key="n">
            <td><q-skeleton type="text" width="110px" /></td>
            <td><q-skeleton type="text" width="90px" /></td>
            <td><q-skeleton type="text" width="120px" /></td>
            <td><q-skeleton type="text" width="100px" /></td>
            <td><q-skeleton type="text" width="80px" /></td>
            <td class="text-right"><q-skeleton type="text" width="30px" class="q-ml-auto" /></td>
            <td class="text-center"><q-skeleton type="text" width="60px" class="q-mx-auto" /></td>
            <td class="text-center"><q-skeleton type="QBadge" width="85px" height="22px" class="q-mx-auto" /></td>
            <td class="text-right"><q-skeleton type="QBtn" width="28px" height="28px" class="q-ml-auto" /></td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// Skeleton loader component for Shop Orders page
</script>
