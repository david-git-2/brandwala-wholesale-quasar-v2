<template>
  <q-dialog :model-value="modelValue" position="right" @update:model-value="$emit('update:modelValue', $event)">
    <q-card class="group-details-panel column no-wrap">
      <q-card-section class="row items-center q-pb-sm">
        <div
          class="accent-swatch q-mr-sm"
          :style="{ backgroundColor: group?.accent_color || 'var(--bw-theme-primary)' }"
        />
        <div class="col">
          <div class="text-overline text-primary">{{ $t('shop_admin.access_group_details') }}</div>
          <div class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
            {{ group?.name }}
          </div>
        </div>
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          :aria-label="$t('shop_admin.cancel')"
          @click="$emit('update:modelValue', false)"
        />
      </q-card-section>

      <q-separator />

      <div class="col scroll q-pa-md">
        <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm">
          {{ $t('shop_admin.members') }}
        </div>

        <div v-if="loading" class="q-gutter-y-sm">
          <q-skeleton v-for="n in 3" :key="n" type="rect" height="56px" class="rounded-borders" />
        </div>

        <div v-else-if="sortedMembers.length === 0" class="column items-center text-center q-pa-lg text-grey-6">
          <q-icon name="ph ph-users" size="32px" color="grey-5" class="q-mb-sm" />
          <div>{{ $t('shop_admin.no_members') }}</div>
        </div>

        <q-list v-else bordered separator class="rounded-borders">
          <q-item v-for="member in sortedMembers" :key="member.id" class="q-py-sm">
            <q-item-section>
              <q-item-label class="text-weight-medium text-grey-9">
                {{ member.email }}
              </q-item-label>
              <q-item-label caption class="text-capitalize">{{ member.role }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <span
                class="status-chip"
                :class="member.is_active ? 'status-chip--active' : 'status-chip--inactive'"
              >
                {{ member.is_active ? $t('shop_admin.active') : $t('shop_admin.inactive') }}
              </span>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useCustomerGroupStore } from 'src/modules/tenant/stores/customerGroupStore';
import type { CustomerGroupMember } from 'src/modules/tenant/types';

const props = defineProps<{
  modelValue: boolean;
  group: { id: number; name: string; accent_color: string | null } | null;
}>();

defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const groupStore = useCustomerGroupStore();
const groupId = computed(() => props.group?.id ?? 0);
const members = ref<CustomerGroupMember[]>([]);
const loading = ref(false);

const sortedMembers = computed(() =>
  [...members.value].sort((a, b) => a.email.localeCompare(b.email)),
);

const loadMembers = async () => {
  if (!groupId.value) return;
  loading.value = true;
  try {
    const result = await groupStore.fetchCustomerGroupMembersByGroup(groupId.value);
    members.value = result.success ? (result.data ?? groupStore.members) : [];
  } finally {
    loading.value = false;
  }
};

watch(
  () => [props.modelValue, groupId.value] as const,
  ([open, id]) => {
    if (open && id) void loadMembers();
  },
);
</script>

<style scoped>
.group-details-panel {
  width: 420px;
  max-width: 100vw;
  height: 100vh;
  border-radius: 0;
}

.accent-swatch {
  width: 14px;
  height: 14px;
  border-radius: 4px;
  flex-shrink: 0;
}

.status-chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
}

.status-chip--active {
  background: #ecfdf3;
  color: #067647;
}

.status-chip--inactive {
  background: #f2f4f7;
  color: #475467;
}
</style>
