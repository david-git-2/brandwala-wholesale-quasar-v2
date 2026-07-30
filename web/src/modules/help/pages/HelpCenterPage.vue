<template>
  <q-page class="q-pa-md help-center-page">
    <div class="row items-center justify-between q-mb-lg q-col-gutter-md">
      <div class="col-12 col-md">
        <div class="row items-center q-gutter-sm">
          <div class="help-title-badge row items-center justify-center bg-primary-soft text-primary">
            <q-icon name="ph ph-book-open-text" size="22px" />
          </div>
          <div>
            <div class="text-h5 text-weight-bold text-grey-9">
              {{ t('help.title') }}
            </div>
            <div class="text-body2 text-grey-7">
              {{ t('help.subtitle') }}
            </div>
          </div>
        </div>
      </div>
      <div class="col-12 col-md-5 row items-center q-gutter-sm justify-end">
        <q-select
          v-model="currentLocale"
          :options="languageOptions"
          dense
          outlined
          emit-value
          map-options
          options-dense
          class="soft-input language-selector"
          style="min-width: 120px"
        >
          <template #prepend>
            <q-icon name="ph ph-globe" size="18px" class="text-grey-7" />
          </template>
        </q-select>

        <q-input
          v-model="search"
          dense
          outlined
          clearable
          debounce="150"
          :placeholder="t('help.search_placeholder')"
          class="soft-input col"
        >
          <template #prepend>
            <q-icon name="ph ph-magnifying-glass" size="18px" />
          </template>
        </q-input>
      </div>
    </div>

    <div v-if="!resolveContext" class="text-body2 text-grey-6 q-pa-md border-radius-8 bg-grey-1">
      {{ t('help.signInPrompt') }}
    </div>

    <div v-else-if="!filteredGuides.length" class="text-body2 text-grey-6 q-pa-md border-radius-8 bg-grey-1 text-center">
      <q-icon name="ph ph-file-search" size="32px" class="text-grey-5 q-mb-xs" />
      <div>{{ t('help.noResults') }}</div>
    </div>

    <div v-else class="row q-col-gutter-md">
      <div v-for="guide in filteredGuides" :key="guide.id" class="col-12 col-sm-6 col-md-4">
        <q-card
          flat
          class="help-center-card card-hover cursor-pointer full-height"
          :class="{ 'help-center-card--active': selectedId === guide.id }"
          @click="selectGuideCard(guide.id)"
        >
          <q-card-section class="q-pa-md">
            <div class="row items-center justify-between q-mb-sm">
              <div class="help-icon-wrapper row items-center justify-center">
                <q-icon :name="guide.icon" size="22px" class="text-primary" />
              </div>
              <q-chip
                dense
                unelevated
                class="text-caption text-weight-medium bg-grey-2 text-grey-8"
              >
                {{ guide.scopes[0] }}
              </q-chip>
            </div>
            <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-xs">
              {{ lt(guide.title, locale) }}
            </div>
            <div class="text-body2 text-grey-7 line-clamp-2">
              {{ lt(guide.caption, locale) }}
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <q-card v-if="selectedGuide" flat class="selected-guide-card q-mt-lg">
      <q-card-section class="row items-center justify-between bg-grey-1 q-py-md">
        <div class="row items-center q-gutter-sm">
          <div class="help-icon-wrapper bg-white row items-center justify-center">
            <q-icon :name="selectedGuide.icon" size="22px" class="text-primary" />
          </div>
          <div>
            <div class="text-h6 text-weight-bold text-grey-9">{{ lt(selectedGuide.title, locale) }}</div>
            <div class="text-body2 text-grey-7">{{ lt(selectedGuide.caption, locale) }}</div>
          </div>
        </div>
        <q-btn
          outline
          color="grey-7"
          icon="ph ph-x"
          round
          dense
          aria-label="Close guide"
          @click="clearSelection"
        />
      </q-card-section>

      <q-tabs
        v-model="sectionTab"
        dense
        align="left"
        active-color="primary"
        indicator-color="primary"
        class="q-px-md text-grey-8 guide-tabs"
        narrow-indicator
      >
        <q-tab name="overview" :label="t('help.tabs.overview')" no-caps />
        <q-tab name="workflows" :label="t('help.tabs.workflows')" no-caps />
        <q-tab name="terms" :label="t('help.tabs.terms')" no-caps />
        <q-tab name="faqs" :label="t('help.tabs.faqs')" no-caps />
      </q-tabs>
      <q-separator />

      <q-card-section class="q-pa-lg">
        <div v-if="sectionTab === 'overview'" class="text-body1 text-grey-9 overview-text" style="line-height: 1.65">
          {{ lt(selectedGuide.overview, locale) }}
        </div>

        <div v-else-if="sectionTab === 'workflows'" class="q-gutter-y-lg">
          <div v-if="!selectedGuide.workflows.length" class="text-grey-6 text-body2">
            {{ t('help.noWorkflows') }}
          </div>
          <div
            v-for="workflow in selectedGuide.workflows"
            :key="workflow.id"
            class="workflow-block q-pa-md rounded-borders bg-grey-1"
          >
            <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md row items-center q-gutter-xs">
              <q-icon name="ph ph-git-fork" class="text-primary" size="18px" />
              <span>{{ lt(workflow.title, locale) }}</span>
            </div>
            <div class="workflow-steps q-gutter-y-xs">
              <div
                v-for="(step, idx) in workflow.steps"
                :key="idx"
                class="row items-start q-gutter-sm step-item q-py-xs"
              >
                <div class="step-badge text-weight-bold text-primary bg-primary-soft">
                  {{ idx + 1 }}
                </div>
                <div class="col text-body2 text-grey-8 step-text">
                  {{ lt(step, locale) }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div v-else-if="sectionTab === 'terms'" class="row q-col-gutter-md">
          <div v-if="!selectedGuide.terms.length" class="col-12 text-grey-6 text-body2">
            {{ t('help.noTerms') }}
          </div>
          <div v-for="term in selectedGuide.terms" :key="term.term.en" class="col-12 col-md-6">
            <div class="term-card q-pa-md border-radius-8 bg-grey-1 full-height">
              <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs row items-center q-gutter-xs">
                <q-icon name="ph ph-tag" class="text-primary" size="16px" />
                <span>{{ lt(term.term, locale) }}</span>
              </div>
              <div class="text-body2 text-grey-8">{{ lt(term.definition, locale) }}</div>
            </div>
          </div>
        </div>

        <div v-else class="q-gutter-y-sm">
          <div v-if="!selectedGuide.faqs.length" class="text-grey-6 text-body2">
            {{ t('help.noFaqs') }}
          </div>
          <q-list class="faq-list border-radius-8">
            <q-expansion-item
              v-for="faq in selectedGuide.faqs"
              :key="faq.question.en"
              group="faqs"
              class="bg-grey-1 q-mb-xs rounded-borders faq-item"
              header-class="text-weight-bold text-grey-9"
            >
              <template #header>
                <q-item-section avatar style="min-width: 32px">
                  <q-icon name="ph ph-question" color="primary" size="18px" />
                </q-item-section>
                <q-item-section class="text-subtitle2 text-weight-bold text-grey-9">
                  {{ lt(faq.question, locale) }}
                </q-item-section>
              </template>
              <q-card class="bg-grey-1">
                <q-card-section class="text-body2 text-grey-8 q-pt-none q-pb-md q-pl-xl">
                  {{ lt(faq.answer, locale) }}
                </q-card-section>
              </q-card>
            </q-expansion-item>
          </q-list>
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';

import type { HelpScope, HelpTab } from '../types';
import { lt } from '../data/localize';
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
const { t, locale } = useI18n();

const search = ref('');
const selectedId = ref<string | null>(null);
const sectionTab = ref<HelpTab>('overview');

const currentLocale = computed({
  get: () => locale.value,
  set: (val: string) => {
    locale.value = val;
    localStorage.setItem('locale', val);
  },
});

const languageOptions = [
  { label: 'English', value: 'en-US' },
  { label: 'বাংলা', value: 'bn' },
];

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
.help-title-badge {
  width: 40px;
  height: 40px;
  border-radius: 10px;
}

.help-icon-wrapper {
  width: 38px;
  height: 38px;
  border-radius: 8px;
  background-color: var(--bw-theme-primary-soft, rgba(30, 136, 229, 0.08));
}

.help-center-card {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 12px;
  transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease, border-color 0.2s ease;
}

.card-hover:hover {
  transform: translateY(-2px);
  border-color: var(--q-primary);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.06);
}

.help-center-card--active {
  border-color: var(--q-primary);
  background-color: var(--bw-theme-primary-soft, rgba(30, 136, 229, 0.03));
}

.selected-guide-card {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.1));
  border-radius: 12px;
  overflow: hidden;
}

.bg-primary-soft {
  background-color: var(--bw-theme-primary-soft, rgba(30, 136, 229, 0.1));
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.step-badge {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  flex-shrink: 0;
  margin-top: 1px;
}

.step-text {
  line-height: 1.5;
}

.term-card {
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.faq-item {
  border: 1px solid rgba(0, 0, 0, 0.06);
  border-left: 3px solid var(--q-primary);
}

.border-radius-8 {
  border-radius: 8px;
}

.guide-tabs {
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
}
</style>
