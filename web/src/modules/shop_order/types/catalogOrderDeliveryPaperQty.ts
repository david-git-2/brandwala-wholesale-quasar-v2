export type CatalogOrderItemDeliveryPaperQty = {
  delivery_paper_id: number;
  paper_status: string;
  /** Total qty on paper line (all split statuses). */
  quantity: number;
  packed_qty: number;
  accepted_qty: number;
  conditioned_qty: number;
  /** Rejected / return-to-warehouse qty. */
  rejected_qty: number;
};

export type CatalogOrderDeliveryPaperQtyByItem = Record<
  string,
  CatalogOrderItemDeliveryPaperQty[]
>;

/** Units picked on this paper (still packed, or already moved to an outcome split). */
export function catalogOrderDeliveryPaperPackedDisplay(
  entry: Pick<
    CatalogOrderItemDeliveryPaperQty,
    'packed_qty' | 'accepted_qty' | 'conditioned_qty' | 'rejected_qty'
  >,
): number {
  const onTrip =
    entry.accepted_qty + entry.conditioned_qty + entry.rejected_qty;
  return Math.max(entry.packed_qty, onTrip);
}
