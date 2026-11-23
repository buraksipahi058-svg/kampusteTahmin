import type { Metadata } from "next";
import Image from "next/image";
import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "Giriş · KampüsBet Yönetim" };

export default function LoginPage() {
  return (
    <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center gap-6 px-4 py-16">
      <div className="flex flex-col items-center text-center">
        <Image
          src="/logo.png"
          alt=""
          width={64}
          height={64}
          priority
          className="rounded-2xl shadow-[0_12px_40px_-12px_rgb(139_92_246/0.9)]"
        />
        <h1 className="mt-4 text-2xl font-semibold tracking-tight">KampüsBet Yönetim</h1>
        <p className="mt-1 text-sm text-muted">Yetkililer ve süperadmin içindir. Uygulamadaki hesabınla gir.</p>
      </div>
      <div className="rounded-xl border border-line bg-panel/90 p-5">
        <LoginForm />
      </div>
    </main>
  );
}
