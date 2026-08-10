<template>
  <div class="q-gutter-y-md">
    <!-- Status tracks skeleton -->
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center q-gutter-xs">
        <q-skeleton type="text" width="70px" height="16px" class="q-mr-sm" />
        <q-skeleton v-for="n in 4" :key="`d-${n}`" type="QBtn" width="90px" height="28px" />
      </div>
    </q-card>
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center q-gutter-xs">
        <q-skeleton type="text" width="70px" height="16px" class="q-mr-sm" />
        <q-skeleton v-for="n in 2" :key="`p-${n}`" type="QBtn" width="110px" height="28px" />
      </div>
    </q-card>

    <div class="row q-col-gutter-md">
      <!-- Left / Main column -->
      <div class="col-12 col-lg-8 q-gutter-y-md">
        <!-- Header details card skeleton -->
        <q-card flat bordered class="q-pa-md">
          <q-skeleton type="text" width="140px" height="22px" class="q-mb-md" />
          <div class="row q-col-gutter-md">
            <div v-for="i in 6" :key="i" class="col-6 col-sm-4">
              <q-skeleton type="text" width="70px" height="14px" class="q-mb-xs" />
              <q-skeleton type="text" width="110px" height="20px" />
            </div>
          </div>
        </q-card>

        <!-- Line items table skeleton -->
        <q-card flat bordered>
          <q-card-section class="q-pb-none">
            <q-skeleton type="text" width="120px" height="22px" />
          </q-card-section>
          <q-markup-table flat bordered class="thrift-table">
            <thead>
              <tr>
                <th><q-skeleton type="text" width="80px" /></th>
                <th class="text-center"><q-skeleton type="text" width="40px" class="q-mx-auto" /></th>
                <th class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></th>
                <th class="text-right"><q-skeleton type="text" width="60px" class="q-ml-auto" /></th>
                <th class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></th>
                <th class="text-right"><q-skeleton type="text" width="70px" class="q-ml-auto" /></th>
                <th class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="n in 3" :key="n">
                <td>
                  <q-skeleton type="text" width="80%" class="q-mb-xs" />
                  <q-skeleton type="text" width="50%" height="12px" />
                </td>
                <td class="text-center"><q-skeleton type="text" width="20px" class="q-mx-auto" /></td>
                <td class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></td>
                <td class="text-right"><q-skeleton type="text" width="40px" class="q-ml-auto" /></td>
                <td class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></td>
                <td class="text-right"><q-skeleton type="text" width="60px" class="q-ml-auto" /></td>
                <td class="text-right"><q-skeleton type="text" width="50px" class="q-ml-auto" /></td>
              </tr>
            </tbody>
          </q-markup-table>
        </q-card>
      </div>

      <!-- Right / Summary sidebar skeleton -->
      <div class="col-12 col-lg-4">
        <q-card flat bordered class="q-pa-md">
          <q-skeleton type="text" width="100px" height="22px" class="q-mb-md" />
          <div class="row justify-between q-mb-sm">
            <q-skeleton type="text" width="60px" />
            <q-skeleton type="text" width="30px" />
          </div>
          <div class="row justify-between q-mb-sm">
            <q-skeleton type="text" width="80px" />
            <q-skeleton type="text" width="70px" />
          </div>
          <q-separator class="q-my-md" />
          <div class="row justify-between items-center">
            <q-skeleton type="text" width="100px" height="24px" />
            <q-skeleton type="text" width="90px" height="28px" />
          </div>
        </q-card>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Skeleton loader component for Thrift Sales Invoice Details page
</script>
