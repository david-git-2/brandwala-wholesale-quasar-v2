<template>
  <q-layout view="hHh lpR fFf" class="auth-layout">
    <q-page-container>
      <q-page class="auth-page">
        <section class="auth-stage">
          <div class="auth-stage__story">
            <div class="auth-stage__eyebrow">BrandWala Wholesale</div>
            <h1 class="auth-stage__headline">
              One system for platform control, tenant operations, and customer ordering.
            </h1>
            <p class="auth-stage__copy">
              Use the correct login entry for your workspace. Each route shares the same Google
              authentication flow, but access is verified by scope.
            </p>

            <div class="auth-stage__pillars">
              <div class="auth-stage__pillar">
                <div class="auth-stage__pillar-title">Platform</div>
                <div class="auth-stage__pillar-copy">
                  Superadmin controls tenants, modules, and rollout governance.
                </div>
              </div>

              <div class="auth-stage__pillar">
                <div class="auth-stage__pillar-title">App</div>
                <div class="auth-stage__pillar-copy">
                  Internal teams manage memberships, customer groups, and operations.
                </div>
              </div>

              <div class="auth-stage__pillar">
                <div class="auth-stage__pillar-title">Shop</div>
                <div class="auth-stage__pillar-copy">
                  Customer-side teams prepare carts, confirm orders, and negotiate.
                </div>
              </div>
            </div>
          </div>

          <div class="auth-stage__panel">
            <router-view />
          </div>
        </section>
      </q-page>
    </q-page-container>
  </q-layout>
</template>

<style scoped>
.auth-layout {
  min-height: 100vh;
  background:
    radial-gradient(circle at top left, rgba(194, 146, 92, 0.18), transparent 30%),
    radial-gradient(circle at bottom right, rgba(78, 115, 82, 0.12), transparent 32%),
    linear-gradient(180deg, #f8f4ee 0%, #efe6db 100%);
}

.auth-page {
  padding: clamp(1rem, 2vw, 1.5rem);
}

.auth-stage {
  min-height: calc(100vh - 2rem);
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(320px, 34rem);
  gap: clamp(1.25rem, 3vw, 2.25rem);
}

.auth-stage__story,
.auth-stage__panel {
  border: 1px solid rgba(91, 72, 49, 0.1);
  border-radius: 2rem;
  background: rgba(255, 251, 246, 0.74);
  backdrop-filter: blur(14px);
}

.auth-stage__story {
  padding: clamp(1.5rem, 4vw, 3rem);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  background:
    radial-gradient(circle at top left, rgba(194, 146, 92, 0.16), transparent 38%),
    linear-gradient(180deg, rgba(255, 252, 248, 0.9), rgba(244, 236, 226, 0.82));
}

.auth-stage__eyebrow {
  font-size: 0.8rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: #7c644b;
}

.auth-stage__headline {
  margin: 1rem 0 0;
  max-width: 12ch;
  font-size: clamp(2.4rem, 6vw, 5.4rem);
  line-height: 0.95;
  font-weight: 700;
  color: #261b12;
}

.auth-stage__copy {
  max-width: 44ch;
  margin: 1.3rem 0 0;
  font-size: 1rem;
  line-height: 1.8;
  color: #5f4e3e;
}

.auth-stage__pillars {
  display: grid;
  gap: 0.85rem;
  margin-top: 2rem;
}

.auth-stage__pillar {
  padding: 1rem 1.1rem;
  border-radius: 1.15rem;
  background: rgba(255, 255, 255, 0.5);
  border: 1px solid rgba(91, 72, 49, 0.08);
}

.auth-stage__pillar-title {
  font-size: 0.78rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: #7c644b;
}

.auth-stage__pillar-copy {
  margin-top: 0.4rem;
  color: #2f2419;
  line-height: 1.6;
}

.auth-stage__panel {
  padding: clamp(1rem, 3vw, 1.4rem);
  display: flex;
  align-items: center;
}

@media (max-width: 1023px) {
  .auth-stage {
    grid-template-columns: 1fr;
  }

  .auth-stage__story {
    min-height: auto;
  }
}

@media (max-width: 599px) {
  .auth-page {
    padding: 0.75rem;
  }

  .auth-stage {
    min-height: calc(100vh - 1.5rem);
  }

  .auth-stage__story,
  .auth-stage__panel {
    border-radius: 1.5rem;
  }
}
</style>
