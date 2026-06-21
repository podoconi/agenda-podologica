import { Calendar } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function AgendaPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Agenda</h1>
        <p className="text-muted-foreground">
          Gestión de citas y horarios del profesional.
        </p>
      </div>
      <Card>
        <CardHeader className="flex flex-row items-center gap-3">
          <Calendar className="size-5 text-primary" aria-hidden="true" />
          <CardTitle>Calendario de citas</CardTitle>
          <Badge variant="secondary" className="ml-auto">
            Pendiente implementación Fase 1
          </Badge>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Aquí se mostrará la vista de agenda con las citas del día,
            creación de nuevas citas y gestión de horarios.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
