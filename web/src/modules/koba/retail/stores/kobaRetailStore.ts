// Koba Retail Store — backed by list_koba_retail_products RPC
// Response shape: { data: KobaRetailProduct[], meta: { page, total, page_size, total_pages } }
import { defineStore } from 'pinia';
import { supabase } from 'src/boot/supabase';
import { handleApiFailure } from 'src/utils/appFeedback';

// ─── Types ──────────────────────────────────────────────────────────────────

export interface KobaRetailProduct {
  id: string;
  name: string;
  sku: string | null;
  barcode: string | null;
  description: string | null;
  stock_quantity: number;
  in_stock: boolean;
  price_gbp: number;
  regular_price: number | null;
  sale_price: number | null;
  commission_percentage: number | null;
  commission: number | null;
  image_url: string | null;
  brand_id: number | null;
  brand: string | null;
  category_id: number | null;
  category: string | null;
  created_at: string;
  updated_at: string;
}

export interface KobaLookupItem {
  id: number;
  name: string;
}

export interface KobaRetailMeta {
  page: number;
  total: number;
  page_size: number;
  total_pages: number;
}

export interface KobaRetailFilters {
  search: string;
  brand_id: number | null;
  category_id: number | null;
}

export interface KobaRetailState {
  items: KobaRetailProduct[];
  brands: KobaLookupItem[];
  categories: KobaLookupItem[];
  loading: boolean;
  loadingLookups: boolean;
  error: string | null;
  meta: KobaRetailMeta;
  filters: KobaRetailFilters;
}

// Hard-coded tenant — update to pull from authStore if multi-tenant is needed
const KOBA_TENANT_ID = 12;

// ─── Store ───────────────────────────────────────────────────────────────────

export const useKobaRetailStore = defineStore('kobaRetail', {
  state: (): KobaRetailState => ({
    items: [],
    brands: [],
    categories: [],
    loading: false,
    loadingLookups: false,
    error: null,
    meta: {
      page: 1,
      total: 0,
      page_size: 20,
      total_pages: 1,
    },
    filters: {
      search: '',
      brand_id: null,
      category_id: null,
    },
  }),

  actions: {
    // ── Fetch paginated products via RPC ──────────────────────────────────
    async fetchProducts(page: number = 1) {
      this.loading = true;
      this.error = null;

      try {
        const { data: rpcResult, error } = await supabase.rpc('list_koba_retail_products', {
          p_tenant_id: KOBA_TENANT_ID,
          p_page: page,
          p_page_size: this.meta.page_size,
          p_search: this.filters.search || null,
          p_brand_id: this.filters.brand_id,
          p_category_id: this.filters.category_id,
        });

        if (error) {
          this.error = error.message ?? 'Failed to load Koba Retail products.';
          handleApiFailure({ success: false, error: this.error }, this.error);
          return;
        }

        const result = rpcResult as { data: KobaRetailProduct[]; meta: KobaRetailMeta };
        this.items = result.data ?? [];
        this.meta = {
          page: result.meta.page,
          total: result.meta.total,
          page_size: result.meta.page_size,
          total_pages: result.meta.total_pages,
        };
      } finally {
        this.loading = false;
      }
    },

    // ── Fetch brand + category lookups (called once on page mount) ────────
    async fetchLookups() {
      this.loadingLookups = true;
      try {
        const [brandsResult, catsResult] = await Promise.all([
          supabase.rpc('list_koba_brands_for_tenant', { p_tenant_id: KOBA_TENANT_ID }),
          supabase.rpc('list_koba_categories_for_tenant', { p_tenant_id: KOBA_TENANT_ID }),
        ]);

        if (!brandsResult.error) {
          this.brands = (brandsResult.data as KobaLookupItem[]) ?? [];
        }
        if (!catsResult.error) {
          this.categories = (catsResult.data as KobaLookupItem[]) ?? [];
        }
      } finally {
        this.loadingLookups = false;
      }
    },

    // ── Apply a new filter set and reload page 1 ──────────────────────────
    async applyFilters(filters: Partial<KobaRetailFilters>) {
      this.filters = { ...this.filters, ...filters };
      await this.fetchProducts(1);
    },

    // ── Clear all filters ─────────────────────────────────────────────────
    async clearFilters() {
      this.filters = { search: '', brand_id: null, category_id: null };
      await this.fetchProducts(1);
    },
  },
});
