import type { createClient } from "@/lib/supabase/server";
import type { RewardLimits } from "./labels";

type Client = Awaited<ReturnType<typeof createClient>>;

// Görev ödülü üst sınırı: süperadmin kolon sınırları (1000 SP / 500 XP), yetkili ekonomi ayarındaki tavan.
// Veritabanı (save_campus_task) aynısını denetler; burası yalnızca formdaki sınır.
export async function rewardLimits(supabase: Client, isSuper: boolean): Promise<RewardLimits> {
  if (isSuper) return { sp: 1000, xp: 500 };
  const { data } = await supabase
    .from("economy_settings")
    .select("campus_task_staff_max_reward, campus_task_staff_max_xp")
    .maybeSingle();
  return { sp: data?.campus_task_staff_max_reward ?? 100, xp: data?.campus_task_staff_max_xp ?? 50 };
}
