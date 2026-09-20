import { supabase } from 'src/boot/supabase';
import type { BdBank, GlobalCurrency, Market, PaymentMethod, UnitOfMeasure } from '../types';

// Currencies
const listCurrencies = async (): Promise<GlobalCurrency[]> => {
  const { data, error } = await supabase
    .from('global_currencies')
    .select('*')
    .order('code', { ascending: true });

  if (error) throw error;
  return (data as GlobalCurrency[] | null) ?? [];
};

const getCurrencyById = async (id: number): Promise<GlobalCurrency | null> => {
  const { data, error } = await supabase
    .from('global_currencies')
    .select('*')
    .eq('id', id)
    .maybeSingle();

  if (error) throw error;
  return data as GlobalCurrency | null;
};

const getCurrencyByCode = async (code: string): Promise<GlobalCurrency | null> => {
  const { data, error } = await supabase
    .from('global_currencies')
    .select('*')
    .eq('code', code.trim().toUpperCase())
    .maybeSingle();

  if (error) throw error;
  return data as GlobalCurrency | null;
};

// Markets
const listMarkets = async (): Promise<Market[]> => {
  const { data, error } = await supabase
    .from('markets')
    .select('*')
    .order('code', { ascending: true });

  if (error) throw error;
  return (data as Market[] | null) ?? [];
};

const getMarketById = async (id: number): Promise<Market | null> => {
  const { data, error } = await supabase
    .from('markets')
    .select('*')
    .eq('id', id)
    .maybeSingle();

  if (error) throw error;
  return data as Market | null;
};

const getMarketByCode = async (code: string): Promise<Market | null> => {
  const { data, error } = await supabase
    .from('markets')
    .select('*')
    .eq('code', code.trim().toUpperCase())
    .maybeSingle();

  if (error) throw error;
  return data as Market | null;
};

// Payment Methods
const listPaymentMethods = async (): Promise<PaymentMethod[]> => {
  const { data, error } = await supabase.rpc('list_payment_methods');
  if (error) throw error;
  return ((data as PaymentMethod[] | null) ?? []).map((row) => ({
    id: 0,
    code: String(row.code),
    name: String(row.name),
    category: String(row.category),
    scope: String(row.scope),
    sort_order: Number(row.sort_order ?? 0),
    is_active: true,
    is_system: true,
  }));
};

const getPaymentMethodById = async (id: number): Promise<PaymentMethod | null> => {
  const { data, error } = await supabase
    .from('payment_methods')
    .select('*')
    .eq('id', id)
    .maybeSingle();

  if (error) throw error;
  return data as PaymentMethod | null;
};

// Units of Measure
const listUnitsOfMeasure = async (): Promise<UnitOfMeasure[]> => {
  const { data, error } = await supabase
    .from('units_of_measure')
    .select('*')
    .order('sort_order', { ascending: true });

  if (error) throw error;
  return (data as UnitOfMeasure[] | null) ?? [];
};

const getUnitOfMeasureById = async (id: number): Promise<UnitOfMeasure | null> => {
  const { data, error } = await supabase
    .from('units_of_measure')
    .select('*')
    .eq('id', id)
    .maybeSingle();

  if (error) throw error;
  return data as UnitOfMeasure | null;
};

const listBdBanks = async (): Promise<BdBank[]> => {
  const { data, error } = await supabase.rpc('list_bd_banks');
  if (error) throw error;
  return ((data as BdBank[] | null) ?? []).map((row) => ({
    id: Number(row.id),
    code: String(row.code),
    name: String(row.name),
    swift_code: row.swift_code ?? null,
    sort_order: Number(row.sort_order ?? 0),
  }));
};

export const globalReferenceRepository = {
  listCurrencies,
  getCurrencyById,
  getCurrencyByCode,
  listMarkets,
  getMarketById,
  getMarketByCode,
  listPaymentMethods,
  getPaymentMethodById,
  listUnitsOfMeasure,
  getUnitOfMeasureById,
  listBdBanks,
};
