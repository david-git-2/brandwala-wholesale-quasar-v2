import { supabase } from 'src/boot/supabase'
import type {
  Market,
  MarketCreateInput,
  MarketDeleteInput,
  MarketUpdateInput,
} from '../types'

const listMarkets = async (): Promise<Market[]> => {
  const { data, error } = await supabase
    .from('markets')
    .select('*')
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  return (data as Market[] | null) ?? []
}

const createMarket = async (market: MarketCreateInput): Promise<Market> => {
  const { data, error } = await supabase
    .from('markets')
    .insert([
      {
        name: market.name.trim(),
        code: market.code.trim().toUpperCase(),
        is_active: market.is_active,
        is_system: market.is_system,
        region: market.region.trim(),
      },
    ])
    .select()

  if (error) {
    throw error
  }

  const createdMarket = Array.isArray(data) ? data[0] : data

  if (!createdMarket) {
    throw new Error('Market was not created.')
  }

  return createdMarket as Market
}

const updateMarket = async (market: MarketUpdateInput): Promise<Market> => {
  const { data, error } = await supabase
    .from('markets')
    .update({
      name: market.name.trim(),
      code: market.code.trim().toUpperCase(),
      is_active: market.is_active,
      is_system: market.is_system,
      region: market.region.trim(),
    })
    .eq('id', market.id)
    .select()

  if (error) {
    throw error
  }

  const updatedMarket = Array.isArray(data) ? data[0] : data

  if (!updatedMarket) {
    throw new Error('Market was not updated.')
  }

  return updatedMarket as Market
}

const deleteMarket = async (market: MarketDeleteInput): Promise<Market> => {
  const { data, error } = await supabase
    .from('markets')
    .delete()
    .eq('id', market.id)
    .select()

  if (error) {
    throw error
  }

  const deletedMarket = Array.isArray(data) ? data[0] : data

  if (!deletedMarket) {
    throw new Error('Market was not deleted.')
  }

  return deletedMarket as Market
}

export const marketRepository = {
  listMarkets,
  createMarket,
  updateMarket,
  deleteMarket,
}
