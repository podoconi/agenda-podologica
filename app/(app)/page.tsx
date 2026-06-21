import { LayoutDashboard } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

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
    </div>
  );
}
