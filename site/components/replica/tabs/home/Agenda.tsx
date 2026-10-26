"use client";

import { CalendarCheck, Circle, CircleCheck } from "lucide-react";
import { useState } from "react";
import { useL } from "@/components/LangProvider";
import { notch } from "../../style";
import { dayLetter, dayName, dayShort, events, firstDay, isWeekend, lastDay, monthLabel, today, type Reminder } from "./data";

const todayBlue = "rgb(51,140,255)";
const cell = 24;
const selectedCell = 30;

/**
 * NotchCalendar: the month, a strip of days centred on the picked one and faded at both
 * ends, and what's on that day underneath; for today, the open reminders too, each with
 * a circle that checks it off.
 */
export function Agenda({
  selected,
  reminders,
  hovered,
  onSelect,
  onComplete,
}: {
  selected: number;
  reminders: Reminder[];
  /** The reminder the script is about to tick, shown hovered. */
  hovered: string | null;
  onSelect: (day: number) => void;
  onComplete: (reminder: Reminder) => void;
}) {
  const l = useL();
  const dayEvents = events(l.lang);
  const days = Array.from({ length: lastDay - firstDay + 1 }, (_, index) => firstDay + index);
  const before = (selected - firstDay) * cell;
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center gap-1.5">
        <span className="text-[16px] font-semibold">{monthLabel(l.lang)}</span>
        <div
          className="relative h-[34px] min-w-0 flex-1 overflow-hidden"
          style={{ maskImage: "linear-gradient(to right, transparent 0%, #000 18%, #000 82%, transparent 100%)" }}
        >
          <div
            className="absolute left-1/2 top-0 flex transition-transform duration-300"
            style={{ transform: `translateX(${-(before + selectedCell / 2)}px)`, transitionTimingFunction: "cubic-bezier(0.32, 0.72, 0, 1)" }}
          >
            {days.map((day) => (
              <DayCell key={day} day={day} selected={day === selected} hasEvents={(dayEvents[day]?.length ?? 0) > 0 || (day === today && reminders.length > 0)} onSelect={() => onSelect(day)} />
            ))}
          </div>
        </div>
      </div>
      <DayAgenda day={selected} reminders={selected === today ? reminders.slice(0, 2) : []} hovered={hovered} onComplete={onComplete} />
    </div>
  );
}

function DayCell({ day, selected, hasEvents, onSelect }: { day: number; selected: boolean; hasEvents: boolean; onSelect: () => void }) {
  const { lang } = useL();
  const weekend = isWeekend(day);
  const label = selected ? "rgba(255,255,255,0.75)" : weekend ? "rgba(255,115,115,0.55)" : notch.tertiary;
  const number = selected ? todayBlue : weekend ? "rgba(255,115,115,0.7)" : notch.secondary;
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-label={dayName(day, lang)}
      aria-pressed={selected}
      className="flex h-[34px] shrink-0 flex-col items-center justify-center gap-px transition-[width] duration-300"
      style={{ width: selected ? selectedCell : cell }}
    >
      <span className="text-[8px] font-semibold leading-[10px]" style={{ color: label }}>{selected ? dayShort(day, lang) : dayLetter(day, lang)}</span>
      <span className="font-semibold leading-[15px] tabular-nums transition-[font-size,color] duration-300" style={{ fontSize: selected ? 14 : 12, color: number }}>
        {String(day).padStart(2, "0")}
      </span>
      <span className="size-[3px] rounded-full" style={{ background: selected ? todayBlue : notch.secondary, opacity: hasEvents ? 1 : 0 }} />
    </button>
  );
}

/** CalendarDayAgenda: one event and one reminder, two of either, or a quiet empty state. */
function DayAgenda({ day, reminders, hovered, onComplete }: { day: number; reminders: Reminder[]; hovered: string | null; onComplete: (reminder: Reminder) => void }) {
  const l = useL();
  const list = events(l.lang)[day] ?? [];
  const shownEvents = list.slice(0, reminders.length === 0 ? 2 : 1);
  const shownReminders = reminders.slice(0, list.length === 0 ? 2 : 1);
  if (shownEvents.length === 0 && shownReminders.length === 0) {
    return (
      <div className="flex h-[54px] flex-col items-center justify-center gap-1.5">
        <CalendarCheck size={13} strokeWidth={1.8} style={{ color: notch.tertiary }} aria-hidden />
        <span className="text-[11px] font-medium" style={{ color: notch.secondary }}>{day === today ? l("Nada para hoje", "Nothing for today") : l("Nada neste dia", "Nothing this day")}</span>
      </div>
    );
  }
  return (
    <div key={day} className="flex h-[54px] motion-safe:animate-[numeric_250ms_ease-out] flex-col gap-1.5">
      {shownEvents.map((event) => (
        <div key={event.title} className="flex items-center gap-2">
          <span className="h-[26px] w-[3px] shrink-0 rounded-full" style={{ background: event.color }} />
          <span className="flex min-w-0 flex-col gap-px">
            <span className="truncate text-[11px] font-medium leading-[13px]">{event.title}</span>
            <span className="text-[9.5px] leading-[12px] tabular-nums" style={{ color: notch.secondary }}>{event.time}</span>
          </span>
        </div>
      ))}
      {shownReminders.map((reminder) => (
        <ReminderRow key={reminder.id} reminder={reminder} hovered={hovered === reminder.id} onComplete={() => onComplete(reminder)} />
      ))}
    </div>
  );
}

/** AgendaReminderRow: an open reminder with a circle that checks it off, as in Lembretes. */
function ReminderRow({ reminder, hovered, onComplete }: { reminder: Reminder; hovered: boolean; onComplete: () => void }) {
  const l = useL();
  const [hover, setHover] = useState(false);
  const lit = hover || hovered;
  return (
    <div className="flex motion-safe:animate-[numeric_250ms_ease-out] items-center gap-2">
      <button
        type="button"
        onClick={onComplete}
        onPointerEnter={() => setHover(true)}
        onPointerLeave={() => setHover(false)}
        aria-label={l(`Concluir ${reminder.title}`, `Complete ${reminder.title}`)}
        title={l("Concluir", "Complete")}
        className="flex size-3 shrink-0 items-center justify-center rounded-full transition-colors duration-150"
        style={{ color: lit ? notch.primary : notch.secondary }}
      >
        {lit ? <CircleCheck size={12} strokeWidth={1.7} aria-hidden /> : <Circle size={12} strokeWidth={1.7} aria-hidden />}
      </button>
      <span className="truncate text-[11px] font-medium">{reminder.title}</span>
    </div>
  );
}
