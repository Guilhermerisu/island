const discord = /(?:^|[\s./_-])(?:discord(?:canary|ptb)?|vesktop|webcord)(?:$|[\s./_-])/i;
const generic = /^(?:discord|vesktop|webcord|incoming (?:voice |video )?call|входящий (?:аудио|видео)?звонок)$/i;

function callerIn(text) {
  return /^(?:incoming (?:voice |video )?call from|(?:входящий )?(?:видео|аудио)?звонок от)\s+(.+?)[.!…]?$/iu.exec(text)?.[1]
    || /^(.+?)\s+(?:is calling(?: you)?|звонит(?: вам)?)[.!…]?$/iu.exec(text)?.[1] || '';
}

export function incomingCall(row) {
  const summary = String(row.summary || '').trim();
  const body = String(row.body || '').trim();
  const category = String(row.category || '');
  const source = [row.app, row.appIcon, row.desktopEntry].join(' ');
  const caller = callerIn(summary) || callerIn(body);
  if (!discord.test(source) && !/^discord$/i.test(summary)) return null;
  if (category !== 'call.incoming' && !caller && !generic.test(summary === 'Discord' ? body : summary)) return null;
  if (category && category !== 'call.incoming' && category !== 'call') return null;
  if (!caller && category !== 'call.incoming' && !/^(incoming |входящий )/iu.test(summary)) return null;
  const name = caller || [summary, body].find(text => text && !generic.test(text)) || '';
  const accept = (row.actions || []).findIndex(action =>
    /^(?:accept|answer|join)(?:[-_ ](?:call|voice|video))*$/i.test(String(action.id || ''))
      || /^(?:accept(?: call)?|answer(?: call)?|join call|принять(?: звонок)?|ответить(?: на звонок)?)$/iu.test(String(action.label || '').trim()));
  return { name, accept };
}

export function bypassDoNotDisturb(notification, enabled) {
  if (!enabled) return false;
  const hints = notification.hints || {};
  return !!incomingCall({
    app: notification.appName,
    appIcon: notification.appIcon,
    desktopEntry: hints['desktop-entry'],
    category: hints.category,
    summary: notification.summary,
    body: String(notification.body || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' '),
  });
}
