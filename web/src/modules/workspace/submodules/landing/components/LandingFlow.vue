<template>
  <section id="flow" class="landing-wrap landing-section">
    <h2 class="landing-h2">{{ landingCopy.flow.h2 }}</h2>
    <ol class="flow">
      <li v-for="(step, i) in landingCopy.flow.steps" :key="step.id" class="flow__step">
        <div class="flow__index">{{ i + 1 }}</div>
        <h3 class="landing-h3">{{ step.title }}</h3>
        <p class="landing-body">{{ step.body }}</p>
      </li>
    </ol>
    <p class="landing-body">
      <router-link :to="HELP_PATH">{{ landingCopy.flow.helpHint }}</router-link>
    </p>
  </section>
</template>

<script setup lang="ts">
import { HELP_PATH, landingCopy } from '../content';
</script>

<style scoped>
.flow {
  display: grid;
  gap: 1.5rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.flow__step {
  position: relative;
  padding-left: 2.5rem;
}

.flow__step:not(:last-child)::before {
  content: '';
  position: absolute;
  left: 0.7rem;
  top: 1.75rem;
  bottom: -1.5rem;
  width: 1px;
  background: var(--tf-neutral-border-strong);
}

.flow__index {
  position: absolute;
  left: 0;
  top: 0.1rem;
  width: 1.5rem;
  height: 1.5rem;
  display: grid;
  place-items: center;
  border: 1px solid var(--tf-neutral-border-strong);
  border-radius: var(--tf-radius-sm);
  background: var(--tf-neutral-surface);
  font-size: var(--tf-text-meta);
  font-family: var(--tf-font-mono);
  color: var(--tf-theme-accent);
}

.flow__step .landing-h3,
.flow__step .landing-body {
  margin-bottom: 0.25rem;
}

@media (min-width: 768px) {
  .flow {
    grid-template-columns: repeat(5, 1fr);
    gap: 1rem;
  }

  .flow__step {
    padding-left: 0;
    padding-top: 2.25rem;
  }

  .flow__index {
    top: 0;
  }

  .flow__step:not(:last-child)::before {
    left: 1.75rem;
    right: -1rem;
    top: 0.7rem;
    bottom: auto;
    width: auto;
    height: 1px;
  }
}
</style>
