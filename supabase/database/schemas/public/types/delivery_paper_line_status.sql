CREATE TYPE public.delivery_paper_line_status AS ENUM (
  'packed',
  'accepted',
  'conditioned',
  'rejected'
);