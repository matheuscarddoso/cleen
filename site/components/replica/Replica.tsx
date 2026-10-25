"use client";

import { useState } from "react";
import { DemoFrame } from "./DemoFrame";
import { Panel } from "./Panel";
import { ReplicaContext } from "./ReplicaContext";
import { panel } from "./style";
import { tabTitle, type Mode, type TabId } from "./tabs";
import { SearchView } from "./tabs/Search";
import { SettingsView } from "./tabs/Settings";
import { tools } from "./tools";

/**
 * Cleen's open notch, rebuilt for the web: the real layout, the real tabs, playing a
 * scripted demo of the tool it opens on, and fully clickable: the tab bar switches
 * tools, the magnifier opens the search, the gear opens Ajustes.
 */
export function Replica({
  label,
  tab: initialTab = "home",
  mode: initialMode = "tool",
  settings = "appearance",
  tone,
  control,
}: {
  label: string;
  tab?: TabId;
  mode?: Mode;
  /** Which Ajustes section opens when the replica starts in Ajustes. */
  settings?: "appearance" | "displays";
  tone?: "blue" | "dusk" | "teal";
  control?: "sm" | "lg";
}) {
  const [tab, setTab] = useState<TabId>(initialTab);
  const [mode, setMode] = useState<Mode>(initialMode);
  const [size, setSize] = useState<{ width: number; height: number }>({ width: panel.width, height: panel.height });
  const Tool = tools[tab];
  // The launcher grows the panel so a page of results fits, like the app (404 pt there;
  // as tall as the stage allows here).
  const height = mode === "search" ? Math.max(size.height, 356) : size.height;
  const title = mode === "search" ? "Buscar" : mode === "settings" ? "Ajustes" : tabTitle(tab);

  return (
    <DemoFrame label={label} tone={tone} control={control}>
      <ReplicaContext.Provider value={{ tab, setTab, mode, setMode, size, setSize }}>
        <Panel
          title={title}
          mode={mode}
          tab={tab}
          width={size.width}
          height={height}
          onTab={(next) => setTab(next)}
          onSearch={() => setMode("search")}
          onSettings={() => setMode(mode === "settings" ? "tool" : "settings")}
        >
          {mode === "search" ? <SearchView /> : mode === "settings" ? <SettingsView initial={settings} /> : <Tool key={tab} />}
        </Panel>
      </ReplicaContext.Provider>
    </DemoFrame>
  );
}
