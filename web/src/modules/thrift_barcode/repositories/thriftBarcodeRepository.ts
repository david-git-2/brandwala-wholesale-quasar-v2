import { supabase } from 'src/boot/supabase';
import type {
  ThriftBarcode,
  ThriftBarcodeListMeta,
  ThriftBarcodeListParams,
  ThriftBarcodeListResult,
} from '../types';

function parseMeta(raw: Record<string, unknown> | undefined): ThriftBarcodeListMeta {
  return {
    total: Number(raw?.total) || 0,
    page: Number(raw?.page) || 1,
    page_size: Number(raw?.page_size) || 50,
    total_pages: Number(raw?.total_pages) || 0,
    unprinted_total: Number(raw?.unprinted_total) || 0,
    available_total: Number(raw?.available_total) || 0,
    printable_total: Number(raw?.printable_total) || 0,
    latest_current_year_barcode_id:
      typeof raw?.latest_current_year_barcode_id === 'string'
        ? raw.latest_current_year_barcode_id
        : null,
  };
}

export const thriftBarcodeRepository = {
  async fetchBarcodesPaginated(params: ThriftBarcodeListParams): Promise<ThriftBarcodeListResult> {
    const { data, error } = await supabase.rpc('list_thrift_barcodes_paginated', {
      p_tenant_id: params.tenantId,
      p_page: params.page ?? 1,
      p_page_size: params.pageSize ?? 50,
      p_search: params.search?.trim() || null,
      p_is_printed: params.isPrinted ?? null,
      p_status: params.status || null,
    });

    if (error) throw error;

    const payload = data as {
      data: ThriftBarcode[];
      meta: ThriftBarcodeListMeta;
    };

    return {
      data: payload.data || [],
      meta: parseMeta(payload.meta as unknown as Record<string, unknown>),
    };
  },

  async fetchBarcodesByIds(ids: number[]): Promise<ThriftBarcode[]> {
    if (!ids.length) return [];

    const { data, error } = await supabase
      .from('thrift_barcodes')
      .select('*')
      .in('id', ids);

    if (error) throw error;

    return ((data || []) as ThriftBarcode[]).sort((a, b) =>
      a.barcode_id.localeCompare(b.barcode_id),
    );
  },

  async generateBarcodes(params: {
    tenantId: number;
    quantity: number;
    insertedBy: string;
  }): Promise<string[]> {
    const { data, error } = await supabase.rpc('generate_thrift_barcodes', {
      p_tenant_id: params.tenantId,
      p_quantity: params.quantity,
      p_inserted_by: params.insertedBy,
    });

    if (error) throw error;
    return data as string[];
  },

  async markBarcodesPrinted(ids: number[]): Promise<void> {
    if (!ids.length) return;
    const { error } = await supabase
      .from('thrift_barcodes')
      .update({ is_printed: 1 })
      .in('id', ids);

    if (error) throw error;
  },
};
