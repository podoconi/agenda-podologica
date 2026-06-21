"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Calendar,
  Users,
  ClipboardCheck,
  BellRing,
  CreditCard,
  Settings,
  LogOut,
} from "lucide-react";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarSeparator,
} from "@/components/ui/sidebar";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

const navItems = [
  { title: "Inicio", href: "/", icon: LayoutDashboard },
  { title: "Agenda", href: "/agenda", icon: Calendar },
  { title: "Pacientes", href: "/pacientes", icon: Users },
  { title: "Atenciones", href: "/atenciones", icon: ClipboardCheck },
  { title: "Seguimientos", href: "/seguimientos", icon: BellRing },
  { title: "Cobros", href: "/cobros", icon: CreditCard },
];

const settingsItem = {
  title: "Configuración",
  href: "/configuracion",
  icon: Settings,
};

function isActive(pathname: string, href: string): boolean {
  if (href === "/") return pathname === "/";
  return pathname === href || pathname.startsWith(href + "/");
}

export function AppSidebar() {
  const pathname = usePathname();

  return (
    <Sidebar collapsible="icon" className="border-r border-sidebar-border">
      <SidebarHeader className="p-4">
        <Link
          href="/"
          className="flex items-center gap-2 font-semibold text-lg"
        >
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-primary-foreground text-sm font-bold shrink-0">
            P
          </span>
          <span className="truncate group-data-[collapsible=icon]:hidden">
            Podoconi
          </span>
        </Link>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Navegación</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {navItems.map((item) => {
                const active = isActive(pathname, item.href);
                return (
                  <SidebarMenuItem key={item.href}>
                    <SidebarMenuButton
                      render={
                        <Link
                          href={item.href}
                          aria-current={active ? "page" : undefined}
                        />
                      }
                      isActive={active}
                      tooltip={item.title}
                    >
                      <item.icon className="size-5" aria-hidden="true" />
                      <span>{item.title}</span>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                );
              })}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>

        <SidebarSeparator />

        <SidebarGroup>
          <SidebarGroupContent>
            <SidebarMenu>
              <SidebarMenuItem>
                <SidebarMenuButton
                  render={
                    <Link
                      href={settingsItem.href}
                      aria-current={
                        isActive(pathname, settingsItem.href)
                          ? "page"
                          : undefined
                      }
                    />
                  }
                  isActive={isActive(pathname, settingsItem.href)}
                  tooltip={settingsItem.title}
                >
                  <settingsItem.icon className="size-5" aria-hidden="true" />
                  <span>{settingsItem.title}</span>
                </SidebarMenuButton>
              </SidebarMenuItem>
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter>
        <SidebarMenu>
          <SidebarMenuItem>
            <DropdownMenu>
              <DropdownMenuTrigger
                render={
                  <SidebarMenuButton
                    size="lg"
                    className="cursor-pointer"
                    tooltip="Perfil"
                  />
                }
              >
                <Avatar className="size-8 shrink-0">
                  <AvatarFallback className="bg-primary/10 text-primary text-sm font-medium">
                    PP
                  </AvatarFallback>
                </Avatar>
                <div className="flex flex-col text-left text-sm leading-tight group-data-[collapsible=icon]:hidden">
                  <span className="truncate font-medium">Profesional</span>
                  <span className="truncate text-xs text-muted-foreground">
                    profesional@podoconi.cl
                  </span>
                </div>
              </DropdownMenuTrigger>
              <DropdownMenuContent side="top" align="start" className="w-56">
                <DropdownMenuItem disabled>Mi perfil</DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem disabled>
                  <LogOut className="mr-2 size-4" aria-hidden="true" />
                  Cerrar sesión
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  );
}
