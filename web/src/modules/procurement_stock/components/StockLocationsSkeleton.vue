<template>
  <div class="q-gutter-y-md">
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="36px" />
        </div>
        <div class="col-auto row q-gutter-x-sm">
          <q-skeleton type="QBtn" width="120px" height="36px" />
          <q-skeleton type="QBtn" width="100px" height="36px" />
        </div>
      </div>
    </q-card>

    <q-card flat bordered class="q-pa-md">
      <q-markup-table flat borderless>
        <thead>
          <tr>
            <th v-for="n in 8" :key="`h-${n}`">
              <q-skeleton type="text" :width="n === 8 ? '48px' : '72px'" />
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in 6" :key="row">
            <td v-for="col in 8" :key="`${row}-${col}`">
              <q-skeleton type="text" :width="col === 8 ? '64px' : '80%'" />
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// StockLocationsSkeleton — first-paint loader for Locations list
</script>
