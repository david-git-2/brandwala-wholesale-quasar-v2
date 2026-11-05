CREATE TABLE public.stock_movement_lines (
  id                bigint                    DEFAULT nextval('public.stock_movement_lines_id_seq'::regclass) NOT NULL,
  movement_id       bigint                    NOT NULL,
  stock_id          bigint,
  from_location_id  bigint,
  to_location_id    bigint,
  from_availability public.stock_availability,
  to_availability   public.stock_availability,
  quantity          numeric                   NOT NULL,
  created_at        timestamp with time zone  DEFAULT now() NOT NULL,
  from_grade_tag_id bigint,
  to_grade_tag_id   bigint
);

CREATE POLICY stock_movement_lines_all ON public.stock_movement_lines
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.stock_movements m
  WHERE ((m.id = stock_movement_lines.movement_id) AND public.has_active_tenant_membership(m.tenant_id)))));

ALTER SEQUENCE public.stock_movement_lines_id_seq OWNED BY public.stock_movement_lines.id;

ALTER TABLE public.stock_movement_lines
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.stock_movement_lines
  ADD CONSTRAINT stock_movement_lines_from_location_id_fkey FOREIGN KEY (from_location_id) REFERENCES public.stock_locations(id) ON DELETE SET NULL;

ALTER TABLE public.stock_movement_lines
  ADD CONSTRAINT stock_movement_lines_pkey PRIMARY KEY (id);

ALTER TABLE public.stock_movement_lines
  ADD CONSTRAINT stock_movement_lines_quantity_check CHECK (quantity > 0::numeric);

ALTER TABLE public.stock_movement_lines
  ADD CONSTRAINT stock_movement_lines_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES public.global_stocks(id) ON DELETE SET NULL;

ALTER TABLE public.stock_movement_lines
  ADD CONSTRAINT stock_movement_lines_to_location_id_fkey FOREIGN KEY (to_location_id) REFERENCES public.stock_locations(id) ON DELETE SET NULL;

ALTER TABLE public.stock_movement_lines
  ADD CONSTRAINT stock_movement_lines_movement_id_fkey FOREIGN KEY (movement_id) REFERENCES public.stock_movements(id) ON DELETE CASCADE;

ALTER TABLE public.stock_movement_lines
  ADD CONSTRAINT stock_movement_lines_from_grade_tag_id_fkey FOREIGN KEY (from_grade_tag_id) REFERENCES public.tags(id);

ALTER TABLE public.stock_movement_lines
  ADD CONSTRAINT stock_movement_lines_to_grade_tag_id_fkey FOREIGN KEY (to_grade_tag_id) REFERENCES public.tags(id);

GRANT ALL ON public.stock_movement_lines TO anon;

GRANT ALL ON public.stock_movement_lines TO authenticated;

GRANT ALL ON public.stock_movement_lines TO service_role;