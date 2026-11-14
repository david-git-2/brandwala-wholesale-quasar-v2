<template>
  <TfEntityListRow @click="$emit('open')">
    <template #avatar>{{ initials }}</template>
    <template #title>
      <span class="tf-entity-list-item__name">{{ customer.group_name }}</span>
      <span v-if="customer.admin_name" class="tf-entity-list-item__subtitle">({{ customer.admin_name }})</span>
    </template>
    <template #meta>{{ metaLine }}</template>
  </TfEntityListRow>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import type { CustomerAccount } from '../types/customer';

const props = defineProps<{
  customer: CustomerAccount;
  initials: string;
}>();

defineEmits<{
  open: [];
}>();

const metaLine = computed(() => {
  const parts: string[] = [];
  if (props.customer.email) parts.push(props.customer.email);
  if (props.customer.phone) parts.push(props.customer.phone);
  if (props.customer.address) parts.push(props.customer.address);
  const members =
    props.customer.member_count === 1
      ? '1 member'
      : `${props.customer.member_count} members`;
  parts.push(members);
  return parts.join(' · ');
});
</script>