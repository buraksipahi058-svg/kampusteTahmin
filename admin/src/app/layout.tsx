import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Toaster } from "sonner";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin", "latin-ext"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin", "latin-ext"],
});

export const metadata: Metadata = {
  title: "KampüsBet Yönetim",
  description: "KampüsBet admin ve yetkili paneli",
  icons: { icon: "/logo.png" },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="tr" className={`dark ${geistSans.variable} ${geistMono.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col font-sans">
        {children}
        {/* İşlem sonuçları köşede kısa bildirim (4 sn); pencerelerin dışında tek bir tane. */}
        <Toaster theme="dark" richColors position="bottom-right" closeButton />
      </body>
    </html>
  );
}
