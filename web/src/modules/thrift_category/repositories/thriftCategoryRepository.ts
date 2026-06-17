import { supabase } from 'src/boot/supabase';
import type { ThriftCategory } from '../types';

export const thriftCategoryRepository = {
  async fetchCategories(tenantId: number): Promise<ThriftCategory[]> {
    const { data, error } = await supabase
      .from('thrift_categories')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });
    if (error) throw error;
    return data as ThriftCategory[];
  },

  async createCategory(category: Partial<ThriftCategory>): Promise<ThriftCategory> {
    const { data, error } = await supabase
      .from('thrift_categories')
      .insert(category)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftCategory;
  },
};
