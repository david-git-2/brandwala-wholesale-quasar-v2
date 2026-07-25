ALTER TABLE public.courier_services ADD COLUMN IF NOT EXISTS tracking_url_template text DEFAULT NULL;

UPDATE public.courier_services
SET tracking_url_template = 'https://steadfast.com.bd/t/{awb}'
WHERE lower(code) = 'steadfast' AND (tracking_url_template IS NULL OR tracking_url_template = '');

UPDATE public.courier_services
SET tracking_url_template = 'https://pathao.com/tracking?consignment_id={awb}'
WHERE lower(code) = 'pathao' AND (tracking_url_template IS NULL OR tracking_url_template = '');

UPDATE public.courier_services
SET tracking_url_template = 'https://redx.com.bd/track-parcel?trackingId={awb}'
WHERE lower(code) = 'redx' AND (tracking_url_template IS NULL OR tracking_url_template = '');
