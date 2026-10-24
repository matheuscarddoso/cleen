"use client";

import { useEffect, useState } from "react";
import { useDemo, useSteps } from "../DemoContext";
import { useReplica } from "../ReplicaContext";
import { notch } from "../style";
import { Agenda } from "./home/Agenda";
import { reminders, today, tracks, type Reminder } from "./home/data";
import { NowPlaying } from "./home/NowPlaying";
import { TimerWidget } from "./home/TimerWidget";
import { isActive, newSession, tick, toggle, type TimerSession } from "./timer/session";
import { useTicker } from "./timer/TimerRing";

type Player = "previous" | "toggle" | "next";
type State = { track: number; playing: boolean; day: number; done: string[] };

/**
 * The script: a song playing, paused and resumed, the next track, a look at tomorrow,
 * back to today, and the first reminder ticked off. The timer counts down throughout.
 */
const script = [2600, 1600, 1800, 2800, 2200, 1400, 900, 2800] as const;
const presses: Record<number, Player> = { 1: "toggle", 2: "toggle", 3: "next" };

function scriptedState(step: number): State {
  return { track: step >= 3 ? 1 : 0, playing: step !== 1, day: step === 4 ? today + 1 : today, done: step === 7 ? ["proposta"] : [] };
}

/** A focus block a third of the way in. */
const startTimer: TimerSession = { ...newSession(25), status: "running", remaining: 18 * 60 + 40 };

/**
 * Início, as NotchHomeTab lays it out: the greeting, then the widgets side by side with
 * hairlines between them. Here: Tocando agora (large), the Timer (small) and the Agenda
 * (medium), which takes what's left of the row.
 */
export function HomeTab() {
  const { playing, reduced } = useDemo();
  const { setTab } = useReplica();
  const [step] = useSteps(script);
  const [manual, setManual] = useState<State | null>(null);
  const [timer, setTimer] = useState<TimerSession>(startTimer);
  const [timerManual, setTimerManual] = useState(false);
  const [pressed, setPressed] = useState<Player | null>(null);

  // The script's press on a player button: lit for a beat, like a hover under the cursor.
  useEffect(() => {
    const press = presses[step];
    if (manual || !playing || !press) return;
    setPressed(press);
    const release = window.setTimeout(() => setPressed(null), 320);
    return () => window.clearTimeout(release);
  }, [manual, playing, step]);

  useTicker(timer.status === "running" && (timerManual || (playing && !reduced)), () => setTimer(tick));

  const state = manual ?? scriptedState(step);
  const track = tracks[state.track] ?? tracks[0]!;
  const open = reminders.filter((reminder) => !state.done.includes(reminder.id));
  const change = (next: (current: State) => State) => {
    setPressed(null);
    setManual(next(state));
  };
  const skipTrack = (by: number) => change((current) => ({ ...current, track: (current.track + by + tracks.length) % tracks.length, playing: true }));
  const complete = (reminder: Reminder) => change((current) => ({ ...current, done: [...current.done, reminder.id] }));
  const pressTimer = () => {
    if (!isActive(timer)) {
      setTab("timer");
      return;
    }
    setTimerManual(true);
    setTimer(toggle);
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-col gap-px">
        <span className="text-[15px] font-semibold leading-[18px]">Boa tarde, Ana!</span>
        <span className="text-[10.5px] leading-[13px]" style={{ color: notch.secondary }}>Quinta-feira, 22 de outubro</span>
      </div>
      <div className="flex items-center gap-4">
        <div className="w-[270px] shrink-0">
          <NowPlaying
            track={track}
            playing={state.playing}
            pressed={manual ? null : pressed}
            onPrevious={() => skipTrack(-1)}
            onToggle={() => change((current) => ({ ...current, playing: !current.playing }))}
            onNext={() => skipTrack(1)}
          />
        </div>
        <Divider />
        <TimerWidget session={timer} still={reduced} onPress={pressTimer} />
        <Divider />
        <div className="min-w-0 flex-1">
          <Agenda
            selected={state.day}
            reminders={open}
            hovered={!manual && step === 6 ? "proposta" : null}
            onSelect={(day) => change((current) => ({ ...current, day }))}
            onComplete={complete}
          />
        </div>
      </div>
    </div>
  );
}

function Divider() {
  return <span aria-hidden className="h-[88px] w-px shrink-0" style={{ background: notch.track }} />;
}
