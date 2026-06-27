import { LayoutDashboard } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { SupabaseHealthCheck } from "@/src/components/feedback/supabase-health-check";

export default function HomePage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Inicio</h1>
        <p className="text-muted-foreground">
          Panel operacional del día. Agenda, pendientes y seguimientos.
        </p>
      </div>
      <Card>
        <CardHeader className="flex flex-row items-center gap-3">
          <LayoutDashboard className="size-5 text-primary" aria-hidden="true" />
          <CardTitle>Dashboard</CardTitle>
          <Badge variant="secondary" className="ml-auto">
            Pendiente implementación Fase 1
          </Badge>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Aquí se mostrará la agenda del día, pendientes de acción,
            seguimientos próximos y cobros pendientes.
          </p>
        </CardContent>
      </Card>

      <Card className="border-dashed">
        <CardHeader>
          <CardTitle className="text-sm font-medium text-muted-foreground">
            Estado de infraestructura
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          <div className="flex items-center gap-2 text-sm">
            <span className="text-muted-foreground">Frontend:</span>
            <Badge className="bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400">
              Operativo
            </Badge>
          </div>
          <SupabaseHealthCheck />
        </CardContent>
      </Card>
    </div>
  );
}
