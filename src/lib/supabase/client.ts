import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { validatePublicEnv } from "@/src/lib/env/client";

let client: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient {
  if (client) return client;

  const env = validatePublicEnv();
  if (!env.valid) {
    throw new Error(
      `Supabase env vars missing: ${env.missing.join(", ")}`
    );
  }

  client = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  return client;
}
