import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/database.types';

type StockMovementRow = Database['public']['Tables']['stock_movements']['Row'];
type StockMovementLineRow = Database['public']['Tables']['stock_movement_lines']['Row'];
type StockMovementType = Database['public']['Enums']['stock_movement_type'];
type StockAvailability = Database['public']['Enums']['stock_availability'];

export type StockMovement = StockMovementRow & {
  line_count?: number;
};

export interface StockMovementLine extends StockMovementLineRow {
  stock_label?: string | null;
}

export interface StockMovementLineView {
  id: number;
  movement_id: number;
  stock_id: number | null;
  quantity: number;
  from_location_id: number | null;
  to_location_id: number | null;
  from_availability: StockAvailability | null;
  to_availability: StockAvailability | null;
  stock_label: string | null;
  from_location_label: string | null;
  to_location_label: string | null;
}

export interface StockMovementDetail {
  movement: StockMovement;
  lines: StockMovementLineView[];
}

export interface CreateStockMovementLineInput {
  stock_id: number;
  quantity: number;
  from_location_id?: number | null;
  to_location_id?: number | null;
  from_availability?: StockAvailability | null;
  to_availability?: StockAvailability | null;
}

export interface CreateStockMovementInput {
  tenant_id: number;
  movement_type: StockMovementType;
  notes?: string | null;
  created_by_email?: string | null;
  lines: CreateStockMovementLineInput[];
}

export interface PostStockMovementResult {
  movement_id: number;
  is_posted: boolean;
  posted_at?: string;
}

const listMovements = async (
  tenantId: number,
  limit = 50,
  offset = 0,
): Promise<StockMovement[]> => {
  const { data, error } = await supabase.rpc('list_stock_movements', {
    p_tenant_id: tenantId,
    p_limit: limit,
    p_offset: offset,
  });
  if (error) throw error;
  const parsed = data as unknown as { data?: StockMovement[]; total?: number };
  return parsed.data ?? [];
};

const getMovementLines = async (movementId: number): Promise<StockMovementLine[]> => {
  const { data, error } = await supabase
    .from('stock_movement_lines')
    .select('*')
    .eq('movement_id', movementId)
    .order('id', { ascending: true });

  if (error) throw error;
  return (data ?? []) as StockMovementLine[];
};

const getMovementDetail = async (movementId: number): Promise<StockMovementDetail> => {
  const { data: movement, error: movError } = await supabase
    .from('stock_movements')
    .select('*')
    .eq('id', movementId)
    .single();

  if (movError) throw movError;

  const { data: rawLines, error: linesError } = await supabase
    .from('stock_movement_lines')
    .select(`
      *,
      global_stocks (
        id,
        quantity,
        global_shipment_items ( name, product_code )
      )
    `)
    .eq('movement_id', movementId)
    .order('id', { ascending: true });

  if (linesError) throw linesError;

  const linesData = rawLines ?? [];

  const locationIds = new Set<number>();
  for (const line of linesData) {
    if (line.from_location_id) locationIds.add(line.from_location_id);
    if (line.to_location_id) locationIds.add(line.to_location_id);
  }

  const locationMap = new Map<number, string>();
  if (locationIds.size > 0) {
    const { data: locations } = await supabase
      .from('stock_locations')
      .select('id, name, code')
      .in('id', Array.from(locationIds));

    for (const loc of locations ?? []) {
      locationMap.set(loc.id, loc.name || loc.code || `#${loc.id}`);
    }
  }

  const mappedLines: StockMovementLineView[] = linesData.map((line) => {
    const stockRow = line.global_stocks as unknown as {
      id: number;
      quantity: number;
      global_shipment_items: { name: string; product_code: string | null } | null;
    } | null;

    let stockLabel: string | null = null;
    if (stockRow?.global_shipment_items) {
      const gsi = stockRow.global_shipment_items;
      stockLabel = `${gsi.name}${gsi.product_code ? ` (${gsi.product_code})` : ''}`;
    } else if (line.stock_id) {
      stockLabel = `Stock #${line.stock_id}`;
    }

    return {
      id: line.id,
      movement_id: line.movement_id,
      stock_id: line.stock_id,
      quantity: line.quantity,
      from_location_id: line.from_location_id,
      to_location_id: line.to_location_id,
      from_availability: line.from_availability as StockAvailability | null,
      to_availability: line.to_availability as StockAvailability | null,
      stock_label: stockLabel,
      from_location_label: line.from_location_id ? (locationMap.get(line.from_location_id) ?? null) : null,
      to_location_label: line.to_location_id ? (locationMap.get(line.to_location_id) ?? null) : null,
    };
  });

  return {
    movement: movement as StockMovement,
    lines: mappedLines,
  };
};

const createMovement = async (input: CreateStockMovementInput): Promise<StockMovement> => {
  const { data: createData, error: createError } = await supabase.rpc('create_stock_movement', {
    p_tenant_id: input.tenant_id,
    p_movement_type: input.movement_type,
    p_notes: input.notes ?? null,
    p_reference_type: null,
    p_reference_id: null,
  });
  if (createError) throw createError;

  const movement = (createData as unknown as { movement: StockMovement }).movement;

  for (const line of input.lines) {
    const { error: lineError } = await supabase.rpc('add_stock_movement_line', {
      p_movement_id: movement.id,
      p_stock_id: line.stock_id,
      p_quantity: line.quantity,
      p_from_location_id: line.from_location_id ?? null,
      p_to_location_id: line.to_location_id ?? null,
      p_from_availability: line.from_availability ?? null,
      p_to_availability: line.to_availability ?? null,
    });
    if (lineError) throw lineError;
  }

  return movement;
};

const postMovement = async (movementId: number): Promise<PostStockMovementResult> => {
  const { data, error } = await supabase.rpc('post_stock_movement', {
    p_movement_id: movementId,
  });

  if (error) throw error;

  const result = data as unknown as PostStockMovementResult;
  if (result && typeof result === 'object') {
    return result;
  }

  return { movement_id: movementId, is_posted: true };
};

export const stockMovementRepository = {
  listMovements,
  getMovementLines,
  getMovementDetail,
  createMovement,
  postMovement,
};
