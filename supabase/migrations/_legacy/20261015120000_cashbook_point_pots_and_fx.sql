-- Cash place × currency pots + frozen FX pair on ledger/pays.
-- Rate list is a form default; posted cash copies the pair onto cashbook_entries.

ALTER TABLE "public"."pays"
  ADD COLUMN IF NOT EXISTS "quote_currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL;

ALTER TABLE "public"."cashbook_entries"
  ADD COLUMN IF NOT EXISTS "cashbook_point_pot_id" bigint,
  ADD COLUMN IF NOT EXISTS "quote_currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
  ADD COLUMN IF NOT EXISTS "rate_date" "date";

CREATE TABLE IF NOT EXISTS "public"."cashbook_point_pots" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "cashbook_point_id" bigint NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "amount" numeric(18,4) DEFAULT 0.0000 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cashbook_point_pots_amount_non_negative" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "cashbook_point_pots_currency_code_trimmed" CHECK (("btrim"("currency_code") <> ''::"text"))
);

ALTER TABLE "public"."cashbook_point_pots" OWNER TO "postgres";

COMMENT ON TABLE "public"."cashbook_point_pots" IS 'On-hand cash at a point in one currency. FX rate is frozen on cashbook_entries, not on this row.';

CREATE TABLE IF NOT EXISTS "public"."books_exchange_rates" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "base_currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "quote_currency_code" "text" NOT NULL,
    "rate" numeric(18,6) NOT NULL,
    "rate_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "source" "text" DEFAULT 'manual'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "books_exchange_rates_rate_positive" CHECK (("rate" > (0)::numeric)),
    CONSTRAINT "books_exchange_rates_codes_trimmed" CHECK ((("btrim"("base_currency_code") <> ''::"text") AND ("btrim"("quote_currency_code") <> ''::"text"))),
    CONSTRAINT "books_exchange_rates_pair_distinct" CHECK (("upper"("base_currency_code") <> "upper"("quote_currency_code")))
);

ALTER TABLE "public"."books_exchange_rates" OWNER TO "postgres";

COMMENT ON TABLE "public"."books_exchange_rates" IS 'Default FX pick: rate = base (BDT) per 1 quote (e.g. GBP). Posted pays copy the pair onto the ledger line.';

ALTER TABLE "public"."cashbook_point_pots" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."cashbook_point_pots_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE "public"."books_exchange_rates" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."books_exchange_rates_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE ONLY "public"."cashbook_point_pots"
    ADD CONSTRAINT "cashbook_point_pots_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."cashbook_point_pots"
    ADD CONSTRAINT "cashbook_point_pots_point_currency_key" UNIQUE ("cashbook_point_id", "currency_code");

ALTER TABLE ONLY "public"."books_exchange_rates"
    ADD CONSTRAINT "books_exchange_rates_pkey" PRIMARY KEY ("id");

CREATE INDEX IF NOT EXISTS "cashbook_entries_pot_lookup_idx"
  ON "public"."cashbook_entries" USING "btree" ("cashbook_point_pot_id", "created_at" DESC)
  WHERE ("cashbook_point_pot_id" IS NOT NULL);

CREATE INDEX IF NOT EXISTS "cashbook_point_pots_parent_tenant_id_idx"
  ON "public"."cashbook_point_pots" USING "btree" ("parent_tenant_id");

CREATE INDEX IF NOT EXISTS "books_exchange_rates_lookup_idx"
  ON "public"."books_exchange_rates" USING "btree" ("parent_tenant_id", "quote_currency_code", "rate_date" DESC);

ALTER TABLE ONLY "public"."cashbook_entries"
    ADD CONSTRAINT "cashbook_entries_cashbook_point_pot_id_fkey"
    FOREIGN KEY ("cashbook_point_pot_id") REFERENCES "public"."cashbook_point_pots"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."cashbook_point_pots"
    ADD CONSTRAINT "cashbook_point_pots_parent_tenant_id_fkey"
    FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."cashbook_point_pots"
    ADD CONSTRAINT "cashbook_point_pots_cashbook_point_id_fkey"
    FOREIGN KEY ("cashbook_point_id") REFERENCES "public"."cashbook_points"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."books_exchange_rates"
    ADD CONSTRAINT "books_exchange_rates_parent_tenant_id_fkey"
    FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE "public"."cashbook_point_pots" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."books_exchange_rates" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cashbook_point_pots_authenticated_policy"
  ON "public"."cashbook_point_pots" TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "books_exchange_rates_authenticated_policy"
  ON "public"."books_exchange_rates" TO "authenticated" USING (true) WITH CHECK (true);

GRANT ALL ON TABLE "public"."cashbook_point_pots" TO "authenticated";
GRANT ALL ON TABLE "public"."cashbook_point_pots" TO "service_role";
GRANT ALL ON TABLE "public"."books_exchange_rates" TO "authenticated";
GRANT ALL ON TABLE "public"."books_exchange_rates" TO "service_role";
GRANT ALL ON SEQUENCE "public"."cashbook_point_pots_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."cashbook_point_pots_id_seq" TO "service_role";
GRANT ALL ON SEQUENCE "public"."books_exchange_rates_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."books_exchange_rates_id_seq" TO "service_role";

INSERT INTO "public"."cashbook_point_pots" ("parent_tenant_id", "cashbook_point_id", "currency_code", "amount")
SELECT "parent_tenant_id", "id", 'BDT', 0.0000
FROM "public"."cashbook_points"
ON CONFLICT ("cashbook_point_id", "currency_code") DO NOTHING;

COMMENT ON TABLE "public"."cashbook_points" IS 'Place for tenant-held cash (till, safe, bank, fintech). No currency on the point; on-hand cash is cashbook_point_pots.';
