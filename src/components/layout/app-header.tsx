"use client";

import { Search, Bell } from "lucide-react";
import { SidebarTrigger } from "@/components/ui/sidebar";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Badge } from "@/components/ui/badge";

interface AppHeaderProps {
  onOpenSearch: () => void;
}

export function AppHeader({ onOpenSearch }: AppHeaderProps) {
  return (
    <header
      className="sticky top-0 z-10 flex h-14 shrink-0 items-center gap-2 border-b border-border bg-background px-4 md:px-6 lg:px-8"
      role="banner"
    >
      <SidebarTrigger className="-ml-1 lg:hidden" aria-label="Abrir menú" />
      <Separator
        orientation="vertical"
        className="mx-2 h-4 lg:hidden"
      />

      <div className="flex-1" />

      <div className="flex items-center gap-1">
        <Button
          variant="ghost"
          size="sm"
          className="hidden gap-2 text-muted-foreground sm:flex"
          onClick={onOpenSearch}
          aria-label="Buscar (Ctrl+K)"
        >
          <Search className="size-4" aria-hidden="true" />
          <span className="text-sm">Buscar...</span>
          <kbd className="pointer-events-none hidden rounded border border-border bg-muted px-1.5 py-0.5 text-[10px] font-medium text-muted-foreground sm:inline-block">
            ⌘K
          </kbd>
        </Button>

        <Button
          variant="ghost"
          size="icon"
          className="sm:hidden"
          onClick={onOpenSearch}
          aria-label="Buscar"
        >
          <Search className="size-5" aria-hidden="true" />
        </Button>

        <Button
          variant="ghost"
          size="icon"
          aria-label="Notificaciones"
          disabled
        >
          <div className="relative">
            <Bell className="size-5" aria-hidden="true" />
            <Badge
              variant="destructive"
              className="absolute -right-1.5 -top-1.5 flex h-4 w-4 items-center justify-center rounded-full p-0 text-[10px]"
              aria-label="3 notificaciones pendientes"
            >
              3
            </Badge>
          </div>
        </Button>
      </div>
    </header>
  );
}
