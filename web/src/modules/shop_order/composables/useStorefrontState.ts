import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

export function useStorefrontState() {
  const route = useRoute();
  const router = useRouter();

  const search = ref('');
  const brand = ref<string | null>(null);
  const category = ref<string | null>(null);

  const applyRouteQueryParams = () => {
    const qVal = (route.query.q || route.query.search) as string | undefined;
    if (qVal) search.value = String(qVal);
    if (route.query.category) category.value = String(route.query.category);
    if (route.query.brand) brand.value = String(route.query.brand);
  };

  applyRouteQueryParams();

  const syncUrlQuery = () => {
    const query: Record<string, string> = {};
    if (search.value) query.search = search.value;
    if (category.value) query.category = category.value;
    if (brand.value) query.brand = brand.value;
    void router.replace({ query });
  };

  watch(
    () => route.query,
    () => {
      applyRouteQueryParams();
    },
  );

  const activeFilterCount = computed(() => {
    let count = 0;
    if (brand.value) count += 1;
    if (category.value) count += 1;
    return count;
  });

  const hasActiveFilters = computed(() => {
    return Boolean(search.value || brand.value || category.value);
  });

  const itemKey = (item: { product_id: number; global_stock_id?: number | null }) =>
    `${item.product_id}-${item.global_stock_id || ''}`;

  const formatMoney = (amount: unknown, symbol?: string | null) => {
    const n = Number(amount);
    if (!Number.isFinite(n)) return '—';
    const sym = symbol?.trim() || '৳';
    const formatted = n.toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
    return `${sym} ${formatted}`;
  };

  return {
    search,
    brand,
    category,
    activeFilterCount,
    hasActiveFilters,
    syncUrlQuery,
    itemKey,
    formatMoney,
  };
}
