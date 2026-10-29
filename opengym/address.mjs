// Prints the Nabu Casa address (https://<remote_domain>) via the Supervisor's Core websocket, or HA's https external_url.
const ws = new WebSocket('ws://supervisor/core/websocket');
const done = (s) => { console.log(s); ws.close(); process.exit(0); };
setTimeout(() => done(''), 10000);
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.type === 'auth_required') ws.send(JSON.stringify({ type: 'auth', access_token: process.env.SUPERVISOR_TOKEN }));
  else if (m.type === 'auth_ok') ws.send(JSON.stringify({ id: 1, type: 'cloud/status' }));
  else if (m.id === 1) {
    const r = m.result || {};
    console.error('cloud/status success=' + m.success + ' remote_enabled=' + r.remote_enabled + ' has_domain=' + !!r.remote_domain);
    if (r.remote_domain) return done('https://' + r.remote_domain);
    ws.send(JSON.stringify({ id: 2, type: 'get_config' }));
  } else if (m.id === 2) {
    const u = (m.result || {}).external_url || '';
    done(u.startsWith('https://') ? u.replace(/\/$/, '') : '');
  } else if (m.type === 'auth_invalid') done('');
};
