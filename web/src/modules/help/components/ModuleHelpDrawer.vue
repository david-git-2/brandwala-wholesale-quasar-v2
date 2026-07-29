<template>
  <q-drawer
    :model-value="drawerOpen"
    side="right"
    overlay
    bordered
    :width="440"
    class="bg-white module-help-drawer"
    @update:model-value="onDrawerUpdate"
  >
    <div class="column full-height">
      <div class="q-pa-md row items-start justify-between bg-grey-1 border-bottom">
        <div class="col">
          <div class="text-subtitle1 text-weight-bold text-grey-9">
            {{ activeGuide?.title ?? 'Module Guide' }}
          </div>
          <div class="text-caption text-grey-7">
            {{ activeGuide?.caption ?? 'Help for this area of the product' }}
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" aria-label="Close help" @click="closeHelp" />
      </div>

      <div v-if="availableGuides.length > 1" class="q-px-md q-pt-sm">
        <q-select
          :model-value="activeGuideId"
          :options="guideOptions"
          dense
          outlined
          emit-value
          map-options
          label="Guide"
          @update:model-value="selectGuide"
        />
      </div>

      <template v-if="activeGuide">
        <q-tabs
          v-model="activeTab"
          dense
          class="text-grey-8 q-px-sm"
          active-color="primary"
          indicator-color="primary"
          align="left"
          narrow-indicator
        >
          <q-tab name="overview" label="Overview" no-caps />
          <q-tab name="workflows" label="Workflows" no-caps />
          <q-tab name="terms" label="Key Terms" no-caps />
          <q-tab name="faqs" label="FAQs" no-caps />
        </q-tabs>
        <q-separator />

        <div class="col scroll q-pa-md">
          <div v-if="activeTab === 'overview'" class="text-body2 text-grey-9" style="line-height: 1.55">
            {{ activeGuide.overview }}
          </div>

          <div v-else-if="activeTab === 'workflows'" class="q-gutter-y-md">
            <div v-if="!activeGuide.workflows.length" class="text-body2 text-grey-6">
              No workflows yet.
            </div>
            <div v-for="workflow in activeGuide.workflows" :key="workflow.id">
              <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-xs">
                {{ workflow.title }}
              </div>
              <ol class="q-pl-md q-ma-none text-body2 text-grey-8">
                <li v-for="(step, idx) in workflow.steps" :key="idx" class="q-mb-xs">
                  {{ step }}
                </li>
              </ol>
            </div>
          </div>

          <div v-else-if="activeTab === 'terms'" class="q-gutter-y-md">
            <div v-if="!activeGuide.terms.length" class="text-body2 text-grey-6">
              No key terms yet.
            </div>
            <div v-for="term in activeGuide.terms" :key="term.term">
              <div class="text-subtitle2 text-weight-bold text-grey-9">{{ term.term }}</div>
              <div class="text-body2 text-grey-8">{{ term.definition }}</div>
            </div>
          </div>

          <div v-else class="q-gutter-y-md">
            <div v-if="!activeGuide.faqs.length" class="text-body2 text-grey-6">No FAQs yet.</div>
            <div v-for="faq in activeGuide.faqs" :key="faq.question">
              <div class="text-subtitle2 text-weight-bold text-grey-9">{{ faq.question }}</div>
              <div class="text-body2 text-grey-8">{{ faq.answer }}</div>
            </div>
          </div>
        </div>
      </template>

      <div v-else class="col flex flex-center q-pa-md text-body2 text-grey-6">
        No guide available for your role on this screen.
      </div>

      <div class="q-pa-md border-top">
        <q-btn
          unelevated
          color="primary"
          no-caps
          class="full-width"
          label="Open Help Center"
          icon="ph ph-book-open-text"
          @click="goToHelpCenter"
        />
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';

import { useModuleHelp } from '../composables/useModuleHelp';
import { helpCenterPathForScope } from '../data/resolveModuleGuide';

const router = useRouter();
const authStore = useAuthStore();
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

const guideOptions = computed(() =>
  availableGuides.value.map((guide) => ({
    label: guide.title,
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
.border-bottom {
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}
</style>
