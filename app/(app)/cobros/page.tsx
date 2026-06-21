import { CreditCard } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function CobrosPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Cobros</h1>
        <p className="text-muted-foreground">
          Gestión de cobros y pagos por atenciones realizadas.
        </p>
      </div>
      <Card>
        <CardHeader className="flex flex-row items-center gap-3">
          <CreditCard className="size-5 text-primary" aria-hidden="true" />
          <CardTitle>Registro de cobros</CardTitle>
          <Badge variant="secondary" className="ml-auto">
            Pendiente implementación Fase 1
          </Badge>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Aquí se mostrará el registro de cobros, pagos pendientes
            y completados con montos totales.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
