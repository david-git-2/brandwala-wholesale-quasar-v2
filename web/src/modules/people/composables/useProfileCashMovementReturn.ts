import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';

function isSafeReturnPath(path: string, tenantSlug: string | undefined): boolean {
  const p = path.trim();
  if (!p.startsWith('/')) return false;
  if (p.startsWith('//')) return false;
  if (tenantSlug && !p.includes(`/${tenantSlug}/`)) return false;
  return p.includes('/app/');
}

export function useProfileCashMovementReturn(options: {
  entityType: () => string;
  entityId: () => number;
}) {
  const route = useRoute();
  const router = useRouter();

  const tenantSlug = computed(() =>
    typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined,
  );

  const partyNameFromQuery = computed(() => {
    const q = route.query.partyName;
    return typeof q === 'string' ? q.trim() : '';
  });

  const defaultPartyPath = computed(() => {
    const slug = tenantSlug.value;
    const prefix = slug ? `/${slug}` : '';
    return `${prefix}/app/cashbook/${options.entityType()}/${options.entityId()}`;
  });

  const returnPath = computed(() => {
    const raw = route.query.returnTo;
    if (typeof raw === 'string' && isSafeReturnPath(raw, tenantSlug.value)) {
      return raw;
    }
    return defaultPartyPath.value;
  });

  const goBack = () => {
    void router.push(returnPath.value);
  };

  return {
    returnPath,
    goBack,
    partyNameFromQuery,
    defaultPartyPath,
  };
}