<template>
  <div class="q-gutter-y-md">
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="36px" />
        </div>
        <div class="col-auto">
          <q-skeleton type="QBtn" width="140px" height="36px" />
        </div>
      </div>
    </q-card>
    <q-card flat bordered class="q-pa-md">
      <q-markup-table flat borderless>
        <thead>
          <tr>
            <th v-for="n in 6" :key="`h-${n}`">
              <q-skeleton type="text" width="72px" />
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in 5" :key="row">
            <td v-for="col in 6" :key="`${row}-${col}`">
              <q-skeleton type="text" width="80%" />
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// CargoCompaniesSkeleton
</script>
