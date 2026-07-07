"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { TaskStatusPill } from "@/components/status-pill";
import {
  allowedTaskStatuses,
  TASK_STATUS_LABELS,
  type AppRole,
  type TaskStatus,
} from "@/lib/status";
import { createClient } from "@/lib/supabase/client";

const SYSTEM_BODY: Partial<Record<TaskStatus, string>> = {
  done: "marked the task as done",
  approved: "approved the task",
};

export function TaskStatusControl({
  taskId,
  projectId,
  status,
  role,
  isAssigned,
}: {
  taskId: string;
  projectId: string;
  status: TaskStatus;
  role: AppRole;
  isAssigned: boolean;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const options = allowedTaskStatuses(role);
  // Workers may only touch tasks assigned to them (DB-enforced too).
  const editable = options.length > 0 && (role !== "worker" || isAssigned);

  async function handleChange(next: TaskStatus) {
    if (next === status) return;
    setBusy(true);
    setError(null);
    const supabase = createClient();

    const { error: updateError } = await supabase
      .from("tasks")
      .update({ status: next })
      .eq("id", taskId);
    if (updateError) {
      setError(updateError.message);
      setBusy(false);
      return;
    }

    const systemBody = SYSTEM_BODY[next];
    if (systemBody) {
      // Thread event, e.g. "marked the task as done" — failures are not fatal.
      await supabase.rpc("send_message", {
        p_project_id: projectId,
        p_task_id: taskId,
        p_kind: "system",
        p_body: systemBody,
      });
    }

    setBusy(false);
    router.refresh();
  }

  if (!editable) {
    return (
      <div className="flex items-center gap-2">
        <TaskStatusPill status={status} />
        {role === "worker" && !isAssigned && (
          <span className="text-xs text-slate-400">
            Assigned workers can update
          </span>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <TaskStatusPill status={status} />
      <select
        aria-label="Task status"
        value={status}
        disabled={busy}
        onChange={(e) => handleChange(e.target.value as TaskStatus)}
        className="min-h-11 rounded-lg border border-slate-300 bg-white px-2.5 py-2 text-sm font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-400/30 disabled:opacity-50"
      >
        {options.map((s) => (
          <option key={s} value={s}>
            {TASK_STATUS_LABELS[s]}
          </option>
        ))}
        {/* Keep the current value selectable even when not settable by this
            role (e.g. a worker viewing an approved task). */}
        {!options.includes(status) && (
          <option value={status} disabled>
            {TASK_STATUS_LABELS[status]}
          </option>
        )}
      </select>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </div>
  );
}
