<template>
  <q-card flat bordered class="dashboard-pulse-skeleton">
    <q-card-section class="dashboard-pulse-skeleton__head">
      <q-skeleton type="text" width="40%" />
    </q-card-section>
    <q-card-section class="dashboard-pulse-skeleton__body">
      <div class="dashboard-pulse-skeleton__metrics">
        <q-skeleton v-for="i in 4" :key="i" type="rect" height="52px" />
      </div>
      <q-skeleton type="rect" class="dashboard-pulse-skeleton__chart" />
    </q-card-section>
    <q-card-section>
      <q-skeleton v-for="i in 3" :key="`bar-${i}`" type="rect" height="28px" class="q-mb-xs" />
    </q-card-section>
  </q-card>
</template>

<style scoped>
.dashboard-pulse-skeleton {
  border-radius: 14px;
  min-height: 18rem;
}

.dashboard-pulse-skeleton__head {
  padding-bottom: 0.35rem;
}

.dashboard-pulse-skeleton__body {
  display: grid;
  grid-template-columns: minmax(0, 1.3fr) minmax(10.5rem, 0.7fr);
  gap: 1rem;
  align-items: start;
}

.dashboard-pulse-skeleton__metrics {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

.dashboard-pulse-skeleton__chart {
  width: 10.5rem;
  height: 10.5rem;
  margin: 0 auto;
  border-radius: 12px;
}

@media (max-width: 720px) {
  .dashboard-pulse-skeleton__body {
    grid-template-columns: 1fr;
  }

  .dashboard-pulse-skeleton__chart {
    order: -1;
  }
}
</style>
