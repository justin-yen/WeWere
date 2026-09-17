-- Production public schema captured 2026-09-12. No user data.
-- Environment-specific apply_retro_filter webhook is managed separately.



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."current_user_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
      SELECT id FROM users WHERE auth_id = auth.uid()
  $$;


ALTER FUNCTION "public"."current_user_id"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "photo_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "text" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'attendee'::"text" NOT NULL,
    "has_developed" boolean DEFAULT false,
    "developed_at" timestamp with time zone,
    "joined_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "event_members_role_check" CHECK (("role" = ANY (ARRAY['host'::"text", 'attendee'::"text"])))
);


ALTER TABLE "public"."event_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "host_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "cover_photo_url" "text",
    "start_time" timestamp with time zone NOT NULL,
    "end_time" timestamp with time zone NOT NULL,
    "status" "text" DEFAULT 'live'::"text" NOT NULL,
    "share_code" "text" DEFAULT "encode"("extensions"."gen_random_bytes"(6), 'hex'::"text") NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "location" "text",
    "location_name" "text",
    "location_address" "text",
    "location_lat" double precision,
    "location_lng" double precision,
    "cover_photo_attribution" "text",
    CONSTRAINT "events_status_check" CHECK (("status" = ANY (ARRAY['live'::"text", 'ended'::"text"])))
);


ALTER TABLE "public"."events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."photos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "storage_path" "text" NOT NULL,
    "filtered_storage_path" "text",
    "width" integer,
    "height" integer,
    "filter_applied" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."photos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "photo_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "emoji" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "reactions_emoji_check" CHECK (("emoji" = ANY (ARRAY['heart'::"text", 'fire'::"text", 'sparkles'::"text", 'openMouth'::"text", 'holdingBackTears'::"text"])))
);


ALTER TABLE "public"."reactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_id" "uuid",
    "display_name" "text" DEFAULT ''::"text" NOT NULL,
    "avatar_url" "text",
    "push_token" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "first_name" "text" DEFAULT ''::"text" NOT NULL,
    "last_name" "text" DEFAULT ''::"text" NOT NULL,
    "instagram_handle" "text",
    "phone_number" "text"
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_members"
    ADD CONSTRAINT "event_members_event_id_user_id_key" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."event_members"
    ADD CONSTRAINT "event_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_share_code_key" UNIQUE ("share_code");



ALTER TABLE ONLY "public"."photos"
    ADD CONSTRAINT "photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reactions"
    ADD CONSTRAINT "reactions_photo_id_user_id_emoji_key" UNIQUE ("photo_id", "user_id", "emoji");



ALTER TABLE ONLY "public"."reactions"
    ADD CONSTRAINT "reactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_auth_id_key" UNIQUE ("auth_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_phone_number_key" UNIQUE ("phone_number");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_comments_photo_id" ON "public"."comments" USING "btree" ("photo_id");



CREATE INDEX "idx_event_members_event_id" ON "public"."event_members" USING "btree" ("event_id");



CREATE INDEX "idx_event_members_user_id" ON "public"."event_members" USING "btree" ("user_id");



CREATE INDEX "idx_events_share_code" ON "public"."events" USING "btree" ("share_code");



CREATE INDEX "idx_events_status" ON "public"."events" USING "btree" ("status");



CREATE INDEX "idx_photos_event_id" ON "public"."photos" USING "btree" ("event_id");



CREATE INDEX "idx_reactions_photo_id" ON "public"."reactions" USING "btree" ("photo_id");






ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_photo_id_fkey" FOREIGN KEY ("photo_id") REFERENCES "public"."photos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."event_members"
    ADD CONSTRAINT "event_members_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_members"
    ADD CONSTRAINT "event_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_host_id_fkey" FOREIGN KEY ("host_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."photos"
    ADD CONSTRAINT "photos_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."photos"
    ADD CONSTRAINT "photos_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."reactions"
    ADD CONSTRAINT "reactions_photo_id_fkey" FOREIGN KEY ("photo_id") REFERENCES "public"."photos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reactions"
    ADD CONSTRAINT "reactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_auth_id_fkey" FOREIGN KEY ("auth_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Anyone can read by share_code" ON "public"."events" FOR SELECT USING (true);



CREATE POLICY "Auth users can add comments" ON "public"."comments" FOR INSERT WITH CHECK (true);



CREATE POLICY "Auth users can create" ON "public"."events" FOR INSERT WITH CHECK (("host_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."auth_id" = "auth"."uid"()))));



CREATE POLICY "Auth users can create events" ON "public"."events" FOR INSERT WITH CHECK (("host_id" = "public"."current_user_id"()));



CREATE POLICY "Auth users can join events" ON "public"."event_members" FOR INSERT WITH CHECK (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Host can update" ON "public"."events" FOR UPDATE USING (("host_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."auth_id" = "auth"."uid"()))));



CREATE POLICY "Host can update event" ON "public"."events" FOR UPDATE USING (("host_id" = "public"."current_user_id"()));



CREATE POLICY "Members can add reactions" ON "public"."reactions" FOR INSERT WITH CHECK (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Members can count photos during live event" ON "public"."photos" FOR SELECT USING (("event_id" IN ( SELECT "event_members"."event_id"
   FROM "public"."event_members"
  WHERE ("event_members"."user_id" = "public"."current_user_id"()))));



CREATE POLICY "Members can insert during live event" ON "public"."photos" FOR INSERT WITH CHECK ((("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."auth_id" = "auth"."uid"()))) AND ("event_id" IN ( SELECT "events"."id"
   FROM "public"."events"
  WHERE ("events"."status" = 'live'::"text"))) AND ("event_id" IN ( SELECT "event_members"."event_id"
   FROM "public"."event_members"
  WHERE ("event_members"."user_id" = ( SELECT "users"."id"
           FROM "public"."users"
          WHERE ("users"."auth_id" = "auth"."uid"())))))));



CREATE POLICY "Members can insert photos during live event" ON "public"."photos" FOR INSERT WITH CHECK ((("user_id" = "public"."current_user_id"()) AND ("event_id" IN ( SELECT "events"."id"
   FROM "public"."events"
  WHERE ("events"."status" = 'live'::"text"))) AND ("event_id" IN ( SELECT "event_members"."event_id"
   FROM "public"."event_members"
  WHERE ("event_members"."user_id" = "public"."current_user_id"())))));



CREATE POLICY "Members can react" ON "public"."reactions" FOR INSERT WITH CHECK (("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."auth_id" = "auth"."uid"()))));



CREATE POLICY "Members can read comments" ON "public"."comments" FOR SELECT USING (true);



CREATE POLICY "Members can read event members" ON "public"."event_members" FOR SELECT USING (("event_id" IN ( SELECT "event_members_1"."event_id"
   FROM "public"."event_members" "event_members_1"
  WHERE ("event_members_1"."user_id" = "public"."current_user_id"()))));



CREATE POLICY "Members can read events" ON "public"."events" FOR SELECT USING (("id" IN ( SELECT "event_members"."event_id"
   FROM "public"."event_members"
  WHERE ("event_members"."user_id" = ( SELECT "users"."id"
           FROM "public"."users"
          WHERE ("users"."auth_id" = "auth"."uid"()))))));



CREATE POLICY "Members can update own membership" ON "public"."event_members" FOR UPDATE USING (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Photos visible after develop" ON "public"."photos" FOR SELECT USING (("event_id" IN ( SELECT "event_members"."event_id"
   FROM "public"."event_members"
  WHERE (("event_members"."user_id" = "public"."current_user_id"()) AND ("event_members"."has_developed" = true)))));



CREATE POLICY "Reactions readable by developed members" ON "public"."reactions" FOR SELECT USING (("photo_id" IN ( SELECT "p"."id"
   FROM ("public"."photos" "p"
     JOIN "public"."event_members" "em" ON (("em"."event_id" = "p"."event_id")))
  WHERE (("em"."user_id" = "public"."current_user_id"()) AND ("em"."has_developed" = true)))));



CREATE POLICY "Reactions readable by event members" ON "public"."reactions" FOR SELECT USING (("photo_id" IN ( SELECT "p"."id"
   FROM ("public"."photos" "p"
     JOIN "public"."event_members" "em" ON (("em"."event_id" = "p"."event_id")))
  WHERE (("em"."user_id" = ( SELECT "users"."id"
           FROM "public"."users"
          WHERE ("users"."auth_id" = "auth"."uid"()))) AND ("em"."has_developed" = true)))));



CREATE POLICY "Users can delete own comments" ON "public"."comments" FOR DELETE USING (("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."auth_id" = "auth"."uid"()))));



CREATE POLICY "Users can insert own" ON "public"."users" FOR INSERT WITH CHECK (("auth_id" = "auth"."uid"()));



CREATE POLICY "Users can read co-attendees" ON "public"."users" FOR SELECT USING (("id" IN ( SELECT "em2"."user_id"
   FROM ("public"."event_members" "em1"
     JOIN "public"."event_members" "em2" ON (("em1"."event_id" = "em2"."event_id")))
  WHERE ("em1"."user_id" = "public"."current_user_id"()))));



CREATE POLICY "Users can read own" ON "public"."users" FOR SELECT USING (("auth_id" = "auth"."uid"()));



CREATE POLICY "Users can remove own reactions" ON "public"."reactions" FOR DELETE USING (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Users can update own" ON "public"."users" FOR UPDATE USING (("auth_id" = "auth"."uid"()));



ALTER TABLE "public"."comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."photos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "service_role";



GRANT ALL ON TABLE "public"."comments" TO "anon";
GRANT ALL ON TABLE "public"."comments" TO "authenticated";
GRANT ALL ON TABLE "public"."comments" TO "service_role";



GRANT ALL ON TABLE "public"."event_members" TO "anon";
GRANT ALL ON TABLE "public"."event_members" TO "authenticated";
GRANT ALL ON TABLE "public"."event_members" TO "service_role";



GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";



GRANT ALL ON TABLE "public"."photos" TO "anon";
GRANT ALL ON TABLE "public"."photos" TO "authenticated";
GRANT ALL ON TABLE "public"."photos" TO "service_role";



GRANT ALL ON TABLE "public"."reactions" TO "anon";
GRANT ALL ON TABLE "public"."reactions" TO "authenticated";
GRANT ALL ON TABLE "public"."reactions" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
