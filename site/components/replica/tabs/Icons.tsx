"use client";

import { Search, SquareArrowOutUpRight } from "lucide-react";
import { useMemo, useRef, useState } from "react";
import { useL } from "@/components/LangProvider";
import { useDemo, useTypewriter } from "../DemoContext";
import { notch } from "../style";
import { ConfirmationPill, FadeScroll, SearchField, copyText, useBeats, useConfirmation } from "./emoji/shared";
import { catalog, componentName, searchIcons, type IconEntry } from "./icons/catalog";
import { ContextMenu, IconCell, copiedLabels, type CopyKind } from "./icons/parts";

/** One moment of the script after a word is typed. */
type Frame = { hover?: number; menu?: boolean; item?: number; pressed?: boolean; copied?: CopyKind };

/** The full grid first, then three searches. */
const queries = ["", "arrow", "calendar", "user"] as const;

/** A beat to read, the pointer across the results, the copy, then the pill. */
const beats = [450, 500, 500, 650, 550, 160, 1500] as const;
const hold = beats.reduce((sum, beat) => sum + beat, 0) + 160;

/** "arrow" and "user" click a cell (the SVG); "calendar" goes through the context menu for JSX. */
const plans: readonly (readonly Frame[])[] = [
  [],
  [{}, { hover: 0 }, { hover: 1 }, { hover: 2 }, { hover: 4 }, { hover: 4, pressed: true }, { hover: 4, copied: "svg" }],
  [{}, { hover: 0 }, { hover: 1 }, { hover: 1, menu: true }, { hover: 1, menu: true, item: 2 }, { hover: 1, menu: true, item: 2 }, { hover: 1, copied: "jsx" }],
  [{}, { hover: 0 }, { hover: 2 }, { hover: 1 }, { hover: 0 }, { hover: 0, pressed: true }, { hover: 0, copied: "svg" }],
];

/** What the previous round left in Recentes. */
const scriptedRecents = ["user", "calendar-check", "arrow-up-right"];

const tab = { width: 612, height: 154, toolbar: 34, columns: 8, gap: 6, cell: 64, menu: { width: 168, height: 124 } } as const;
const cellWidth = (tab.width - tab.gap * (tab.columns - 1)) / tab.columns;

function clampMenu(x: number, y: number) {
  return { x: Math.max(4, Math.min(x, tab.width - tab.menu.width - 4)), y: Math.max(0, Math.min(y, tab.height - tab.menu.height)) };
}

/** Where the script's pointer is on result `index`: the menu opens there. */
function menuAtCell(index: number) {
  const column = index % tab.columns;
  const row = Math.floor(index / tab.columns);
  return clampMenu(column * (cellWidth + tab.gap) + cellWidth * 0.6, tab.toolbar + row * (tab.cell + tab.gap) + tab.cell * 0.55);
}

/** The icon's SVG as lucide.dev serves it, read off the glyph on screen. */
function svgMarkup(root: HTMLElement | null, name: string): string | null {
  const glyph = root?.querySelector(`[data-icon="${name}"] svg`);
  if (!glyph) return null;
  const copy = glyph.cloneNode(true) as SVGElement;
  for (const attribute of ["aria-hidden", "style"]) copy.removeAttribute(attribute);
  copy.setAttribute("width", "24");
  copy.setAttribute("height", "24");
  copy.setAttribute("class", `lucide lucide-${name}`);
  return new XMLSerializer().serializeToString(copy);
}

/**
 * Ícones, as NotchIconsTab lays it out: the outlined search, the count and lucide.dev on
 * top, then the cards (Recentes, then Todos A to Z; the matches alone while searching).
 * A click copies the SVG, the context menu the name, JSX or a Blade/HTML tag, and Return
 * the top match's SVG; the pill confirms it with the icon itself.
 */
export function IconsTab() {
  const { reduced } = useDemo();
  const l = useL();
  const typing = useTypewriter(queries, { speed: 120, hold });
  const [manual, setManual] = useState<{ query: string; recents: string[] } | null>(null);
  const [menu, setMenu] = useState<{ entry: IconEntry; x: number; y: number } | null>(null);
  const [copied, showCopied] = useConfirmation<{ entry: IconEntry; kind: CopyKind }>(1200);
  const root = useRef<HTMLDivElement>(null);

  const index = reduced ? 1 : typing.index;
  const beat = useBeats(!manual && !reduced && typing.finished ? String(typing.index) : null, beats);
  const frame: Frame = manual ? {} : reduced ? { hover: 2 } : (plans[index]?.[beat] ?? {});
  const query = manual ? manual.query : reduced ? queries[1] : typing.text;
  const results = useMemo(() => searchIcons(query), [query]);
  const searching = query.trim().length > 0;
  const recents = (manual ? manual.recents : scriptedRecents).flatMap((name) => catalog.filter((entry) => entry.name === name));
  const scriptedCopy = frame.copied && searching ? results[frame.hover ?? 0] : undefined;
  const pill = manual ? copied : scriptedCopy && frame.copied ? { entry: scriptedCopy, kind: frame.copied } : null;
  const scriptedMenu = frame.menu && searching && frame.hover !== undefined ? results[frame.hover] : undefined;

  const take = () => manual ?? { query, recents: scriptedRecents };
  const copy = (entry: IconEntry, kind: CopyKind) => {
    const state = take();
    setManual({ ...state, recents: [entry.name, ...state.recents.filter((name) => name !== entry.name)].slice(0, 24) });
    setMenu(null);
    showCopied({ entry, kind });
    const text = kind === "svg" ? svgMarkup(root.current, entry.name) : kind === "jsx" ? `<${componentName(entry.name)} />` : kind === "html" ? `<i data-lucide="${entry.name}"></i>` : entry.name;
    if (text) void copyText(text);
  };
  const openMenu = (entry: IconEntry, at: { clientX: number; clientY: number }) => {
    const box = root.current?.getBoundingClientRect();
    const scale = box && root.current ? box.width / root.current.offsetWidth : 1;
    setManual(take());
    setMenu({ entry, ...clampMenu(box ? (at.clientX - box.left) / scale : 0, box ? (at.clientY - box.top) / scale : 0) });
  };

  const count = searching ? results.length : catalog.length;
  const shownCount = count.toLocaleString(l.locale);
  const countLabel = searching
    ? count === 1
      ? l("1 resultado", "1 result")
      : l(`${shownCount} resultados`, `${shownCount} results`)
    : count === 1
      ? l("1 ícone", "1 icon")
      : l(`${shownCount} ícones`, `${shownCount} icons`);
  const cell = (entry: IconEntry, position: number, inResults: boolean, prefix: string) => (
    <IconCell
      key={`${prefix}-${entry.name}`}
      entry={entry}
      suggested={inResults && position === 0}
      hovered={inResults && frame.hover === position}
      pressed={inResults && frame.hover === position && frame.pressed === true}
      onCopy={copy}
      onMenu={openMenu}
    />
  );

  return (
    <div ref={root} className="relative flex h-full flex-col gap-2">
      <div className="flex h-[26px] shrink-0 items-center gap-2">
        <SearchField
          value={query}
          placeholder={l("Buscar ícone", "Search icons")}
          caret={!manual && !reduced}
          onChange={(value) => setManual({ ...take(), query: value })}
          onSubmit={() => {
            const first = results[0];
            if (first) copy(first, "svg");
          }}
        />
        <span className="flex-1" />
        <span className="text-[10.5px] tabular-nums" style={{ color: notch.tertiary }}>
          {countLabel}
        </span>
        <a
          href="https://lucide.dev/icons/"
          target="_blank"
          rel="noopener noreferrer"
          aria-label={l("Abrir lucide.dev", "Open lucide.dev")}
          title={l("Abrir lucide.dev", "Open lucide.dev")}
          className="flex h-6 w-[26px] items-center justify-center rounded-[7px] transition-colors duration-150 hover:bg-white/10 hover:text-white text-white/55"
        >
          <SquareArrowOutUpRight size={13} strokeWidth={2.1} aria-hidden />
        </a>
      </div>
      {searching && results.length === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center gap-[5px]">
          <Search size={18} strokeWidth={1.8} style={{ color: notch.tertiary }} aria-hidden />
          <p className="text-[11.5px]" style={{ color: notch.secondary }}>{l("Nenhum ícone encontrado", "No icons found")}</p>
        </div>
      ) : (
        <FadeScroll key={searching ? "results" : "all"}>
          <div className="grid gap-1.5 pb-1" style={{ gridTemplateColumns: `repeat(auto-fill, minmax(${tab.cell}px, 1fr))` }}>
            {searching ? (
              results.map((entry, position) => cell(entry, position, true, "result"))
            ) : (
              <>
                {recents.length > 0 && <SectionTitle>{l("Recentes", "Recents")}</SectionTitle>}
                {recents.map((entry, position) => cell(entry, position, false, "recent"))}
                <SectionTitle>{l("Todos", "All")}</SectionTitle>
                {catalog.map((entry, position) => cell(entry, position, false, "all"))}
              </>
            )}
          </div>
        </FadeScroll>
      )}
      {(menu || scriptedMenu) && (
        <ContextMenu
          at={menu ?? menuAtCell(frame.hover ?? 0)}
          active={menu ? null : (frame.item ?? null)}
          focusFirst={menu !== null}
          onClose={() => {
            setManual(take());
            setMenu(null);
          }}
          onPick={(kind) => {
            const entry = menu?.entry ?? scriptedMenu;
            if (!entry) return;
            if (kind === "page") {
              setMenu(null);
              window.open(`https://lucide.dev/icons/${entry.name}`, "_blank", "noopener,noreferrer");
            } else {
              copy(entry, kind);
            }
          }}
        />
      )}
      <ConfirmationPill shown={pill !== null} live={manual !== null}>
        {pill && <pill.entry.icon size={15} strokeWidth={2} aria-hidden />}
        {pill ? copiedLabels[l.lang][pill.kind] : ""}
      </ConfirmationPill>
    </div>
  );
}

function SectionTitle({ children }: { children: string }) {
  return (
    <h3 className="col-span-full pt-1 text-[10.5px] font-medium" style={{ color: notch.tertiary }}>
      {children}
    </h3>
  );
}

