import type { Item } from "./catalog";

/** One entry of the ⌘K panel: what it does, its shortcut, and what it says once done. */
export type Action = { title: string; keys?: readonly string[]; message: string; destructive?: boolean };

/** Alias and global shortcut, offered on everything found the same way every time. */
const personalize = (item: Item): Action[] => [
  { title: item.alias ? `Mudar apelido (${item.alias})` : "Dar um apelido", message: `Apelido de “${item.title}” guardado` },
  { title: item.hotkey ? `Mudar atalho (${item.hotkey.join("")})` : "Dar um atalho global", message: `Atalho de “${item.title}” guardado` },
  ...(item.hotkey ? [{ title: "Tirar o atalho", message: "Atalho tirado" }] : []),
];

/**
 * The secondary actions of a result, as ⌘K lists them in the app (SearchCatalog.swift):
 * the first one is Return's, the rest have their own keys. Picked by the kind of row.
 */
export function actionsFor(item: Item): Action[] {
  const main = (title: string): Action => ({ title, keys: ["↩"], message: item.outcome.kind === "done" ? item.outcome.message : "Feito" });
  const [kind] = item.id.split(".");
  switch (kind) {
    case "app":
      return [
        main("Abrir"),
        { title: "Mostrar no Finder", keys: ["⌘", "↩"], message: `${item.title} no Finder` },
        { title: "Copiar caminho", keys: ["⌘", "⇧", "C"], message: "Caminho copiado" },
        { title: "Ocultar", keys: ["⌘", "H"], message: `${item.title} oculto` },
        { title: "Sair", keys: ["⌘", "Q"], message: `${item.title} fechado` },
        { title: "Forçar saída", message: "Pronto para revisar", destructive: true },
        ...personalize(item),
      ];
    case "openWindow":
      return [
        main("Ir para a janela"),
        { title: "Fechar janela", keys: ["⌘", "W"], message: "Janela fechada" },
        { title: `Sair do ${item.subtitle ?? "app"}`, keys: ["⌘", "Q"], message: `${item.subtitle ?? "App"} fechado` },
      ];
    case "file":
      return [
        main("Abrir"),
        { title: "Mostrar no Finder", keys: ["⌘", "↩"], message: `${item.title} no Finder` },
        { title: "Abrir com Pré-Visualização", message: `${item.title} aberto` },
        { title: "Copiar caminho", keys: ["⌘", "⇧", "C"], message: "Caminho copiado" },
        { title: "Copiar arquivo", keys: ["⌘", "C"], message: "Arquivo copiado" },
        { title: "Mover para o Lixo", keys: ["⌘", "⌫"], message: "Pronto para revisar", destructive: true },
      ];
    case "clip":
      return [main("Colar"), { title: "Copiar", keys: ["⌘", "C"], message: "Copiado" }];
    case "event":
      return [
        main(item.verb ?? "Abrir"),
        { title: "Abrir no Calendário", keys: ["⌘", "↩"], message: `${item.title} no Calendário` },
        ...(item.verb === "Entrar na reunião" ? [{ title: "Copiar link da reunião", keys: ["⌘", "C"], message: "Link da reunião copiado" }] : []),
      ];
    case "snippet":
      return [main("Colar"), { title: "Copiar", keys: ["⌘", "C"], message: "Copiado" }, ...personalize(item)];
    case "calc":
    case "smart":
    case "color":
      return [main("Copiar"), { title: "Colar", keys: ["⌘", "↩"], message: "Colado" }];
    case "emoji":
      return [main("Colar"), { title: "Copiar", keys: ["⌘", "C"], message: "Copiado" }];
    case "quicklink":
      return [main("Abrir"), { title: "Copiar", keys: ["⌘", "C"], message: "Endereço copiado" }, ...personalize(item)];
    case "web":
      return [main("Buscar"), { title: "Copiar", keys: ["⌘", "C"], message: "Endereço copiado" }];
    default:
      return [main(item.kind === "Janela" ? "Ajustar janela" : "Executar"), ...personalize(item)];
  }
}
