#!/usr/bin/env node
'use strict';
/**
 * Katman ve paket sınırı denetimi (CLAUDE.md §1, D-11).
 *   node tool/check_boundaries.js [--root dir] [--files …] [--list]
 *  B01 gu_ui pubspec: yasaklı bağımlılık (gu_data, firebase_*, cloud_*, go_router*, *riverpod*, get_it, shared_preferences…)
 *  B02 gu_ui kaynağı: yasaklı import
 *  B03 gu_data kaynağı: Flutter UI import'u (material/widgets/cupertino/rendering/painting)
 *  B04 lib/features, lib/product: Firebase SDK'sına doğrudan import (yalnızca gu_data üzerinden)
 *  B05 feature → başka feature import'u
 *  B06 gu_data pubspec: flutter widget bağımlılığı (flutter_svg, cached_network_image …)
 */
const fs = require('fs');
const path = require('path');
const core = require('./lib/scan_core');

const argv = process.argv.slice(2);
const root = core.projectRoot(argv);

const FIREBASE_PKG = /^(firebase_|cloud_firestore|cloud_functions|firebase_core)/;
const GU_UI_FORBIDDEN_DEP = /^(gu_data|gu_core|firebase_.*|cloud_.*|go_router.*|.*riverpod.*|get_it|shared_preferences.*|intl|flutter_localizations|connectivity_plus|url_launcher|share_plus|permission_handler|mobile_scanner|image_picker|path_provider|package_info_plus)$/;
const GU_DATA_FORBIDDEN_DEP = /^(flutter_svg|cached_network_image|go_router.*|.*riverpod.*|table_calendar|qr_flutter|mobile_scanner|image_picker|flutter_localizations)$/;
const GU_UI_IMPORT_FORBIDDEN = /^package:(gu_data|firebase_[a-z_]+|cloud_firestore|cloud_functions|go_router|flutter_riverpod|riverpod_annotation|get_it|shared_preferences)\b/;
const FLUTTER_UI_IMPORT = /^package:flutter\/(material|widgets|cupertino|rendering|painting|gestures|animation)\.dart$/;

function readDeps(file) {
  const out = { deps: [], dev: [] };
  if (!fs.existsSync(file)) return out;
  let sec = null;
  for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    if (/^\S/.test(raw)) { sec = /^dependencies:/.test(raw) ? 'deps' : /^dev_dependencies:/.test(raw) ? 'dev' : null; continue; }
    if (!sec) continue;
    const m = /^ {2}([A-Za-z0-9_]+):/.exec(raw);
    if (m) out[sec].push(m[1]);
  }
  return out;
}

function appName() {
  try { const m = /^name:\s*(\S+)/m.exec(fs.readFileSync(path.join(root, 'pubspec.yaml'), 'utf8')); return m ? m[1] : null; } catch (e) { return null; }
}

const viol = [];
function add(file, line, rule, msg, text) { viol.push({ file, line, rule, msg, text }); }

// pubspec denetimi
{
  const ui = path.join(root, 'packages/gu_ui/pubspec.yaml');
  const data = path.join(root, 'packages/gu_data/pubspec.yaml');
  for (const d of readDeps(ui).deps) if (GU_UI_FORBIDDEN_DEP.test(d)) add('packages/gu_ui/pubspec.yaml', 1, 'B01', `gu_ui saf arayüz paketidir; \`${d}\` bağımlılığı yasak (packages.md §2.3)`, d);
  for (const d of readDeps(data).deps) if (GU_DATA_FORBIDDEN_DEP.test(d)) add('packages/gu_data/pubspec.yaml', 1, 'B06', `gu_data'da arayüz/rota/state paketi yasak: \`${d}\``, d);
}

let files = core.filesFromArgs(argv, root);
if (!files) files = core.walk(root, (f) => /\.dart$/.test(f) && /\/(lib)\//.test(core.toPosix(f)));
const app = appName();
const importRe = /^\s*(?:import|export)\s+['"]([^'"]+)['"]/;
for (const f of files) {
  const rel = core.toPosix(path.relative(root, f));
  if (!/\.dart$/.test(rel) || /\.(g|gen|freezed)\.dart$/.test(rel)) continue;
  const lines = fs.readFileSync(f, 'utf8').split(/\r?\n/);
  const inUi = /^packages\/gu_ui\/lib\//.test(rel);
  const inData = /^packages\/gu_data\/lib\//.test(rel);
  const feat = /^lib\/features\/([^/]+)\//.exec(rel);
  const inApp = /^lib\/(features|product)\//.test(rel);
  lines.forEach((ln, i) => {
    const m = importRe.exec(ln);
    if (!m) return;
    const imp = m[1];
    if (inUi && GU_UI_IMPORT_FORBIDDEN.test(imp)) add(rel, i + 1, 'B02', `gu_ui şu import'u yapamaz: ${imp}`, ln);
    if (inData && FLUTTER_UI_IMPORT.test(imp)) add(rel, i + 1, 'B03', `gu_data Flutter UI import'u yapamaz: ${imp}`, ln);
    if (inApp && FIREBASE_PKG.test(imp.replace(/^package:/, ''))) add(rel, i + 1, 'B04', `Firebase SDK'sına doğrudan erişim yasak (yalnızca gu_data): ${imp}`, ln);
    if (feat) {
      let target = null;
      if (app && imp.startsWith(`package:${app}/features/`)) target = imp.slice(`package:${app}/features/`.length).split('/')[0];
      else if (!imp.startsWith('package:') && !imp.startsWith('dart:')) {
        const resolved = core.toPosix(path.relative(root, path.resolve(path.dirname(f), imp)));
        const mm = /^lib\/features\/([^/]+)\//.exec(resolved);
        if (mm) target = mm[1];
      }
      if (target && target !== feat[1]) add(rel, i + 1, 'B05', `feature '${feat[1]}' → '${target}' import'u yasak; ortak olanı lib/product veya paketlere çıkar`, ln);
    }
  });
}

if (argv.includes('--list')) {
  console.log('B01 gu_ui bağımlılık · B02 gu_ui import · B03 gu_data UI import · B04 Firebase SDK doğrudan · B05 feature→feature · B06 gu_data bağımlılık');
  process.exit(0);
}
process.exit(core.report(viol, argv, 'check_boundaries'));
