import { getPreferencePath } from 'src/modules/tenant/submodules/membership/utils/preferenceUtils';
import { MEMBERSHIP_UI_PATHS } from 'src/modules/tenant/submodules/membership/types/preferences';
import type { MembershipPreferenceSchema } from 'src/modules/tenant/submodules/membership/types/preferences';

export type AdminWorkspaceTenantRef = {
  id: number;
  slug: string;
};

export const readAdminWorkspaceTenant = (
  preference: MembershipPreferenceSchema | unknown,
): AdminWorkspaceTenantRef | null => {
  const raw = getPreferencePath(
    parsePreference(preference),
    MEMBERSHIP_UI_PATHS.adminWorkspaceTenant,
  );

  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }

  const record = raw as Record<string, unknown>;
  const id = record.id;
  const slug = record.slug;

  if (typeof id !== 'number' || !Number.isFinite(id) || id <= 0) {
    return null;
  }

  if (typeof slug !== 'string' || !slug.trim()) {
    return null;
  }

  return { id, slug: slug.trim() };
};

const parsePreference = (preference: MembershipPreferenceSchema | unknown): MembershipPreferenceSchema => {
  if (!preference || typeof preference !== 'object' || Array.isArray(preference)) {
    return {};
  }
  return preference as MembershipPreferenceSchema;
};