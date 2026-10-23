# Cleen

## Decisões fixas (não mudar sem o dono pedir)

- **Espelho: a imagem é espelhada.** `MirrorModel.fixOrientation()` define
  `automaticallyAdjustsVideoMirroring = false` e `isVideoMirrored = true` depois que a
  câmera já está rodando. Não deixar no automático do macOS e não remover: a orientação
  já inverteu sem querer duas vezes.
