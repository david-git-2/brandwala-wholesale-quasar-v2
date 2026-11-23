<template>
  <section class="auth-card auth-card--skeleton" aria-busy="true" aria-label="Loading sign-in">
    <div class="auth-card__accent-bar" aria-hidden="true" />

    <div class="auth-card__header">
      <q-skeleton type="text" width="72%" height="1.75rem" class="auth-card__skel-title" />
      <q-skeleton type="text" width="48%" height="0.875rem" class="q-mt-xs" />
    </div>

    <div class="auth-card__divider" aria-hidden="true">
      <q-skeleton type="text" width="6.5rem" height="0.75rem" />
    </div>

    <q-skeleton type="rect" height="48px" class="auth-card__skel-cta" />

    <q-skeleton type="text" width="85%" height="0.85rem" class="auth-card__skel-note" />
  </section>
</template>

<style scoped>
.auth-card {
  --card-accent: var(--tf-theme-primary);
  --card-pad-x: clamp(1rem, 4vw, 1.75rem);
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  background: var(--tf-theme-surface);
  border-radius: 8px;
  border: 1px solid var(--tf-theme-border);
  box-shadow:
    0 2px 4px rgb(0 0 0 / 0.04),
    0 8px 24px rgb(0 0 0 / 0.06);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
  padding: 0 0 1.75rem;
}

.auth-card__accent-bar {
  height: 4px;
  background: var(--card-accent);
  opacity: 0.35;
}

.auth-card__header {
  padding: 1.5rem var(--card-pad-x) 0;
}

.auth-card__skel-title :deep(.q-skeleton) {
  border-radius: 6px;
}

.auth-card__divider {
  margin: 0 var(--card-pad-x);
  display: flex;
  align-items: center;
  justify-content: center;
}

.auth-card__divider::before,
.auth-card__divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: color-mix(in srgb, var(--tf-theme-muted) 22%, #ffffff);
}

.auth-card__skel-cta {
  margin: 0 var(--card-pad-x);
  border-radius: 8px;
}

.auth-card__skel-note {
  margin: 0 var(--card-pad-x);
}
</style>