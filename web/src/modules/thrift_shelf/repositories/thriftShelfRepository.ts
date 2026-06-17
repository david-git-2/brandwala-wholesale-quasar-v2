import { supabase } from 'src/boot/supabase';
import type { ThriftShelf } from '../types';

export const thriftShelfRepository = {
  async fetchShelves(tenantId: number): Promise<ThriftShelf[]> {
    const { data, error } = await supabase
      .from('thrift_shelves')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('shelf_code', { ascending: true });
    if (error) throw error;
    return data as ThriftShelf[];
  },

  async createShelf(shelf: Partial<ThriftShelf>): Promise<ThriftShelf> {
    const { data, error } = await supabase
      .from('thrift_shelves')
      .insert(shelf)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftShelf;
  },
};
