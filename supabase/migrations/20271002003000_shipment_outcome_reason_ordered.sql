-- Paper qty lives on outcomes as reason `ordered`. Receive splits use general / other reasons.

alter type public.global_shipment_outcome_reason add value if not exists 'ordered';
