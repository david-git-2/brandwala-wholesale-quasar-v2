<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header Skeleton -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <q-skeleton type="text" width="100px" height="14px" class="q-mb-xs" />
          <q-skeleton type="text" width="220px" height="32px" />
        </div>
        <div class="col-auto">
          <q-skeleton type="QBtn" width="130px" height="36px" />
        </div>
      </section>

      <!-- Table Skeleton Card -->
      <q-card flat bordered class="q-pa-md">
        <q-markup-table flat class="thrift-table">
          <thead>
            <tr>
              <th style="width: 50px"><q-skeleton type="text" width="30px" /></th>
              <th><q-skeleton type="text" width="140px" /></th>
              <th class="text-right" style="width: 120px"><q-skeleton type="text" width="80px" class="q-ml-auto" /></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="n in 5" :key="n">
              <td><q-skeleton type="text" width="20px" /></td>
              <td><q-skeleton type="text" width="60%" /></td>
              <td class="text-right">
                <div class="row justify-end q-gutter-x-xs">
                  <q-skeleton type="QBtn" width="28px" height="28px" />
                  <q-skeleton type="QBtn" width="28px" height="28px" />
                  <q-skeleton type="QBtn" width="28px" height="28px" />
                </div>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </q-card>
    </div>
  </q-page>
</template>
