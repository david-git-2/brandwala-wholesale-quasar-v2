<template>
  <div class="q-gutter-y-md">
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="36px" />
        </div>
      </div>
    </q-card>

    <q-markup-table flat bordered class="thrift-table">
      <thead>
        <tr>
          <th style="width: 50px"><q-skeleton type="text" width="20px" class="q-mx-auto" /></th>
          <th><q-skeleton type="text" width="80px" /></th>
          <th><q-skeleton type="text" width="120px" /></th>
          <th><q-skeleton type="text" width="60px" /></th>
          <th style="width: 60px"><q-skeleton type="text" width="40px" class="q-mx-auto" /></th>
          <th><q-skeleton type="text" width="70px" /></th>
          <th><q-skeleton type="text" width="70px" /></th>
          <th><q-skeleton type="text" width="60px" /></th>
          <th class="text-right"><q-skeleton type="text" width="60px" class="q-ml-auto" /></th>
          <th><q-skeleton type="text" width="80px" /></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="n in 6" :key="n">
          <td><q-skeleton type="text" width="20px" class="q-mx-auto" /></td>
          <td><q-skeleton type="text" width="85%" /></td>
          <td>
            <q-skeleton type="text" width="60%" class="q-mb-xs" />
            <q-skeleton type="text" width="40%" height="12px" />
          </td>
          <td><q-skeleton type="text" width="70%" /></td>
          <td class="text-center"><q-skeleton type="text" width="30px" class="q-mx-auto" /></td>
          <td><q-skeleton type="QBadge" width="60px" height="20px" /></td>
          <td><q-skeleton type="QBadge" width="60px" height="20px" /></td>
          <td><q-skeleton type="QBadge" width="50px" height="20px" /></td>
          <td class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></td>
          <td><q-skeleton type="text" width="60%" /></td>
        </tr>
      </tbody>
    </q-markup-table>
  </div>
</template>

<script setup lang="ts">
// Skeleton loader component for Thrift Sales page
</script>
