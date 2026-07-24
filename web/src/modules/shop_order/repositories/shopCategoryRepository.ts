import { supabase } from 'src/boot/supabase';
import type {
  ShopCategory,
  CreateShopCategoryPayload,
  UpdateShopCategoryPayload,
} from '../types';

export const shopCategoryRepository = {
  async listCategories(tenantId: number): Promise<ShopCategory[]> {
    const { data, error } = await supabase
      .from('shop_categories')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('name', { ascending: true });

    if (error) {
      throw error;
    }

    return (data as ShopCategory[]) || [];
  },

  async createCategory(payload: CreateShopCategoryPayload): Promise<ShopCategory> {
    const { data, error } = await supabase
      .from('shop_categories')
      .insert({
        tenant_id: payload.tenant_id,
        name: payload.name.trim(),
        slug: payload.slug.trim().toLowerCase(),
        description: payload.description ? payload.description.trim() : null,
        icon: payload.icon || 'category',
        is_active: payload.is_active ?? true,
      })
      .select()
      .single();

    if (error) {
      throw error;
    }

    return data as ShopCategory;
  },

  async updateCategory(payload: UpdateShopCategoryPayload): Promise<ShopCategory> {
    const { data, error } = await supabase
      .from('shop_categories')
      .update({
        name: payload.name.trim(),
        slug: payload.slug.trim().toLowerCase(),
        description: payload.description ? payload.description.trim() : null,
        icon: payload.icon || 'category',
        is_active: payload.is_active ?? true,
        updated_at: new Date().toISOString(),
      })
      .eq('id', payload.id)
      .eq('tenant_id', payload.tenant_id)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return data as ShopCategory;
  },

  async deleteCategory(id: number, tenantId: number): Promise<void> {
    const { error } = await supabase
      .from('shop_categories')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenantId);

    if (error) {
      throw error;
    }
  },
};
