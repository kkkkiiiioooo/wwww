# webtermv4 — terminal web leve (estilo ttyd)

Um único terminal no navegador (sem abas), feito para rodar em navegadores limitados como o da **TV Samsung 2024 (Tizen)**. É a versão leve do projeto: xterm.js + PTY via WebSocket, sem framework e sem WASM.

## Como usar
- Subir tudo (servidor + túnel + vigia): `setsid bash tunel.sh &` (na raiz do repositório)
- Link fixo: http://bore.pub:37682/?t=TerminalSecreto
- Só o servidor local: `cd apps/webtermv4; npm i; TOKEN=abc npm start` e abrir http://IP:7681/?t=abc
- Variáveis: HOST (0.0.0.0), PORT (7681), TOKEN (aleatório se vazio), SHELL (/bin/bash)

## Flags e parâmetros (manual)
**Parâmetros da URL**
| Parâmetro | Obrigatório | O que faz |
|---|---|---|
| `t=TOKEN` | sim | Senha. Sem ele (ou errado) o servidor responde 401 e derruba o WebSocket. Fixo: `TerminalSecreto`. |
| `dbg=1` | não | Modo diagnóstico: cada evento de teclado do terminal (keydown, beforeinput, input, composition*) é enviado ao servidor e gravado. Não muda o comportamento do terminal; só acrescenta um pequeno envio por tecla. |
| `noauto=1` | não | Desliga a tela cheia automática e o foco/teclado automático (os botões continuam). Serve para comparar quando algo (ex.: ditado) falha. |

Exemplos: `http://bore.pub:37682/?t=TerminalSecreto` (normal) e `http://bore.pub:37682/?t=TerminalSecreto&dbg=1` (diagnóstico).

**Onde o debug é escrito:** no arquivo `/tmp/wt-dbg.log` da **máquina onde o servidor roda** (o sandbox), uma linha JSON por evento (ev, key, code, kc=keyCode, data, it=inputType, comp=isComposing). Não aparece na tela nem no navegador. Não há limpeza nem rotação (apague com `: > /tmp/wt-dbg.log`) e o arquivo some quando o sandbox é trocado. Ler sem encher a tela: `tail -n 20 /tmp/wt-dbg.log | cut -c1-170`.

**Variáveis de ambiente do servidor (`server.js`)**
| Variável | Padrão | Função |
|---|---|---|
| `PORT` | 7681 | Porta HTTP/WebSocket local |
| `HOST` | 0.0.0.0 | Endereço de escuta |
| `TOKEN` | aleatório | Senha (o `tunel.sh` fixa `TerminalSecreto`) |
| `SHELL` | /bin/bash | Programa iniciado no terminal |
| `LANG` | `C.UTF-8` se vazio | Idioma do PTY (necessário para acentos e símbolos) |

**Variável do vigia (`tunel.sh`)**
| Variável | Padrão | Função |
|---|---|---|
| `RP` | 37682 | Porta pública no bore.pub (muda sozinha para 37683… se a porta ficar presa) |

**Rotas:** `/` página externa (barra + iframe), `/t` terminal, `/ws` WebSocket, `/x.js`, `/x.css`, `/f.js` (xterm). Todas exigem `?t=`.
**Comandos úteis:** logs do vigia `/tmp/tunel.log`; link atual `/tmp/tunel.link`; religar `setsid bash tunel.sh &`.

## Arquitetura
Navegador → `/` (index.html: barra fina + iframe) → iframe `/t` (term.html: xterm.js) → WebSocket `/ws` → server.js → PTY (@lydell/node-pty) → bash.
Fora do sandbox: bore.pub:37682 → túnel (bore) → localhost:7681.

## Arquivos
- `server.js`: HTTP + WebSocket + PTY. Token obrigatório (`?t=`), 401 sem token. Ping a cada 20 s no WebSocket.
- `index.html`: página externa. Barra de 20 px com 2 botões e o iframe do terminal.
- `term.html`: o terminal (xterm.js + addon-fit), reconecta sozinho em 2 s.
- `package.json`: dependências (@xterm/xterm, @xterm/addon-fit, ws, @lydell/node-pty).

## Decisões e motivos (o que foi feito e por quê)
1. **xterm.js em vez de ghostty-web**: sem WASM e ~3 MB de node_modules; muito mais leve que a v1 (ghostty-web + SolidJS), que travava a TV.
2. **Terminal dentro de um iframe + botão no pai**: o teclado virtual da TV só abre quando o foco muda para o campo de texto. O botão ⌨ (na página externa) move o foco para dentro do iframe (`term.focus()`), e isso abre o teclado. Foi isto que fez o teclado funcionar na TV.
3. **Barra fina de 20 px**: botão ⌨ (teclado) e botão ↗ (abre nova aba com o endereço **atual**, `location.href`, então funciona com qualquer túnel). Uma barra de entrada maior foi testada e descartada por roubar espaço.
4. **Campo interno do xterm visível (24 px, quase transparente) + inputmode=text**: o campo original ficava fora da tela (left:-9999em), e alguns navegadores não abrem o teclado para isso.
5. **Barra de espaço (bug do Tizen/ttyd)**: o espaço não chegava ao xterm em alguns casos (só funcionava quando a tela atualizava rápido). Solução: capturar `keydown` (key=" ") e `beforeinput` (data=" ") na fase de captura do campo e enviar o espaço direto ao WebSocket, com `stopImmediatePropagation` para não duplicar. Não interfere durante composição de IME (keyCode 229).
6. **Ping a cada 20 s no WebSocket**: mantém a conexão viva quando você fica sem digitar (sintoma observado: "parece que a conexão cai quando não digito").
7. **Token fixo `TerminalSecreto`**: a senha. É fraca de propósito (pedido do usuário); trocar se o uso for sério, pois quem acertar tem um shell.
8. **Caracteres especiais (cedilha, acentos, euro, libra)**: o teclado da TV envia esses caracteres de formas diferentes (keydown com `key` nao-ASCII e keyCode 229, ou `beforeinput`). Solucao: na fase de captura do campo do xterm, se `keydown.key` ou `beforeinput.data` tiver caractere nao-ASCII e nao estiver em composicao (IME), enviamos o texto direto ao WebSocket e cancelamos o evento (sem duplicar). Composicao de acento morto continua com o xterm.
9. **Locale UTF-8 no PTY**: o ambiente nao tinha LANG, entao o bash/readline mostrava bytes (`\303\247`) em vez de caracteres. O servidor agora define `LANG=C.UTF-8` quando vazio.
10. **Modo diagnostico**: abrir a URL com `&dbg=1` grava os eventos de teclado (keydown/beforeinput/input/composition) em `/tmp/wt-dbg.log` no servidor. Use para investigar teclas que falhem no aparelho.
11. **Digitacao por voz (ditado)**: o ditado costuma chegar como `input` com `inputType` = `insertReplacementText` ou `insertFromComposition`, que o xterm ignora. Na fase de captura enviamos `e.data` (ou o valor do campo) ao WebSocket e limpamos o campo. **Pendente de teste na TV.** Se falhar: abrir a URL com `&dbg=1`, ditar uma frase e ler `/tmp/wt-dbg.log` no servidor para ver os eventos reais. Tentativa descartada: reenviar o valor do campo apos cada `input` (duplica letras digitadas normalmente).
12. **Tela cheia**: botão "Tela cheia"/"Sair" na barra (alterna, usa a API Fullscreen com prefixo webkit). Automático: navegadores só permitem tela cheia após um gesto do usuário, então ela é ativada **uma vez** no primeiro toque/tecla (na barra ou no terminal; o terminal avisa a página externa). Se você sair, ela não volta sozinha; use o botão. Pendente de teste na TV.
13. **Teclas especiais na barra**: Esc, Tab, Ctrl (fixo: toque nele e depois numa letra; fica laranja e solta sozinho), ^C, ^D, setas, Home, End, PgUp, PgDn, Del. Os botões chamam `sk()` dentro do iframe (envia a sequência ao WebSocket) e devolvem o foco ao terminal para o teclado não fechar. A barra rola na horizontal se faltar espaço; mantém 20 px. Testado no Chromium (seta, Ctrl+letra, ^C, altura); na TV pendente.
14. **Teclado automático (melhor esforço)**: ao carregar o terminal e no primeiro toque/tecla a página tenta focar o campo; ao entrar/sair da tela cheia também. Navegadores só abrem o teclado virtual após um gesto, então no primeiro toque ele deve abrir, mas sem toque algum pode não abrir. Pendente na TV.
15. **Regressão do ditado (hipótese, a confirmar na TV)**: depois das teclas especiais/tela cheia o ditado parou. Suspeitos: (a) qualquer *tecla* (inclusive a do microfone do controle) disparava a tela cheia automática e o refoco; (b) `kb()` tirava e devolvia o foco do campo (blur/focus reinicia a sessão de voz). Correção: a tela cheia automática agora só reage a clique/toque (não a teclas) e `kb()` não faz nada se o campo já está focado. Testado em Chromium: tecla não dispara, clique dispara 1 vez, campo sem blur, ditado simulado ok. Se ainda falhar: comparar com `&noauto=1` e depois `&dbg=1`.

## Túnel e vigia (tunel.sh)
- Usa o **bore** (sem conta/chave). Porta remota fixa 37682 → link sempre igual. Porta ocupada: o script tenta de novo; após 8 falhas seguidas troca para 37683, 37684… (link novo em `/tmp/tunel.link`).
- **Vigia**: a cada 15 s testa o servidor local e a URL pública (ponta a ponta). Se o servidor cair, reinicia. Se a URL pública falhar 2 vezes seguidas (túnel "meio morto": o processo bore vivo mas sem tráfego), reinicia o bore. O próprio teste gera tráfego e mantém o túnel ativo.
- Log: `/tmp/tunel.log`. PID do vigia: `/tmp/tunel.pid` (uma única instância; rodar de novo substitui a antiga).
- **Limite honesto**: o vigia roda dentro do sandbox. Se o sandbox inteiro for encerrado, tudo para; é preciso religar com `setsid bash tunel.sh &`.

## Testes feitos (2026-10-18)
| Teste | Resultado |
|---|---|
| `/` sem token | 401 |
| `/`, `/t`, xterm.js, css, fit com token | 200 |
| Digitar no shell pelo WebSocket | OK (eco `AB2`) |
| Chromium headless pelo link público: botão ⌨ foca o campo, digitar, espaços (`echo A B  C` → `A B C`) | OK, sem duplicar |
| Vigia: bore congelado (SIGSTOP) | detectado e reiniciado em ~30 s, link voltou 200 |
| Vigia: servidor node morto (SIGKILL) | reiniciado em ~15 s, link 200 |
| TV Samsung 2024: teclado | OK (confirmado pelo usuário) |
| TV Samsung 2024: barra de espaço com a correção | OK (confirmado pelo usuário) |
| Chromium headless: caracteres cedilha, euro, e agudo, libra (via insertText, keydown 229 e beforeinput) | OK, 1 vez cada, shell em UTF-8 |
| TV Samsung 2024: caracteres especiais | **pendente de teste humano** |

## Limitações conhecidas
- Reconectar abre um shell novo (a sessão anterior é perdida). Para persistir, rodar `tmux` dentro do terminal.
- Sem abas, temas ou histórico (fora de escopo).
- bore.pub é um serviço público e gratuito: a porta pode ser ocupada por terceiros; HTTP sem TLS (o token trafega em texto claro).

## Versão e temporizadores (taxas de atualização)
- **Versão na barra superior**: `vX.Y tX.Y` = versão do index.html + versão do term.html (iframe). Se os dois não forem iguais ou ficar `t?`, o navegador está com cache antigo. Mudar `IV` (index.html) e `V` (term.html) a cada alteração visível.
- Reconexão do WebSocket: 0,5 s (`setTimeout(go,500)` no term.html; era 2 s até v4.1b). Entrada enviada com o socket fechado é descartada em silêncio (sx testa readyState===1).
- Supervisor tunel.sh: testa node e túnel a cada 15 s.
- Modo dbg=1: checa o texto interno do campo de entrada (VAL) a cada 150 ms.
- xterm 5.5.0, renderizador DOM padrão (sem addon canvas/webgl). Só desenha a saída; não participa da entrada de voz.
- Ditado: o xterm 5.5.0 lê texto de keydown 229 comparando o campo após `setTimeout` de 0 ms (`_handleAnyTextareaChanges`, lib/xterm.js); texto que chega depois disso é perdido.

## v4.2 (ditado)
beforeinput insertText até 1,5 s depois de keydown 229 é enviado direto ao shell, com ou sem acento (contorna o xterm 5.5.0, que descarta: PR #6009 e issues #6045/#6185 em github.com/xtermjs/xterm.js, todos abertos). Rollback: git checkout 4-palavras-funcionam.
