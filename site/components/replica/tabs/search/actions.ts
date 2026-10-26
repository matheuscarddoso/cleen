import { pick, type Lang } from "@/lib/lang";
import type { Item } from "./catalog";

/** One entry of the ⌘K panel: what it does, its shortcut, and what it says once done. */
export type Action = { title: string; keys?: readonly string[]; message: string; destructive?: boolean };

/** Alias and global shortcut, offered on everything found the same way every time. */
const personalize = (item: Item, lang: Lang): Action[] => {
  const l = pick(lang);
  return [
    { title: item.alias ? l(`Mudar apelido (${item.alias})`, `Change Alias (${item.alias})`) : l("Dar um apelido", "Add Alias"), message: l(`Apelido de “${item.title}” guardado`, `Alias for “${item.title}” saved`) },
    { title: item.hotkey ? l(`Mudar atalho (${item.hotkey.join("")})`, `Change Shortcut (${item.hotkey.join("")})`) : l("Dar um atalho global", "Add Global Shortcut"), message: l(`Atalho de “${item.title}” guardado`, `Shortcut for “${item.title}” saved`) },
    ...(item.hotkey ? [{ title: l("Tirar o atalho", "Remove Shortcut"), message: l("Atalho tirado", "Shortcut removed") }] : []),
  ];
};

/**
 * The secondary actions of a result, as ⌘K lists them in the app (SearchCatalog.swift):
 * the first one is Return's, the rest have their own keys. Picked by the kind of row.
 */
export function actionsFor(item: Item, lang: Lang = "pt"): Action[] {
  const l = pick(lang);
  const main = (title: string): Action => ({ title, keys: ["↩"], message: item.outcome.kind === "done" ? item.outcome.message : l("Feito", "Done") });
  const copy = (message: string): Action => ({ title: l("Copiar", "Copy"), keys: ["⌘", "C"], message });
  const [kind] = item.id.split(".");
  switch (kind) {
    case "app":
      return [
        main(l("Abrir", "Open")),
        { title: l("Mostrar no Finder", "Show in Finder"), keys: ["⌘", "↩"], message: l(`${item.title} no Finder`, `${item.title} in Finder`) },
        { title: l("Copiar caminho", "Copy Path"), keys: ["⌘", "⇧", "C"], message: l("Caminho copiado", "Path copied") },
        { title: l("Ocultar", "Hide"), keys: ["⌘", "H"], message: l(`${item.title} oculto`, `${item.title} hidden`) },
        { title: l("Sair", "Quit"), keys: ["⌘", "Q"], message: l(`${item.title} fechado`, `${item.title} quit`) },
        { title: l("Forçar saída", "Force Quit"), message: l("Pronto para revisar", "Ready to review"), destructive: true },
        ...personalize(item, lang),
      ];
    case "openWindow":
      return [
        main(l("Ir para a janela", "Go to Window")),
        { title: l("Fechar janela", "Close Window"), keys: ["⌘", "W"], message: l("Janela fechada", "Window closed") },
        { title: l(`Sair do ${item.subtitle ?? "app"}`, `Quit ${item.subtitle ?? "App"}`), keys: ["⌘", "Q"], message: l(`${item.subtitle ?? "App"} fechado`, `${item.subtitle ?? "App"} quit`) },
      ];
    case "file":
      return [
        main(l("Abrir", "Open")),
        { title: l("Mostrar no Finder", "Show in Finder"), keys: ["⌘", "↩"], message: l(`${item.title} no Finder`, `${item.title} in Finder`) },
        { title: l("Abrir com Pré-Visualização", "Open with Preview"), message: l(`${item.title} aberto`, `${item.title} opened`) },
        { title: l("Copiar caminho", "Copy Path"), keys: ["⌘", "⇧", "C"], message: l("Caminho copiado", "Path copied") },
        { title: l("Copiar arquivo", "Copy File"), keys: ["⌘", "C"], message: l("Arquivo copiado", "File copied") },
        { title: l("Mover para o Lixo", "Move to Trash"), keys: ["⌘", "⌫"], message: l("Pronto para revisar", "Ready to review"), destructive: true },
      ];
    case "clip":
      return [main(l("Colar", "Paste")), copy(l("Copiado", "Copied"))];
    case "event": {
      const join = l("Entrar na reunião", "Join Meeting");
      return [
        main(item.verb ?? l("Abrir", "Open")),
        { title: l("Abrir no Calendário", "Open in Calendar"), keys: ["⌘", "↩"], message: l(`${item.title} no Calendário`, `${item.title} in Calendar`) },
        ...(item.verb === join ? [{ title: l("Copiar link da reunião", "Copy Meeting Link"), keys: ["⌘", "C"], message: l("Link da reunião copiado", "Meeting link copied") }] : []),
      ];
    }
    case "snippet":
      return [main(l("Colar", "Paste")), copy(l("Copiado", "Copied")), ...personalize(item, lang)];
    case "calc":
    case "smart":
    case "color":
      return [main(l("Copiar", "Copy")), { title: l("Colar", "Paste"), keys: ["⌘", "↩"], message: l("Colado", "Pasted") }];
    case "emoji":
      return [main(l("Colar", "Paste")), copy(l("Copiado", "Copied"))];
    case "quicklink":
      return [main(l("Abrir", "Open")), copy(l("Endereço copiado", "URL copied")), ...personalize(item, lang)];
    case "web":
      return [main(l("Buscar", "Search")), copy(l("Endereço copiado", "URL copied"))];
    default:
      // Window layouts arrange; Cleen's commands, the Mac's and the tabs run.
      return [main(kind === "window" ? l("Ajustar janela", "Arrange Window") : l("Executar", "Run")), ...personalize(item, lang)];
  }
}
