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

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  client = createClient(url, anonKey);

  return client;
}
