<template>
  <q-drawer
    :model-value="modelValue"
    side="right"
    overlay
    bordered
    :width="440"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div v-if="group" class="column full-height no-wrap">
      <div class="row items-center justify-between q-pa-md border-bottom">
        <div class="ellipsis">
          <div class="text-subtitle1 text-weight-bold ellipsis">{{ group.name }}</div>
          <div class="text-caption text-grey-7">{{ group.type }} · {{ group.member_count }} members</div>
        </div>
        <q-btn flat round dense icon="ph ph-x" :ripple="false" @click="$emit('update:modelValue', false)" />
      </div>

      <div class="row items-center justify-between q-px-md q-py-sm">
        <span class="text-body2 text-weight-medium">Members</span>
        <TfBtn variant="primary" size="sm" label="Add" icon="ph ph-plus" @click="$emit('add-member')" />
      </div>

      <div class="col scroll q-px-md q-pb-md">
        <TfSkeletonRows v-if="membersQuery.isLoading.value && !members.length" :rows="5" :cols="2" />
        <div v-else-if="!members.length" class="text-body2 text-grey-7 q-py-lg">
          No members yet. Add someone by email.
        </div>
        <q-list v-else dense separator class="rounded-borders">
          <q-item v-for="member in members" :key="member.id" class="q-px-none">
            <q-item-section>
              <q-item-label>{{ member.name }}</q-item-label>
              <q-item-label caption>{{ member.email }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-badge color="grey-4" text-color="grey-9" :label="member.role" />
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfSkeletonRows from 'src/components/ui/TfSkeletonRows.vue';
import type { PpPeopleGroup } from '../types/ppPeople';
import { usePpPeopleGroupMembersQuery } from '../composables/usePpPeopleGroupMembersQuery';

const props = defineProps<{
  modelValue: boolean;
  group: PpPeopleGroup | null;
}>();

defineEmits<{
  'update:modelValue': [value: boolean];
  'add-member': [];
}>();

const groupId = computed(() => props.group?.id ?? null);
const membersQuery = usePpPeopleGroupMembersQuery(groupId);
const members = computed(() => membersQuery.data.value ?? []);
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid var(--tf-neutral-200, rgba(0, 0, 0, 0.08));
}
</style>