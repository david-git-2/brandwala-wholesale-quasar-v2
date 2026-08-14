import { supabase } from 'src/boot/supabase';
import type { Tag, TagCategory } from '../types';

export const listTagCategories = async (moduleKey?: string): Promise<TagCategory[]> => {
  const { data, error } = await supabase.rpc('list_tag_categories', {
    p_module_key: moduleKey ?? undefined,
  });

  if (error) throw error;
  return (data as TagCategory[] | null) ?? [];
};

export const listTagsForCategory = async (params: {
  categoryId?: number;
  moduleKey?: string;
  code?: string;
}): Promise<Tag[]> => {
  const { data, error } = await supabase.rpc('list_tags_for_category', {
    p_category_id: params.categoryId ?? undefined,
    p_module_key: params.moduleKey ?? undefined,
    p_code: params.code ?? undefined,
  });

  if (error) throw error;
  return (data as Tag[] | null) ?? [];
};

export const getTagBySlug = async (params: {
  categoryId?: number;
  moduleKey?: string;
  code?: string;
  slug: string;
}): Promise<Tag | null> => {
  const { data, error } = await supabase.rpc('get_tag_by_slug', {
    p_category_id: params.categoryId ?? undefined,
    p_module_key: params.moduleKey ?? undefined,
    p_code: params.code ?? undefined,
    p_slug: params.slug,
  });

  if (error) throw error;
  return (data as Tag | null) ?? null;
};

export const tagRepository = {
  listTagCategories,
  listTagsForCategory,
  getTagBySlug,
};
