"use client";

import { Pin, Search, Settings, X, type LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { notch, panel } from "./style";
import { tabs, type TabId } from "./tabs";

/** NotchShape: flat top, concave shoulders into the menu bar, rounded bottom corners. */
function shapePath(width: number, height: number) {
  const top = panel.topRadius;
  const bottom = panel.bottomRadius;
  return [
    "M0 0",
    `Q${top} 0 ${top} ${top}`,
    `L${top} ${height - bottom}`,
    `Q${top} ${height} ${top + bottom} ${height}`,
    `L${width - top - bottom} ${height}`,
    `Q${width - top} ${height} ${width - top} ${height - bottom}`,
    `L${width - top} ${top}`,
    `Q${width - top} 0 ${width} 0`,
    "Z",
  ].join(" ");
}

/** A small grey glyph button for the header (NotchIconButton: 26 × 24, 12 pt glyph). */
export function HeaderButton({ icon: Icon, label, active = false, onClick }: { icon: LucideIcon; label: string; active?: boolean; onClick?: () => void }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onClick}
      className={`flex h-6 w-[26px] items-center justify-center rounded-[7px] transition-colors duration-150 hover:bg-white/10 hover:text-white ${active ? "text-white" : "text-white/55"}`}
    >
      <Icon size={13} strokeWidth={2.1} aria-hidden />
    </button>
  );
}

/**
 * The open notch, as NotchOpenContent lays it out: the header in the strip beside the
 * camera, the tool below, and the tab bar at the bottom. In search or Ajustes the tool
 * area takes the tab bar's room, like the app.
 */
export function Panel({
  title,
  mode,
  tab,
  onTab,
  onSearch,
  onSettings,
  width = panel.width,
  height = panel.height,
  children,
}: {
  title: string;
  mode: "tool" | "search" | "settings";
  tab: TabId;
  onTab: (tab: TabId) => void;
  onSearch: () => void;
  onSettings: () => void;
  width?: number;
  height?: number;
  children: ReactNode;
}) {
  const body = width - panel.topRadius * 2;
  return (
    <div
      className="relative text-white transition-[width,height] duration-500"
      style={{ width, height, transitionTimingFunction: "cubic-bezier(0.32, 0.72, 0, 1)" }}
    >
      <svg aria-hidden className="absolute inset-0 overflow-visible drop-shadow-[0_18px_34px_rgba(0,0,0,0.55)]" width={width} height={height}>
        <path d={shapePath(width, height)} fill="#000" />
      </svg>
      <div className="absolute bottom-0 top-0 flex flex-col" style={{ left: panel.topRadius, width: body }}>
        <div className="flex shrink-0 items-center gap-1" style={{ height: panel.notchHeight, paddingInline: panel.inset - 2 }}>
          <span className="text-[15px] font-semibold">{title}</span>
          <span className="flex-1" />
          {mode !== "search" && <HeaderButton icon={Search} label="Buscar (⌥ Espaço)" onClick={onSearch} />}
          <HeaderButton icon={Pin} label="Manter aberto" active />
          <HeaderButton icon={mode === "settings" ? X : Settings} label={mode === "settings" ? "Fechar ajustes" : "Ajustes"} active={mode === "settings"} onClick={onSettings} />
        </div>
        <div
          className="relative min-h-0 flex-1 overflow-hidden"
          style={{ paddingInline: panel.inset, paddingTop: mode === "tool" ? 6 : 4, paddingBottom: mode === "tool" ? 0 : mode === "search" ? 12 : 10 }}
        >
          {children}
        </div>
        {mode === "tool" && (
          <div className="flex shrink-0 justify-center gap-0.5" style={{ paddingTop: 6, paddingBottom: 10 }} role="tablist" aria-label="Ferramentas">
            {tabs.map(({ id, title: name, icon: Icon }) => {
              const selected = id === tab;
              return (
                <button
                  key={id}
                  type="button"
                  role="tab"
                  aria-selected={selected}
                  aria-label={name}
                  title={name}
                  onClick={() => onTab(id)}
                  className="flex h-[26px] w-[30px] items-center justify-center rounded-[7px] transition-colors duration-150 hover:bg-white/10"
                  style={{ background: selected ? notch.selection : undefined, color: selected ? notch.primary : notch.secondary }}
                >
                  <Icon size={14} strokeWidth={2.1} aria-hidden />
                </button>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
