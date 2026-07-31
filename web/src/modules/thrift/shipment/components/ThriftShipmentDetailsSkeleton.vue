<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Header Skeleton -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-skeleton type="QBtn" width="32px" height="32px" />
            <div>
              <q-skeleton type="text" width="100px" height="14px" class="q-mb-xs" />
              <q-skeleton type="text" width="240px" height="32px" />
              <q-skeleton type="text" width="180px" height="14px" class="q-mt-xs" />
            </div>
          </div>
        </div>
        <div class="col-auto row q-gutter-sm items-center">
          <q-skeleton type="QBadge" width="100px" height="24px" />
          <q-skeleton type="QBadge" width="100px" height="24px" />
        </div>
      </section>

      <!-- Grid Layout Skeleton -->
      <div class="row q-col-gutter-md">
        <!-- Sidebar Skeleton -->
        <div class="col-12 col-md-3 q-gutter-y-md">
          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="60%" height="18px" class="q-mb-sm" />
            <q-separator class="q-my-sm" />
            <div v-for="n in 2" :key="n" class="row justify-between q-py-xs">
              <q-skeleton type="text" width="40%" height="14px" />
              <q-skeleton type="text" width="20%" height="14px" />
            </div>
          </q-card>

          <q-card flat bordered class="q-pa-md">
            <q-skeleton type="text" width="50%" height="18px" class="q-mb-md" />
            <div class="column q-gutter-y-sm">
              <q-skeleton v-for="n in 8" :key="n" type="QInput" height="36px" />
            </div>
          </q-card>
        </div>

        <!-- Main Table Area Skeleton -->
        <div class="col-12 col-md-9">
          <q-card flat bordered class="q-pa-sm">
            <div class="row items-center justify-between q-mb-md">
              <q-skeleton type="text" width="140px" height="24px" />
              <div class="row q-gutter-x-sm">
                <q-skeleton type="QInput" width="200px" height="36px" />
                <q-skeleton type="QBtn" width="90px" height="36px" />
              </div>
            </div>

            <!-- Table Skeleton -->
            <q-markup-table flat class="thrift-table">
              <thead>
                <tr>
                  <th v-for="n in 5" :key="n"><q-skeleton type="text" width="70px" /></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="n in 5" :key="n">
                  <td v-for="i in 5" :key="i"><q-skeleton type="text" width="80%" /></td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>
