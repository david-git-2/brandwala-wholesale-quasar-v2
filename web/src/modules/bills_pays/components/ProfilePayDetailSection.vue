<template>
  <section>
    <ProfilePayDetailSectionTitle :title="title" :caption="caption" />
    <dl
      class="profile-pay-detail-section__grid profile-pay-detail-dialog__card q-pa-sm"
      :class="{ 'profile-pay-detail-section__grid--muted': muted }"
    >
      <template v-for="item in rows" :key="item.label">
        <dt>{{ item.label }}</dt>
        <dd :class="{ 'profile-pay-detail-section__mono': mono }">{{ item.value }}</dd>
      </template>
    </dl>
  </section>
</template>

<script setup lang="ts">
import ProfilePayDetailSectionTitle from './ProfilePayDetailSectionTitle.vue';

defineProps<{
  title: string;
  caption?: string;
  rows: Array<{ label: string; value: string }>;
  muted?: boolean;
  mono?: boolean;
}>();
</script>

<style scoped lang="scss">
.profile-pay-detail-section__grid {
  display: grid;
  grid-template-columns: minmax(8.5rem, 38%) 1fr;
  gap: 8px 14px;
  margin: 0;
  font-size: 13px;
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
}

.profile-pay-detail-section__grid--muted {
  font-size: 12px;
  opacity: 0.92;
}

.profile-pay-detail-section__grid dt {
  margin: 0;
  color: var(--tf-text-muted, #6b6560);
  font-weight: 500;
}

.profile-pay-detail-section__grid dd {
  margin: 0;
  word-break: break-word;
  color: var(--tf-neutral-ink, #1a1816);
}

.profile-pay-detail-section__mono {
  font-family: ui-monospace, monospace;
  font-size: 12px;
}
</style>