<template>
  <div class="clean-list-item" @click="$emit('open')">
    <div class="item-main-info row items-center no-wrap">
      <q-avatar size="32px" class="item-avatar flex-shrink-0 q-mr-sm">
        {{ initials }}
      </q-avatar>
      <div class="item-info">
        <div class="item-title-line">
          <span class="item-name">{{ customer.group_name }}</span>
          <span v-if="customer.admin_name" class="meta-subtext">({{ customer.admin_name }})</span>
        </div>
        <div class="item-meta-line">
          <span v-if="customer.email" class="meta-item">{{ customer.email }}</span>
          <span v-if="customer.email && customer.phone" class="meta-dot">·</span>
          <span v-if="customer.phone" class="meta-item">{{ customer.phone }}</span>
          <span v-if="(customer.email || customer.phone) && customer.address" class="meta-dot">·</span>
          <span v-if="customer.address" class="meta-item meta-address">{{ customer.address }}</span>
          <span class="meta-dot">·</span>
          <span class="meta-item">
            {{ customer.member_count }}
            {{ customer.member_count === 1 ? 'member' : 'members' }}
          </span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import type { CustomerAccount } from '../types/customer';

defineProps<{
  customer: CustomerAccount;
  initials: string;
}>();

defineEmits<{
  open: [];
}>();
</script>

<style scoped lang="scss">
@import '../styles/customer-clean-list.scss';
</style>
