import type { Metadata } from "next";
import { Figtree, Atkinson_Hyperlegible } from "next/font/google";
import { Toaster } from "sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";
import "./globals.css";

const figtree = Figtree({
  subsets: ["latin", "latin-ext"],
  variable: "--font-sans",
  display: "swap",
});

const atkinson = Atkinson_Hyperlegible({
  subsets: ["latin", "latin-ext"],
  variable: "--font-clinical",
  weight: ["400", "700"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Podoconi — Agenda Podológica",
  description: "Sistema de gestión para profesionales de podología",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="es"
      className={cn(figtree.variable, atkinson.variable)}
      suppressHydrationWarning
    >
      <body className="min-h-dvh bg-background text-foreground antialiased">
        <TooltipProvider delay={300}>
          {children}
        </TooltipProvider>
        <Toaster
          position="bottom-right"
          toastOptions={{
            className: "font-sans",
          }}
        />
      </body>
    </html>
  );
}
