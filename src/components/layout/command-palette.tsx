"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Calendar,
  ClipboardCheck,
  CreditCard,
  LayoutDashboard,
  Plus,
  Search,
  Settings,
  User,
  Users,
} from "lucide-react";
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from "@/components/ui/command";

const navigationItems = [
  { label: "Inicio", href: "/", icon: LayoutDashboard },
  { label: "Agenda", href: "/agenda", icon: Calendar },
  { label: "Pacientes", href: "/pacientes", icon: Users },
  { label: "Atenciones", href: "/atenciones", icon: ClipboardCheck },
  { label: "Cobros", href: "/cobros", icon: CreditCard },
  { label: "Configuración", href: "/configuracion", icon: Settings },
];

const quickActions = [
  { label: "Nueva cita", icon: Plus },
  { label: "Nuevo paciente", icon: Plus },
  { label: "Registrar cobro", icon: Plus },
];

const recentPatients = [
  { label: "María López González", icon: User },
  { label: "Juan Pérez Soto", icon: User },
  { label: "Ana Martínez Rojas", icon: User },
];

interface CommandPaletteProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function CommandPalette({ open, onOpenChange }: CommandPaletteProps) {
  const router = useRouter();

  const handleSelect = useCallback(
    (href: string) => {
      onOpenChange(false);
      router.push(href);
    },
    [router, onOpenChange]
  );

  return (
    <CommandDialog open={open} onOpenChange={onOpenChange}>
      <CommandInput placeholder="Buscar pacientes, acciones..." />
      <CommandList>
        <CommandEmpty>
          No se encontraron resultados. Intenta con otro término.
        </CommandEmpty>

        <CommandGroup heading="Navegación">
          {navigationItems.map((item) => (
            <CommandItem
              key={item.href}
              onSelect={() => handleSelect(item.href)}
            >
              <item.icon className="mr-2 size-4" aria-hidden="true" />
              <span>{item.label}</span>
            </CommandItem>
          ))}
        </CommandGroup>

        <CommandSeparator />

        <CommandGroup heading="Acciones rápidas">
          {quickActions.map((item) => (
            <CommandItem key={item.label} disabled>
              <item.icon className="mr-2 size-4" aria-hidden="true" />
              <span>{item.label}</span>
              <span className="ml-auto text-xs text-muted-foreground">
                Próximamente
              </span>
            </CommandItem>
          ))}
        </CommandGroup>

        <CommandSeparator />

        <CommandGroup heading="Pacientes recientes">
          {recentPatients.map((item) => (
            <CommandItem key={item.label} disabled>
              <item.icon className="mr-2 size-4" aria-hidden="true" />
              <span>{item.label}</span>
              <span className="ml-auto text-xs text-muted-foreground">
                Mock
              </span>
            </CommandItem>
          ))}
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}

export function useCommandPalette() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        setOpen((prev) => !prev);
      }
    }
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, []);

  return { open, setOpen };
}
