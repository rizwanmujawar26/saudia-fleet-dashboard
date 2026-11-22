/**
 * Saudia Connectivity Fleet Status — daily Google Sheet feed.
 *
 * A Google Apps Script bound to a private Google Sheet. Once a day it reads every
 * dashboard node from the Firebase Realtime Database and rewrites one tab per area
 * as plain rows, then records what changed since yesterday on the "Changes" tab.
 *
 * Auth: the script runs as the Sheet owner, who also owns the Firebase project, and
 * reads with that Google account's OAuth token (?access_token=). No password, key or
 * secret is stored anywhere. It only ever GETs.
 *
 * Setup (once): Extensions → Apps Script, paste this file and appsscript.json, run
 * setup(), click Allow. See PROJECT_HANDOFF.md › "Google Sheet feed".
 *
 * Dates follow the dashboard: DD-Mon-YYYY, never month-first. Timestamps stored as
 * ISO UTC become "DD-Mon-YYYY HH:MM UTC".
 */

const FEED_DB = 'https://saudia-fleet-dashboard-default-rtdb.firebaseio.com';
const FEED_NODES = ['fleet', 'fleetSpecs', 'configs', 'aircraft', 'aircraftModem', 'activities', 'issues',
  'hardware', 'units', 'mediaLoads', 'mediaCycles', 'mediaCycleDisks', 'modmans', 'avr', 'assets', 'flights', 'audit'];
const FEED_HOUR = 6;                 // daily refresh, Asia/Riyadh (appsscript.json timeZone)
const FEED_CHANGES_KEEP_DAYS = 90;   // rows older than this drop off the Changes tab
const FEED_CELL_MAX = 45000;         // Sheets refuses cells over 50,000 characters

// ───────────────────────────── Apps Script entry points ─────────────────────────────

/** Run once by hand: installs the daily trigger and does the first refresh. */
function setup() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'dailyRefresh')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('dailyRefresh').timeBased().everyDays(1).atHour(FEED_HOUR).create();
  dailyRefresh();
}

/** The daily job (also safe to run by hand at any time). */
function dailyRefresh() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) return;
  try {
    const now = new Date();
    const data = fetchAllNodes_();
    const tabs = buildTabs(data, now.getTime());
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const changes = [];
    tabs.forEach(t => {
      t.rows = t.rows.map(r => r.map(cellOut_));   // compare exactly what the sheet will hold
      const sh = ss.getSheetByName(t.name) || ss.insertSheet(t.name);
      if (t.diff) {
        const prev = sh.getLastRow() > 0 ? sh.getDataRange().getDisplayValues() : null;
        diffTables(prev, t.rows).forEach(c => changes.push([fmtStamp(now.toISOString())].concat([t.name], c)));
      }
      writeTab_(sh, t.rows);
    });
    writeChanges_(ss, changes, now);
    writeAbout_(ss, tabs, changes.length, now);
    orderTabs_(ss, ['About', 'Changes'].concat(tabs.map(t => t.name)));
    const to = PropertiesService.getScriptProperties().getProperty('DIGEST_TO');
    if (to && changes.length) sendDigest_(to, ss, changes, now);
  } finally {
    lock.releaseLock();
  }
}

function fetchAllNodes_() {
  const token = ScriptApp.getOAuthToken();
  const reqs = FEED_NODES.map(n => ({
    url: FEED_DB + '/' + n + '.json?access_token=' + encodeURIComponent(token),
    muteHttpExceptions: true,
  }));
  const res = UrlFetchApp.fetchAll(reqs);
  const out = {};
  res.forEach((r, i) => {
    const code = r.getResponseCode();
    // A failed read must stop the run: writing a half-empty sheet would look like data loss
    // and fill the Changes tab with false "removed" rows.
    if (code !== 200) throw new Error('Read /' + FEED_NODES[i] + ' failed: HTTP ' + code + ' ' + r.getContentText().slice(0, 200));
    out[FEED_NODES[i]] = JSON.parse(r.getContentText()) || {};
  });
  if (!Object.keys(out.fleet).length) throw new Error('/fleet came back empty — refusing to overwrite the sheet');
  return out;
}

function writeTab_(sh, rows) {
  sh.clearContents();
  const width = rows[0].length;
  // A text cell starting with "=" would still be read as a formula; the apostrophe keeps it text
  // and is not part of the displayed value, so tomorrow's diff still matches.
  const body = rows.map(r => r.map(v => { const s = cellOut_(v); return s.charAt(0) === '=' ? "'" + s : s; }));
  sh.getRange(1, 1, body.length, width).setNumberFormat('@').setValues(body);
  sh.setFrozenRows(1);
  sh.getRange(1, 1, 1, width).setFontWeight('bold');
  const extraCols = sh.getMaxColumns() - width;
  if (extraCols > 0) sh.deleteColumns(width + 1, extraCols);
  const extraRows = sh.getMaxRows() - body.length;
  if (extraRows > 1) sh.deleteRows(body.length + 2, extraRows - 1);
}

function cellOut_(v) {
  const s = v == null ? '' : String(v);
  return s.length > FEED_CELL_MAX ? s.slice(0, FEED_CELL_MAX) + ' …[truncated]' : s;
}

function writeChanges_(ss, changes, now) {
  const head = ['Refreshed', 'Tab', 'Key', 'Change', 'Field', 'Before', 'After'];
  const sh = ss.getSheetByName('Changes') || ss.insertSheet('Changes');
  let old = sh.getLastRow() > 1 ? sh.getRange(2, 1, sh.getLastRow() - 1, head.length).getDisplayValues() : [];
  const cutoff = now.getTime() - FEED_CHANGES_KEEP_DAYS * 864e5;
  old = old.filter(r => { const t = parseStamp(r[0]); return t == null || t >= cutoff; });
  const fresh = changes.length ? changes : [[fmtStamp(now.toISOString()), '—', '', 'No changes', '', '', '']];
  writeTab_(sh, [head].concat(fresh, old));
}

function writeAbout_(ss, tabs, nChanges, now) {
  const sh = ss.getSheetByName('About') || ss.insertSheet('About');
  const rows = [
    ['Saudia Connectivity Fleet Status — daily data feed', ''],
    ['Last refreshed', fmtStamp(now.toISOString())],
    ['Refresh schedule', 'Daily at ' + ('0' + FEED_HOUR).slice(-2) + ':00 Riyadh time'],
    ['Changes since previous refresh', String(nChanges)],
    ['Source', 'Firebase Realtime Database behind the dashboard (read-only copy)'],
    ['Date format', 'DD-Mon-YYYY; timestamps are UTC'],
    ['', ''],
    ['Tab', 'Rows'],
  ].concat(tabs.map(t => [t.name, String(t.rows.length - 1)]));
  writeTab_(sh, rows);
  sh.setFrozenRows(0);
  sh.getRange(1, 1).setFontWeight('bold');
  sh.getRange(8, 1, 1, 2).setFontWeight('bold');
}

function orderTabs_(ss, names) {
  names.forEach((n, i) => {
    const sh = ss.getSheetByName(n);
    if (sh) { ss.setActiveSheet(sh); ss.moveActiveSheet(i + 1); }
  });
  ss.getSheets().forEach(sh => { if (sh.getName() === 'Sheet1' && sh.getLastRow() === 0) ss.deleteSheet(sh); });
  ss.setActiveSheet(ss.getSheetByName('About'));
}

function sendDigest_(to, ss, changes, now) {
  const lines = changes.slice(0, 200).map(c => '• ' + c[1] + ' › ' + c[2] + ' — ' + c[3] +
    (c[4] ? ' ' + c[4] + ': ' + (c[5] || '∅') + ' → ' + (c[6] || '∅') : ''));
  MailApp.sendEmail({
    to: to,
    subject: 'Saudia fleet feed — ' + changes.length + ' change(s) — ' + fmtDate(now.toISOString()),
    body: lines.join('\n') + (changes.length > 200 ? '\n… and ' + (changes.length - 200) + ' more' : '') +
      '\n\nFull sheet: ' + ss.getUrl(),
  });
}

// ───────────────────────────── Pure helpers (tested locally) ─────────────────────────────

const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** ISO UTC → "DD-Mon-YYYY HH:MM UTC"; anything else passes through untouched. */
function fmtStamp(v) {
  if (typeof v === 'number') v = new Date(v).toISOString();
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(v || '');
  return m ? m[3] + '-' + MON[+m[2] - 1] + '-' + m[1] + ' ' + m[4] + ':' + m[5] + ' UTC' : (v == null ? '' : String(v));
}
/** ISO UTC → "DD-Mon-YYYY"; a stored DD-Mon-YYYY passes through. */
function fmtDate(v) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(v || '');
  return m ? m[3] + '-' + MON[+m[2] - 1] + '-' + m[1] : (v == null ? '' : String(v));
}
function parseStamp(s) {
  const m = /^(\d{2})-([A-Z][a-z]{2})-(\d{4})(?: (\d{2}):(\d{2}))?/.exec(s || '');
  if (!m) return null;
  return Date.UTC(+m[3], MON.indexOf(m[2]), +m[1], +(m[4] || 0), +(m[5] || 0));
}
/** Sort key for a stored DD-Mon-YYYY date (undated sorts last). */
function dateKey(s) { const t = parseStamp(s); return t == null ? 9e15 : t; }

function yn(v) { return v === true ? 'Yes' : v === false ? 'No' : (v == null ? '' : String(v)); }
function txt(v) { return v == null ? '' : (typeof v === 'object' ? JSON.stringify(v) : String(v)); }
function entries(o) { return Object.keys(o || {}).map(k => [k, o[k] || {}]); }
function byKey(a, b) { return a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0; }

const LRU_LABEL = {
  sim: 'SIM Card', ife_server: 'IFE Server', modman: 'MODMAN', kandu: 'KANDU', krfu: 'KRFU',
  rx_antenna: 'RX Antenna', tx_antenna: 'TX Antenna', cwap: 'CWAP',
  lf_kandu: 'KANDU (linefit)', lf_krfu: 'KRFU (linefit)', lf_rx_antenna: 'RX Antenna (linefit)', lf_tx_antenna: 'TX Antenna (linefit)',
};
const OPS_LABEL = { aog: 'AOG', c_check: 'C-Check', scheduled_maint: 'Scheduled maintenance', storage: 'Storage', active: 'In service' };

/** A unit's current fitment: the installed one, else the latest by fitted date. */
function currentFitment(u) {
  const fs = Object.keys(u.fitments || {}).map(k => u.fitments[k]);
  const on = fs.filter(f => f.state === 'installed' && !f.removedDate);
  const pool = on.length ? on : fs;
  pool.sort((a, b) => dateKey(b.fittedDate) - dateKey(a.fittedDate));
  return pool[0] || null;
}

/**
 * Turns the raw database into the sheet's tabs: [{ name, diff, rows: [header, ...] }].
 * Column A of every diffed tab is a stable key, so the Changes tab can pair rows across days.
 */
function buildTabs(d, nowMs) {
  const fleet = d.fleet || {}, specs = d.fleetSpecs || {}, cfgs = d.configs || {}, ac = d.aircraft || {};
  const tails = Object.keys(fleet).sort();
  const tabs = [];
  const add = (name, head, rows, diff) => tabs.push({ name: name, diff: diff !== false, rows: [head].concat(rows.sort(byKey)) });
  const statusOf = t => (fleet[t] && fleet[t].fleetStatus) || '';
  const fitOf = t => !statusOf(t) ? '' : (fleet[t].fit === 'linefit' ? 'Linefit' : 'Retrofit');

  // Fleet — one row per aircraft on the roster.
  add('Fleet', ['Tail', 'Type', 'Variant', 'MSN', 'Config', 'IFE supplier', 'IFE system', 'Fit', 'Status', 'Connectivity scope',
    'System', 'Delivered', 'Delivery date', 'Seats (J/Y/total)', 'Engines', 'Retrofit start', 'Retrofit end', 'Install site',
    'Middleware date', 'Middleware site', 'Activated', 'Activation site', 'Operational state', 'Out since', 'Expected back',
    'Ops reason', 'Ops location', 'Comments', 'Note'], tails.map(t => {
    const f = fleet[t], s = specs[t] || {}, a = ac[t] || {}, c = cfgs[f.config] || {}, o = a.ops || {};
    return [t, f.type, s.variant, s.msn, f.config, c.ifeSupplier, c.ifeSystem, fitOf(t), statusOf(t), f.scope, f.system,
      f.delivered === false ? 'No (future)' : 'Yes', s.deliveryDate,
      [s.seatBusiness, s.seatEconomy, s.seatTotal].map(txt).join(' / '),
      [s.engineQty && s.engineQty + '×', s.engineMfr, s.engineModel].filter(Boolean).join(' '),
      a.retrofitStart, a.retrofitEnd, a.retrofitLocation, a.completionDate, a.completionLocation, a.activatedDate,
      a.activationLocation, o.state ? (OPS_LABEL[o.state] || o.state) : '', o.since, o.expectedReturn, o.reason, o.location,
      f.comments, a.note].map(txt);
  }));

  // Software — every aircraft with a software record.
  add('Software', ['Tail', 'Status', 'Middleware version', 'Middleware date', 'Middleware site', 'OTA Patch #2', 'OTA Patch #3',
    'OTA Patch #4', 'OTA Patch #5', 'UGO version', 'Tiles version', 'IPHO', 'MG101 provisioning', 'SBC / Beam config',
    'SSID visibility', 'FLS6 version', 'FLS6 date', 'SBC config', 'SBC config date', 'Local config', 'Local config date'],
  Object.keys(ac).map(t => {
    const a = ac[t];
    return [t, statusOf(t), a.swVersion, a.completionDate, a.completionLocation, fmtStamp(a.otaPatchUTC), fmtStamp(a.otaPatch3UTC),
      fmtStamp(a.otaPatch4UTC), fmtStamp(a.otaPatch5UTC), a.ugoVersion, a.tilesVersion, a.iphoStatus, a.mg101Status,
      a.beamcfgStatus, a.wifiVisibility, a.fls6Version, a.fls6Date, a.sbcConfig, a.sbcConfigDate, a.localConfig, a.localConfigDate].map(txt);
  }));

  // Media — current media per aircraft, the loading log, and the monthly cycles.
  add('Media', ['Tail', 'Status', 'Current media', 'Cycle', 'Package', 'Loaded'],
    Object.keys(ac).filter(t => ac[t].media).map(t => {
      const m = ac[t].media;
      return [t, statusOf(t), m.mediaDisplay, m.mediaCycle, m.mediaSource, fmtStamp(m.loadedDateUTC)].map(txt);
    }));
  add('Media loads', ['Id', 'Tail', 'Cycle', 'Package', 'Loaded', 'Logged'], entries(d.mediaLoads).map(([id, m]) =>
    [id, m.aircraft, m.cycle, m.source, fmtStamp(m.loadedAt), fmtStamp(m.loggedAt)].map(txt)));
  add('Media cycles', ['Cycle', 'Start', 'End', 'Size', 'Content delivered', 'Downloaded', 'Disks duplicated', 'Disks to team',
    'Disk list frozen', 'Notes'], entries(d.mediaCycles).map(([id, c]) =>
    [id, c.start, c.end, c.size, c.contentDelivered, c.downloaded, c.disksDuplicated, c.disksToTeam,
      fmtStamp(c.disksSnapshotAt), c.notes].map(txt)));
  const cd = [];
  entries(d.mediaCycleDisks).forEach(([cyc, disks]) => entries(disks).forEach(([id, k]) =>
    cd.push([cyc + ' / ' + id, cyc, id, k.nsgSerial, k.type, k.make, k.mfrSerial, k.totalSize, k.content, k.location, k.custodian].map(txt))));
  add('Media cycle disks', ['Key', 'Cycle', 'Disk', 'NSG serial', 'Type', 'Make', 'Maker serial', 'Size', 'Content', 'Location', 'Custodian'], cd);

  // MODMAN register (/modmans) and the modem identities per aircraft (/aircraftModem).
  add('MODMAN', ['Id', 'Tail', 'Status', 'Install date', 'Removal date', 'Removal reason', 'Kontron S/N', 'Eclipse S/N',
    'Astronics S/N', 'Hughes ESN', 'Hughes MAC', 'Hughes chassis ID', 'Taurus MG ID (new)', 'Taurus TID (new)',
    'Taurus MG ID (old)', 'Taurus TID (old)', 'Hughes commissioned', 'Taurus commissioned', 'Shop status', 'Shop ref',
    'Shop finding', 'Notes', 'Added'], entries(d.modmans).map(([id, m]) =>
    [id, m.aircraft, m.status, m.installDate, m.removalDate, m.removalReason, m.kontronSn, m.eclipseSn, m.astronicsSn, m.hnsEsn,
      m.hnsMac, m.hnsChassisId, m.taurusNewMgId, m.taurusNewTid, m.taurusOldMgId, m.taurusOldTid, m.commHughes, m.commTaurus,
      m.shopStatus, m.shopRef, m.shopFinding, m.notes, fmtStamp(m.addedAt)].map(txt)));
  add('Modem', ['Tail', 'Taurus MG ID', 'Taurus TID', 'Taurus commissioned', 'Hughes chassis ID', 'Hughes ESN', 'Hughes commissioned'],
    entries(d.aircraftModem).map(([t, m]) => {
      const ta = m.taurus || {}, h = m.hughes || {};
      return [t, ta.mgId, ta.tid, ta.commissionedDate, h.chassisId, h.esn, h.commissionedDate].map(txt);
    }));

  // SIM register — one row per SIM card with where it is now.
  const units = entries(d.units);
  add('SIM', ['Unit id', 'ICCID / serial', 'Tail', 'State', 'Fitted', 'Removed', 'Removal reason', 'Roaming', 'Notes'],
    units.filter(([, u]) => u.lruId === 'sim').map(([id, u]) => {
      const f = currentFitment(u) || {};
      return [id, u.serial, f.aircraft, f.state || 'spare', f.fittedDate, f.removedDate, f.removalReason,
        yn(f.roaming != null ? f.roaming : u.roaming), [u.notes, f.notes].filter(Boolean).join(' · ')].map(txt);
    }));

  // Hardware — every fitment of every non-SIM unit (a unit refitted twice has two rows).
  const hw = [];
  units.filter(([, u]) => u.lruId !== 'sim').forEach(([id, u]) => {
    const fs = entries(u.fitments);
    if (!fs.length) fs.push(['—', {}]);
    fs.forEach(([fid, f]) => hw.push([id + ' / ' + fid, LRU_LABEL[u.lruId] || u.lruId, u.serial, u.altSerial, f.aircraft,
      f.position, f.state, f.fittedDate, f.removedDate, f.removalReason, f.condition, f.shopStatus, f.shopRef, f.shopFinding,
      [u.notes, f.notes].filter(Boolean).join(' · ')].map(txt)));
  });
  add('Hardware', ['Key', 'Equipment', 'Serial', 'Second serial (Eclipse)', 'Tail', 'Position', 'State', 'Fitted', 'Removed',
    'Removal reason', 'Condition', 'Shop status', 'Shop ref', 'Shop finding', 'Notes'], hw);
  add('Equipment types', ['Equipment', 'Vendor', 'Part number', 'Software version'], entries(d.hardware).map(([id, h]) =>
    [LRU_LABEL[id] || id, h.vendor, h.partNumber, h.swVersion].map(txt)));

  add('Assets', ['Id', 'Category', 'Type', 'Make', 'Model', 'NSG serial', 'Maker serial', 'Size', 'Content', 'Location',
    'Custodian', 'Status', 'Added'], entries(d.assets).map(([id, a]) =>
    [id, a.category, a.type, a.make, a.model, a.nsgSerial, a.mfrSerial, a.totalSize, a.content, a.location, a.custodian,
      a.status, fmtStamp(a.addedAt)].map(txt)));

  // Maintenance — every issue, open first is left to the reader's filter; "Open" is derived.
  add('Maintenance issues', ['Id', 'Tail', 'Open', 'Service', 'Impact', 'Severity', 'Priority', 'Reason', 'Detail', 'Discovered',
    'Informed (official inop)', 'Resolved', 'Resolution', 'Customer', 'Logged by', 'Logged'], entries(d.issues).map(([id, i]) =>
    [id, i.tail, i.resolvedDate ? 'No' : 'Yes', i.service, i.impact, i.severity, i.priority, i.reason, i.detail, i.discoveredDate,
      i.informedDate, i.resolvedDate, i.resolutionNote, i.customer, i.loggedBy, fmtStamp(i.loggedAt)].map(txt)));

  // Operational history — every archived out-of-service period plus the current one.
  const ops = [];
  Object.keys(ac).forEach(t => {
    entries(ac[t].opsLog).forEach(([k, o]) => ops.push([t + ' / ' + k, t, OPS_LABEL[o.state] || o.state, o.since, o.until,
      o.reason, o.location].map(txt)));
    const o = ac[t].ops;
    if (o && o.state && o.state !== 'active') ops.push([t + ' / current', t, OPS_LABEL[o.state] || o.state, o.since,
      '(ongoing)', o.reason, o.location].map(txt));
  });
  add('Operational history', ['Key', 'Tail', 'State', 'From', 'Until', 'Reason', 'Location'], ops);

  add('Activities', ['Id', 'Tail', 'Date', 'Category', 'Title', 'Task', 'Outcome', 'Location', 'Details', 'Report id', 'Notes', 'Logged'],
    entries(d.activities).map(([id, a]) =>
      [id, a.aircraft, a.date, a.category, a.title, a.task, a.outcome, a.location,
        Object.keys(a.details || {}).map(k => k + ': ' + txt(a.details[k])).join('; '), a.visitId, a.notes, fmtStamp(a.loggedAt)].map(txt)));

  add('Reports', ['Id', 'Reference', 'Tail', 'Type', 'Status', 'From', 'To', 'Location', 'Area', 'Hangar', 'Bay', 'Mode',
    'Attendees', 'Summary', 'Follow-up', 'Detailed report', 'Created', 'Updated'], entries(d.avr).map(([id, v]) =>
    [id, v.ref, v.aircraft, v.reportType, v.status, v.dateStart, v.dateEnd, v.location, v.locArea, v.locHangar, v.bay, v.mode,
      Object.keys(v.attendees || {}).sort().map(k => { const p = v.attendees[k] || {}; return [p.name, p.company].filter(Boolean).join(' (') + (p.company ? ')' : ''); }).join('; '),
      v.summary, v.followUp, v.detailedReport, fmtStamp(v.createdAt), fmtStamp(v.updatedAt)].map(txt)));

  add('Flights', ['Id', 'Tail', 'Date', 'Kind', 'Flight', 'Callsign', 'From', 'To', 'Departure (UTC)', 'Duration (min)',
    'Distance (km)', 'FR24 id', 'Note'], entries(d.flights).map(([id, f]) =>
    [id, f.tail, f.date, f.kind, f.flight, f.callsign, [f.fromIata, f.from].filter(Boolean).join(' '),
      [f.toIata, f.to].filter(Boolean).join(' '), f.dep, f.durMin, f.distanceKm, f.fr24Id, f.note].map(txt)));

  // Edit log — the dashboard's own /audit trail for the last 7 days (who changed what).
  const since = (nowMs || Date.now()) - 7 * 864e5, edits = [];
  entries(d.audit).forEach(([id, e]) => {
    if (!(e.ts >= since)) return;
    const ch = Array.isArray(e.changes) ? e.changes : Object.keys(e.changes || {}).map(k => e.changes[k]);
    ch.forEach((c, n) => edits.push([id + ' / ' + n, fmtStamp(e.ts), e.email, e.method, (c && c.p) || e.path,
      c && c.b, c && c.a, e.undoOf ? 'Undo of ' + e.undoOf : ''].map(txt)));
  });
  add('Edit log (7 days)', ['Key', 'When', 'Who', 'Action', 'Path', 'Before', 'After', 'Note'], edits, false);

  return tabs;
}

/**
 * Compares yesterday's tab with today's, pairing rows by column A.
 * Returns [key, change, field, before, after] rows.
 */
function diffTables(prev, next) {
  if (!prev || !prev.length) return [['', 'First snapshot', '', '', String(next.length - 1) + ' rows']];
  const ph = prev[0], nh = next[0], out = [];
  const index = rows => { const m = {}; rows.slice(1).forEach(r => { m[r[0]] = r; }); return m; };
  const pm = index(prev), nm = index(next);
  Object.keys(nm).forEach(k => {
    const n = nm[k], p = pm[k];
    if (!p) { out.push([k, 'Added', '', '', '']); return; }
    nh.forEach((col, i) => {
      if (i === 0) return;
      const j = ph.indexOf(col);
      const before = j < 0 ? '' : String(p[j] == null ? '' : p[j]);
      const after = String(n[i] == null ? '' : n[i]);
      if (before !== after) out.push([k, 'Changed', col, before, after]);
    });
  });
  Object.keys(pm).forEach(k => { if (!nm[k]) out.push([k, 'Removed', '', '', '']); });
  return out;
}

// Lets the local test harness (Node) load this file; Apps Script ignores it.
if (typeof module !== 'undefined') module.exports = { buildTabs, diffTables, fmtStamp, fmtDate, parseStamp, currentFitment };
