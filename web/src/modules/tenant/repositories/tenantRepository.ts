import { supabase } from 'src/boot/supabase'

import type { Tenant } from '../types'

const listTenants = async (): Promise<Tenant[]> => {
  const { data, error } = await supabase.rpc('list_tenants_for_superadmin')

  if (error) {
    throw error
  }

  return (data as Tenant[] | null) ?? []
}

export const tenantRepository = {
  listTenants,
}
