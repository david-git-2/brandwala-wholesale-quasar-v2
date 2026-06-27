import { supabase } from 'src/boot/supabase';
import type { ThriftCurrency } from '../types';

export const thriftCurrencyRepository = {
  async fetchActiveCurrencies(): Promise<ThriftCurrency[]> {
    const { data, error } = await supabase
      .from('global_currencies')
      .select('*')
      .eq('is_active', true)
      .order('code', { ascending: true });
    if (error) throw error;
    return (data || []) as ThriftCurrency[];
  },
};
