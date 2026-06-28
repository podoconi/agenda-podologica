-- ============================================================================
-- Migration 01: Extensions and Helpers
-- Source: SUPABASE_SQL_PHASE1_BLUEPRINT_v1.2 § Migracion 01
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Generic trigger function for auto-updating actualizado_en
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.actualizado_en = now();
  RETURN NEW;
END;
$$;
