"use client";

import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { validatePublicEnv } from "@/src/lib/env/client";

type HealthStatus = "checking" | "connected" | "env-error" | "connection-error";

export function SupabaseHealthCheck() {
  const [status, setStatus] = useState<HealthStatus>("checking");
  const [detail, setDetail] = useState("");

  useEffect(() => {
    async function check() {
      const env = validatePublicEnv();
      if (!env.valid) {
        setStatus("env-error");
        setDetail(`Variables faltantes: ${env.missing.join(", ")}`);
        return;
      }

      try {
        const { getSupabaseClient } = await import(
          "@/src/lib/supabase/client"
        );
        const supabase = getSupabaseClient();

        const start = performance.now();
        const { error } = await supabase.auth.getSession();
        const elapsed = Math.round(performance.now() - start);

        if (error) {
          setStatus("connection-error");
          setDetail(error.message);
        } else {
          setStatus("connected");
          setDetail(`${elapsed}ms`);
        }
      } catch (err) {
        setStatus("connection-error");
        setDetail(err instanceof Error ? err.message : "Error desconocido");
      }
    }

    check();
  }, []);

  return (
    <div className="flex items-center gap-2 text-sm">
      <span className="text-muted-foreground">Supabase:</span>
      {status === "checking" && (
        <Badge variant="secondary">Verificando...</Badge>
      )}
      {status === "connected" && (
        <Badge className="bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400">
          Conectado ({detail})
        </Badge>
      )}
      {status === "env-error" && (
        <Badge variant="destructive" title={detail}>
          Error de configuración
        </Badge>
      )}
      {status === "connection-error" && (
        <Badge variant="destructive" title={detail}>
          Error de conexión
        </Badge>
      )}
    </div>
  );
}
