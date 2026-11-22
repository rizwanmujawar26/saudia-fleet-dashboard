#!/usr/bin/env node
/**
 * Local data feed: turns a folder of node JSON files (as written by backup.sh) into one
 * Excel workbook, one sheet per area, using the same buildTabs()/diffTables() as the
 * Google Sheet feed (feed/Code.gs). Called by scripts/export-feed.sh.
 *
 *   node scripts/export-feed.js <dataDir> <outDir>
 *
 * Writes <outDir>/Saudia-Fleet-Data-DD-Mon-YYYY.xlsx and keeps <outDir>/.last-tabs.json so
 * the next run's "Changes" sheet lists what changed since this one. No npm packages: the
 * .xlsx is plain SpreadsheetML zipped with /usr/bin/zip.
 */
'use strict';
const fs = require('fs'), path = require('path'), os = require('os'), cp = require('child_process');

const [dataDir, outDir] = process.argv.slice(2);
if (!dataDir || !outDir) { console.error('usage: export-feed.js <dataDir> <outDir>'); process.exit(2); }

// feed/Code.gs is plain JS with a CommonJS export at the bottom; load it as .js.
const src = path.join(__dirname, '..', 'feed', 'Code.gs');
const mod = { exports: {} };
new Function('module', 'exports', fs.readFileSync(src, 'utf8'))(mod, mod.exports);
const { buildTabs, diffTables, fmtStamp } = mod.exports;

const NODES = ['fleet', 'fleetSpecs', 'configs', 'aircraft', 'aircraftModem', 'activities', 'issues', 'hardware', 'units',
  'mediaLoads', 'mediaCycles', 'mediaCycleDisks', 'modmans', 'avr', 'assets', 'flights', 'audit'];
const data = {};
for (const n of NODES) {
  const f = path.join(dataDir, n + '.json');
  if (!fs.existsSync(f)) { console.error('missing ' + f + ' — refusing to write a partial export'); process.exit(1); }
  data[n] = JSON.parse(fs.readFileSync(f, 'utf8')) || {};
}
if (!Object.keys(data.fleet).length) { console.error('/fleet is empty — refusing to export'); process.exit(1); }

const now = new Date();
const tabs = buildTabs(data, now.getTime());
fs.mkdirSync(outDir, { recursive: true });

// Changes since the previous export.
const lastFile = path.join(outDir, '.last-tabs.json');
const prev = fs.existsSync(lastFile) ? JSON.parse(fs.readFileSync(lastFile, 'utf8')) : null;
const changes = [];
for (const t of prev ? tabs : []) {
  if (!t.diff) continue;
  const p = prev && prev.tabs ? prev.tabs[t.name] : null;
  diffTables(p, t.rows).forEach(c => changes.push([t.name].concat(c)));
}
const since = prev ? fmtStamp(prev.at) : '(first export)';
const changeRows = [['Tab', 'Key', 'Change', 'Field', 'Before', 'After']]
  .concat(changes.length ? changes : [['—', '', prev ? 'No changes' : 'First export — nothing to compare yet', '', '', '']]);

const about = [
  ['Saudia Connectivity Fleet Status — data export', ''],
  ['Exported', fmtStamp(now.toISOString())],
  ['Changes compared with export of', since],
  ['Changes found', String(changes.length)],
  ['Source', 'Firebase Realtime Database behind the dashboard (read-only copy)'],
  ['Date format', 'DD-Mon-YYYY; timestamps are UTC'],
  ['', ''],
  ['Sheet', 'Rows'],
].concat(tabs.map(t => [t.name, String(t.rows.length - 1)]));

const sheets = [{ name: 'About', rows: about, head: false }, { name: 'Changes', rows: changeRows, head: true }]
  .concat(tabs.map(t => ({ name: t.name, rows: t.rows, head: true })));

// The file is named by the local (Mac) date, day-first — never the UTC date.
const localDay = String(now.getDate()).padStart(2, '0') + '-' + ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.getMonth()] + '-' + now.getFullYear();
const file = path.join(outDir, 'Saudia-Fleet-Data-' + localDay + '.xlsx');
writeXlsx(file, sheets);
fs.writeFileSync(lastFile, JSON.stringify({ at: now.toISOString(), tabs: Object.fromEntries(tabs.map(t => [t.name, t.rows])) }));

console.log(file);
console.log('  ' + tabs.length + ' data sheets · ' + changes.length + ' change(s) since ' + since);

// ───────────────────────────── minimal .xlsx writer ─────────────────────────────

function esc(s) {
  // XML 1.0 forbids most control characters; strip them rather than corrupt the file.
  return String(s).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function colName(i) { let s = ''; for (i++; i; i = Math.floor((i - 1) / 26)) s = String.fromCharCode(65 + (i - 1) % 26) + s; return s; }
function sheetName(n) { return n.replace(/[\\/?*[\]:]/g, '-').slice(0, 31); }

function sheetXml(sh) {
  const width = Math.max(...sh.rows.map(r => r.length));
  const widths = Array.from({ length: width }, (_, c) =>
    Math.min(60, Math.max(8, ...sh.rows.slice(0, 400).map(r => String(r[c] == null ? '' : r[c]).split('\n')[0].length + 2))));
  const rows = sh.rows.map((r, ri) => '<row r="' + (ri + 1) + '">' + r.map((v, ci) => {
    const s = v == null ? '' : String(v).slice(0, 32000);   // Excel's cell limit is 32,767
    if (s === '') return '';
    const bold = (sh.head && ri === 0) || (!sh.head && (ri === 0 || r[0] === 'Sheet'));
    return '<c r="' + colName(ci) + (ri + 1) + '" t="inlineStr"' + (bold ? ' s="1"' : '') + '><is><t xml:space="preserve">' + esc(s) + '</t></is></c>';
  }).join('') + '</row>').join('');
  const pane = sh.head ? '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>' : '';
  const filter = sh.head && sh.rows.length > 1 ? '<autoFilter ref="A1:' + colName(width - 1) + sh.rows.length + '"/>' : '';
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' + pane +
    '<cols>' + widths.map((w, i) => '<col min="' + (i + 1) + '" max="' + (i + 1) + '" width="' + w + '" customWidth="1"/>').join('') + '</cols>' +
    '<sheetData>' + rows + '</sheetData>' + filter + '</worksheet>';
}

function writeXlsx(file, sheets) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'feedxlsx-'));
  const put = (p, s) => { fs.mkdirSync(path.dirname(path.join(dir, p)), { recursive: true }); fs.writeFileSync(path.join(dir, p), s); };
  const ns = 'http://schemas.openxmlformats.org';
  put('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="' + ns + '/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
    sheets.map((_, i) => '<Override PartName="/xl/worksheets/sheet' + (i + 1) + '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join('') + '</Types>');
  put('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="' + ns + '/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="' + ns + '/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
  put('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="' + ns + '/spreadsheetml/2006/main" xmlns:r="' + ns + '/officeDocument/2006/relationships"><sheets>' +
    sheets.map((s, i) => '<sheet name="' + esc(sheetName(s.name)) + '" sheetId="' + (i + 1) + '" r:id="rId' + (i + 1) + '"/>').join('') + '</sheets></workbook>');
  put('xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="' + ns + '/package/2006/relationships">' +
    sheets.map((_, i) => '<Relationship Id="rId' + (i + 1) + '" Type="' + ns + '/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' + (i + 1) + '.xml"/>').join('') +
    '<Relationship Id="rId' + (sheets.length + 1) + '" Type="' + ns + '/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>');
  put('xl/styles.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="' + ns + '/spreadsheetml/2006/main">' +
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>' +
    '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>' +
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
    '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>' +
    '</styleSheet>');
  sheets.forEach((s, i) => put('xl/worksheets/sheet' + (i + 1) + '.xml', sheetXml(s)));
  const tmp = file + '.tmp';
  try { fs.unlinkSync(tmp); } catch (e) { /* none */ }
  cp.execFileSync('/usr/bin/zip', ['-q', '-X', '-D', '-r', tmp, '[Content_Types].xml', '_rels', 'xl'], { cwd: dir });
  fs.renameSync(tmp, file);
  fs.rmSync(dir, { recursive: true, force: true });
}
