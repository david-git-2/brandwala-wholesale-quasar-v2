import { ref } from 'vue';
import { Dark } from 'quasar';
import { useMembershipPreferenceStore } from '../modules/membership/stores/membershipPreferenceStore';
import type { MembershipPreferenceSchema } from '../modules/membership/types/preferences';

const darkMode = ref(false);
const density = ref<'comfortable' | 'compact'>('comfortable');
const navPinned = ref(true);

const setLocalStorage = (key: string, val: string) => {
  if (typeof window !== 'undefined') {
    window.localStorage.setItem(key, val);
  }
};

export const applyDarkMode = (val: boolean) => {
  darkMode.value = val;
  Dark.set(val);
  setLocalStorage('brandwala.appearance.darkMode', val ? 'true' : 'false');
};

export const applyDensity = (val: 'comfortable' | 'compact') => {
  density.value = val;
  if (typeof document !== 'undefined') {
    if (val === 'compact') {
      document.body.classList.add('body--compact');
    } else {
      document.body.classList.remove('body--compact');
    }
  }
  setLocalStorage('brandwala.appearance.density', val);
};

export const applyNavPinned = (val: boolean) => {
  navPinned.value = val;
  setLocalStorage('brandwala.appearance.navPinned', val ? 'true' : 'false');
};

export const setDarkMode = async (val: boolean, membershipId?: number | null) => {
  applyDarkMode(val);
  if (membershipId) {
    const store = useMembershipPreferenceStore();
    store.patchPreferencePath(membershipId, ['ui', 'appearance', 'darkMode'], val);
    await store.savePreference(membershipId);
  }
};

export const setDensity = async (val: 'comfortable' | 'compact', membershipId?: number | null) => {
  applyDensity(val);
  if (membershipId) {
    const store = useMembershipPreferenceStore();
    store.patchPreferencePath(membershipId, ['ui', 'appearance', 'density'], val);
    await store.savePreference(membershipId);
  }
};

export const setNavPinned = async (val: boolean, membershipId?: number | null) => {
  applyNavPinned(val);
  if (membershipId) {
    const store = useMembershipPreferenceStore();
    store.patchPreferencePath(membershipId, ['ui', 'appearance', 'navPinned'], val);
    await store.savePreference(membershipId);
  }
};

export const reconcilePreferences = async (
  membershipId: number,
  preferences: MembershipPreferenceSchema,
) => {
  const store = useMembershipPreferenceStore();

  const backendDarkMode = preferences.ui?.appearance?.darkMode;
  const backendDensity = preferences.ui?.appearance?.density;
  const backendNavPinned = preferences.ui?.appearance?.navPinned;

  let changed = false;

  if (backendDarkMode !== undefined) {
    if (darkMode.value !== backendDarkMode) {
      applyDarkMode(backendDarkMode);
    }
  } else {
    store.patchPreferencePath(membershipId, ['ui', 'appearance', 'darkMode'], darkMode.value);
    changed = true;
  }

  if (backendDensity !== undefined) {
    if (density.value !== backendDensity) {
      applyDensity(backendDensity);
    }
  } else {
    store.patchPreferencePath(membershipId, ['ui', 'appearance', 'density'], density.value);
    changed = true;
  }

  if (backendNavPinned !== undefined) {
    if (navPinned.value !== backendNavPinned) {
      applyNavPinned(backendNavPinned);
    }
  } else {
    store.patchPreferencePath(membershipId, ['ui', 'appearance', 'navPinned'], navPinned.value);
    changed = true;
  }

  if (changed) {
    await store.savePreference(membershipId);
  }
};

export function useAppearance() {
  return {
    darkMode,
    density,
    navPinned,
    setDarkMode,
    setDensity,
    setNavPinned,
    reconcilePreferences,
  };
}
