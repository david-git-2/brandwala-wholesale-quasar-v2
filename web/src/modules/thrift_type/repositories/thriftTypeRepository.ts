import { supabase } from 'src/boot/supabase';
import type { ThriftType } from '../types';

export const thriftTypeRepository = {
  async fetchTypes(tenantId: number): Promise<ThriftType[]> {
    const { data, error } = await supabase
      .from('thrift_types')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });
    if (error) throw error;
    return data as ThriftType[];
  },

  async createType(type: Partial<ThriftType>): Promise<ThriftType> {
    const { data, error } = await supabase
      .from('thrift_types')
      .insert(type)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftType;
  },
};
