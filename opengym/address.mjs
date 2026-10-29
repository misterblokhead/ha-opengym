// Prints HA's https external_url, else the Nabu Casa address (https://<remote_domain>) when remote access is on, via the
// Supervisor's Core websocket: the order ChallengeHouse prefills in. Node 22's global WebSocket.
const ws = new WebSocket('ws://supervisor/core/websocket');
const done = (s) => { console.log(s); ws.close(); process.exit(0); };
setTimeout(() => done(''), 10000);
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.type === 'auth_required') ws.send(JSON.stringify({ type: 'auth', access_token: process.env.SUPERVISOR_TOKEN }));
  else if (m.type === 'auth_ok') ws.send(JSON.stringify({ id: 1, type: 'get_config' }));
  else if (m.id === 1) {
    const u = (m.result || {}).external_url || '';
    if (u.startsWith('https://')) return done(u.replace(/\/$/, ''));
    ws.send(JSON.stringify({ id: 2, type: 'cloud/status' }));
  } else if (m.id === 2) {
    const r = m.result || {};
    console.error('cloud/status success=' + m.success + ' remote_enabled=' + r.remote_enabled + ' has_domain=' + !!r.remote_domain);
    done(r.remote_enabled && r.remote_domain ? 'https://' + r.remote_domain : '');
  } else if (m.type === 'auth_invalid') done('');
};
