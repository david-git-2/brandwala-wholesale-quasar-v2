<template>
  <div class="q-gutter-y-md">
    <q-card flat bordered class="q-pa-md rounded-card">
      <div class="row items-center justify-between q-col-gutter-md">
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="40px" />
        </div>
        <div class="col-auto row q-gutter-xs">
          <q-skeleton type="QChip" width="80px" height="32px" />
          <q-skeleton type="QChip" width="80px" height="32px" />
          <q-skeleton type="QChip" width="80px" height="32px" />
        </div>
      </div>
    </q-card>

    <q-card flat bordered class="rounded-card">
      <q-markup-table flat borderless>
        <thead>
          <tr>
            <th class="text-left" style="width: 25%;"><q-skeleton type="text" width="60%" /></th>
            <th class="text-left" style="width: 25%;"><q-skeleton type="text" width="50%" /></th>
            <th class="text-right" style="width: 20%;"><q-skeleton type="text" width="70%" /></th>
            <th class="text-right" style="width: 20%;"><q-skeleton type="text" width="70%" /></th>
            <th class="text-right" style="width: 10%;"><q-skeleton type="text" width="40%" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="i in 5" :key="i">
            <td>
              <div class="row items-center q-gutter-x-sm">
                <q-skeleton type="QAvatar" size="36px" />
                <div class="col">
                  <q-skeleton type="text" width="80%" />
                  <q-skeleton type="text" width="50%" height="12px" />
                </div>
              </div>
            </td>
            <td>
              <q-skeleton type="text" width="70%" />
              <q-skeleton type="text" width="40%" height="12px" />
            </td>
            <td class="text-right">
              <q-skeleton type="text" width="60%" class="q-ml-auto" />
            </td>
            <td class="text-right">
              <q-skeleton type="text" width="60%" class="q-ml-auto" />
            </td>
            <td class="text-right">
              <q-skeleton type="QBtn" width="100px" height="32px" class="q-ml-auto" />
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// Presentational skeleton loader matching DropshipMerchantsPage layout
</script>

<style scoped>
.rounded-card {
  border-radius: 8px;
}
</style>
