# Cleen

Limpeza e saúde do Mac, morando no notch. Nativo (SwiftUI, macOS 26), sem
dependências.

## Instalar

Precisa de um Mac com chip Apple e macOS 26 ou mais novo.

1. Abra o `Cleen.dmg` e arraste o Cleen para Aplicativos.
2. Abra o Cleen em Aplicativos. O app não é notarizado pela Apple, então na primeira
   vez o macOS avisa que não pôde verificá-lo. Clique em **OK**, vá em **Ajustes do
   Sistema › Privacidade e Segurança**, role até o fim e clique em **Abrir Mesmo
   Assim** ao lado do Cleen. Só na primeira vez.
3. O tour de boas-vindas pede as permissões, uma de cada vez, e explica para que
   serve cada uma. Todas são opcionais.

O Cleen passa a abrir junto com o Mac (desliga em Ajustes, no próprio notch).

Para desinstalar: saia pelo ícone da barra de menus e mova o Cleen para o Lixo.

## O notch

Passe o mouse no notch (ou ⌃⌥C) e o painel desce dele. A primeira página é a do dia:
saudação, o que está tocando em qualquer app (YouTube, Spotify, Música…) com capa e
controles, o Espelho e a coluna Hoje / Lembretes. As outras abas: Calendário, Shelf,
Área de transferência, Screenshots, Uso de IA e as ferramentas de limpeza. Você
escolhe quais aparecem e em que ordem. Fechado, o notch mostra o anel do disco e o
espaço livre dos dois lados da câmera. Em telas sem notch, o Cleen desenha um, e
pode mostrar um notch em cada monitor externo (Ajustes).

O "tocando agora" usa o Now Playing do sistema. Desde o macOS 15.4 ele só responde
a binários da Apple, então `Support/NowPlaying` tem uma biblioteca pequena que o
`/usr/bin/perl` carrega e que transmite as mudanças como JSON (a mesma técnica do
projeto mediaremote-adapter). As ações destrutivas pedem dois cliques no próprio
painel, sem diálogo.

## O que faz

| Seção | O que encontra | Para onde vai |
|---|---|---|
| Visão geral | Roda tudo de uma vez e limpa o que é seguro num clique | — |
| Limpeza | Caches, logs, Lixeira, instaladores, anexos do Mail, Xcode, npm/Composer/Homebrew/etc., cache de navegadores, Docker, simuladores sem runtime | Caches: apagados de vez. Instaladores e backups: Lixo |
| Projetos | `node_modules`, `vendor`, `.next`, `target`, `.build`, `Pods`… de projetos parados | Apagados de vez (voltam com um install) |
| Arquivos grandes | Seus arquivos acima de N MB, com data de último uso | Lixo |
| Duplicados | Cópias idênticas byte a byte (tamanho → 64 KB → SHA-256) | Lixo |
| Mapa do disco | Tamanho de cada pasta, navegável, pasta pessoal ou disco inteiro | Lixo |
| Desinstalar apps | App + tudo o que ele espalhou em `~/Library` | Lixo |
| Restos de apps | Dados de apps que já foram apagados | Lixo |
| Inicialização | Launch agents/daemons com verificação de assinatura | Desativar (reversível) ou Lixo |
| Sistema | CPU, memória, rede, processos | — |
| Manutenção | Liberar RAM, snapshots locais, DNS, Spotlight, Abrir Com, fontes, verificar disco | — |

## Segurança

Toda remoção passa por `SafetyGuard` (`Sources/CleenKit/Core/SafetyGuard.swift`):
nunca remove pastas do sistema, as pastas principais da conta (`~/Library`,
`~/Documents`…), nada fora da pasta pessoal e de `/Applications`, e não deixa um
symlink no caminho levar a um desses lugares. O que você criou sempre vai para o
Lixo. Só o que se recria sozinho é apagado de vez.

## Privacidade

Nada é coletado nem enviado para o autor. O Cleen só usa a rede em dois casos:

- **Uso de IA:** os limites do plano do Claude vêm de `api.anthropic.com`, com o
  login que o próprio Claude Code guardou nas Chaves do macOS (o macOS pergunta antes
  de liberar). O gasto em tokens e os limites do Codex são lidos dos arquivos locais de cada um.
- **Ícone do site tocando:** quando uma aba do navegador toca algo sem capa, o Cleen
  pede o ícone ao próprio site daquela aba.

## Desenvolvimento

```bash
swift build                     # compila
swift test                      # testes da CleenKit (Swift Testing)
./scripts/bundle.sh             # gera build/Cleen.app
./scripts/bundle.sh --install   # instala em /Applications e abre
./scripts/dmg.sh                # gera build/Cleen.dmg
```

A versão do app vem da última tag (`v1.0.0` → 1.0.0). Para lançar uma versão: crie a
tag e rode `./scripts/dmg.sh`.

Para conferir telas: `--notch <aba>` abre o notch fixado numa aba, `--settings` abre
Ajustes, `--scan` já analisa, `--onboarding` repete o tour;
`./scripts/shoot-notch.sh <pasta>` fotografa todas as abas do notch.

Estrutura: `CleenKit` tem toda a lógica de disco e sistema, sem UI e testada
contra pastas temporárias. `Cleen` é o app (SwiftUI, isolamento padrão
`MainActor`).
