import { supabase } from 'src/boot/supabase';
import type {
  PpPeopleGroup,
  PpPeopleGroupMember,
  PpPeopleGroupType,
  PpPeopleMemberRole,
} from '../types/ppPeople';

function asJsonArray(data: unknown): unknown[] {
  if (Array.isArray(data)) return data;
  if (typeof data === 'string') {
    try {
      const parsed: unknown = JSON.parse(data);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

function parseGroups(data: unknown): PpPeopleGroup[] {
  const rows = asJsonArray(data);
  return rows.filter(
    (row): row is PpPeopleGroup =>
      row != null
      && typeof row === 'object'
      && typeof (row as PpPeopleGroup).id === 'number'
      && typeof (row as PpPeopleGroup).name === 'string',
  );
}

function parseGroup(data: unknown): PpPeopleGroup {
  if (data == null || typeof data !== 'object') {
    throw new Error('Invalid group response.');
  }
  const row = data as PpPeopleGroup;
  if (typeof row.id !== 'number' || typeof row.name !== 'string') {
    throw new Error('Invalid group response.');
  }
  return row;
}

function parseMembers(data: unknown): PpPeopleGroupMember[] {
  const rows = asJsonArray(data);
  return rows.filter(
    (row): row is PpPeopleGroupMember =>
      row != null
      && typeof row === 'object'
      && typeof (row as PpPeopleGroupMember).id === 'number'
      && typeof (row as PpPeopleGroupMember).email === 'string',
  );
}

function parseMember(data: unknown): PpPeopleGroupMember {
  if (data == null || typeof data !== 'object') {
    throw new Error('Invalid member response.');
  }
  const row = data as PpPeopleGroupMember;
  if (typeof row.id !== 'number' || typeof row.email !== 'string') {
    throw new Error('Invalid member response.');
  }
  return row;
}

const listGroups = async (tenantId: number, type: PpPeopleGroupType): Promise<PpPeopleGroup[]> => {
  const { data, error } = await supabase.rpc('list_pp_people_groups', {
    p_tenant_id: tenantId,
    p_type: type,
  });
  if (error) throw error;
  return parseGroups(data);
};

const createGroup = async (
  tenantId: number,
  name: string,
  type: PpPeopleGroupType,
): Promise<PpPeopleGroup> => {
  const { data, error } = await supabase.rpc('create_pp_people_group', {
    p_tenant_id: tenantId,
    p_name: name,
    p_type: type,
  });
  if (error) throw error;
  return parseGroup(data);
};

const listMembers = async (
  tenantId: number,
  peopleGroupId: number,
): Promise<PpPeopleGroupMember[]> => {
  const { data, error } = await supabase.rpc('list_pp_people_group_members', {
    p_tenant_id: tenantId,
    p_people_group_id: peopleGroupId,
  });
  if (error) throw error;
  return parseMembers(data);
};

const createMember = async (params: {
  tenantId: number;
  peopleGroupId: number;
  name: string;
  email: string;
  role: PpPeopleMemberRole;
}): Promise<PpPeopleGroupMember> => {
  const { data, error } = await supabase.rpc('create_pp_people_group_member', {
    p_tenant_id: params.tenantId,
    p_people_group_id: params.peopleGroupId,
    p_name: params.name,
    p_email: params.email,
    p_role: params.role,
  });
  if (error) throw error;
  return parseMember(data);
};

export const ppPeopleRepository = {
  listGroups,
  createGroup,
  listMembers,
  createMember,
};