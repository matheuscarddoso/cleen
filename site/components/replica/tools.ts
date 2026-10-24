import type { ComponentType } from "react";
import type { TabId } from "./tabs";
import { ConverterTab } from "./tabs/Converter";
import { EmojiTab } from "./tabs/Emoji";
import { HomeTab } from "./tabs/Home";
import { IconsTab } from "./tabs/Icons";
import { OverviewTab } from "./tabs/Overview";
import { StocksTab } from "./tabs/Stocks";
import { SystemTab } from "./tabs/System";
import { TimerTab } from "./tabs/Timer";
import { WeatherTab } from "./tabs/Weather";

/** Every tool the replica can show, by tab. */
export const tools: Record<TabId, ComponentType> = {
  home: HomeTab,
  timer: TimerTab,
  weather: WeatherTab,
  stocks: StocksTab,
  converter: ConverterTab,
  emoji: EmojiTab,
  icons: IconsTab,
  overview: OverviewTab,
  system: SystemTab,
};
