<template>
  <section class="shop-home-hero-wrap" aria-label="Dashboard overview">
    <q-card flat class="shop-home-card shop-home-hero q-pa-lg">
      <div class="shop-home-hero__row">
        <div class="shop-home-hero__copy">
          <div v-if="scopeLabel" class="shop-home-hero__eyebrow">
            <span class="shop-home-hero__dot" aria-hidden="true" />
            <span>{{ scopeLabel }}</span>
          </div>
          <h1 class="shop-home-hero__title q-my-none">
            {{ greetingText }}
          </h1>
          <p class="shop-home-hero__sub q-mb-none">
            {{ subtitle }}
          </p>
        </div>

        <div class="shop-home-hero__actions">
          <button
            v-if="hasActiveCarts"
            type="button"
            class="shop-home-hero__btn shop-home-hero__btn--primary"
            data-test="quick-action-resume-cart"
            @click="$emit('resume-latest-cart')"
          >
            <q-icon name="ph ph-shopping-cart-simple" size="16px" />
            <span>{{ resumeLabel }}</span>
          </button>

          <button
            type="button"
            class="shop-home-hero__btn"
            :class="hasActiveCarts ? 'shop-home-hero__btn--ghost' : 'shop-home-hero__btn--primary'"
            data-test="shop-portal-quick-action"
            @click="$emit('start')"
          >
            <span>{{ primaryCtaLabel }}</span>
            <q-icon name="ph ph-arrow-right" size="16px" />
          </button>
        </div>
      </div>

      <div
        v-if="needsAttentionCount > 0"
        class="shop-home-attention q-mt-md"
        role="status"
        data-test="dashboard-attention-banner"
      >
        <div class="shop-home-attention__left">
          <q-icon name="ph ph-warning-circle" size="18px" class="shop-home-attention__icon" />
          <span class="shop-home-attention__text">{{ attentionText }}</span>
        </div>
        <button
          type="button"
          class="shop-home-attention__cta"
          data-test="dashboard-attention-cta"
          @click="$emit('review-attention')"
        >
          <span>{{ $t('customer_dashboard.attention_review') }}</span>
          <q-icon name="ph ph-arrow-right" size="14px" />
        </button>
      </div>
    </q-card>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = withDefaults(
  defineProps<{
    userName?: string | null;
    scopeLabel?: string | null;
    shopCount?: number;
    hasActiveCarts?: boolean;
    latestCartShopName?: string | null;
    needsYouCount?: number;
    paymentNeededCount?: number;
  }>(),
  {
    userName: null,
    scopeLabel: null,
    shopCount: 0,
    hasActiveCarts: false,
    latestCartShopName: null,
    needsYouCount: 0,
    paymentNeededCount: 0,
  },
);

defineEmits<{
  (e: 'start'): void;
  (e: 'resume-latest-cart'): void;
  (e: 'review-attention'): void;
}>();

const { t } = useI18n();

const firstName = computed(() => {
  const raw = props.userName?.trim();
  if (!raw) return '';
  return raw.split(/\s+/)[0] ?? raw;
});

const greetingText = computed(() => {
  const hour = new Date().getHours();
  const key =
    hour < 12
      ? 'customer_dashboard.greeting_morning'
      : hour < 17
        ? 'customer_dashboard.greeting_afternoon'
        : 'customer_dashboard.greeting_evening';
  const name = firstName.value || 'there';
  return t(key, { name });
});

const subtitle = computed(() =>
  props.shopCount > 1
    ? t('customer_dashboard.portal_choose_shop_sub')
    : t('customer_dashboard.portal_start_order_sub'),
);

const primaryCtaLabel = computed(() =>
  props.shopCount > 1
    ? t('customer_dashboard.shops_title')
    : t('customer_dashboard.browse_catalog'),
);

const resumeLabel = computed(() =>
  props.latestCartShopName
    ? `${t('customer_dashboard.resume_latest_cart')} · ${props.latestCartShopName}`
    : t('customer_dashboard.resume_latest_cart'),
);

const needsAttentionCount = computed(
  () => (props.needsYouCount ?? 0) + (props.paymentNeededCount ?? 0),
);

const attentionText = computed(() => {
  if ((props.needsYouCount ?? 0) > 0) {
    return t('customer_dashboard.attention_needs_you', props.needsYouCount);
  }
  return t('customer_dashboard.attention_payment_needed', props.paymentNeededCount);
});
</script>
