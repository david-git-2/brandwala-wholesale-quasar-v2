import type { PpPeopleGroupType } from '../../types/ppPeople';

export const ppPeopleQueryKeys = {
  all: ['pp-people'] as const,
  groups: (tenantId: number | null, type: PpPeopleGroupType) =>
    [...ppPeopleQueryKeys.all, 'groups', tenantId, type] as const,
  members: (tenantId: number | null, groupId: number | null) =>
    [...ppPeopleQueryKeys.all, 'members', tenantId, groupId] as const,
};