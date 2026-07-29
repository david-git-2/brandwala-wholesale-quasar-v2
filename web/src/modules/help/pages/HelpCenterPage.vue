<template>
  <q-page class="q-pa-md help-center-page">
    <div class="row items-center justify-between q-mb-md q-col-gutter-sm">
      <div class="col-12 col-md">
        <div class="text-h5 text-weight-bold text-grey-9">Help Center</div>
        <div class="text-body2 text-grey-7">
          Guides filtered for your role. Open any card or search by keyword.
        </div>
      </div>
      <div class="col-12 col-md-4">
        <q-input
          v-model="search"
          dense
          outlined
          clearable
          debounce="150"
          placeholder="Search guides…"
          class="soft-input"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" />
          </template>
        </q-input>
      </div>
    </div>

    <div v-if="!resolveContext" class="text-body2 text-grey-6">
      Sign in to a workspace to view help guides.
    </div>

    <div v-else-if="!filteredGuides.length" class="text-body2 text-grey-6">
      No guides match your search.
    </div>

    <div v-else class="row q-col-gutter-md">
      <div v-for="guide in filteredGuides" :key="guide.id" class="col-12 col-sm-6 col-md-4">
        <q-card
          flat
          bordered
          class="help-center-card cursor-pointer full-height"
          :class="{ 'help-center-card--active': selectedId === guide.id }"
          @click="selectGuideCard(guide.id)"
        >
          <q-card-section>
            <div class="row items-center q-gutter-sm q-mb-sm">
              <q-icon :name="guide.icon" size="24px" color="primary" />
              <div class="text-subtitle1 text-weight-bold text-grey-9">{{ guide.title }}</div>
            </div>
            <div class="text-body2 text-grey-7">{{ guide.caption }}</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <q-card v-if="selectedGuide" flat bordered class="q-mt-lg">
      <q-card-section class="row items-center justify-between">
        <div>
          <div class="text-h6 text-weight-bold text-grey-9">{{ selectedGuide.title }}</div>
          <div class="text-body2 text-grey-7">{{ selectedGuide.caption }}</div>
        </div>
        <q-btn flat round dense icon="ph ph-x" aria-label="Close guide" @click="clearSelection" />
      </q-card-section>

      <q-tabs
        v-model="sectionTab"
        dense
        align="left"
        active-color="primary"
        indicator-color="primary"
        class="q-px-sm"
        narrow-indicator
      >
        <q-tab name="overview" label="Overview" no-caps />
        <q-tab name="workflows" label="Workflows" no-caps />
        <q-tab name="terms" label="Key Terms" no-caps />
        <q-tab name="faqs" label="FAQs" no-caps />
      </q-tabs>
      <q-separator />

      <q-card-section>
        <div v-if="sectionTab === 'overview'" class="text-body2" style="line-height: 1.55">
          {{ selectedGuide.overview }}
        </div>

        <div v-else-if="sectionTab === 'workflows'" class="q-gutter-y-md">
          <div v-if="!selectedGuide.workflows.length" class="text-grey-6">No workflows yet.</div>
          <div v-for="workflow in selectedGuide.workflows" :key="workflow.id">
            <div class="text-subtitle2 text-weight-bold q-mb-xs">{{ workflow.title }}</div>
            <ol class="q-pl-md q-ma-none text-body2">
              <li v-for="(step, idx) in workflow.steps" :key="idx" class="q-mb-xs">{{ step }}</li>
            </ol>
          </div>
        </div>

        <div v-else-if="sectionTab === 'terms'" class="q-gutter-y-md">
          <div v-if="!selectedGuide.terms.length" class="text-grey-6">No key terms yet.</div>
          <div v-for="term in selectedGuide.terms" :key="term.term">
            <div class="text-subtitle2 text-weight-bold">{{ term.term }}</div>
            <div class="text-body2">{{ term.definition }}</div>
          </div>
        </div>

        <div v-else class="q-gutter-y-md">
          <div v-if="!selectedGuide.faqs.length" class="text-grey-6">No FAQs yet.</div>
          <div v-for="faq in selectedGuide.faqs" :key="faq.question">
            <div class="text-subtitle2 text-weight-bold">{{ faq.question }}</div>
            <div class="text-body2">{{ faq.answer }}</div>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';

import type { HelpScope, HelpTab } from '../types';
import {
  getModuleGuideById,
  mapAccessRoleToHelpAudience,
  resolveHelpScopeFromPath,
  searchModuleGuides,
} from '../data/resolveModuleGuide';

const props = defineProps<{
  helpScope?: HelpScope;
}>();

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const search = ref('');
const selectedId = ref<string | null>(null);
const sectionTab = ref<HelpTab>('overview');

const scope = computed(
  () => props.helpScope ?? resolveHelpScopeFromPath(route.path) ?? ('app' as HelpScope),
);
const audience = computed(() => mapAccessRoleToHelpAudience(authStore.matchedRole));

const resolveContext = computed(() => {
  if (!audience.value) return null;
  return { scope: scope.value, audience: audience.value };
});

const filteredGuides = computed(() => {
  if (!resolveContext.value) return [];
  return searchModuleGuides(search.value, resolveContext.value);
});

const selectedGuide = computed(() =>
  selectedId.value ? getModuleGuideById(selectedId.value) ?? null : null,
);

const syncFromQuery = () => {
  const moduleParam = typeof route.query.module === 'string' ? route.query.module : null;
  const sectionParam = typeof route.query.section === 'string' ? route.query.section : null;
  if (moduleParam) {
    selectedId.value = moduleParam;
  }
  if (
    sectionParam === 'overview' ||
    sectionParam === 'workflows' ||
    sectionParam === 'terms' ||
    sectionParam === 'faqs'
  ) {
    sectionTab.value = sectionParam;
  }
};

watch(
  () => [route.query.module, route.query.section],
  () => syncFromQuery(),
  { immediate: true },
);

const selectGuideCard = (id: string) => {
  selectedId.value = id;
  sectionTab.value = 'overview';
  void router.replace({
    query: {
      ...route.query,
      module: id,
      section: 'overview',
    },
  });
};

const clearSelection = () => {
  selectedId.value = null;
  const nextQuery = { ...route.query };
  delete nextQuery.module;
  delete nextQuery.section;
  void router.replace({ query: nextQuery });
};

watch(sectionTab, (tab) => {
  if (!selectedId.value) return;
  void router.replace({
    query: {
      ...route.query,
      module: selectedId.value,
      section: tab,
    },
  });
});
</script>

<style scoped>
.help-center-card {
  transition: border-color 0.15s ease;
}
.help-center-card--active {
  border-color: var(--q-primary);
}
</style>
