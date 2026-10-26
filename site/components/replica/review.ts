import type { LucideIcon } from "lucide-react";

/**
 * DeletionReview (Sources/Cleen/Notch/Deletion): before anything is deleted the notch
 * grows and lists what goes, with Cancelar and Confirmar.
 */
export type ReviewItem = { name: string; detail?: string; size?: number; icon: LucideIcon };

export type ReviewOutcome = "trash" | "delete" | "mixed";

export type Review = {
  title: string;
  outcome: ReviewOutcome;
  items: ReviewItem[];
  onConfirm: () => void;
  onCancel?: () => void;
};

/** "Mover 3 itens para o Lixo?", "Apagar 1 item?" */
export function reviewTitle(count: number, outcome: ReviewOutcome): string {
  if (outcome === "trash") return count === 1 ? "Mover 1 item para o Lixo?" : `Mover ${count} itens para o Lixo?`;
  return count === 1 ? "Apagar 1 item?" : `Apagar ${count} itens?`;
}

/** What happens to it, said plainly under the title. */
export function consequence(outcome: ReviewOutcome): string {
  if (outcome === "trash") return "Vai para o Lixo: dá para recuperar de lá.";
  if (outcome === "delete") return "É apagado de vez, sem passar pelo Lixo.";
  return "Parte vai para o Lixo e parte é apagada de vez.";
}
