export type EnvValidation = {
  valid: boolean;
  missing: string[];
};

const REQUIRED_PUBLIC_VARS = [
  "NEXT_PUBLIC_SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_ANON_KEY",
] as const;

export function validatePublicEnv(): EnvValidation {
  const missing = REQUIRED_PUBLIC_VARS.filter(
    (key) => !process.env[key]
  );

  return {
    valid: missing.length === 0,
    missing,
  };
}
