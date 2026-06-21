import { Users } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function PacientesPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Pacientes</h1>
        <p className="text-muted-foreground">
          Registro y gestión de fichas de pacientes.
        </p>
      </div>
      <Card>
        <CardHeader className="flex flex-row items-center gap-3">
          <Users className="size-5 text-primary" aria-hidden="true" />
          <CardTitle>Listado de pacientes</CardTitle>
          <Badge variant="secondary" className="ml-auto">
            Pendiente implementación Fase 1
          </Badge>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Aquí se mostrará la lista de pacientes con búsqueda,
            filtros y acceso a fichas individuales.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
