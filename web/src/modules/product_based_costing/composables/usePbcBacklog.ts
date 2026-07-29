import { ref } from 'vue';
import { supabase } from 'src/boot/supabase';
import { showSuccessNotification, handleApiFailure } from 'src/utils/appFeedback';

export interface BacklogItem {
  id: number;
  tenant_id: number;
  billing_profile_id: number;
  product_id: number;
  open_quantity: number;
  name: string;
  image_url: string | null;
  barcode: string | null;
  product_code: string | null;
  price_gbp: number | null;
  product_weight: number | null;
  package_weight: number | null;
  note: string | null;
}

export function usePbcBacklog() {
  const items = ref<BacklogItem[]>([]);
  const loading = ref(false);
  const saving = ref(false);
  const error = ref<string | null>(null);

  async function fetchBacklogItems(tenantId: number, billingProfileId: number) {
    if (!tenantId || !billingProfileId) {
      items.value = [];
      return;
    }

    loading.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase.rpc('list_pbc_backlog_items', {
        p_tenant_id: tenantId,
        p_billing_profile_id: billingProfileId,
      });

      if (err) {
        throw err;
      }

      items.value = (data as BacklogItem[] | null) ?? [];
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to fetch backlog items';
      error.value = message;
      console.error('Error listing PBC backlog items:', err);
    } finally {
      loading.value = false;
    }
  }

  async function upsertBacklogFromItem(costingItemId: number) {
    if (!costingItemId) return null;

    try {
      const { data, error: err } = await supabase.rpc('upsert_pbc_backlog_from_item', {
        p_costing_item_id: costingItemId,
      });

      if (err) {
        throw err;
      }

      return data as BacklogItem | null;
    } catch (err: unknown) {
      console.error('Error upserting PBC backlog item:', err);
      return null;
    }
  }

  async function consumeBacklogItems(fileId: number, backlogIds: number[]) {
    if (!fileId || !backlogIds.length) return [];

    saving.value = true;
    error.value = null;

    try {
      const { data, error: err } = await supabase.rpc('add_pbc_backlog_to_costing_file', {
        p_file_id: fileId,
        p_backlog_ids: backlogIds,
      });

      if (err) {
        handleApiFailure({ success: false, error: err.message }, 'Failed to add backlog items');
        throw err;
      }

      const addedItemIds = (data as number[] | null) ?? [];
      showSuccessNotification(`Added ${addedItemIds.length} item(s) from backlog.`);
      return addedItemIds;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to consume backlog items';
      error.value = message;
      return [];
    } finally {
      saving.value = false;
    }
  }

  return {
    items,
    loading,
    saving,
    error,
    fetchBacklogItems,
    upsertBacklogFromItem,
    consumeBacklogItems,
  };
}
