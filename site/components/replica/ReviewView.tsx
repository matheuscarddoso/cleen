"use client";

import { useEffect, useRef } from "react";
import { useL } from "@/components/LangProvider";
import { bytes } from "./tabs/overview/disk";
import { consequence, type Review } from "./review";
import { notch } from "./style";

/**
 * DeletionReviewView: what goes (largest first), how much, where it ends up, and
 * Cancelar (Esc) beside Confirmar (Return). It covers the tool, which stays underneath.
 */
export function ReviewView({ review, onClose }: { review: Review; onClose: () => void }) {
  const l = useL();
  const confirm = useRef<HTMLButtonElement>(null);
  const items = [...review.items].sort((a, b) => (b.size ?? 0) - (a.size ?? 0));
  const total = items.reduce((sum, item) => sum + (item.size ?? 0), 0);

  // Return confirms, Esc cancels, as the app's default and cancel actions. Only once the
  // visitor is using the replica: a scripted review must not pull the page's focus.
  useEffect(() => {
    if (navigator.userActivation?.isActive) confirm.current?.focus({ preventScroll: true });
  }, []);

  const cancel = () => {
    review.onCancel?.();
    onClose();
  };

  return (
    <div
      role="alertdialog"
      aria-label={review.title}
      className="flex h-full animate-[numeric_300ms_ease-out] flex-col gap-2.5 pb-3.5 pt-1.5"
      onKeyDown={(event) => {
        if (event.key === "Escape") {
          event.preventDefault();
          cancel();
        }
      }}
    >
      <div className="flex items-baseline gap-3 px-0.5">
        <div className="flex min-w-0 flex-col gap-0.5">
          <span className="text-[15px] font-semibold leading-[18px]">{review.title}</span>
          <span className="text-[11px] leading-[13px]" style={{ color: review.outcome === "trash" ? notch.secondary : notch.warning }}>
            {consequence(review.outcome, l.lang)}
          </span>
        </div>
        <span className="flex-1" />
        {total > 0 && <span className="text-[15px] font-semibold tabular-nums">{bytes(total, l.lang)}</span>}
      </div>
      <div className="min-h-0 flex-1 overflow-hidden">
        <div className="overflow-hidden rounded-[12px]" style={{ background: notch.card, boxShadow: `inset 0 0 0 1px ${notch.cardStroke}` }}>
          {items.map((item, index) => {
            const Icon = item.icon;
            return (
              <div key={item.name}>
                {index > 0 && <div className="ml-[38px] h-px" style={{ background: notch.separator }} />}
                <div className="flex min-h-9 items-center gap-2.5 px-2.5 py-1.5">
                  <span className="flex size-[18px] shrink-0 items-center justify-center" style={{ color: notch.secondary }}>
                    <Icon size={13} strokeWidth={2.1} aria-hidden />
                  </span>
                  <span className="flex min-w-0 flex-col gap-px">
                    <span className="truncate text-[12px] font-medium leading-[14px]">{item.name}</span>
                    {item.detail && (
                      <span className="truncate text-[11px] leading-[13px]" style={{ color: notch.tertiary }}>
                        {item.detail}
                      </span>
                    )}
                  </span>
                  <span className="flex-1" />
                  {item.size !== undefined && (
                    <span className="shrink-0 text-[11px] font-medium tabular-nums" style={{ color: notch.secondary }}>
                      {bytes(item.size, l.lang)}
                    </span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
      <div className="flex justify-end gap-2">
        <button
          type="button"
          onClick={cancel}
          className="flex h-[26px] items-center rounded-full px-3 text-[12px] font-medium transition-[background-color,scale] duration-150 hover:bg-white/16 active:scale-[0.96]"
          style={{ background: notch.control }}
        >
          {l("Cancelar", "Cancel")}
        </button>
        <button
          ref={confirm}
          type="button"
          onClick={() => {
            review.onConfirm();
            onClose();
          }}
          className="flex h-[26px] items-center rounded-full px-3 text-[12px] font-medium text-white transition-[opacity,scale] duration-150 hover:opacity-95 active:scale-[0.96]"
          style={{ background: notch.critical }}
        >
          {l("Confirmar", "Confirm")}
        </button>
      </div>
    </div>
  );
}
