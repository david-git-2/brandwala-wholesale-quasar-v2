import { supabase } from 'src/boot/supabase';
import type {
  GlobalCurrency,
  GlobalCurrencyCreateInput,
  GlobalCurrencyUpdateInput,
  PaymentMethod,
  PaymentMethodCreateInput,
  PaymentMethodUpdateInput,
  UnitOfMeasure,
  UnitOfMeasureCreateInput,
  UnitOfMeasureUpdateInput,
} from '../types';

let cachedCurrencies: GlobalCurrency[] | null = null;

const listCurrencies = async (forceReload = false): Promise<GlobalCurrency[]> => {
  if (!forceReload && cachedCurrencies) {
    return cachedCurrencies;
  }
  const { data, error } = await supabase
    .from('global_currencies')
    .select('*')
    .order('code', { ascending: true });

  if (error) throw error;
  cachedCurrencies = (data as GlobalCurrency[] | null) ?? [];
  return cachedCurrencies;
};

const createCurrency = async (input: GlobalCurrencyCreateInput): Promise<GlobalCurrency> => {
  const { data, error } = await supabase
    .from('global_currencies')
    .insert([
      {
        name: input.name.trim(),
        country: input.country.trim(),
        code: input.code.trim().toUpperCase(),
        symbol: input.symbol.trim(),
        is_active: input.is_active,
      },
    ])
    .select()
    .single();

  if (error) throw error;
  cachedCurrencies = null; // Clear cache on changes
  return data as GlobalCurrency;
};

const updateCurrency = async (input: GlobalCurrencyUpdateInput): Promise<GlobalCurrency> => {
  const { data, error } = await supabase
    .from('global_currencies')
    .update({
      name: input.name.trim(),
      country: input.country.trim(),
      code: input.code.trim().toUpperCase(),
      symbol: input.symbol.trim(),
      is_active: input.is_active,
    })
    .eq('id', input.id)
    .select()
    .single();

  if (error) throw error;
  cachedCurrencies = null; // Clear cache on changes
  return data as GlobalCurrency;
};

const deleteCurrency = async (id: number): Promise<void> => {
  const { error } = await supabase.from('global_currencies').delete().eq('id', id);
  if (error) throw error;
  cachedCurrencies = null; // Clear cache on changes
};

const listPaymentMethods = async (): Promise<PaymentMethod[]> => {
  const { data, error } = await supabase
    .from('payment_methods')
    .select('*')
    .order('sort_order', { ascending: true });

  if (error) throw error;
  return (data as PaymentMethod[] | null) ?? [];
};

const createPaymentMethod = async (input: PaymentMethodCreateInput): Promise<PaymentMethod> => {
  const { data, error } = await supabase
    .from('payment_methods')
    .insert([
      {
        code: input.code.trim().toUpperCase(),
        name: input.name.trim(),
        category: input.category,
        scope: input.scope,
        sort_order: input.sort_order,
        is_active: input.is_active,
        is_system: false,
      },
    ])
    .select()
    .single();

  if (error) throw error;
  return data as PaymentMethod;
};

const updatePaymentMethod = async (input: PaymentMethodUpdateInput): Promise<PaymentMethod> => {
  const { data, error } = await supabase
    .from('payment_methods')
    .update({
      code: input.code.trim().toUpperCase(),
      name: input.name.trim(),
      category: input.category,
      scope: input.scope,
      sort_order: input.sort_order,
      is_active: input.is_active,
    })
    .eq('id', input.id)
    .select()
    .single();

  if (error) throw error;
  return data as PaymentMethod;
};

const deletePaymentMethod = async (id: number): Promise<void> => {
  const { error } = await supabase.from('payment_methods').delete().eq('id', id);
  if (error) throw error;
};

const listUnitsOfMeasure = async (): Promise<UnitOfMeasure[]> => {
  const { data, error } = await supabase
    .from('units_of_measure')
    .select('*')
    .order('sort_order', { ascending: true });

  if (error) throw error;
  return (data as UnitOfMeasure[] | null) ?? [];
};

const createUnitOfMeasure = async (input: UnitOfMeasureCreateInput): Promise<UnitOfMeasure> => {
  const { data, error } = await supabase
    .from('units_of_measure')
    .insert([
      {
        code: input.code.trim().toUpperCase(),
        name: input.name.trim(),
        unit_type: input.unit_type,
        symbol: input.symbol?.trim() || null,
        sort_order: input.sort_order,
        is_active: input.is_active,
        is_system: false,
      },
    ])
    .select()
    .single();

  if (error) throw error;
  return data as UnitOfMeasure;
};

const updateUnitOfMeasure = async (input: UnitOfMeasureUpdateInput): Promise<UnitOfMeasure> => {
  const { data, error } = await supabase
    .from('units_of_measure')
    .update({
      code: input.code.trim().toUpperCase(),
      name: input.name.trim(),
      unit_type: input.unit_type,
      symbol: input.symbol?.trim() || null,
      sort_order: input.sort_order,
      is_active: input.is_active,
    })
    .eq('id', input.id)
    .select()
    .single();

  if (error) throw error;
  return data as UnitOfMeasure;
};

const deleteUnitOfMeasure = async (id: number): Promise<void> => {
  const { error } = await supabase.from('units_of_measure').delete().eq('id', id);
  if (error) throw error;
};

export const globalReferenceRepository = {
  listCurrencies,
  createCurrency,
  updateCurrency,
  deleteCurrency,
  listPaymentMethods,
  createPaymentMethod,
  updatePaymentMethod,
  deletePaymentMethod,
  listUnitsOfMeasure,
  createUnitOfMeasure,
  updateUnitOfMeasure,
  deleteUnitOfMeasure,
};
