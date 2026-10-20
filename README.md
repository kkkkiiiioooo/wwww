# Web terminal v4.2

## Inicio rapido

```bash
BROWSER=firefox bash ./start.sh
```

Se `BROWSER` (ou `browser`) estiver definido, `./start.sh` abre a aplicacao automaticamente nesse navegador quando o servidor ficar pronto.

O `start.sh` e um script em **bash** e, se `node`/`npm` nao estiverem disponiveis, instala automaticamente o **Node.js LTS** pelo script oficial para Debian da NodeSource antes de iniciar o projeto.
