import type { InjectionKey, Ref } from 'vue';

export const PROCUREMENT_DEMAND_TABLE_SCROLL_KEY: InjectionKey<Ref<HTMLElement | null>> = Symbol(
  'procurementDemandTableScroll',
);
