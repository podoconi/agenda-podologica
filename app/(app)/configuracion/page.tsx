import { Settings } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function ConfiguracionPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Configuración</h1>
        <p className="text-muted-foreground">
          Ajustes de organización, tipos de atención y aranceles.
        </p>
      </div>
      <Card>
        <CardHeader className="flex flex-row items-center gap-3">
          <Settings className="size-5 text-primary" aria-hidden="true" />
          <CardTitle>Ajustes generales</CardTitle>
          <Badge variant="secondary" className="ml-auto">
            Pendiente implementación Fase 1
          </Badge>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Aquí se mostrarán los ajustes de organización,
            profesionales, tipos de atención y valores de arancel.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
