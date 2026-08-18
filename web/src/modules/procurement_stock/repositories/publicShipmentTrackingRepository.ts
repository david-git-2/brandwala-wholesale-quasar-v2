import { supabase } from 'src/boot/supabase';

export interface PublicProgressTag {
  id: number;
  name: string;
  color: string | null;
  sort_order: number | null;
}

export interface PublicProgressFlow {
  id: number;
  name: string;
  slug: string;
  is_default: boolean;
}

export interface PublicShipmentStatus {
  id: number;
  name: string;
  status: string;
  progress_flow: PublicProgressFlow | null;
  progress_tag: PublicProgressTag | null;
  progress_tags: PublicProgressTag[];
  updated_at: string;
}

export const getShipmentPublicStatus = async (
  token: string,
): Promise<PublicShipmentStatus | null> => {
  const { data, error } = await (supabase as any).rpc('get_shipment_public_status', {
    p_token: token,
  });
  if (error) throw error;
  return (data as PublicShipmentStatus | null) ?? null;
};

export const publicShipmentTrackingRepository = {
  getShipmentPublicStatus,
};
