"use client";

import { useEffect, useRef, useState } from "react";
import { useL } from "@/components/LangProvider";
import { useDemo, useSteps } from "../DemoContext";
import { useReplica } from "../ReplicaContext";
import { notch, panel } from "../style";
import { ScrollFade } from "./settings/controls";
import {
  appearanceDefaults,
  appearanceScript,
  at,
  displaysDefaults,
  displaysScript,
  sections,
  shownSize,
  sidebar,
  type Appearance,
  type Displays,
  type Section,
  type SectionId,
} from "./settings/model";
import { AboutPage, AgentsPage, AppearancePage, CleaningPage, DisplaysPage, GeneralPage, TabsPage } from "./settings/pages";
import { useGlide } from "./settings/useGlide";

type State = { section: SectionId; appearance: Appearance; displays: Displays };

const appearanceBeats = appearanceScript.map((beat) => beat.ms);
const displaysBeats = displaysScript.map((beat) => beat.ms);

/**
 * Ajustes, as NotchSettingsView lays it out: the sections on the left (150 wide), a
 * hairline, the chosen page on the right with its title and the rows, scrolling with
 * soft edges. It plays Aparência or Telas on its own; the first click, key or scroll
 * hands everything to the visitor, and the panel size really changes the panel.
 */
export function SettingsView({ initial }: { initial: "appearance" | "displays" }) {
  const l = useL();
  const { setSize } = useReplica();
  const { reduced } = useDemo();
  const [step] = useSteps(initial === "appearance" ? appearanceBeats : displaysBeats);
  const appearanceBeat = initial === "appearance" ? at(appearanceScript, appearanceDefaults, step) : { state: appearanceDefaults, scroll: "top" as const };
  const scripted: State = {
    section: initial === "appearance" ? "notch" : "displays",
    appearance: appearanceBeat.state,
    displays: initial === "displays" ? at(displaysScript, displaysDefaults, step).state : displaysDefaults,
  };
  const [own, setOwn] = useState<State | null>(null);
  const state = own ?? scripted;
  const owned = own !== null;

  // The script drags the sliders; the visitor's own drags land where the pointer is.
  const gliding = !owned && !reduced;
  const builtIn = useGlide(state.displays.builtIn, gliding);
  const external = useGlide(state.displays.external, gliding);
  const shown: State = { ...state, displays: { builtIn, external } };
  const take = (patch: Partial<State> = {}) => setOwn({ ...shown, ...patch });

  // The panel follows Largura / Altura, as in the app.
  const size = shownSize(state.appearance.width, state.appearance.height);
  useEffect(() => {
    setSize({ width: size.width, height: size.height });
  }, [setSize, size.width, size.height]);

  // Leaving Ajustes mid-script puts the panel back; a size the visitor chose stays.
  const visitorOwns = useRef(false);
  useEffect(() => {
    visitorOwns.current = owned;
  }, [owned]);
  useEffect(
    () => () => {
      if (!visitorOwns.current) setSize({ width: panel.width, height: panel.height });
    },
    [setSize],
  );

  // The script scrolls the page down to the size rows and back up.
  const page = useRef<HTMLDivElement>(null);
  const scroll = owned ? null : appearanceBeat.scroll;
  useEffect(() => {
    const element = page.current;
    if (!element || scroll === null) return;
    const anchor = element.querySelector<HTMLElement>('[data-anchor="size"]');
    const top = scroll === "size" && anchor ? anchor.offsetTop - 4 : 0;
    element.scrollTo({ top, behavior: reduced ? "auto" : "smooth" });
  }, [reduced, scroll]);

  const sectionsShown = sections(l.lang);
  const section = sectionsShown[state.section];

  return (
    <div className="flex h-full items-stretch tracking-[0.003em]">
      <nav aria-label={l("Seções dos ajustes", "Settings sections")} className="h-full w-[150px] shrink-0">
        <ScrollFade className="h-full">
          <div className="flex flex-col gap-px">
            {sidebar(l.lang).map((group) => (
              <div key={group.title ?? "top"} className="contents">
                {group.title && (
                  <p className="px-2 pb-0.5 pt-1.5 text-[9.5px] font-semibold uppercase leading-[11px] tracking-[0.6px]" style={{ color: notch.tertiary }}>
                    {group.title}
                  </p>
                )}
                {group.sections.map((id) => (
                  <SidebarRow key={id} section={sectionsShown[id]} selected={id === state.section} onSelect={() => take({ section: id })} />
                ))}
              </div>
            ))}
          </div>
        </ScrollFade>
      </nav>
      <div aria-hidden className="mx-3.5 w-px shrink-0" style={{ background: notch.separator }} />
      <ScrollFade key={section.id} className="h-full min-w-0 flex-1" scrollRef={page} onUserScroll={() => {
          if (!owned) take();
        }}>
        <section aria-label={section.title} className="relative flex flex-col gap-2.5 pb-1">
          <header className="-mt-px mb-px flex flex-col gap-[3px]">
            <h3 className="text-[15px] font-semibold leading-[18px] tracking-normal">{section.title}</h3>
            <p className="text-[11px] leading-[13px]" style={{ color: notch.secondary }}>
              {section.subtitle}
            </p>
          </header>
          <Page state={shown} gliding={gliding} onAppearance={(patch) => take({ appearance: { ...state.appearance, ...patch } })} onDisplays={(patch) => take({ displays: { builtIn, external, ...patch } })} />
        </section>
      </ScrollFade>
    </div>
  );
}

/** The chosen page; Aparência and Telas are driven from above so the script can play them. */
function Page({
  state,
  gliding,
  onAppearance,
  onDisplays,
}: {
  state: State;
  gliding: boolean;
  onAppearance: (patch: Partial<Appearance>) => void;
  onDisplays: (patch: Partial<Displays>) => void;
}) {
  switch (state.section) {
    case "general":
      return <GeneralPage />;
    case "displays":
      return <DisplaysPage levels={state.displays} gliding={gliding} onChange={onDisplays} />;
    case "notch":
      return <AppearancePage prefs={state.appearance} onChange={onAppearance} />;
    case "tabs":
      return <TabsPage />;
    case "cleaning":
      return <CleaningPage />;
    case "agents":
      return <AgentsPage />;
    case "about":
      return <AboutPage />;
  }
}

/** SettingsSidebarRow: 24 tall, glyph in a 16 pt column, the chosen one on a grey plate. */
function SidebarRow({ section, selected, onSelect }: { section: Section; selected: boolean; onSelect: () => void }) {
  const Icon = section.icon;
  return (
    <button
      type="button"
      aria-current={selected ? "page" : undefined}
      onClick={onSelect}
      className={`flex h-6 shrink-0 items-center gap-2 rounded-[7px] px-2 text-left text-[12px] font-medium transition-[background-color,color] duration-150 ${selected ? "" : "hover:bg-white/5"}`}
      style={{ background: selected ? notch.selection : undefined, color: selected ? notch.primary : "rgba(255,255,255,0.7)" }}
    >
      <span aria-hidden className="flex w-4 shrink-0 justify-center">
        {Icon === "claude" ? (
          <span
            className="block size-3"
            style={{ background: "currentColor", maskImage: "url(/claude.svg)", WebkitMaskImage: "url(/claude.svg)", maskSize: "contain", maskRepeat: "no-repeat", maskPosition: "center" }}
          />
        ) : (
          <Icon size={13} strokeWidth={1.8} />
        )}
      </span>
      <span className="truncate">{section.title}</span>
    </button>
  );
}
