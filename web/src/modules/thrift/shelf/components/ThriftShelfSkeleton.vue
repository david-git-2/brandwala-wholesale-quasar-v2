<template>
  <div class="q-gutter-y-md">
    <q-card flat class="floating-surface shadow-1">
      <q-markup-table flat>
        <thead>
          <tr>
            <th style="width: 50px"><q-skeleton type="text" width="24px" /></th>
            <th style="width: 70px"><q-skeleton type="text" width="30px" /></th>
            <th><q-skeleton type="text" width="100px" /></th>
            <th><q-skeleton type="text" width="120px" /></th>
            <th><q-skeleton type="text" width="140px" /></th>
            <th class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 6" :key="n">
            <td><q-skeleton type="text" width="20px" /></td>
            <td><q-skeleton type="text" width="30px" /></td>
            <td><q-skeleton type="text" width="50%" /></td>
            <td><q-skeleton type="text" width="60%" /></td>
            <td><q-skeleton type="text" width="40%" /></td>
            <td class="text-right"><q-skeleton type="QBtn" width="48px" height="24px" class="q-ml-auto" /></td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// ThriftShelfSkeleton component for loading state
</script>
