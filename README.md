# Omarchy Audio

App nativo para macOS, feito em SwiftUI e AVFoundation, para ouvir no Mac o áudio
que está tocando no Omarchy. Fica na barra de menus, como o Dita, e também tem
uma janela compacta com volume, mute e visualização do sinal recebido.

## Abrir e conectar

Abra `build/Omarchy Audio.app` no Finder ou execute:

```bash
open "$HOME/develop/omarchy-audio/build/Omarchy Audio.app"
```

Clique em **Ouvir Omarchy** e coloque uma música ou vídeo para tocar no Linux.
O som sai no dispositivo selecionado nos Ajustes de Som do Mac. O botão ao lado
do nome da saída abre esses ajustes. **Desconectar** encerra a captura remota;
fechar a janela mantém o app e a transmissão na barra de menus. **Sair** encerra ambos.

O host inicial é `arch`, usando o usuário, a porta e a chave já configurados no SSH
do macOS. O botão de engrenagem permite mudar o alias. Host e volume são preservados.
Não é necessário iniciar a transmissão pelo Terminal nem usar o atalho `ouvir-omarchy`.

## Requisitos

- macOS 14 ou superior; este app foi validado no macOS 26 com Apple Silicon.
- `/usr/bin/ssh` com uma conexão por chave já configurada, sem pedido de senha.
- No Omarchy: PipeWire/PulseAudio em execução e os comandos `pactl` e `parec`.
- Para compilar: Command Line Tools do Xcode (Swift 6). Sem pacotes externos.

O áudio usa AVAudioEngine/AVAudioSourceNode nativos: não depende de FFmpeg,
servidor de áudio extra, captura de microfone ou driver virtual. O app não lê
chaves privadas; o próprio OpenSSH usa a configuração existente. É uma aplicação
local assinada ad hoc, sem notarização para distribuição pública.

## Desenvolvimento

```bash
swift run AudioChecks
bash scripts/build-app.sh
open "build/Omarchy Audio.app"
```

Para verificar a conexão real e o renderizador por seis segundos (com o app
fechado), execute `"build/Omarchy Audio.app/Contents/MacOS/OmarchyAudio" --check-stream`.
Esse diagnóstico toca o áudio remoto na saída do Mac, imprime os contadores de
frames recebidos/reproduzidos e encerra a conexão, retornando erro se não houver fluxo.

`AudioChecks` é um executável de verificação, para executar de fato as asserções
mesmo em máquinas com apenas Command Line Tools, sem depender do runner XCTest.
Ele cobre pacotes fragmentados, canais, sinais, underrun, overflow, concorrência
e validação de host, incluindo a reserva contra variações da rede (16 verificações).
Build e assinatura ficam dentro do projeto. Depois de recompilar, feche o app
anterior e abra o `.app` novamente para carregar a nova versão.

## Funcionamento e limites

Um processo SSH dedicado executa `parec` no monitor da saída padrão do Linux.
O app recebe PCM estéreo de 16 bits a 48 kHz, converte para Float32 e alimenta o
renderizador nativo. Uma reserva inicial de 100 ms absorve variações da rede.
A fila mantém no máximo 500 ms de áudio, descartando o mais antigo quando há
acúmulo. Esse limite não representa a latência total da rede.
O renderizador nunca espera pelo lock do produtor: em underrun ele emite silêncio.

O indicador mostra o sinal remoto antes do volume e do mute locais. Silêncio é
um fluxo válido e mantém a conexão ativa. Se o SSH termina ou deixa de enviar
dados, o app apresenta o erro e permite reconectar. Não há reconexão automática.
Ao desconectar ou sair, o SSH dedicado é encerrado; isso fecha a captura remota.

Se mudar a saída padrão no Omarchy, desconecte e conecte novamente. A transmissão
pode causar atraso perceptível em vídeos. O app não silencia a saída física do Linux.
O áudio passa diretamente pela memória e não é salvo em arquivo.

Se o app não conectar, teste `ssh arch` no Terminal. Isso permite confirmar a
identidade do host e corrigir a autenticação, sem inserir senhas no app.
