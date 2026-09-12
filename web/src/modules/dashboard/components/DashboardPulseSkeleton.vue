<template>
  <section class="dashboard-story-skeleton">
    <q-skeleton type="text" width="35%" height="12px" />
    <div class="dashboard-story-skeleton__body">
      <div class="dashboard-story-skeleton__copy">
        <q-skeleton type="text" width="55%" height="2.5rem" />
        <q-skeleton type="text" width="40%" height="13px" />
        <q-skeleton v-for="i in 3" :key="i" type="text" width="70%" height="15px" />
      </div>
      <q-skeleton type="circle" class="dashboard-story-skeleton__chart" />
    </div>
  </section>
</template>

<style scoped>
.dashboard-story-skeleton {
  display: grid;
  gap: 0.85rem;
  min-width: 0;
}

.dashboard-story-skeleton__body {
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) minmax(9rem, 0.8fr);
  gap: 1.5rem 2rem;
  align-items: start;
}

.dashboard-story-skeleton__copy {
  display: grid;
  gap: 0.55rem;
}

.dashboard-story-skeleton__chart {
  width: 12rem;
  height: 12rem;
  margin: 0 auto;
}

@media (max-width: 720px) {
  .dashboard-story-skeleton__body {
    grid-template-columns: 1fr;
  }

  .dashboard-story-skeleton__chart {
    order: -1;
  }
}
</style>
