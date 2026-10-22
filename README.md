# Cleen

Limpeza e saúde do Mac, morando no notch. Nativo (SwiftUI, macOS 26), sem
dependências, sem rede.

## O notch

Passe o mouse no notch (ou ⌃⌥C) e o painel desce dele. A primeira página é a do dia:
saudação, o que está tocando em qualquer app (YouTube, Spotify, Música…) com capa e
controles, e a coluna Hoje / Lembretes. As ferramentas ficam nas abas: Visão geral do
disco com limpeza em um clique, Limpeza, Projetos, Arquivos grandes, Sistema,
Inicialização e Manutenção. Fechado, mostra o anel do
disco e o espaço livre dos dois lados da câmera. Em telas sem notch, o Cleen desenha
um, e pode mostrar um notch em cada monitor externo (Ajustes).

O "tocando agora" usa o Now Playing do sistema. Desde o macOS 15.4 ele só responde
a binários da Apple, então `Support/NowPlaying` tem uma biblioteca pequena que o
`/usr/bin/perl` carrega e que transmite as mudanças como JSON (a mesma técnica do
projeto mediaremote-adapter). As ações destrutivas pedem dois cliques no próprio painel, sem diálogo. A janela
completa (ícone da barra de menus ou o botão no painel) tem tudo, incluindo Mapa do
disco, Duplicados e o desinstalador.

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

Toda remoção passa por `SafetyGuard` (`Sources/CleenKit/Core/SafetyGuard.swift`):
nunca remove pastas do sistema, as pastas principais da conta (`~/Library`,
`~/Documents`…), nada fora da pasta pessoal e de `/Applications`, e não deixa um
symlink no caminho levar a um desses lugares. O que você criou sempre vai para o
Lixo. Só o que se recria sozinho é apagado de vez.

## Desenvolvimento

```bash
swift build                     # compila
swift test                      # testes da CleenKit (Swift Testing)
./scripts/bundle.sh             # gera build/Cleen.app
./scripts/bundle.sh --install   # instala em /Applications e abre
```

Para conferir telas: `open build/Cleen.app --args --open junk --scan` abre a
janela numa seção e já analisa; `--notch <aba>` abre o notch fixado numa aba;
`./scripts/shoot-notch.sh <pasta>` fotografa todas as abas do notch.

Estrutura: `CleenKit` tem toda a lógica de disco e sistema, sem UI e testada
contra pastas temporárias. `Cleen` é o app (SwiftUI, isolamento padrão
`MainActor`).

Para enxergar Lixeira, Mail, Safari e containers de outros apps, dê **Acesso Total
ao Disco** ao Cleen em Ajustes do Sistema › Privacidade e Segurança.
