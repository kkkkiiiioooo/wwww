import http from 'http';import fs from 'fs';import path from 'path';import crypto from 'crypto';
import{fileURLToPath}from'url';import pty from'@lydell/node-pty';import{WebSocketServer}from'ws';
const dir=path.dirname(fileURLToPath(import.meta.url)),nm=path.join(dir,'node_modules');
const{PORT=7681,HOST='0.0.0.0'}=process.env,SH=process.env.SHELL||'/bin/bash';
const TOKEN=process.env.TOKEN||crypto.randomBytes(6).toString('hex');
const F={'/':[path.join(dir,'index.html'),'text/html'],'/t':[path.join(dir,'term.html'),'text/html'],'/x.js':[nm+'/@xterm/xterm/lib/xterm.js','text/javascript'],'/x.css':[nm+'/@xterm/xterm/css/xterm.css','text/css'],'/f.js':[nm+'/@xterm/addon-fit/lib/addon-fit.js','text/javascript']};
const ok=(u)=>u.searchParams.get('t')===TOKEN;
const srv=http.createServer((q,r)=>{const u=new URL(q.url,'http://x'),f=F[u.pathname];
  if(!f||!ok(u)){r.writeHead(f?401:404);return r.end()}
  fs.readFile(f[0],(e,d)=>{if(e){r.writeHead(404);return r.end()}r.writeHead(200,{'Content-Type':f[1]});r.end(d)})});
srv.on('connection',(s)=>s.setNoDelay(true));
const wss=new WebSocketServer({noServer:true});
srv.on('upgrade',(q,s,h)=>{const u=new URL(q.url,'http://x');if(u.pathname!=='/ws'||!ok(u)){s.destroy();return}wss.handleUpgrade(q,s,h,(ws)=>conn(ws,u))});
function conn(ws,u){const p=pty.spawn(SH,[],{name:'xterm-256color',cols:+u.searchParams.get('cols')||80,rows:+u.searchParams.get('rows')||24,cwd:process.env.HOME,env:{...process.env,LANG:process.env.LANG||'C.UTF-8'}});
  const hb=setInterval(()=>ws.readyState===1&&ws.ping(),20000);p.onData((d)=>ws.readyState===1&&ws.send(d));p.onExit(()=>ws.close());
  ws.on('message',(m)=>{const s=m.toString();if(s[0]==='{'){try{const j=JSON.parse(s);if(j.type==='resize'){p.resize(j.cols,j.rows);return}if(j.type==='dbg'){global.DB=1;fs.appendFile('/tmp/wt-dbg.log',JSON.stringify(j)+'\n',()=>{});return}}catch{}}if(global.DB&&s.length>1)fs.appendFile('/tmp/wt-dbg.log',JSON.stringify({type:'dbg',ev:'IN',data:s.slice(0,60)})+'\n',()=>{});p.write(s)});
  ws.on('close',()=>{clearInterval(hb);p.kill()})}
srv.listen(PORT,HOST,()=>console.log(`http://IP:${PORT}/?t=${TOKEN}`));
