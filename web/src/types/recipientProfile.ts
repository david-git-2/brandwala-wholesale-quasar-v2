import type { Database } from 'src/types/supabase'

export type RecipientProfile = Database['public']['Tables']['recipient_profiles']['Row']
export type CreateRecipientProfileInput = Database['public']['Tables']['recipient_profiles']['Insert']
export type UpdateRecipientProfileInput = {
  id: number
  patch: Database['public']['Tables']['recipient_profiles']['Update']
}
