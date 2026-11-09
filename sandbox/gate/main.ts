// Gate entry point (TASK-042). Configured by environment, set by scripts\sandbox.ps1:
//   GATE_PROXY_PORT  forward proxy port on the sandbox network (default 3128)
//   GATE_ROUTER      the router, host:port, passed on GATE_ROUTER_PORT (defaults host.docker.internal:4000, 4000),
//                    and through the proxy as http://<GATE_NAME>:<GATE_ROUTER_PORT> (default name gate)
//   GATE_FORWARDS    TCP forwards into the sandbox, "<listen>=<host>:<port>,..."
//   GATE_DNS_PORT    the placeholder DNS for the sandbox, UDP (default 53)
import { createFakeDns, createForward, createGate, createRouterPass, parseForwards, routerHandler } from './gate.ts';

const [rhost, rport] = (process.env.GATE_ROUTER ?? 'host.docker.internal:4000').split(':');
const proxyPort = Number(process.env.GATE_PROXY_PORT ?? 3128);
const routerPort = Number(process.env.GATE_ROUTER_PORT ?? 4000);
const say = (o: object) => console.log(JSON.stringify({ t: new Date().toISOString(), ...o }));
const toRouter = routerHandler({ target: { host: rhost, port: Number(rport) } });
createGate({ local: { hosts: [process.env.GATE_NAME ?? 'gate'], port: routerPort, handle: toRouter, tunnelTo: routerPort } }).listen(proxyPort, () => say({ proxy: proxyPort }));
createRouterPass(toRouter).listen(routerPort, () => say({ router: `${routerPort} -> ${rhost}:${rport}` }));
for (const f of parseForwards(process.env.GATE_FORWARDS ?? '')) {
  createForward(f).listen(f.listen, () => say({ forward: `${f.listen} -> ${f.host}:${f.port}` }));
}
const dnsPort = Number(process.env.GATE_DNS_PORT ?? 53);
createFakeDns().bind(dnsPort, () => say({ dns: dnsPort }));
for (const sig of ['SIGTERM', 'SIGINT']) process.on(sig, () => process.exit(0));
