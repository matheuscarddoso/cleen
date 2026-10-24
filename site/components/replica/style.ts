/**
 * The app's NotchStyle (Sources/Cleen/Notch/NotchStyle.swift) as web values, so the
 * replicas read exactly like the notch. Sizes are points of the real panel.
 */
export const notch = {
  card: "rgba(255,255,255,0.045)",
  cardStroke: "rgba(255,255,255,0.07)",
  separator: "rgba(255,255,255,0.07)",
  barFill: "rgba(255,255,255,0.78)",
  control: "rgba(255,255,255,0.1)",
  controlHover: "rgba(255,255,255,0.16)",
  selection: "rgba(255,255,255,0.14)",
  track: "rgba(255,255,255,0.12)",
  primary: "#ffffff",
  secondary: "rgba(255,255,255,0.55)",
  tertiary: "rgba(255,255,255,0.32)",
  good: "rgb(92,214,133)",
  warning: "rgb(255,158,61)",
  critical: "rgb(255,84,84)",
  cardRadius: 14,
} as const;

/** The open panel at the default size (NotchSettings: 680 × 234, notch 32 tall). */
export const panel = {
  width: 680,
  height: 234,
  notchHeight: 32,
  topRadius: 14,
  bottomRadius: 30,
  /** Room between the panel's rounded edge and its content (NotchOpenContent.inset). */
  inset: 20,
} as const;

/** The tool's own area: what's left after the header strip and the tab bar. */
export const toolArea = {
  width: panel.width - panel.topRadius * 2 - panel.inset * 2,
  height: panel.height - panel.notchHeight - 6 - (6 + 26 + 10),
} as const;

/** Usage bars go white → orange → red as they fill (NotchStyle.level). */
export function level(fraction: number): string {
  if (fraction >= 0.9) return notch.critical;
  if (fraction >= 0.75) return notch.warning;
  return notch.barFill;
}
