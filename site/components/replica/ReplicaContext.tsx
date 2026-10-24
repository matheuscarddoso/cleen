"use client";

import { createContext, useContext } from "react";
import type { Mode, TabId } from "./tabs";

export type Replica = {
  tab: TabId;
  setTab: (tab: TabId) => void;
  mode: Mode;
  setMode: (mode: Mode) => void;
  /** The panel's size, as Ajustes › Aparência sets it. */
  size: { width: number; height: number };
  setSize: (size: { width: number; height: number }) => void;
};

export const ReplicaContext = createContext<Replica | null>(null);

/** The replica the current tool lives in: switch tabs, open search or Ajustes. */
export function useReplica(): Replica {
  const replica = useContext(ReplicaContext);
  if (!replica) throw new Error("useReplica must be used inside <Replica>");
  return replica;
}
