<template>
  <div class="q-gutter-y-md">
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-12 col-sm-4">
          <q-skeleton type="QInput" height="36px" />
        </div>
        <div class="col-auto row q-gutter-x-sm">
          <q-skeleton type="QBtn" width="80px" height="36px" />
          <q-skeleton type="QBtn" width="60px" height="36px" />
          <q-skeleton type="QBtn" width="80px" height="36px" />
        </div>
      </div>
    </q-card>

    <q-card flat class="floating-surface shadow-1">
      <q-markup-table flat>
        <thead>
          <tr>
            <th style="width: 50px"><q-skeleton type="QCheckbox" /></th>
            <th style="width: 60px"><q-skeleton type="text" /></th>
            <th style="width: 80px"><q-skeleton type="text" /></th>
            <th v-for="n in 6" :key="n"><q-skeleton type="text" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="i in 10" :key="i">
            <td><q-skeleton type="QCheckbox" /></td>
            <td><q-skeleton type="text" /></td>
            <td>
              <q-skeleton
                type="rect"
                class="image-avatar-skeleton"
                style="width: 40px; height: 40px; border-radius: 4px"
              />
            </td>
            <td v-for="n in 6" :key="n"><q-skeleton type="text" /></td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// ThriftStockSkeleton component for loading state
</script>
