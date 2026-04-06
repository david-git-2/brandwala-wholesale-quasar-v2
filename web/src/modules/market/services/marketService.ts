import { marketRepository } from '../repositories/marketRepository'
import type {
  Market,
  MarketCreateInput,
  MarketDeleteInput,
  MarketServiceResult,
  MarketUpdateInput,
} from '../types'

const listMarkets = async (): Promise<MarketServiceResult<Market[]>> => {
  try {
    const data = await marketRepository.listMarkets()

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load markets.',
    }
  }
}

const createMarket = async (
  market: MarketCreateInput,
): Promise<MarketServiceResult<Market>> => {
  try {
    const data = await marketRepository.createMarket(market)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create market.',
    }
  }
}

const updateMarket = async (
  market: MarketUpdateInput,
): Promise<MarketServiceResult<Market>> => {
  try {
    const data = await marketRepository.updateMarket(market)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update market.',
    }
  }
}

const deleteMarket = async (
  market: MarketDeleteInput,
): Promise<MarketServiceResult<Market>> => {
  try {
    const data = await marketRepository.deleteMarket(market)

    return {
      success: true,
      data,
    }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete market.',
    }
  }
}

export const marketService = {
  listMarkets,
  createMarket,
  updateMarket,
  deleteMarket,
}
