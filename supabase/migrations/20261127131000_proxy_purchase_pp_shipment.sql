-- Proxy purchase: shipments

CREATE TABLE IF NOT EXISTS "public"."pp_shipment" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "shipment_code" "text" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "pp_shipment_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "pp_shipment_code_not_blank" CHECK (("length"(TRIM(BOTH FROM "shipment_code")) > 0)),
    CONSTRAINT "pp_shipment_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'in_transit'::"text", 'received'::"text", 'cancelled'::"text"])))
);

ALTER TABLE "public"."pp_shipment" OWNER TO "postgres";

CREATE SEQUENCE IF NOT EXISTS "public"."pp_shipment_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE "public"."pp_shipment_id_seq" OWNER TO "postgres";
ALTER SEQUENCE "public"."pp_shipment_id_seq" OWNED BY "public"."pp_shipment"."id";
ALTER TABLE ONLY "public"."pp_shipment" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pp_shipment_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."pp_shipment"
    ADD CONSTRAINT "pp_shipment_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."pp_shipment"
    ADD CONSTRAINT "pp_shipment_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS "pp_shipment_tenant_code_active_uidx"
    ON "public"."pp_shipment" ("tenant_id", "shipment_code")
    WHERE ("deleted_at" IS NULL);

CREATE INDEX IF NOT EXISTS "pp_shipment_tenant_active_idx"
    ON "public"."pp_shipment" ("tenant_id", "created_at" DESC)
    WHERE ("deleted_at" IS NULL);

CREATE OR REPLACE TRIGGER "trg_pp_shipment_updated_at"
    BEFORE UPDATE ON "public"."pp_shipment"
    FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE FUNCTION "public"."list_pp_shipments"(
    "p_tenant_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'tenant_id', s.tenant_id,
          'name', s.name,
          'shipment_code', s.shipment_code,
          'status', s.status,
          'created_at', s.created_at
        )
        ORDER BY s.created_at DESC, s.id DESC
      ),
      '[]'::jsonb
    )
    FROM public.pp_shipment s
    WHERE s.tenant_id = p_tenant_id
      AND s.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_shipments"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_pp_shipment"(
    "p_tenant_id" bigint,
    "p_name" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_name text := trim(coalesce(p_name, ''));
  v_code text;
  v_row public.pp_shipment%ROWTYPE;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF length(v_name) = 0 THEN
    RAISE EXCEPTION 'Shipment name is required' USING ERRCODE = '22023';
  END IF;

  v_code := public.next_document_number(p_tenant_id, 'proxy_shipment');

  INSERT INTO public.pp_shipment (tenant_id, name, shipment_code, status)
  VALUES (p_tenant_id, v_name, v_code, 'draft')
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'tenant_id', v_row.tenant_id,
    'name', v_row.name,
    'shipment_code', v_row.shipment_code,
    'status', v_row.status,
    'created_at', v_row.created_at
  );
END;
$$;

ALTER FUNCTION "public"."create_pp_shipment"("p_tenant_id" bigint, "p_name" "text") OWNER TO "postgres";

ALTER TABLE "public"."pp_shipment" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pp_shipment_select" ON "public"."pp_shipment"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

GRANT ALL ON TABLE "public"."pp_shipment" TO "anon";
GRANT ALL ON TABLE "public"."pp_shipment" TO "authenticated";
GRANT ALL ON TABLE "public"."pp_shipment" TO "service_role";

GRANT ALL ON SEQUENCE "public"."pp_shipment_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pp_shipment_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pp_shipment_id_seq" TO "service_role";

GRANT ALL ON FUNCTION "public"."list_pp_shipments"("p_tenant_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."list_pp_shipments"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_pp_shipments"("p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."create_pp_shipment"("p_tenant_id" bigint, "p_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_pp_shipment"("p_tenant_id" bigint, "p_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_pp_shipment"("p_tenant_id" bigint, "p_name" "text") TO "service_role";