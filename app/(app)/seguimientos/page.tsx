import { BellRing } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function SeguimientosPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Seguimientos</h1>
        <p className="text-muted-foreground">
          Control de seguimientos y retornos de pacientes.
        </p>
      </div>
      <Card>
        <CardHeader className="flex flex-row items-center gap-3">
          <BellRing className="size-5 text-primary" aria-hidden="true" />
          <CardTitle>Seguimientos pendientes</CardTitle>
          <Badge variant="secondary" className="ml-auto">
            Pendiente implementación Fase 1
          </Badge>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Aquí se mostrarán los seguimientos activos, vencidos
            y próximos con alertas por paciente.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
