import { ClipboardCheck } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function AtencionesPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Atenciones</h1>
        <p className="text-muted-foreground">
          Registro clínico de atenciones podológicas.
        </p>
      </div>
      <Card>
        <CardHeader className="flex flex-row items-center gap-3">
          <ClipboardCheck className="size-5 text-primary" aria-hidden="true" />
          <CardTitle>Historial de atenciones</CardTitle>
          <Badge variant="secondary" className="ml-auto">
            Pendiente implementación Fase 1
          </Badge>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Aquí se mostrará el historial de atenciones clínicas,
            con acceso a detalles y registro de nuevas atenciones.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
