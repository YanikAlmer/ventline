"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { Avatar } from "@/components/avatar";
import { NewTaskButton } from "@/components/project/new-task-button";
import { TaskStatusPill } from "@/components/status-pill";
import { useTranslator } from "@/i18n/client";
import { formatDate } from "@/lib/format";
import type { Locale } from "@/i18n/config";
import type { Profile, TaskWithAssignees, WorkPackage } from "@/lib/queries";
import { stepProgress } from "@/lib/queries";
import { TASK_STATUSES, TASK_STATUS_DOT } from "@/lib/status";
import { createClient } from "@/lib/supabase/client";

type Member = Pick<Profile, "id" | "full_name" | "role">;

/**
 * The project board. Work packages are the rows; steps are never peers of
 * their package — they appear only inside it, behind a disclosure, so the
 * board keeps showing the shape of the job rather than a flat list that grows
 * with every checklist item.
 */
export function TaskBoard({
  projectId,
  companyId,
  packages,
  members,
  locale,
  canManage,
}: {
  projectId: string;
  companyId: string;
  packages: WorkPackage[];
  members: Member[];
  locale: Locale;
  canManage: boolean;
}) {
  const t = useTranslator();
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  function toggle(id: string) {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  const grouped = TASK_STATUSES.map((status) => ({
    status,
    packages: packages.filter((pkg) => pkg.status === status),
  })).filter((group) => group.packages.length > 0);

  if (packages.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-500">
        {t("projects.detail.noTasks")}
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {grouped.map(({ status, packages: group }) => (
        <div key={status}>
          <h3 className="mb-2 flex items-center gap-2 text-sm font-bold uppercase tracking-wide text-slate-500">
            {t(`status.task.${status}`)}
            <span className="rounded-full bg-slate-200 px-2 py-0.5 text-xs font-bold text-slate-600">
              {group.length}
            </span>
          </h3>
          <ul className="space-y-2">
            {group.map((pkg) => (
              <li
                key={pkg.id}
                className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm"
              >
                <PackageRow
                  pkg={pkg}
                  projectId={projectId}
                  locale={locale}
                  expanded={expanded.has(pkg.id)}
                  onToggle={() => toggle(pkg.id)}
                />
                {expanded.has(pkg.id) && (
                  <StepList
                    pkg={pkg}
                    projectId={projectId}
                    companyId={companyId}
                    members={members}
                    locale={locale}
                    canManage={canManage}
                  />
                )}
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}

function PackageRow({
  pkg,
  projectId,
  locale,
  expanded,
  onToggle,
}: {
  pkg: WorkPackage;
  projectId: string;
  locale: Locale;
  expanded: boolean;
  onToggle: () => void;
}) {
  const t = useTranslator();
  const progress = stepProgress(pkg);

  return (
    <div className="flex items-center gap-2 px-2 py-1">
      {/* The disclosure is a sibling of the link, not nested inside it:
          a button inside an anchor is invalid and swallows the click. */}
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        aria-label={
          expanded ? t("tasks.steps.collapse") : t("tasks.steps.expand")
        }
        className="flex size-9 shrink-0 items-center justify-center rounded-lg text-slate-400 hover:bg-slate-100 hover:text-slate-700 disabled:opacity-30"
        disabled={progress.total === 0}
      >
        <span
          className={`transition-transform ${expanded ? "rotate-90" : ""}`}
          aria-hidden
        >
          ▶
        </span>
      </button>

      <Link
        href={`/projects/${projectId}/tasks/${pkg.id}`}
        className="flex min-w-0 flex-1 items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-slate-50"
      >
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold text-slate-900">{pkg.title}</p>
          <p className="mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-slate-500">
            {progress.total > 0 && (
              <span className="font-semibold text-slate-600">
                {t("tasks.steps.progress", {
                  done: progress.done,
                  total: progress.total,
                })}
              </span>
            )}
            {pkg.due_date && (
              <span>
                {t("projects.detail.due", {
                  date: formatDueMoment(pkg.due_date, pkg.due_time, locale),
                })}
              </span>
            )}
            {pkg.visible_to_customer && (
              <span className="font-semibold text-rose-600">
                {t("projects.detail.customerVisible")}
              </span>
            )}
          </p>
        </div>
        <div className="flex items-center -space-x-1.5">
          {pkg.task_assignments.slice(0, 3).map((a) => (
            <Avatar
              key={a.profile_id}
              name={a.profiles.full_name}
              seed={a.profiles.id}
              size="sm"
            />
          ))}
        </div>
        <TaskStatusPill status={pkg.status} />
      </Link>
    </div>
  );
}

function StepList({
  pkg,
  projectId,
  companyId,
  members,
  locale,
  canManage,
}: {
  pkg: WorkPackage;
  projectId: string;
  companyId: string;
  members: Member[];
  locale: Locale;
  canManage: boolean;
}) {
  const t = useTranslator();

  return (
    <div className="border-t border-slate-100 bg-slate-50/70 py-2 pl-12 pr-3">
      {pkg.steps.length === 0 ? (
        <p className="px-2 py-1.5 text-xs text-slate-500">
          {t("tasks.steps.none")}
        </p>
      ) : (
        <OrderableSteps
          pkg={pkg}
          projectId={projectId}
          locale={locale}
          canManage={canManage}
        />
      )}
      {canManage && (
        <div className="px-2 pb-1 pt-2">
          <NewTaskButton
            projectId={projectId}
            companyId={companyId}
            members={members}
            parent={{ id: pkg.id, title: pkg.title }}
          />
        </div>
      )}
    </div>
  );
}

/**
 * The step rows themselves, reorderable.
 *
 * Move buttons rather than drag-and-drop. HTML5 drag does not fire on touch at
 * all, and this board is used on a phone in a van as often as at a desk; a
 * pointer-events implementation that works on both is a dependency and a week
 * of edge cases for a list that is rarely longer than six items. Buttons also
 * come with keyboard and screen-reader support for free.
 *
 * The new order is applied locally first and reverted if the server refuses,
 * because the whole point of reordering is seeing the list settle.
 */
function OrderableSteps({
  pkg,
  projectId,
  locale,
  canManage,
}: {
  pkg: WorkPackage;
  projectId: string;
  locale: Locale;
  canManage: boolean;
}) {
  const t = useTranslator();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // The server's order, as a key. Not just the set of ids but their sequence,
  // so that when router.refresh() brings back the order we just saved, the key
  // changes and the optimistic copy drops itself.
  const serverKey = pkg.steps.map((step) => step.id).join(",");

  // Optimistic order, tagged with the server state it was derived from, and
  // compared during render rather than synced in an effect: an effect that
  // calls setState re-renders the whole board a second time on every parent
  // update, and shows the wrong list in the frame between.
  const [optimistic, setOptimistic] =
    useState<{ key: string; steps: TaskWithAssignees[] } | null>(null);
  const order =
    optimistic && optimistic.key === serverKey ? optimistic.steps : pkg.steps;

  async function move(index: number, delta: number) {
    const target = index + delta;
    if (target < 0 || target >= order.length) return;

    const next = [...order];
    [next[index], next[target]] = [next[target], next[index]];
    setOptimistic({ key: serverKey, steps: next });
    setBusy(true);
    setError(null);

    const supabase = createClient();
    const { error: rpcError } = await supabase.rpc("reorder_task_steps", {
      p_parent_id: pkg.id,
      p_ordered_ids: next.map((s) => s.id),
    });
    setBusy(false);

    if (rpcError) {
      // Most likely someone else added a step while this list was open, which
      // the server refuses rather than half-applies. Putting the list back is
      // the honest response — the order on screen was never real.
      setOptimistic(null);
      setError(rpcError.message);
      return;
    }
    router.refresh();
  }

  return (
    <>
      <ul>
        {order.map((step, index) => (
          <li key={step.id} className="flex items-center gap-1">
            {canManage && order.length > 1 && (
              <div className="flex shrink-0 flex-col">
                <button
                  type="button"
                  onClick={() => move(index, -1)}
                  disabled={busy || index === 0}
                  aria-label={t("tasks.steps.moveUp", { title: step.title })}
                  className="px-1 text-[10px] leading-none text-slate-400 hover:text-slate-900 disabled:opacity-25"
                >
                  ▲
                </button>
                <button
                  type="button"
                  onClick={() => move(index, 1)}
                  disabled={busy || index === order.length - 1}
                  aria-label={t("tasks.steps.moveDown", { title: step.title })}
                  className="px-1 text-[10px] leading-none text-slate-400 hover:text-slate-900 disabled:opacity-25"
                >
                  ▼
                </button>
              </div>
            )}
            <div className="min-w-0 flex-1">
              <StepRow step={step} projectId={projectId} locale={locale} />
            </div>
          </li>
        ))}
      </ul>
      {error && <p className="px-2 pt-1 text-xs text-red-700">{error}</p>}
    </>
  );
}

function StepRow({
  step,
  projectId,
  locale,
}: {
  step: TaskWithAssignees;
  projectId: string;
  locale: Locale;
}) {
  const t = useTranslator();

  return (
    <Link
      href={`/projects/${projectId}/tasks/${step.id}`}
      className="flex items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-white"
    >
      <span
        className={`size-2 shrink-0 rounded-full ${TASK_STATUS_DOT[step.status]}`}
        aria-hidden
      />
      <span className="min-w-0 flex-1 truncate text-sm text-slate-800">
        {step.title}
      </span>
      {step.due_date && (
        <span className="shrink-0 text-xs text-slate-500">
          {formatDueMoment(step.due_date, step.due_time, locale)}
        </span>
      )}
      <span className="shrink-0 text-xs font-semibold text-slate-500">
        {t(`status.task.${step.status}`)}
      </span>
      <div className="flex shrink-0 items-center -space-x-1.5">
        {step.task_assignments.slice(0, 2).map((a) => (
          <Avatar
            key={a.profile_id}
            name={a.profiles.full_name}
            seed={a.profiles.id}
            size="sm"
          />
        ))}
      </div>
    </Link>
  );
}

/**
 * "3. Sep" or "3. Sep, 08:00". The time is stored separately from the date
 * (see the migration) and is optional, so it is appended rather than folded
 * into the date format.
 */
export function formatDueMoment(
  dueDate: string | null,
  dueTime: string | null,
  locale: Locale
): string {
  const date = formatDate(dueDate, locale);
  if (!dueTime) return date;
  return `${date}, ${dueTime.slice(0, 5)}`;
}
