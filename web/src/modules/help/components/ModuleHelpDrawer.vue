<template>
  <q-drawer
    :model-value="drawerOpen"
    side="right"
    overlay
    bordered
    :width="$q.screen.width < 460 ? $q.screen.width : 460"
    class="bg-grey-1 module-help-drawer"
    @update:model-value="onDrawerUpdate"
  >
    <div class="column fit overflow-hidden">
      <div class="q-pa-md row items-center justify-between bg-white border-bottom no-wrap flex-shrink-0 shadow-1" style="z-index: 10;">
        <div class="col row items-center q-gutter-x-sm no-wrap style-min-w-0">
          <div class="drawer-title-badge row items-center justify-center bg-primary-soft text-primary flex-shrink-0">
            <q-icon :name="activeGuide?.icon ?? 'ph ph-book-open-text'" size="20px" />
          </div>
          <div class="col style-min-w-0">
            <div class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
              {{ activeGuide ? lt(activeGuide.title, locale) : t('help.drawerTitle') }}
            </div>
            <div class="text-caption text-grey-7" style="line-height: 1.3">
              {{ activeGuide ? lt(activeGuide.caption, locale) : t('help.drawerSubtitle') }}
            </div>
          </div>
        </div>
        <div class="row items-center q-gutter-x-xs no-wrap flex-shrink-0 self-start q-mt-xs">
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

      <div v-if="availableGuides.length > 1" class="q-px-md q-pt-md bg-grey-1 flex-shrink-0">
        <q-select
          :model-value="activeGuideId"
          :options="guideOptions"
          dense
          outlined
          emit-value
          map-options
          options-dense
          label="Guide"
          class="soft-input bg-white"
          @update:model-value="selectGuide"
        />
      </div>

      <template v-if="activeGuide">
        <div class="flex-shrink-0 bg-grey-1">
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
        </div>

        <q-scroll-area class="col bg-grey-1">
          <div class="q-pa-md">
            <div v-if="activeTab === 'overview'" class="overview-block bg-white q-pa-md rounded-borders border-light shadow-1 relative-position overflow-hidden">
              <div class="absolute-top-left full-width" style="height: 4px; background: linear-gradient(90deg, var(--q-primary), #64b5f6);"></div>
              <div class="row items-center q-mb-sm q-gutter-sm">
                <div class="bg-primary-soft text-primary rounded-borders flex flex-center" style="width: 28px; height: 28px;">
                  <q-icon name="ph ph-info" size="18px" />
                </div>
                <div class="text-subtitle2 text-weight-bold text-grey-9">{{ t('help.tabs.overview') }}</div>
              </div>
              <div class="text-body2 text-grey-8" style="line-height: 1.6">
                {{ lt(activeGuide.overview, locale) }}
              </div>
            </div>

            <div v-else-if="activeTab === 'workflows'" class="q-gutter-y-md">
              <div v-if="!activeGuide.workflows.length" class="flex flex-center column q-pa-xl text-grey-5">
                <q-icon name="ph ph-wind" size="48px" class="q-mb-sm opacity-50" />
                <div class="text-body2">{{ t('help.noWorkflows') }}</div>
              </div>
              <div
                v-for="workflow in activeGuide.workflows"
                :key="workflow.id"
                class="workflow-block card-hover q-pa-md rounded-borders bg-white border-light"
              >
                <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-md row items-center q-gutter-sm">
                  <div class="bg-primary-soft text-primary rounded-borders flex flex-center" style="width: 28px; height: 28px;">
                     <q-icon name="ph ph-git-fork" size="16px" />
                  </div>
                  <span class="col">{{ lt(workflow.title, locale) }}</span>
                </div>
                <div class="q-gutter-y-sm">
                  <div
                    v-for="(step, idx) in workflow.steps"
                    :key="idx"
                    class="row items-start q-gutter-sm step-item q-py-xs"
                  >
                    <div class="step-badge text-weight-bold text-primary bg-primary-soft shadow-1">
                      {{ idx + 1 }}
                    </div>
                    <div class="col text-body2 text-grey-8 step-text" v-html="formatRichText(lt(step, locale))"></div>
                  </div>
                </div>
              </div>
            </div>

            <div v-else-if="activeTab === 'terms'" class="q-gutter-y-sm">
              <div v-if="!activeGuide.terms.length" class="flex flex-center column q-pa-xl text-grey-5">
                <q-icon name="ph ph-bookmarks" size="48px" class="q-mb-sm opacity-50" />
                <div class="text-body2">{{ t('help.noTerms') }}</div>
              </div>
              <div
                v-for="term in activeGuide.terms"
                :key="term.term.en"
                class="term-card card-hover q-pa-md rounded-borders bg-white border-light shadow-1"
              >
                <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm row items-center q-gutter-sm">
                  <div class="bg-primary-soft text-primary rounded-borders flex flex-center" style="width: 24px; height: 24px;">
                     <q-icon name="ph ph-tag" size="14px" />
                  </div>
                  <span class="text-primary">{{ lt(term.term, locale) }}</span>
                </div>
                <div class="text-body2 text-grey-8" v-html="formatRichText(lt(term.definition, locale))"></div>
              </div>
            </div>

            <div v-else class="q-gutter-y-xs">
              <div v-if="!activeGuide.faqs.length" class="flex flex-center column q-pa-xl text-grey-5">
                <q-icon name="ph ph-chats" size="48px" class="q-mb-sm opacity-50" />
                <div class="text-body2">{{ t('help.noFaqs') }}</div>
              </div>
              <q-list dense class="faq-list">
                <q-expansion-item
                  v-for="faq in activeGuide.faqs"
                  :key="faq.question.en"
                  group="drawer-faqs"
                  class="bg-white q-mb-xs rounded-borders faq-item card-hover"
                  header-class="text-weight-bold text-grey-9 text-body2"
                >
                  <template #header>
                    <q-item-section avatar style="min-width: 28px">
                      <div class="bg-primary-soft text-primary rounded-borders flex flex-center" style="width: 24px; height: 24px;">
                         <q-icon name="ph ph-question" size="14px" />
                      </div>
                    </q-item-section>
                    <q-item-section class="text-subtitle2 text-weight-bold text-grey-9">
                      {{ lt(faq.question, locale) }}
                    </q-item-section>
                  </template>
                  <q-card class="bg-transparent">
                    <q-card-section class="text-body2 text-grey-8 q-pt-none q-pb-md q-pl-xl" v-html="formatRichText(lt(faq.answer, locale))"></q-card-section>
                  </q-card>
                </q-expansion-item>
              </q-list>
            </div>
          </div>
        </q-scroll-area>
      </template>

      <div v-else class="col flex flex-center q-pa-md text-body2 text-grey-6">
        No guide available for your role on this screen.
      </div>

      <div class="q-pa-md border-top bg-white flex-shrink-0" style="z-index: 10;">
        <q-btn
          unelevated
          color="primary"
          no-caps
          class="full-width shadow-2"
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
import { useQuasar } from 'quasar';

import { useAuthStore } from 'src/modules/auth/stores/authStore';

import { useModuleHelp } from '../composables/useModuleHelp';
import { lt } from '../data/localize';
import { helpCenterPathForScope } from '../data/resolveModuleGuide';

const router = useRouter();
const authStore = useAuthStore();
const { t, locale } = useI18n();
const $q = useQuasar();

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

const formatRichText = (text: string) => {
  if (!text) return '';
  // Format parenthetical lists (e.g., Code, Name, Category) as tags FIRST
  let formatted = text.replace(/\(([^)]+)\)/g, (match, content) => {
    if (content.includes(',')) {
      const parts = content.split(',').map((s: string) => s.trim());
      const tags = parts.map((p: string) => `<span class='field-tag-badge bg-grey-2 text-grey-8 rounded-borders q-px-xs'>${p}</span>`).join(`<span class='text-grey-5'>, </span>`);
      return `( ${tags} )`;
    }
    return match;
  });

  // Replace "Text" with a primary button-like badge (use single quotes for HTML to avoid subsequent or previous regex matching)
  formatted = formatted.replace(
    /"([^"]+)"/g,
    `<span class='action-badge action-badge-primary bg-primary text-white text-weight-bold q-px-sm q-py-xs text-caption q-mx-xs shadow-2'>$1</span>`
  );
  
  // Replace **Text** with a grey button-like badge
  formatted = formatted.replace(
    /\*\*([^*]+)\*\*/g,
    `<span class='action-badge action-badge-grey bg-grey-2 text-grey-9 text-weight-bold q-px-sm q-py-xs text-caption q-mx-xs shadow-1'>$1</span>`
  );

  return formatted;
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
.border-light {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
}

.step-badge {
  width: 22px;
  height: 22px;
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
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
}

.faq-item {
  border: 1px solid var(--bw-theme-border, rgba(0, 0, 0, 0.08));
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

.card-hover {
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}
.card-hover:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
  transform: translateY(-1px);
}

:deep(.action-badge) {
  display: inline-flex !important;
  align-items: center !important;
  white-space: nowrap !important;
  line-height: 1.2 !important;
  margin: 1px 4px !important;
  border-radius: 9999px !important;
  padding: 3px 10px !important;
  vertical-align: middle !important;
  font-weight: 600 !important;
}

:deep(.action-badge-primary) {
  border: 1px solid var(--q-primary) !important;
  box-shadow: 0 2px 5px rgba(0, 0, 0, 0.2) !important;
}

:deep(.action-badge-grey) {
  border: 1px solid rgba(0, 0, 0, 0.15) !important;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.12) !important;
}

:deep(.field-tag-badge) {
  font-size: 11px !important;
  border-radius: 6px !important;
  border: 1px solid rgba(0, 0, 0, 0.08) !important;
  display: inline-block !important;
  white-space: nowrap !important;
}
</style>
