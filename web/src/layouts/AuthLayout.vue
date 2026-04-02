<template>
  <q-layout view="hHh lpR fFf" class="auth-layout">
    <q-page-container>
      <q-page class="auth-page">
        <section class="auth-stage">
          <div class="auth-stage__shell">
            <div class="auth-stage__brand">BrandWala Wholesale</div>
            <router-view />
          </div>
        </section>
      </q-page>
    </q-page-container>
  </q-layout>
</template>

<style scoped>
.auth-layout {
  --auth-stage-base: #f6f0e8;
  --auth-stage-surface: rgb(255 251 246 / 0.84);
  --auth-stage-border: rgb(84 61 35 / 0.1);
  --auth-stage-accent: var(--bw-brand-accent, #8d5f2f);
  min-height: 100vh;
  background:
    radial-gradient(circle at top center, rgb(255 255 255 / 0.84), transparent 28%),
    radial-gradient(circle at bottom left, rgb(141 95 47 / 0.08), transparent 24%),
    linear-gradient(180deg, rgb(255 255 255) 0%, var(--auth-stage-base) 100%);
}

.auth-page {
  min-height: 100vh;
  padding: clamp(1rem, 2vw, 1.5rem);
}

.auth-stage {
  min-height: calc(100vh - 3rem);
  display: grid;
  place-items: center;
}

.auth-stage__shell {
  width: min(100%, 29rem);
  padding: clamp(1rem, 3vw, 1.35rem);
  border: 1px solid var(--auth-stage-border);
  border-radius: 2rem;
  background: var(--auth-stage-surface);
  backdrop-filter: blur(16px);
  box-shadow: 0 24px 60px rgb(31 23 15 / 0.08);
}

.auth-stage__brand {
  margin-bottom: 0.9rem;
  text-align: center;
  font-size: 0.76rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--auth-stage-accent);
}

@media (max-width: 1023px) {
  .auth-stage__shell {
    width: min(100%, 28rem);
  }
}

@media (max-width: 599px) {
  .auth-page {
    padding: 0.9rem;
  }

  .auth-stage {
    min-height: calc(100vh - 1.8rem);
  }

  .auth-stage__shell {
    border-radius: 1.5rem;
    padding: 0.85rem;
  }
}
</style>
