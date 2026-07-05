import { supabase } from 'src/boot/supabase'
import type { RecipientProfile, CreateRecipientProfileInput, UpdateRecipientProfileInput } from 'src/types/recipientProfile'

export const recipientProfileRepository = {
  async list(tenantId: number): Promise<RecipientProfile[]> {
    const { data, error } = await supabase
      .from('recipient_profiles')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async create(payload: CreateRecipientProfileInput): Promise<RecipientProfile> {
    const { data, error } = await supabase
      .from('recipient_profiles')
      .insert([payload])
      .select('*')
      .single()
    if (error) throw error
    return data
  },

  async update(payload: UpdateRecipientProfileInput): Promise<RecipientProfile> {
    const { data, error } = await supabase
      .from('recipient_profiles')
      .update(payload.patch)
      .eq('id', payload.id)
      .select('*')
      .single()
    if (error) throw error
    return data
  },

  async delete(id: number): Promise<void> {
    const { error } = await supabase
      .from('recipient_profiles')
      .delete()
      .eq('id', id)
    if (error) throw error
  }
}
