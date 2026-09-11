<template>
  <div class="shop-company-switch">
    <q-btn-dropdown
      v-if="groups.length > 1"
      flat
      no-caps
      unelevated
      class="shop-company-switch__trigger"
      dropdown-icon="ph ph-caret-down"
      :label="currentName"
      content-class="shop-company-switch__menu"
      data-test="shop-company-switcher"
      :aria-label="$t('shop.switch_company')"
    >
      <q-list>
        <q-item
          v-for="group in groups"
          :key="group.member_id"
          v-close-popup
          clickable
          :active="group.customer_group_id === currentId"
          :data-test="`shop-company-switch-${group.customer_group_id}`"
          @click="$emit('switch-company', group)"
        >
          <q-item-section avatar>
            <q-icon name="ph ph-buildings" size="18px" color="grey-7" />
          </q-item-section>
          <q-item-section>
            <q-item-label>{{ group.customer_group_name }}</q-item-label>
            <q-item-label caption>{{ roleLabel(group.matched_role) }}</q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
    </q-btn-dropdown>

    <div v-else-if="currentName" class="shop-company-switch__static ellipsis">
      {{ currentName }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import type { ShopLoginGroupRow } from 'src/modules/auth/utils/shopCustomerGroupSession';

defineProps<{
  currentName: string;
  currentId: number | null;
  groups: ShopLoginGroupRow[];
}>();

defineEmits<{
  (e: 'switch-company', group: ShopLoginGroupRow): void;
}>();

const { t } = useI18n();

const roleLabel = (role: string) => {
  if (role === 'admin') return t('shop.company_role_admin');
  if (role === 'manager') return t('shop.company_role_manager');
  if (role === 'staff') return t('shop.company_role_staff');
  return role;
};
</script>

<style scoped>
.shop-company-switch {
  min-width: 0;
  max-width: 100%;
}

.shop-company-switch__static,
.shop-company-switch__trigger {
  font-size: 0.78rem;
  line-height: 1.2;
  max-width: 100%;
  color: var(--bw-theme-muted, #5e4955);
}

.shop-company-switch__trigger {
  border-radius: 8px;
  padding: 0.05rem 0.2rem;
}

.shop-company-switch__trigger :deep(.q-btn__content) {
  max-width: 100%;
}
</style>
