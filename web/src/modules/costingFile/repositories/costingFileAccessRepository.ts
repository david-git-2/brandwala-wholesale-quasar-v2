import { supabase } from 'src/boot/supabase'

import type {
  CostingFileViewer,
  CostingFileViewerGrantInput,
  CostingFileViewerRevokeInput,
  TenantViewer,
} from '../types'

const listTenantViewers = async (tenantId: number): Promise<TenantViewer[]> => {
  const { data, error } = await supabase.rpc('list_tenant_viewers', {
    p_tenant_id: tenantId,
  })

  if (error) {
    throw error
  }

  return (data as TenantViewer[] | null) ?? []
}

const listCostingFileViewers = async (costingFileId: number): Promise<CostingFileViewer[]> => {
  const { data, error } = await supabase.rpc('list_costing_file_viewers', {
    p_costing_file_id: costingFileId,
  })

  if (error) {
    throw error
  }

  return (data as CostingFileViewer[] | null) ?? []
}

const grantCostingFileViewer = async (
  payload: CostingFileViewerGrantInput,
): Promise<CostingFileViewer> => {
  const { data, error } = await supabase.rpc('grant_costing_file_viewer', {
    p_costing_file_id: payload.costingFileId,
    p_membership_id: payload.membershipId,
  })

  if (error) {
    throw error
  }

  const granted = Array.isArray(data) ? data[0] : data

  if (!granted) {
    throw new Error('Costing file viewer was not granted.')
  }

  return granted as CostingFileViewer
}

const revokeCostingFileViewer = async (
  payload: CostingFileViewerRevokeInput,
): Promise<Pick<CostingFileViewer, 'costing_file_viewer_id' | 'costing_file_id' | 'membership_id'>> => {
  const { data, error } = await supabase.rpc('revoke_costing_file_viewer', {
    p_costing_file_id: payload.costingFileId,
    p_membership_id: payload.membershipId,
  })

  if (error) {
    throw error
  }

  const revoked = Array.isArray(data) ? data[0] : data

  if (!revoked) {
    throw new Error('Costing file viewer was not removed.')
  }

  return revoked as Pick<CostingFileViewer, 'costing_file_viewer_id' | 'costing_file_id' | 'membership_id'>
}

export const costingFileAccessRepository = {
  listTenantViewers,
  listCostingFileViewers,
  grantCostingFileViewer,
  revokeCostingFileViewer,
}

