import { supabase } from 'src/boot/supabase';
import type { ThriftShipment } from '../types';

export const thriftShipmentRepository = {
  async fetchShipments(tenantId: number): Promise<ThriftShipment[]> {
    const { data, error } = await supabase
      .from('thrift_shipments')
      .select('*')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    return (data || []) as ThriftShipment[];
  },

  async fetchShipmentById(tenantId: number, id: number): Promise<ThriftShipment | null> {
    const { data, error } = await supabase
      .from('thrift_shipments')
      .select('*')
      .eq('tenant_id', tenantId)
      .eq('id', id)
      .maybeSingle();
    if (error) throw error;
    return data as ThriftShipment | null;
  },

  async createShipment(shipment: Partial<ThriftShipment>): Promise<ThriftShipment> {
    const { data, error } = await supabase
      .from('thrift_shipments')
      .insert(shipment)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftShipment;
  },

  async updateShipment(id: number, partial: Partial<ThriftShipment>): Promise<ThriftShipment> {
    const { data, error } = await supabase
      .from('thrift_shipments')
      .update(partial)
      .eq('id', id)
      .select()
      .single();
    if (error) throw error;
    return data as ThriftShipment;
  },

  async deleteShipment(id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_shipments')
      .delete()
      .eq('id', id);
    if (error) throw error;
  },

  async fetchUnitCountsByShipment(tenantId: number): Promise<Map<number, number>> {
    const { data, error } = await supabase
      .from('thrift_stocks')
      .select('shipment_id, quantity')
      .eq('tenant_id', tenantId);
    if (error) throw error;

    const map = new Map<number, number>();
    for (const row of data || []) {
      const shId = row.shipment_id;
      const qty = row.quantity || 0;
      map.set(shId, (map.get(shId) || 0) + qty);
    }
    return map;
  },
};
