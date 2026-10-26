"use client";

import { HardDrive } from "lucide-react";
import type { ReactNode } from "react";
import { BatteryCharging, Calendar, Headphones, Timer } from "./Icons";
import { ClosedNotch, Screen, Swap } from "./Notch";
import { useLoop, useSeconds } from "./useLoop";

type Activity = { key: string; label: string; width: string; left: ReactNode; right: ReactNode };

const durations = [2600, 2600, 2600, 2600, 3000, 3200] as const;

/** The closed notch going through what it tells you during a day, one after another. */
export function LiveActivities() {
  const { ref, index, setIndex, running } = useLoop<HTMLDivElement>(durations, 3);
  const elapsed = useSeconds(running && index === 5, index !== 5);
  const remaining = 25 * 60 - 1 - elapsed;
  const clock = `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")}`;

  const activities: Activity[] = [
    {
      key: "disk",
      label: "Disco",
      width: "300px",
      left: <Row><HardDrive className="h-4 w-4 text-white/70" strokeWidth={2} /> Livre</Row>,
      // The closed notch's meter: the figure with a thin bar of what's used under it.
      right: (
        <span className="relative pb-[5px] tabular-nums">
          62,1 GB
          <span className="absolute inset-x-0 bottom-0 h-[2.5px] overflow-hidden rounded-full bg-white/20">
            <span className="block h-full w-[75%] rounded-full bg-white/80" />
          </span>
        </span>
      ),
    },
    {
      key: "power",
      label: "Carregador",
      width: "330px",
      left: <Row><BatteryCharging className="h-[18px] w-[18px] text-[#30d158]" /> Carregando</Row>,
      right: <span className="text-[#30d158]">82%</span>,
    },
    {
      key: "headphones",
      label: "Fones",
      width: "350px",
      left: <Row><Headphones className="h-4 w-4" /> AirPods Pro</Row>,
      right: <span className="text-[#30d158]">Conectado</span>,
    },
    {
      key: "meeting",
      label: "Reunião",
      width: "300px",
      left: <Row><Calendar className="h-4 w-4 text-[#bf5af2]" /> Design</Row>,
      right: <span>5 min</span>,
    },
    {
      key: "music",
      label: "Música",
      width: "300px",
      left: <span className="h-[18px] w-[18px] rounded-[5px] bg-black bg-[url(/covers/iceman.jpg)] bg-cover bg-center" />,
      right: <Equalizer playing={running && index === 4} />,
    },
    {
      key: "timer",
      label: "Timer",
      width: "300px",
      left: <Row><Timer className="h-4 w-4 text-[#ff9f0a]" /> Foco</Row>,
      right: <span className="tabular-nums">{clock}</span>,
    },
  ];
  const active = activities[index] ?? activities[0]!;

  return (
    <div ref={ref}>
      <Screen tone="teal" className="aspect-[1280/666] min-h-[250px] rounded-[10px] [clip-path:inset(0_round_10px)]">
        <ClosedNotch width={active.width}>
          {activities.map((activity, position) => (
            <Swap key={activity.key} shown={position === index} className="flex items-center justify-between px-4 text-[14px] font-medium text-white">
              {activity.left}
              {activity.right}
            </Swap>
          ))}
        </ClosedNotch>
        <div className="absolute inset-x-0 bottom-6 flex flex-wrap justify-center gap-2 px-4">
          {activities.map((activity, position) => (
            <button
              key={activity.key}
              type="button"
              aria-pressed={position === index}
              onClick={() => setIndex(position)}
              className={`rounded-full px-3 py-1.5 text-[13px] font-medium backdrop-blur-md transition-colors duration-200 ${position === index ? "bg-white text-black" : "bg-white/12 text-white/80 hover:bg-white/20"}`}
            >
              {activity.label}
            </button>
          ))}
        </div>
      </Screen>
    </div>
  );
}

function Row({ children }: { children: ReactNode }) {
  return <span className="flex items-center gap-2">{children}</span>;
}

/** Four bars bouncing to the music, still when nothing plays. */
function Equalizer({ playing }: { playing: boolean }) {
  return (
    <span className="flex h-3.5 items-end gap-[3px]">
      {[0.9, 0.5, 1, 0.65].map((height, bar) => (
        <span
          key={bar}
          className="equalizer-bar w-[3px] rounded-full bg-[#ff9f0a]"
          style={{ height: `${height * 100}%`, animationDelay: `${bar * -0.27}s`, animationPlayState: playing ? "running" : "paused" }}
        />
      ))}
    </span>
  );
}
