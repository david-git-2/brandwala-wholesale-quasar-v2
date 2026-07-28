<template>
  <div class="row q-col-gutter-md">
    <!-- Sidebar Controls Skeleton -->
    <div class="col-12 col-md-4 no-print">
      <q-card flat bordered class="q-pa-md">
        <q-skeleton type="text" width="160px" height="24px" class="q-mb-md" />

        <div v-for="n in 5" :key="n" class="q-mb-md">
          <q-skeleton type="QInput" height="40px" />
        </div>

        <q-skeleton type="text" width="140px" height="20px" class="q-mb-md" />
        <q-skeleton type="QInput" height="40px" class="q-mb-lg" />

        <q-skeleton type="QBtn" width="100%" height="40px" />
      </q-card>
    </div>

    <!-- Preview Sheet Skeleton -->
    <div class="col-12 col-md-8">
      <q-card flat bordered class="q-pa-lg" style="min-height: 800px">
        <div class="row justify-between items-center q-mb-lg">
          <div>
            <q-skeleton type="text" width="180px" height="28px" class="q-mb-xs" />
            <q-skeleton type="text" width="120px" height="16px" />
          </div>
          <div>
            <q-skeleton type="text" width="140px" height="24px" />
          </div>
        </div>

        <q-separator class="q-my-md" />

        <div class="row q-col-gutter-md q-mb-lg">
          <div class="col-6">
            <q-skeleton type="text" width="100px" height="18px" class="q-mb-xs" />
            <q-skeleton type="text" width="80%" height="14px" />
            <q-skeleton type="text" width="60%" height="14px" />
          </div>
          <div class="col-6">
            <q-skeleton type="text" width="100px" height="18px" class="q-mb-xs" />
            <q-skeleton type="text" width="80%" height="14px" />
            <q-skeleton type="text" width="60%" height="14px" />
          </div>
        </div>

        <q-markup-table flat bordered class="q-mb-lg">
          <thead>
            <tr>
              <th><q-skeleton type="text" width="60%" /></th>
              <th><q-skeleton type="text" width="40%" /></th>
              <th><q-skeleton type="text" width="40%" /></th>
              <th class="text-right"><q-skeleton type="text" width="50%" class="q-ml-auto" /></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="n in 3" :key="n">
              <td><q-skeleton type="text" width="70%" /></td>
              <td><q-skeleton type="text" width="30%" /></td>
              <td><q-skeleton type="text" width="40%" /></td>
              <td class="text-right"><q-skeleton type="text" width="50%" class="q-ml-auto" /></td>
            </tr>
          </tbody>
        </q-markup-table>

        <div class="row justify-end">
          <div class="col-12 col-sm-5 q-gutter-y-xs">
            <div class="row justify-between">
              <q-skeleton type="text" width="40%" />
              <q-skeleton type="text" width="30%" />
            </div>
            <div class="row justify-between">
              <q-skeleton type="text" width="40%" />
              <q-skeleton type="text" width="30%" />
            </div>
            <q-separator class="q-my-xs" />
            <div class="row justify-between">
              <q-skeleton type="text" width="50%" height="20px" />
              <q-skeleton type="text" width="35%" height="20px" />
            </div>
          </div>
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
// Dedicated skeleton loader for DropshipOrderRecipientInvoicePreviewPage
</script>
