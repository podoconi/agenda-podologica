"use client";

import { AppSidebar } from "./app-sidebar";
import { AppHeader } from "./app-header";
import { CommandPalette, useCommandPalette } from "./command-palette";
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar";

export function AppShell({ children }: { children: React.ReactNode }) {
  const { open: commandOpen, setOpen: setCommandOpen } = useCommandPalette();

  return (
    <SidebarProvider>
      <a
        href="#main-content"
        className="fixed left-2 top-2 z-50 -translate-y-16 rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-transform focus:translate-y-0"
      >
        Ir al contenido principal
      </a>

      <AppSidebar />

      <SidebarInset>
        <AppHeader onOpenSearch={() => setCommandOpen(true)} />
        <main
          id="main-content"
          className="flex-1 overflow-y-auto px-4 py-6 md:px-6 lg:px-8 lg:py-8"
          tabIndex={-1}
        >
          <div className="mx-auto max-w-7xl">{children}</div>
        </main>
      </SidebarInset>

      <CommandPalette open={commandOpen} onOpenChange={setCommandOpen} />
    </SidebarProvider>
  );
}
