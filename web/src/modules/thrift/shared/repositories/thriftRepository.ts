import { supabase } from 'src/boot/supabase';
import type { ThriftCategory, ThriftType, ThriftBox, ThriftShelf } from '../types';

export const thriftRepository = {
  async fetchCategories(tenantId: number): Promise<ThriftCategory[]> {
    const { data, error } = await supabase
      .from('thrift_categories')
      .select('*')
      .or(`tenant_id.eq.${tenantId},is_global.eq.true`)
      .order('name', { ascending: true });
    if (error) throw error;
    return data as ThriftCategory[];
  },

  async createCategory(category: Partial<ThriftCategory>): Promise<ThriftCategory> {
    const { data, error } = await supabase
      .from('thrift_categories')
      .insert({ ...category, is_global: false })
      .select()
      .single();
    if (error) throw error;
    return data as ThriftCategory;
  },

  async updateCategory(id: number, updates: Partial<ThriftCategory>): Promise<ThriftCategory> {
    const { data, error } = await supabase
      .from('thrift_categories')
      .update(updates)
      .eq('id', id)
      .eq('is_global', false)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftCategory;
  },

  async deleteCategory(id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_categories')
      .delete()
      .eq('id', id)
      .eq('is_global', false);
    if (error) throw error;
  },

  async fetchTypes(tenantId: number): Promise<ThriftType[]> {
    const { data, error } = await supabase
      .from('thrift_types')
      .select('*')
      .or(`tenant_id.eq.${tenantId},is_global.eq.true`)
      .order('name', { ascending: true });
    if (error) throw error;
    return data as ThriftType[];
  },

  async createType(type: Partial<ThriftType>): Promise<ThriftType> {
    const { data, error } = await supabase
      .from('thrift_types')
      .insert({ ...type, is_global: false })
      .select()
      .single();
    if (error) throw error;
    return data as ThriftType;
  },

  async updateType(id: number, updates: Partial<ThriftType>): Promise<ThriftType> {
    const { data, error } = await supabase
      .from('thrift_types')
      .update(updates)
      .eq('id', id)
      .eq('is_global', false)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftType;
  },

  async deleteType(id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_types')
      .delete()
      .eq('id', id)
      .eq('is_global', false);
    if (error) throw error;
  },

  async fetchBoxes(tenantId: number): Promise<ThriftBox[]> {
    const { data, error } = await supabase
      .from('thrift_boxes')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });
    if (error) throw error;
    return data as ThriftBox[];
  },

  async createBox(box: Partial<ThriftBox>): Promise<ThriftBox> {
    const { data, error } = await supabase
      .from('thrift_boxes')
      .insert(box)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftBox;
  },

  async updateBox(id: number, updates: Partial<ThriftBox>): Promise<ThriftBox> {
    const { data, error } = await supabase
      .from('thrift_boxes')
      .update(updates)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftBox;
  },

  async deleteBox(id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_boxes')
      .delete()
      .eq('id', id);
    if (error) throw error;
  },

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

  async updateShelf(id: number, updates: Partial<ThriftShelf>): Promise<ThriftShelf> {
    const { data, error } = await supabase
      .from('thrift_shelves')
      .update(updates)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftShelf;
  },

  async deleteShelf(id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_shelves')
      .delete()
      .eq('id', id);
    if (error) throw error;
  },
};
