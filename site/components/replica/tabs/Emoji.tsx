"use client";

import { Car, Clock, Flag, Heart, Lightbulb, PawPrint, Smile, Utensils, Volleyball, type LucideIcon } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { useDemo, useTypewriter } from "../DemoContext";
import { HeaderButton } from "../Panel";
import { notch } from "../style";
import { categoryTitles, emojiItem, searchEmoji, sections, type EmojiCategory, type EmojiItem } from "./emoji/data";
import { ConfirmationPill, FadeScroll, SearchField, copyText, useBeats, useConfirmation } from "./emoji/shared";

type Jump = "recents" | EmojiCategory;

const jumpIcons: Record<Jump, LucideIcon> = {
  recents: Clock,
  people: Smile,
  nature: PawPrint,
  food: Utensils,
  activity: Volleyball,
  travel: Car,
  objects: Lightbulb,
  symbols: Heart,
  flags: Flag,
};

/** The full grid first, then three searches; each walks the matches and picks one. */
const queries = ["", "coração", "fogo", "festa"] as const;

/** Where the pointer goes in each search's results; the last stop is the pick. */
const paths: readonly (readonly number[])[] = [[], [0, 1, 2, 0], [1, 2, 1, 0], [0, 1, 2, 3]];

/** After the word: a beat to read, three hovers, the press, then the pill. */
const beats = [450, 520, 520, 520, 160, 1500] as const;
const hold = beats.reduce((sum, beat) => sum + beat, 0) + 160;

/** What the previous round left in Recentes. */
const scriptedRecents = ["🎊", "🔥", "❤️", "👍"];

/**
 * Emoji, as NotchEmojiTab lays it out: the outlined search and the category jumps on
 * top, the grid of large emoji below (Recentes, then Apple's groups). Clicking or
 * Return copies the emoji and the pill confirms it; on the Mac it's pasted where you
 * were typing.
 */
export function EmojiTab() {
  const { reduced } = useDemo();
  const typing = useTypewriter(queries, { speed: 120, hold });
  const [manual, setManual] = useState<{ query: string; recents: string[] } | null>(null);
  const [picked, showPicked] = useConfirmation<string>(1200);
  const [jump, setJump] = useState<{ to: Jump; stamp: number } | null>(null);
  const scroller = useRef<HTMLDivElement>(null);

  const scriptedIndex = reduced ? 1 : typing.index;
  const beat = useBeats(!manual && !reduced && typing.finished ? String(typing.index) : null, beats);
  const query = manual ? manual.query : reduced ? queries[1] : typing.text;
  const results = useMemo(() => searchEmoji(query), [query]);
  const searching = query.trim().length > 0;
  const path = paths[scriptedIndex] ?? [];
  const highlighted = manual ? -1 : reduced ? 0 : beat >= 1 && beat <= 5 ? (path[Math.min(beat, 4) - 1] ?? -1) : -1;
  const scriptedPick = !manual && beat === 5 ? results[highlighted] : undefined;
  const recents = manual ? manual.recents : scriptedRecents;

  const take = () => manual ?? { query, recents };
  const use = (entry: EmojiItem) => {
    const state = take();
    setManual({ ...state, recents: [entry.emoji, ...state.recents.filter((emoji) => emoji !== entry.emoji)].slice(0, 24) });
    showPicked(entry.emoji);
    void copyText(entry.emoji);
  };

  // A jump scrolls once the full grid is on screen (leaving a search swaps it in first).
  useEffect(() => {
    if (!jump) return;
    const target = scroller.current?.querySelector<HTMLElement>(`[data-section="${jump.to}"]`);
    scroller.current?.scrollTo({ top: target ? target.offsetTop : 0, behavior: reduced ? "auto" : "smooth" });
  }, [jump, reduced]);

  const pill = manual ? picked : scriptedPick?.emoji ?? null;
  const jumps: Jump[] = [...(recents.length > 0 ? (["recents"] as const) : []), ...sections.map((section) => section.category)];

  return (
    <div className="relative flex h-full flex-col gap-2">
      <div className="flex h-[26px] shrink-0 items-center gap-2">
        <SearchField
          value={query}
          placeholder="Buscar emoji"
          caret={!manual && !reduced}
          onChange={(value) => setManual({ ...take(), query: value })}
          onSubmit={() => {
            const first = results[0];
            if (first) use(first);
          }}
        />
        <span className="flex-1" />
        <div className="flex">
          {jumps.map((target) => (
            <HeaderButton
              key={target}
              icon={jumpIcons[target]}
              label={target === "recents" ? "Recentes" : categoryTitles[target]}
              onClick={() => {
                setManual({ ...take(), query: "" });
                setJump({ to: target, stamp: Date.now() });
              }}
            />
          ))}
        </div>
      </div>
      {searching && results.length === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center gap-[5px]">
          <Smile size={18} strokeWidth={1.8} style={{ color: notch.tertiary }} aria-hidden />
          <p className="text-[11.5px]" style={{ color: notch.secondary }}>Nenhum emoji encontrado</p>
        </div>
      ) : (
        <FadeScroll key={searching ? "results" : "all"} scrollRef={scroller}>
          <div className="grid gap-0.5 pb-1" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(36px, 1fr))" }}>
            {searching ? (
              results.map((entry, index) => <EmojiCell key={entry.emoji} entry={entry} highlighted={index === highlighted} pressed={index === highlighted && beat === 4} onUse={use} />)
            ) : (
              <>
                {recents.length > 0 && (
                  <Section id="recents" title="Recentes" items={recents.map((emoji) => emojiItem(emoji) ?? { emoji, name: emoji, category: "symbols", terms: [], nameWords: 0 })} onUse={use} />
                )}
                {sections.map((section) => (
                  <Section key={section.category} id={section.category} title={categoryTitles[section.category]} items={section.items} onUse={use} />
                ))}
              </>
            )}
          </div>
        </FadeScroll>
      )}
      <ConfirmationPill shown={pill !== null} live={manual !== null}>
        <span className="text-[14px] leading-none">{pill}</span>
        Copiado
      </ConfirmationPill>
    </div>
  );
}

function Section({ id, title, items, onUse }: { id: Jump; title: string; items: EmojiItem[]; onUse: (entry: EmojiItem) => void }) {
  return (
    <>
      <h3 data-section={id} className="col-span-full pb-0.5 pt-1.5 text-[10.5px] font-medium" style={{ color: notch.tertiary }}>
        {title}
      </h3>
      {items.map((entry) => (
        <EmojiCell key={`${id}-${entry.emoji}`} entry={entry} highlighted={false} pressed={false} onUse={onUse} />
      ))}
    </>
  );
}

/** One emoji: large, a grey square under the pointer, a quick press-in on the click. */
function EmojiCell({ entry, highlighted, pressed, onUse }: { entry: EmojiItem; highlighted: boolean; pressed: boolean; onUse: (entry: EmojiItem) => void }) {
  return (
    <button
      type="button"
      onClick={() => onUse(entry)}
      title={entry.name}
      aria-label={entry.name}
      className="flex h-9 items-center justify-center rounded-[8px] text-[26px] leading-none transition-[background-color,scale] duration-150 hover:bg-white/10 active:scale-[0.88]"
      style={{ background: highlighted ? notch.control : undefined, scale: pressed ? "0.88" : undefined }}
    >
      {entry.emoji}
    </button>
  );
}
