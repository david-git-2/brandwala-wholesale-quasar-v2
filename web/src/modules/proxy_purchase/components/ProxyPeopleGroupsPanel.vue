<template>
  <div class="column no-wrap pp-groups-panel">
    <div class="row items-center q-gutter-sm q-mb-sm flex-shrink-0">
      <TfDrawerSectionTabs
        v-model="peopleTab"
        class="col"
        :tabs="peopleTabs"
        aria-label="Proxy people type"
      />
      <TfBtn
        variant="icon"
        size="md"
        icon="ph ph-copy"
        aria-label="Copy proxy login URL"
        class="col-auto"
        :disable="!tenantSlug"
        @click="copyProxyLoginUrl"
      />
      <TfBtn
        variant="primary"
        size="md"
        label="Create group"
        icon="ph ph-plus"
        class="col-auto"
        @click="createDialogOpen = true"
      />
    </div>

    <TfEntityListShell
      v-if="groupsQuery.isLoading.value && !groups.length"
      root-class="pp-groups-list--fit"
    >
      <TfEntityListRow v-for="n in 3" :key="n" skeleton />
    </TfEntityListShell>

    <TfEmptyState
      v-else-if="!groups.length"
      title="No groups yet"
      message="Create a customer or supplier group to invite proxy portal members."
    >
      <TfBtn variant="primary" size="md" label="Create group" @click="createDialogOpen = true" />
    </TfEmptyState>

    <TfEntityListShell v-else root-class="pp-groups-list--fit">
      <TfEntityListRow
        v-for="group in groups"
        :key="group.id"
        clickable
        show-chevron
        :active="selectedGroup?.id === group.id"
        @click="openGroup(group)"
      >
        <template #title>
          <span class="text-weight-medium">{{ group.name }}</span>
        </template>
        <template #meta>
          <span class="text-caption text-grey-7">
            {{ group.member_count }} {{ group.member_count === 1 ? 'member' : 'members' }}
          </span>
        </template>
      </TfEntityListRow>
    </TfEntityListShell>

    <PpCreateGroupDialog
      v-model="createDialogOpen"
      :default-type="peopleTab"
      :loading="createGroup.isPending.value"
      @submit="onCreateGroup"
    />

    <PpPeopleGroupDrawer
      v-model="drawerOpen"
      :group="selectedGroup"
      @add-member="addMemberDialogOpen = true"
    />

    <PpAddMemberDialog
      v-model="addMemberDialogOpen"
      :loading="createMember.isPending.value"
      @submit="onAddMember"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { copyToClipboard } from 'quasar';
import TfBtn from 'src/components/ui/TfBtn.vue';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfEntityListRow from 'src/components/ui/TfEntityListRow.vue';
import TfEntityListShell from 'src/components/ui/TfEntityListShell.vue';
import PpAddMemberDialog from './PpAddMemberDialog.vue';
import PpCreateGroupDialog from './PpCreateGroupDialog.vue';
import PpPeopleGroupDrawer from './PpPeopleGroupDrawer.vue';
import { usePpPeopleGroupsQuery } from '../composables/usePpPeopleGroupsQuery';
import { usePpPeopleMutations } from '../composables/usePpPeopleMutations';
import type { PpPeopleGroup, PpPeopleGroupType, PpPeopleMemberRole } from '../types/ppPeople';

const authStore = useAuthStore();
const tenantSlug = computed(() => authStore.tenantSlug ?? '');

const copyProxyLoginUrl = async () => {
  const slug = tenantSlug.value;
  if (!slug) {
    showErrorNotification('Tenant slug is not available.');
    return;
  }
  const origin = typeof window === 'undefined' ? '' : window.location.origin;
  const url = `${origin}/${slug}/proxy/login`;
  try {
    await copyToClipboard(url);
    showSuccessNotification('Proxy login URL copied.');
  } catch {
    showErrorNotification('Could not copy the login URL.');
  }
};

const peopleTab = ref<PpPeopleGroupType>('customer');
const peopleTabs = [
  { name: 'customer', label: 'Customer', icon: 'ph ph-shopping-bag' },
  { name: 'supplier', label: 'Supplier', icon: 'ph ph-truck' },
];

const createDialogOpen = ref(false);
const addMemberDialogOpen = ref(false);
const drawerOpen = ref(false);
const selectedGroup = ref<PpPeopleGroup | null>(null);
const selectedGroupId = computed(() => selectedGroup.value?.id ?? null);

const groupsQuery = usePpPeopleGroupsQuery(peopleTab);
const groups = computed(() => groupsQuery.data.value ?? []);

const { createGroup, createMember } = usePpPeopleMutations(peopleTab, selectedGroupId);

watch(peopleTab, () => {
  drawerOpen.value = false;
  selectedGroup.value = null;
});

const openGroup = (group: PpPeopleGroup) => {
  selectedGroup.value = group;
  drawerOpen.value = true;
};

const onCreateGroup = async (payload: { name: string; type: PpPeopleGroupType }) => {
  try {
    const created = await createGroup.mutateAsync(payload);
    createDialogOpen.value = false;
    if (created.type === peopleTab.value) {
      selectedGroup.value = created;
      drawerOpen.value = true;
    }
  } catch {
    /* notified */
  }
};

const onAddMember = async (payload: {
  name: string;
  email: string;
  role: PpPeopleMemberRole;
}) => {
  try {
    await createMember.mutateAsync(payload);
    addMemberDialogOpen.value = false;
  } catch {
    /* notified */
  }
};
</script>

<style scoped>
.pp-groups-panel {
  width: 100%;
  flex: 0 0 auto;
  align-self: flex-start;
}

.pp-groups-panel :deep(.pp-groups-list--fit.tf-entity-list-card) {
  flex: 0 0 auto;
  min-height: 0;
}

.pp-groups-panel :deep(.pp-groups-list--fit .tf-entity-list-scroll) {
  flex: 0 0 auto;
  min-height: 0;
  overflow: visible;
}
</style>