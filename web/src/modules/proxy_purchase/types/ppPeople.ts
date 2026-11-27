export type PpPeopleGroupType = 'customer' | 'supplier';
export type PpPeopleMemberRole = 'admin' | 'staff';

export interface PpPeopleGroup {
  id: number;
  tenant_id: number;
  name: string;
  type: PpPeopleGroupType;
  member_count: number;
  created_at: string;
}

export interface PpPeopleGroupMember {
  id: number;
  people_group_id: number;
  name: string;
  email: string;
  role: PpPeopleMemberRole;
  is_active: boolean;
  created_at: string;
}