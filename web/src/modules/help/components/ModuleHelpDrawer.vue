<template>
  <q-drawer
    :model-value="drawerOpen"
    side="right"
    overlay
    bordered
    :width="460"
    class="bg-white module-help-drawer"
    @update:model-value="onDrawerUpdate"
  >
    <div class="column full-height overflow-hidden">
      <div class="q-pa-md row items-center justify-between bg-grey-1 border-bottom no-wrap">
        <div class="col row items-center q-gutter-x-sm no-wrap style-min-w-0">
          <div class="drawer-title-badge row items-center justify-center bg-primary-soft text-primary flex-shrink-0">
            <q-icon :name="activeGuide?.icon ?? 'ph ph-book-open-text'" size="20px" />
          </div>
          <div class="col style-min-w-0">
            <div class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
              {{ activeGuide ? lt(activeGuide.title, locale) : t('help.drawerTitle') }}
            </div>
            <div class="text-caption text-grey-7 ellipsis">
              {{ activeGuide ? lt(activeGuide.caption, locale) : t('help.drawerSubtitle') }}
            </div>
          </div>
        </div>
        <div class="row items-center q-gutter-x-xs no-wrap flex-shrink-0">
          <q-btn
            flat
            dense
            round
            icon="ph ph-globe"
            class="text-grey-7"
            aria-label="Toggle language"
            @click="toggleLanguage"
          >
            <q-tooltip>{{ currentLocale === 'bn' ? 'English' : 'বাংলা' }}</q-tooltip>
          </q-btn>
          <q-btn flat round dense icon="ph ph-x" aria-label="Close help" @click="closeHelp" />
        </div>
      </div>

      <div v-if="availableGuides.length > 1" class="q-px-md q-pt-sm">
        <q-select
          :model-value="activeGuideId"
          :options="guideOptions"
          dense
          outlined
          emit-value
          map-options
          options-dense
          label="Guide"
          class="soft-input"
          @update:model-value="selectGuide"
        />
      </div>

      <template v-if="activeGuide">
        <q-tabs
          v-model="activeTab"
          dense
          class="text-grey-8 q-px-sm guide-tabs"
          active-color="primary"
          indicator-color="primary"
          align="left"
          narrow-indicator
          outside-arrows
          mobile-arrows
        >
          <q-tab name="overview" :label="t('help.tabs.overview')" no-caps />
          <q-tab name="workflows" :label="t('help.tabs.workflows')" no-caps />
          <q-tab name="terms" :label="t('help.tabs.terms')" no-caps />
          <q-tab name="faqs" :label="t('help.tabs.faqs')" no-caps />
        </q-tabs>
        <q-separator />

        <div class="col scroll q-pa-md">
          <div v-if="activeTab === 'overview'" class="text-body2 text-grey-9 overview-text" style="line-height: 1.6">
            {{ lt(activeGuide.overview, locale) }}
          </div>

          <div v-else-if="activeTab === 'workflows'" class="q-gutter-y-md">
            <div v-if="!activeGuide.workflows.length" class="text-body2 text-grey-6">
              {{ t('help.noWorkflows') }}
            </div>
            <div
              v-for="workflow in activeGuide.workflows"
              :key="workflow.id"
              class="workflow-block q-pa-sm rounded-borders bg-grey-1"
            >
              <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs row items-center q-gutter-xs">
                <q-icon name="ph ph-git-fork" class="text-primary" size="16px" />
                <span>{{ lt(workflow.title, locale) }}</span>
              </div>
              <div class="q-gutter-y-xs">
                <div
                  v-for="(step, idx) in workflow.steps"
                  :key="idx"
                  class="row items-start q-gutter-xs step-item q-py-xs"
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

          <div v-else-if="activeTab === 'terms'" class="q-gutter-y-sm">
            <div v-if="!activeGuide.terms.length" class="text-body2 text-grey-6">
              {{ t('help.noTerms') }}
            </div>
            <div
              v-for="term in activeGuide.terms"
              :key="term.term.en"
              class="term-card q-pa-sm rounded-borders bg-grey-1"
            >
              <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs row items-center q-gutter-xs">
                <q-icon name="ph ph-tag" class="text-primary" size="15px" />
                <span>{{ lt(term.term, locale) }}</span>
              </div>
              <div class="text-body2 text-grey-8">{{ lt(term.definition, locale) }}</div>
            </div>
          </div>

          <div v-else class="q-gutter-y-xs">
            <div v-if="!activeGuide.faqs.length" class="text-body2 text-grey-6">
              {{ t('help.noFaqs') }}
            </div>
            <q-list dense class="faq-list">
              <q-expansion-item
                v-for="faq in activeGuide.faqs"
                :key="faq.question.en"
                group="drawer-faqs"
                class="bg-grey-1 q-mb-xs rounded-borders faq-item"
                header-class="text-weight-bold text-grey-9 text-body2"
              >
                <template #header>
                  <q-item-section avatar style="min-width: 28px">
                    <q-icon name="ph ph-question" color="primary" size="16px" />
                  </q-item-section>
                  <q-item-section class="text-subtitle2 text-weight-bold text-grey-9">
                    {{ lt(faq.question, locale) }}
                  </q-item-section>
                </template>
                <q-card class="bg-grey-1">
                  <q-card-section class="text-body2 text-grey-8 q-pt-none q-pb-sm q-pl-lg">
                    {{ lt(faq.answer, locale) }}
                  </q-card-section>
                </q-card>
              </q-expansion-item>
            </q-list>
          </div>
        </div>
      </template>

      <div v-else class="col flex flex-center q-pa-md text-body2 text-grey-6">
        No guide available for your role on this screen.
      </div>

      <div class="q-pa-md border-top bg-grey-1">
        <q-btn
          unelevated
          color="primary"
          no-caps
          class="full-width"
          :label="t('help.openHelpCenter')"
          icon="ph ph-book-open-text"
          @click="goToHelpCenter"
        />
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';

import { useModuleHelp } from '../composables/useModuleHelp';
import { lt } from '../data/localize';
import { helpCenterPathForScope } from '../data/resolveModuleGuide';

const router = useRouter();
const authStore = useAuthStore();
const { t, locale } = useI18n();

const {
  drawerOpen,
  activeGuideId,
  activeTab,
  activeGuide,
  availableGuides,
  scope,
  closeHelp,
  selectGuide,
} = useModuleHelp();

const currentLocale = computed({
  get: () => locale.value,
  set: (val: string) => {
    locale.value = val;
    localStorage.setItem('locale', val);
  },
});

const toggleLanguage = () => {
  currentLocale.value = currentLocale.value === 'bn' ? 'en-US' : 'bn';
};

const guideOptions = computed(() =>
  availableGuides.value.map((guide) => ({
    label: lt(guide.title, locale.value),
    value: guide.id,
  })),
);

const onDrawerUpdate = (open: boolean) => {
  drawerOpen.value = open;
};

const goToHelpCenter = () => {
  if (!scope.value) return;
  const path = helpCenterPathForScope(scope.value, authStore.tenantSlug);
  const location: { path: string; query?: Record<string, string> } = { path };
  if (activeGuideId.value != null) {
    location.query = { module: activeGuideId.value, section: activeTab.value };
  }
  closeHelp();
  void router.push(location);
};
</script>

<style scoped>
.drawer-title-badge {
  width: 34px;
  height: 34px;
  border-radius: 8px;
}

.bg-primary-soft {
  background-color: var(--bw-theme-primary-soft, rgba(30, 136, 229, 0.1));
}

.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}

.step-badge {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  flex-shrink: 0;
  margin-top: 1px;
}

.step-text {
  line-height: 1.45;
}

.term-card {
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.faq-item {
  border: 1px solid rgba(0, 0, 0, 0.06);
  border-left: 3px solid var(--q-primary);
}

.guide-tabs {
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
}

.style-min-w-0 {
  min-width: 0;
}

.flex-shrink-0 {
  flex-shrink: 0;
}

.overflow-hidden {
  overflow: hidden;
}
</style>
