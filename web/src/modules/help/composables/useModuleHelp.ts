import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';

import type { HelpScope, HelpTab, ModuleGuide } from '../types';
import {
  getModuleGuideById,
  listModuleGuides,
  mapAccessRoleToHelpAudience,
  resolveHelpScopeFromPath,
  resolveModuleGuideFromPath,
} from '../data/resolveModuleGuide';

const drawerOpen = ref(false);
const activeGuideId = ref<string | null>(null);
const activeTab = ref<HelpTab>('overview');
const forcedScope = ref<HelpScope | null>(null);

export type OpenHelpOptions = {
  guideId?: string;
  tab?: HelpTab;
  sectionId?: string;
  scope?: HelpScope;
};

export function useModuleHelp() {
  const route = useRoute();
  const authStore = useAuthStore();

  const audience = computed(() => mapAccessRoleToHelpAudience(authStore.matchedRole));

  const scope = computed<HelpScope | null>(() => {
    if (forcedScope.value) return forcedScope.value;
    return resolveHelpScopeFromPath(route.path);
  });

  const resolveContext = computed(() => {
    if (!scope.value || !audience.value) return null;
    return { scope: scope.value, audience: audience.value };
  });

  const availableGuides = computed<ModuleGuide[]>(() => {
    if (!resolveContext.value) return [];
    return listModuleGuides(resolveContext.value);
  });

  const activeGuide = computed<ModuleGuide | null>(() => {
    if (!activeGuideId.value) return null;
    const guide = getModuleGuideById(activeGuideId.value);
    if (!guide || !resolveContext.value) return guide ?? null;
    if (
      !guide.scopes.includes(resolveContext.value.scope) ||
      !guide.audiences.includes(resolveContext.value.audience)
    ) {
      return null;
    }
    return guide;
  });

  const openHelp = (options: OpenHelpOptions = {}) => {
    if (options.scope) {
      forcedScope.value = options.scope;
    }

    const ctx = resolveContext.value;
    let guide: ModuleGuide | undefined;

    if (options.guideId) {
      guide = getModuleGuideById(options.guideId);
    } else if (ctx) {
      guide = resolveModuleGuideFromPath(route.path, ctx);
    }

    if (!guide && ctx) {
      guide =
        listModuleGuides(ctx).find((g) => g.id === 'getting_started') ??
        listModuleGuides(ctx)[0];
    }

    activeGuideId.value = guide?.id ?? null;
    activeTab.value = options.tab ?? 'overview';

    if (options.sectionId && guide) {
      const workflow = guide.workflows.find((w) => w.id === options.sectionId);
      if (workflow) activeTab.value = 'workflows';
    }

    drawerOpen.value = true;
  };

  const closeHelp = () => {
    drawerOpen.value = false;
  };

  const selectGuide = (guideId: string) => {
    activeGuideId.value = guideId;
    activeTab.value = 'overview';
  };

  const setHelpScope = (next: HelpScope | null) => {
    forcedScope.value = next;
  };

  return {
    drawerOpen,
    activeGuideId,
    activeTab,
    activeGuide,
    availableGuides,
    scope,
    audience,
    openHelp,
    closeHelp,
    selectGuide,
    setHelpScope,
  };
}
