import type { Metadata } from "next";

import { LanguageSwitch } from "@/components/language-switch";
import { I18nProvider } from "@/i18n/client";
import { getLocale } from "@/i18n/server";
import { createTranslator } from "@/i18n/translate";

import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const t = createTranslator(await getLocale());
  return {
    title: {
      default: "Ventline",
      template: "%s · Ventline",
    },
    description: t("app.tagline"),
  };
}

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const locale = await getLocale();

  return (
    <html lang={locale}>
      <body className="min-h-dvh antialiased">
        <I18nProvider locale={locale}>
          {children}
          <footer>
            <LanguageSwitch />
          </footer>
        </I18nProvider>
      </body>
    </html>
  );
}
