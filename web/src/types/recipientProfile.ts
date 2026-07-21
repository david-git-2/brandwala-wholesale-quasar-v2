import type { Database } from 'src/types/supabase';

type DbRow = Database['public']['Tables']['recipient_profiles']['Row'];

export interface RecipientProfile extends Omit<DbRow, 'addresses'> {
  addresses: any;
}

export type CreateRecipientProfileInput =
  Database['public']['Tables']['recipient_profiles']['Insert'];
export type UpdateRecipientProfileInput = {
  id: number;
  patch: Database['public']['Tables']['recipient_profiles']['Update'];
};
