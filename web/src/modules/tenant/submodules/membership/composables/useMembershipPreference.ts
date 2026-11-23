import { ref, watch, onMounted, computed, type Ref } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useMembershipPreferenceStore } from '../stores/membershipPreferenceStore';
import { clonePreferenceValue, getPreferencePath, valuesEqual } from '../utils/preferenceUtils';

export function useMembershipPreference<T>(options: {
  path: readonly string[];
  defaultValue: T;
  debounceMs?: number;
  equals?: (a: T, b: T) => boolean;
}) {
  const authStore = useAuthStore();
  const store = useMembershipPreferenceStore();
  const value = ref(options.defaultValue) as Ref<T>;
  const lastPersistedValue = ref(clonePreferenceValue(options.defaultValue)) as Ref<T>;
  const isHydrated = ref(false);
  const error = ref<string | null>(null);
  const equals = options.equals ?? valuesEqual;
  const debounceMs = options.debounceMs ?? 500;
  const loading = computed(() => store.loading);

  let isSaving = false;
  let suppressHydrate = false;
  let pendingSave = false;
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  const applyValue = (next: T, updatePersistedSnapshot: boolean) => {
    value.value = clonePreferenceValue(next);
    if (updatePersistedSnapshot) {
      lastPersistedValue.value = clonePreferenceValue(next);
    }
  };

  const hydrateFromStore = () => {
    if (suppressHydrate) {
      return;
    }
    if (!authStore.membershipId || store.loadedMembershipId !== authStore.membershipId) {
      isHydrated.value = false;
      return;
    }

    const rawVal = getPreferencePath(store.preference, options.path);
    if (rawVal !== undefined && rawVal !== null) {
      applyValue(rawVal as T, true);
    } else {
      applyValue(options.defaultValue, true);
    }
    isHydrated.value = true;
    error.value = null;
  };

  const ensureStoreReady = async () => {
    const membershipId = authStore.membershipId;
    if (!membershipId) {
      return false;
    }
    if (store.loadedMembershipId !== membershipId) {
      const result = await store.ensureLoaded(
        membershipId,
        authStore.user?.email ?? null,
        authStore.tenantId,
      );
      if (!result.success) {
        error.value = result.error ?? 'Failed to load membership preferences.';
        return false;
      }
    }
    return store.loadedMembershipId === membershipId;
  };

  const persistNow = async () => {
    const membershipId = authStore.membershipId;
    if (!membershipId || !isHydrated.value) {
      return { success: false as const, error: 'Preferences are not ready to save.' };
    }

    if (equals(value.value, lastPersistedValue.value)) {
      return { success: true as const };
    }

    if (isSaving) {
      pendingSave = true;
      return { success: false as const, error: 'Save already in progress.' };
    }

    isSaving = true;
    suppressHydrate = true;
    error.value = null;

    try {
      store.patchPreferencePath(membershipId, options.path, clonePreferenceValue(value.value));
      const result = await store.savePreference(membershipId);
      if (!result.success) {
        error.value = result.error ?? 'Failed to save membership preferences.';
        return { success: false as const, error: error.value };
      }
      lastPersistedValue.value = clonePreferenceValue(value.value);
      return { success: true as const };
    } finally {
      isSaving = false;
      suppressHydrate = false;
      if (pendingSave) {
        pendingSave = false;
        if (!equals(value.value, lastPersistedValue.value)) {
          void persistNow();
        }
      }
    }
  };

  const schedulePersist = () => {
    if (!isHydrated.value) {
      return;
    }
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
    timeoutId = setTimeout(() => {
      timeoutId = null;
      void persistNow();
    }, debounceMs);
  };

  const init = async () => {
    isHydrated.value = false;
    const ready = await ensureStoreReady();
    if (ready) {
      hydrateFromStore();
    }
  };

  onMounted(() => {
    void init();
  });

  watch(
    () => authStore.membershipId,
    () => {
      void init();
    },
  );

  watch(
    () => store.loadedMembershipId,
    () => {
      if (!suppressHydrate) {
        hydrateFromStore();
      }
    },
  );

  watch(
    () => store.preference,
    () => {
      if (!suppressHydrate && isHydrated.value) {
        hydrateFromStore();
      }
    },
    { deep: true },
  );

  watch(
    value,
    () => {
      schedulePersist();
    },
    { deep: true },
  );

  return {
    value,
    loading,
    error,
    isHydrated,
    persistNow,
  };
}
