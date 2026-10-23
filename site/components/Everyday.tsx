"use client";

import { useEffect, useRef, useState, type ComponentType, type ReactNode, type SVGProps } from "react";
import { Camera, Inbox, Pin, ScrollText, Search, Send, Settings, Timer } from "./Icons";
import { Shoulders, Swap } from "./Notch";
import { Wallpaper } from "./Wallpaper";
import { useSeconds } from "./useLoop";

/** How long each feature plays before the next one takes over. */
const SHOW_MS = 6500;

type Feature = {
  key: string;
  title: string;
  text: string;
  icon: ComponentType<SVGProps<SVGSVGElement>>;
  gradient: string;
};

const features: Feature[] = [
  { key: "teleprompter", title: "Teleprompter", text: "O roteiro rola logo abaixo da câmera, com o olhar na lente.", icon: ScrollText, gradient: "linear-gradient(180deg,#ffb340,#ff7a00)" },
  { key: "timer", title: "Timers", text: "Pomodoro ou timer simples, contando no notch fechado.", icon: Timer, gradient: "linear-gradient(180deg,#ff6961,#d70015)" },
  { key: "shelf", title: "Shelf", text: "Solte arquivos no notch e mande por AirDrop num gesto.", icon: Inbox, gradient: "linear-gradient(180deg,#5ac8fa,#0a7aff)" },
  { key: "mirror", title: "Espelho", text: "Uma olhada na câmera antes da chamada, sem abrir app.", icon: Camera, gradient: "linear-gradient(180deg,#8e8e93,#48484a)" },
];

/**
 * Apple's "watch" switcher: the scene on top shows one feature at a time; below, each
 * feature with its button and a bar that fills while it's on, then hands over to the next.
 * It only advances on screen, with the tab visible, and never with reduced motion.
 */
export function Everyday() {
  const ref = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const [running, setRunning] = useState(false);
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    let visible = false;
    const update = () => {
      setReduced(motion.matches);
      setRunning(visible && !motion.matches && document.visibilityState === "visible");
    };
    const observer = new IntersectionObserver(([entry]) => {
      visible = entry?.isIntersecting ?? false;
      update();
    }, { threshold: 0.4 });
    observer.observe(element);
    motion.addEventListener("change", update);
    document.addEventListener("visibilitychange", update);
    return () => {
      observer.disconnect();
      motion.removeEventListener("change", update);
      document.removeEventListener("visibilitychange", update);
    };
  }, []);

  const next = () => setIndex((current) => (current + 1) % features.length);

  return (
    <div ref={ref}>
      <Stage>
        <Swap shown={index === 0}><Teleprompter playing={running && index === 0} /></Swap>
        <Swap shown={index === 1}><TimerScene counting={running && index === 1} /></Swap>
        <Swap shown={index === 2}><Shelf key={index === 2 ? "on" : "off"} /></Swap>
        <Swap shown={index === 3}><Mirror /></Swap>
      </Stage>

      <div className="mx-auto mt-10 grid max-w-[1040px] grid-cols-2 gap-x-6 gap-y-10 lg:grid-cols-4">
        {features.map((feature, position) => {
          const Icon = feature.icon;
          const active = position === index;
          return (
            <div key={feature.key} className="flex h-full flex-col items-center text-center">
              <span
                aria-hidden
                className="flex h-14 w-14 items-center justify-center rounded-[14px] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_4px_10px_rgba(0,0,0,0.12)]"
                style={{ background: feature.gradient }}
              >
                <Icon className="h-7 w-7" strokeWidth={1.75} />
              </span>
              <h3 className="mt-3 text-[21px] font-semibold leading-[1.19] tracking-[0.011em]">{feature.title}</h3>
              <p className="mt-1 max-w-[230px] flex-1 text-[17px] leading-[1.47] text-mute">{feature.text}</p>
              <button
                type="button"
                onClick={() => setIndex(position)}
                aria-pressed={active}
                className={`mt-4 rounded-full px-4 py-2 text-[17px] leading-[1.18] transition-[background-color,color,scale] duration-200 active:scale-[0.96] ${active ? "cursor-default bg-[#e8e8ed] text-ink" : "bg-accent text-white hover:bg-[#0077ed]"}`}
              >
                {active ? "Mostrando" : "Ver"}
              </button>
              <span aria-hidden className="mt-4 h-[3px] w-24 overflow-hidden rounded-full bg-black/10">
                {active && !reduced && (
                  <span
                    key={index}
                    className="block h-full origin-left rounded-full bg-ink"
                    style={{ animation: `progress ${SHOW_MS}ms linear forwards`, animationPlayState: running ? "running" : "paused" }}
                    onAnimationEnd={next}
                  />
                )}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** Design size of the scenes; the stage scales it to whatever width it gets. */
const DESIGN = { width: 960, height: 380 } as const;
/** Below this, the stage zooms into the panel instead of shrinking the whole scene. */
const PANEL_FOCUS = 720;

function Stage({ children }: { children: ReactNode }) {
  const box = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState<number | null>(null);
  useEffect(() => {
    const element = box.current;
    if (!element) return;
    const observer = new ResizeObserver(([entry]) => {
      if (entry) setWidth(entry.contentRect.width);
    });
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  const scale = width === null ? 1 : width / (width < PANEL_FOCUS ? PANEL_FOCUS : DESIGN.width);
  const offset = width === null ? 0 : (width - DESIGN.width * scale) / 2;
  return (
    <div
      ref={box}
      className="relative mx-auto max-w-[1160px] overflow-hidden rounded-[18px]"
      style={width === null ? { aspectRatio: `${DESIGN.width} / ${DESIGN.height}` } : { height: DESIGN.height * scale }}
    >
      <Wallpaper tone="blue" />
      <div aria-hidden className="absolute left-0 top-0 origin-top-left" style={{ width: DESIGN.width, height: DESIGN.height, transform: `translateX(${offset}px) scale(${scale})` }}>
        {children}
      </div>
    </div>
  );
}

/** The open notch: a black panel hanging from the top edge, title and icons on top. */
function Panel({ title, children, height }: { title: string; children: ReactNode; height: number }) {
  return (
    <div className="absolute left-1/2 top-0 w-[680px] -translate-x-1/2 rounded-b-[30px] bg-black px-7 pb-6 pt-4 text-white shadow-[0_24px_60px_rgba(0,0,0,0.45)]" style={{ height }}>
      <Shoulders size={12} />
      <div className="flex items-center justify-between">
        <span className="text-[17px] font-semibold">{title}</span>
        <span className="flex gap-4 text-white/75">
          <Search className="h-4 w-4" />
          <Pin className="h-4 w-4" />
          <Settings className="h-4 w-4" />
        </span>
      </div>
      {children}
    </div>
  );
}

const script =
  "Bom dia, pessoal. Hoje eu quero mostrar três mudanças no checkout. Primeiro, o pagamento agora cabe em uma tela só. Depois, o Pix aparece antes do cartão, que é como a maioria paga. E por último, o recibo chega no e-mail na hora, sem ninguém precisar pedir.";

function Teleprompter({ playing }: { playing: boolean }) {
  return (
    <Panel title="Teleprompter" height={300}>
      <div className="relative mt-3 h-[196px] overflow-hidden [mask-image:linear-gradient(transparent,black_22%,black_70%,transparent)]">
        <div className="teleprompter-roll px-10 text-center text-[26px] font-medium leading-[1.45] text-white" style={{ animationPlayState: playing ? "running" : "paused" }}>
          <p className="pb-10">{script}</p>
          <p className="pb-10">{script}</p>
        </div>
      </div>
      <div className="absolute inset-x-0 bottom-5 flex justify-center gap-2 text-[13px] font-medium">
        <span className="rounded-full bg-white px-3 py-1 text-black">{playing ? "Pausar" : "Continuar"}</span>
        <span className="rounded-full bg-white/10 px-3 py-1">1,0×</span>
        <span className="rounded-full bg-white/10 px-3 py-1">Espelhar</span>
      </div>
    </Panel>
  );
}

function TimerScene({ counting }: { counting: boolean }) {
  const total = 25 * 60;
  const elapsed = useSeconds(counting, false, 7 * 60 + 12);
  const remaining = Math.max(0, total - elapsed);
  const clock = `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")}`;
  const circumference = 2 * Math.PI * 58;
  return (
    <Panel title="Timer" height={250}>
      <div className="mt-6 flex items-center gap-8">
        <span className="relative flex shrink-0 items-center justify-center">
          <Timer className="absolute h-8 w-8 text-white/70" strokeWidth={1.75} />
          <svg viewBox="0 0 132 132" className="h-[132px] w-[132px] -rotate-90">
            <circle cx="66" cy="66" r="58" fill="none" stroke="rgba(255,255,255,0.12)" strokeWidth="8" />
            <circle
              cx="66" cy="66" r="58" fill="none" stroke="#ff453a" strokeWidth="8" strokeLinecap="round"
              strokeDasharray={circumference} strokeDashoffset={circumference * (1 - remaining / total)}
              className="transition-[stroke-dashoffset] duration-1000 ease-linear"
            />
          </svg>
        </span>
        <div className="min-w-0">
          <p className="text-[14px] font-medium text-white/55">Pomodoro · foco 2 de 4</p>
          <p className="text-[68px] font-light leading-none tabular-nums tracking-[-0.02em]">{clock}</p>
          <p className="mt-2 text-[14px] text-white/45">a contagem segue no notch fechado</p>
        </div>
        <div className="ml-auto flex flex-col items-end gap-3 text-[14px] font-medium">
          <span className="flex rounded-full bg-white/10 p-1">
            <span className="rounded-full px-3 py-1 text-white/70">Timer</span>
            <span className="rounded-full bg-white px-3 py-1 text-black">Pomodoro</span>
          </span>
          <span className="flex gap-2">
            <span className="rounded-full bg-white px-4 py-1.5 text-black">Pausar</span>
            <span className="rounded-full bg-white/10 px-4 py-1.5">+1 min</span>
          </span>
        </div>
      </div>
    </Panel>
  );
}

const files = [
  { name: "contrato.pdf", tag: "PDF", color: "#ff453a" },
  { name: "capa.png", tag: "PNG", color: "#30d158" },
  { name: "assets.zip", tag: "ZIP", color: "#8e8e93" },
  { name: "pitch.key", tag: "KEY", color: "#0a84ff" },
] as const;

function Shelf() {
  return (
    <Panel title="Shelf" height={256}>
      <div className="mt-6 flex items-end gap-5">
        {files.map((file, position) => (
          <div key={file.name} className={`flex w-[104px] flex-col items-center ${position === files.length - 1 ? "shelf-drop" : ""}`}>
            <span className="drop-shadow-[0_6px_10px_rgba(0,0,0,0.45)]">
              <span
                className="relative flex h-[104px] w-[82px] items-end justify-center rounded-[8px] bg-gradient-to-b from-white to-[#e5e5ea] pb-3"
                style={{ clipPath: "polygon(0 0, 72% 0, 100% 22%, 100% 100%, 0 100%)" }}
              >
                <span aria-hidden className="absolute right-0 top-0 h-[23px] w-[23px] rounded-bl-[4px] bg-[#c7c7cc]" style={{ clipPath: "polygon(0 0, 0 100%, 100% 100%)" }} />
                <span className="rounded-[4px] px-1.5 py-0.5 text-[11px] font-medium text-white" style={{ background: file.color }}>
                  {file.tag}
                </span>
              </span>
            </span>
            <span className="mt-2 text-[13px] font-medium text-white/85">{file.name}</span>
          </div>
        ))}
        <div className="ml-auto flex flex-col items-end gap-2 pb-6 text-[14px] font-medium">
          <span className="flex items-center gap-2 rounded-full bg-[#0a84ff] px-4 py-1.5">
            <Send className="h-3.5 w-3.5" /> AirDrop
          </span>
          <span className="whitespace-nowrap rounded-full bg-white/10 px-4 py-1.5">Selecionar tudo</span>
        </div>
      </div>
    </Panel>
  );
}

function Mirror() {
  return (
    <Panel title="Espelho" height={340}>
      <div
        className="relative mx-auto mt-4 h-[250px] w-[420px] overflow-hidden rounded-[22px]"
        style={{ background: "radial-gradient(70% 80% at 22% 18%, #f3d9b1 0%, transparent 60%), radial-gradient(60% 70% at 85% 30%, #7a8fa8 0%, transparent 65%), linear-gradient(180deg, #a08a76, #3d3631)" }}
      >
        <svg viewBox="0 0 420 250" className="absolute inset-0 h-full w-full blur-[3px]">
          <defs>
            <linearGradient id="skin" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0" stopColor="#d9b49a" />
              <stop offset="1" stopColor="#a77d62" />
            </linearGradient>
          </defs>
          <rect x="190" y="150" width="40" height="40" rx="14" fill="#b88b6e" />
          <ellipse cx="210" cy="112" rx="50" ry="62" fill="url(#skin)" />
          <path d="M158 104c-6-52 40-72 72-62 34 8 46 34 40 62-6-24-26-38-56-36-30 0-50 14-56 36z" fill="#2b211c" />
          <path d="M70 262c8-58 64-82 140-82s132 24 140 82z" fill="#2f3b4c" />
        </svg>
        <span className="absolute left-3 top-3 rounded-full bg-black/50 px-2.5 py-1 text-[12px] font-medium backdrop-blur">Câmera FaceTime HD</span>
      </div>
    </Panel>
  );
}
