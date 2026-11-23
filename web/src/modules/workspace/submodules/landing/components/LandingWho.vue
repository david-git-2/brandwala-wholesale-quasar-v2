<template>
  <section class="landing-wrap landing-section">
    <h2 class="landing-h2">{{ landingCopy.who.h2 }}</h2>
    <ul class="who">
      <li v-for="item in landingCopy.who.items" :key="item.title">
        <h3 class="landing-h3">{{ item.title }}</h3>
        <p class="landing-body">{{ item.body }}</p>
      </li>
    </ul>
  </section>
</template>

<script setup lang="ts">
import { landingCopy } from '../content';
</script>

<style scoped>
.who {
  display: grid;
  gap: 1.25rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.who .landing-h3,
.who .landing-body {
  margin-bottom: 0.25rem;
}

@media (min-width: 768px) {
  .who {
    grid-template-columns: repeat(3, 1fr);
  }
}
</style>
