"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { useTranslator } from "@/i18n/client";
import { createClient } from "@/lib/supabase/client";

export function CustomerVisibilityToggle({
  taskId,
  visible,
}: {
  taskId: string;
  visible: boolean;
}) {
  const router = useRouter();
  const t = useTranslator();
  const [busy, setBusy] = useState(false);

  async function handleToggle() {
    setBusy(true);
    const supabase = createClient();
    const { error } = await supabase
      .from("tasks")
      .update({ visible_to_customer: !visible })
      .eq("id", taskId);
    setBusy(false);
    if (error) {
      alert(t("tasks.visibility.updateFailed", { message: error.message }));
      return;
    }
    router.refresh();
  }

  return (
    <label className="flex min-h-11 w-fit cursor-pointer items-center gap-2.5 text-sm font-semibold text-slate-700">
      <input
        type="checkbox"
        checked={visible}
        disabled={busy}
        onChange={handleToggle}
        className="size-4 accent-rose-600"
      />
      {t("tasks.visibility.label")}
    </label>
  );
}
