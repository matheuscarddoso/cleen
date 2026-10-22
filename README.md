# Lustro

Limpeza e saúde do Mac, na barra de menus. Nativo (SwiftUI, macOS 26), sem
dependências, sem rede.

## O que faz

| Seção | O que encontra | Para onde vai |
|---|---|---|
| Visão geral | Roda tudo de uma vez e limpa o que é seguro num clique | — |
| Lixo do sistema | Caches, logs, Lixeira, instaladores, anexos do Mail, Xcode, npm/Composer/Homebrew/etc., cache de navegadores, Docker, simuladores sem runtime | Caches: apagados de vez. Instaladores e backups: Lixo |
| Projetos de código | `node_modules`, `vendor`, `.next`, `target`, `.build`, `Pods`… de projetos parados | Apagados de vez (voltam com um install) |
| Arquivos grandes | Seus arquivos acima de N MB, com data de último uso | Lixo |
| Duplicados | Cópias idênticas byte a byte (tamanho → 64 KB → SHA-256) | Lixo |
| Mapa do disco | Tamanho de cada pasta, navegável, pasta pessoal ou disco inteiro | Lixo |
| Desinstalar apps | App + tudo o que ele espalhou em `~/Library` | Lixo |
| Restos de apps | Dados de apps que já foram apagados | Lixo |
| Inicialização | Launch agents/daemons com verificação de assinatura | Desativar (reversível) ou Lixo |
| Monitor | CPU, memória, rede, processos | — |
| Manutenção | Liberar RAM, snapshots locais, DNS, Spotlight, Abrir Com, fontes, verificar disco | — |

## Segurança

Toda remoção passa por `SafetyGuard` (`Sources/LustroKit/Core/SafetyGuard.swift`):
nunca remove pastas do sistema, as pastas principais da conta (`~/Library`,
`~/Documents`…), nada fora da pasta pessoal e de `/Applications`, e não deixa um
symlink no caminho levar a um desses lugares. O que você criou sempre vai para o
Lixo. Só o que se recria sozinho é apagado de vez.

## Desenvolvimento

```bash
swift build                     # compila
swift test                      # testes da LustroKit (Swift Testing)
./scripts/bundle.sh             # gera build/Lustro.app
./scripts/bundle.sh --install   # instala em /Applications e abre
```

Para conferir telas: `open build/Lustro.app --args --open junk --scan` abre a
janela numa seção e já analisa; `--panel-preview` mostra o painel da barra de
menus numa janela comum.

Estrutura: `LustroKit` tem toda a lógica de disco e sistema, sem UI e testada
contra pastas temporárias. `Lustro` é o app (SwiftUI, isolamento padrão
`MainActor`).

Para enxergar Lixeira, Mail, Safari e containers de outros apps, dê **Acesso Total
ao Disco** ao Lustro em Ajustes do Sistema › Privacidade e Segurança.
