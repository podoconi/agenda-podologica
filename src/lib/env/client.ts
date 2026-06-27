export type EnvValidation = {
  valid: boolean;
  missing: string[];
};

export function validatePublicEnv(): EnvValidation {
  const missing: string[] = [];

  if (!process.env.NEXT_PUBLIC_SUPABASE_URL) {
    missing.push("NEXT_PUBLIC_SUPABASE_URL");
  }
  if (!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    missing.push("NEXT_PUBLIC_SUPABASE_ANON_KEY");
  }

  return {
    valid: missing.length === 0,
    missing,
  };
}
