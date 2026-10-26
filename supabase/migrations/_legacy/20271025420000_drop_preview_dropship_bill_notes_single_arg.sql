-- CREATE OR REPLACE with new parameters added a second overload; one-arg calls became ambiguous.
DROP FUNCTION IF EXISTS "public"."preview_dropship_issued_bill_notes_at_deliver"(bigint);

GRANT ALL ON FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"(bigint, numeric, numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"(bigint, numeric, numeric) TO "service_role";
