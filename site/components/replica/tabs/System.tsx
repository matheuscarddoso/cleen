"use client";

import { BatteryCharging, BatteryMedium, Cpu, Globe, HardDrive, MemoryStick } from "lucide-react";
import { Fragment, useState, type ReactElement } from "react";
import { useL } from "@/components/LangProvider";
import { useDemo, usePlayingInterval } from "../DemoContext";
import { level, notch } from "../style";
import { NumericText } from "./stocks/NumericText";
import { MeterRow, Sparkline, UsageBar } from "./system/parts";
import { bytes, diskTotal, firstVitals, memoryBytes, memoryTotal, percent, pressure, rate, step } from "./system/vitals";

/** One sample every 1.2 s: brisker than the app's 2 s so the loop fits a glance. */
const tickMs = 1200;
const seed = 0x5eed;

/**
 * Sistema, as NotchSystemTab lays it out: one grouped list of live vitals, each a glyph,
 * a label, a thin bar and the value; the network row trades its bar for the download
 * line. Readings move only while the demo plays; reduced motion holds the first one.
 */
export function SystemTab() {
  const l = useL();
  const { reduced } = useDemo();
  const [vitals, setVitals] = useState(firstVitals);
  usePlayingInterval(() => setVitals((current) => step(current, seed)), tickMs);
  const shown = reduced ? firstVitals : vitals;
  const animated = !reduced;

  const memoryFraction = shown.memoryUsed / memoryTotal;
  const memoryState = pressure(shown.memoryUsed);
  const memoryColor = memoryState === "critical" ? notch.critical : memoryState === "warning" ? notch.warning : undefined;
  const diskUsed = 1 - shown.diskFree / diskTotal;
  const diskColor = level(diskUsed) === notch.barFill ? notch.primary : level(diskUsed);
  const battery = shown.battery;

  const rows: ReactElement[] = [
    <MeterRow key="cpu" icon={Cpu} label="CPU" value={percent(shown.cpu)} animated={animated}>
      <UsageBar fraction={shown.cpu} />
    </MeterRow>,
    <MeterRow key="memory" icon={MemoryStick} label={l("Memória", "Memory")} value={memoryBytes(shown.memoryUsed, l.lang)} valueColor={memoryColor} animated={animated}>
      <UsageBar fraction={memoryFraction} tint={memoryColor} />
    </MeterRow>,
    <MeterRow key="disk" icon={HardDrive} label={l("Disco", "Disk")} value={l(`${bytes(shown.diskFree, l.lang)} livres`, `${bytes(shown.diskFree, l.lang)} free`)} valueColor={diskColor} animated={animated}>
      <UsageBar fraction={diskUsed} />
    </MeterRow>,
    <MeterRow key="network" icon={Globe} label={l("Rede", "Network")} value={`↑ ${rate(shown.upload, l.lang)}`} animated={animated}>
      <span className="flex w-full items-center gap-2">
        <span aria-hidden className="text-[10.5px]" style={{ color: notch.tertiary }}>↓</span>
        <span className="min-w-0 flex-1">
          <Sparkline values={shown.downloadHistory} />
        </span>
        <span className="sr-only">Download</span>
        <span className="shrink-0 whitespace-nowrap text-[11px] font-medium text-white/85">
          <NumericText value={rate(shown.download, l.lang)} animated={animated} />
        </span>
      </span>
    </MeterRow>,
    <MeterRow
      key="battery"
      icon={battery.charging ? BatteryCharging : BatteryMedium}
      iconSize={15}
      label={l("Bateria", "Battery")}
      value={percent(battery.level)}
      detail={l(`saúde ${percent(battery.health)}`, `health ${percent(battery.health)}`)}
      animated={animated}
    >
      <UsageBar fraction={battery.level} tint={battery.level < 0.2 ? notch.critical : notch.barFill} />
    </MeterRow>,
  ];

  return (
    <div className="pt-1">
      <ul aria-label={l("Sinais vitais do Mac", "Mac vitals")} className="overflow-hidden rounded-[12px] border" style={{ background: notch.card, borderColor: notch.cardStroke }}>
        {rows.map((row, index) => (
          <Fragment key={row.key}>
            {row}
            {index < rows.length - 1 && <li aria-hidden className="ml-9 h-px" style={{ background: notch.separator }} />}
          </Fragment>
        ))}
      </ul>
    </div>
  );
}
