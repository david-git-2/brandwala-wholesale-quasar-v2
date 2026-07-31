<template>
  <div class="q-gutter-y-md">
    <!-- Header Skeleton -->
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <q-skeleton type="text" width="100px" height="14px" class="q-mb-xs" />
        <q-skeleton type="text" width="240px" height="32px" class="q-mb-xs" />
        <q-skeleton type="text" width="380px" height="18px" />
      </div>
    </section>

    <!-- Table Skeleton Card -->
    <q-card flat bordered>
      <q-markup-table flat>
        <thead>
          <tr>
            <th><q-skeleton type="text" width="140px" /></th>
            <th class="text-right"><q-skeleton type="text" width="90px" class="q-ml-auto" /></th>
            <th class="text-right"><q-skeleton type="text" width="90px" class="q-ml-auto" /></th>
            <th class="text-right"><q-skeleton type="text" width="100px" class="q-ml-auto" /></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="n in 5" :key="n">
            <td><q-skeleton type="text" width="60%" /></td>
            <td class="text-right"><q-skeleton type="text" width="40px" class="q-ml-auto" /></td>
            <td class="text-right"><q-skeleton type="text" width="40px" class="q-ml-auto" /></td>
            <td class="text-right">
              <div class="row justify-end items-center q-gutter-x-xs">
                <q-skeleton type="QBtn" width="32px" height="32px" />
                <q-skeleton type="QBtn" width="100px" height="32px" />
              </div>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card>
  </div>
</template>

<script setup lang="ts">
// ThriftStockTagPrintSkeleton component for page loading state
</script>
