// Converts the XML that `godot --doctool --gdscript-docs` exports into Starlight pages.
//
// Usage: node docs/gdscript-docs.mjs <sdk-xml-dir> <gen-xml-dir> <content-dir>
//
// The SDK classes go to <content-dir>/sdk-gd, one page per script; the generated classes listed in GEN_CLASSES go to
// <content-dir>/gen-gd. Classes and members whose names start with "_" are left out.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PROJECT_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SDK_DIR = 'addons/archmage';
const SDK_ENTRY = 'archmage.gd';
const GEN_DIR = 'tests/conf';
const GEN_CLASSES = ['ConfigAtlas', 'AtlasExtension', 'L10n'];
const GODOT_CLASSES_URL = 'https://docs.godotengine.org/en/stable/classes';

const [sdkXmlDir, genXmlDir, contentDir] = process.argv.slice(2);
if (!contentDir) {
  console.error('Usage: node docs/gdscript-docs.mjs <sdk-xml-dir> <gen-xml-dir> <content-dir>');
  process.exit(2);
}

const warnings = [];

// ---------------------------------------------------------------------------------------------------------------
// XML

function decodeEntities(s) {
  return s.replace(/&(#x[0-9a-fA-F]+|#\d+|lt|gt|amp|quot|apos);/g, (_, e) => {
    switch (e) {
      case 'lt': return '<';
      case 'gt': return '>';
      case 'amp': return '&';
      case 'quot': return '"';
      case 'apos': return "'";
      default: return String.fromCodePoint(e[1] === 'x' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10));
    }
  });
}

function parseXml(src) {
  const root = { name: '#root', attrs: {}, children: [], text: '' };
  const stack = [root];
  const re = /<\?[\s\S]*?\?>|<!--[\s\S]*?-->|<(\/?)([\w:.-]+)((?:\s+[\w:.-]+="[^"]*")*)\s*(\/?)>|([^<]+)/g;
  let m;
  while ((m = re.exec(src))) {
    if (m[5] !== undefined) {
      stack.at(-1).text += decodeEntities(m[5]);
    } else if (m[2] && m[1]) {
      stack.pop();
    } else if (m[2]) {
      const attrs = {};
      for (const a of m[3].matchAll(/([\w:.-]+)="([^"]*)"/g)) attrs[a[1]] = decodeEntities(a[2]);
      const el = { name: m[2], attrs, children: [], text: '' };
      stack.at(-1).children.push(el);
      if (!m[4]) stack.push(el);
    }
  }
  return root.children[0];
}

const child = (el, name) => el.children.find((c) => c.name === name);
const children = (el, name, item) => child(el, name)?.children.filter((c) => c.name === item) ?? [];

// ---------------------------------------------------------------------------------------------------------------
// Names

// Script path (relative to the project) -> class name, such as addons/archmage/duration.gd -> Archmage.Duration.
const scriptNames = new Map();
// Class name -> script path, for the scripts that have a class_name.
const classScripts = new Map();

function scanClassNames(dir) {
  for (const file of fs.readdirSync(path.join(PROJECT_DIR, dir))) {
    if (!file.endsWith('.gd')) continue;
    const rel = `${dir}/${file}`;
    const m = fs.readFileSync(path.join(PROJECT_DIR, rel), 'utf-8').match(/^class_name (\w+)/m);
    if (m) {
      classScripts.set(m[1], rel);
      scriptNames.set(rel, m[1]);
    }
  }
}

scanClassNames(SDK_DIR);
scanClassNames(GEN_DIR);
const entryClass = scriptNames.get(`${SDK_DIR}/${SDK_ENTRY}`);
if (!entryClass) throw new Error(`${SDK_DIR}/${SDK_ENTRY} has no class_name`);
const sdkShortNames = new Map(); // Duration -> Archmage.Duration
for (const m of fs.readFileSync(path.join(PROJECT_DIR, SDK_DIR, SDK_ENTRY), 'utf-8')
  .matchAll(/^const (\w+) = preload\("([^"]+)"\)/gm)) {
  scriptNames.set(path.posix.join(SDK_DIR, m[2]), `${entryClass}.${m[1]}`);
  sdkShortNames.set(m[1], `${entryClass}.${m[1]}`);
}

function scriptName(p) {
  const name = scriptNames.get(p);
  if (!name) warnings.push(`no class name for script ${p}`);
  return name ?? p;
}

// Rewrites the names that the doctool gives types: "addons/archmage/fs.gd" -> Archmage.FS, int[] -> Array[int].
function typeName(type, enumName) {
  let t = enumName || type || 'Variant';
  t = t.replace(/"([^"]+\.gd)"/g, (_, p) => scriptName(p));
  t = t.replace(/([\w.]+)\[\]/g, 'Array[$1]');
  return t;
}

// Returns the names of the static vars of a class from its script; the doctool does not mark them.
function staticVars(script, inner) {
  const names = new Set();
  if (!script) return names;
  let current = null;
  for (const line of fs.readFileSync(path.join(PROJECT_DIR, script), 'utf-8').split('\n')) {
    const cls = line.match(/^class (\w+)/);
    if (cls) {
      current = cls[1];
      continue;
    }
    if (/^[^\s#]/.test(line)) current = null;
    const v = line.match(/^(\t?)static var (\w+)/);
    if (v && (v[1] ? current === inner && inner : !inner)) names.add(v[2]);
  }
  return names;
}

// ---------------------------------------------------------------------------------------------------------------
// Classes

function loadClasses(xmlDir, dir, keep) {
  const loaded = [];
  for (const file of fs.readdirSync(xmlDir).sort()) {
    if (!file.endsWith('.xml')) continue;
    const el = parseXml(fs.readFileSync(path.join(xmlDir, file), 'utf-8'));
    const raw = el.attrs.name;
    // "addons/archmage/atlas_options.gd".OverrideConfig, HeroTable.HeroCfg, "addons/archmage/duration.gd" or L10n
    const m = raw.match(/^(?:"([^"]+)"|(\w+))(?:\.(\w+))?$/);
    if (!m) {
      warnings.push(`unknown class name ${raw}`);
      continue;
    }
    const outerName = m[1] ? scriptNames.get(m[1]) ?? m[1] : m[2];
    const script = m[1] ?? classScripts.get(m[2]);
    const inner = m[3] ?? null;
    loaded.push({
      xmlName: raw,
      name: inner ? `${outerName}.${inner}` : outerName,
      shortName: inner ?? outerName,
      outer: inner ? outerName : null,
      script,
      dir,
      el,
      kept: !keep || keep.includes(outerName),
    });
  }
  return loaded;
}

const allClasses = [...loadClasses(sdkXmlDir, 'sdk-gd', null), ...loadClasses(genXmlDir, 'gen-gd', GEN_CLASSES)];
const classes = new Map(); // full name -> class, for the classes that get a page or a section of one
for (const c of allClasses) {
  if (!c.kept || c.shortName.startsWith('_')) continue;
  c.page = c.outer ?? c.name;
  c.slug = c.page.toLowerCase().replace(/\./g, '-');
  classes.set(c.name, c);
}
// Generated classes that have no page, such as HeroTable; members of these types are left out of gen-gd.
const genOmitted = new Set(allClasses.filter((c) => c.dir === 'gen-gd' && !classes.has(c.name)).map((c) => c.name));

const isPublic = (name) => !name.startsWith('_');

for (const c of classes.values()) {
  const el = c.el;
  const statics = staticVars(c.script, c.outer ? c.shortName : null);
  c.brief = child(el, 'brief_description')?.text.trim() ?? '';
  c.description = child(el, 'description')?.text.trim() ?? '';
  c.inherits = el.attrs.inherits ? typeName(el.attrs.inherits) : '';
  c.methods = children(el, 'methods', 'method').map((m) => ({
    name: m.attrs.name,
    qualifiers: (m.attrs.qualifiers ?? '').split(' ').filter(Boolean),
    returns: typeName(child(m, 'return')?.attrs.type, child(m, 'return')?.attrs.enum),
    params: m.children.filter((p) => p.name === 'param').map((p) => ({
      name: p.attrs.name,
      type: typeName(p.attrs.type, p.attrs.enum),
      default: p.attrs.default,
    })),
    description: child(m, 'description')?.text.trim() ?? '',
  }));
  c.ctor = c.methods.find((m) => m.name === '_init' && (m.params.length > 0 || m.description));
  c.methods = c.methods.filter((m) => isPublic(m.name));
  c.members = children(el, 'members', 'member')
    .filter((m) => isPublic(m.attrs.name))
    .map((m) => ({
      name: m.attrs.name,
      type: typeName(m.attrs.type, m.attrs.enum),
      default: m.attrs.default,
      isStatic: statics.has(m.attrs.name),
      description: m.text.trim(),
    }))
    .filter((m) => !(c.dir === 'gen-gd' && genOmitted.has(m.type)));
  const constants = children(el, 'constants', 'constant').filter((k) => isPublic(k.attrs.name)).map((k) => ({
    name: k.attrs.name,
    value: k.attrs.value,
    enumName: k.attrs.enum,
    description: k.text.trim(),
  }));
  // A constant whose value is <Object> is a preloaded script. The entry class lists them as the SDK classes; in
  // other scripts they are the local names of the scripts that they use.
  c.scriptConstants = c.name === entryClass ? constants.filter((k) => k.value === '<Object>') : [];
  c.constants = constants.filter((k) => k.value !== '<Object>' && !k.enumName);
  c.enums = [];
  for (const k of constants.filter((k) => k.enumName)) {
    let e = c.enums.find((x) => x.name === k.enumName);
    if (!e) {
      e = { name: k.enumName, values: [], description: '' };
      c.enums.push(e);
    }
    e.values.push(k);
  }
  for (const e of children(el, 'enums', 'enum')) {
    const x = c.enums.find((y) => y.name === e.attrs.name);
    if (x) x.description = e.text.trim();
  }
  c.signals = children(el, 'signals', 'signal').filter((s) => isPublic(s.attrs.name)).map((s) => ({
    name: s.attrs.name,
    params: s.children.filter((p) => p.name === 'param').map((p) => ({
      name: p.attrs.name,
      type: typeName(p.attrs.type, p.attrs.enum),
    })),
    description: child(s, 'description')?.text.trim() ?? '',
  }));
  c.anchors = new Map(); // "method:name" -> anchor
}

const pages = [...classes.values()].filter((c) => !c.outer);
for (const p of pages) p.inners = [...classes.values()].filter((c) => c.outer === p.name);

// ---------------------------------------------------------------------------------------------------------------
// References

function godotUrl(cls, kind, name) {
  const lower = cls.toLowerCase();
  const url = `${GODOT_CLASSES_URL}/class_${lower}.html`;
  if (!kind) return url;
  const id = lower.replace(/@/g, '');
  const n = name.toLowerCase().replace(/_/g, '-');
  if (kind === 'enum') return `${url}#enum-${id}-${n}`;
  const k = { member: 'property', constructor: 'constructor', operator: 'operator' }[kind] ?? kind;
  return `${url}#class-${id}-${k}-${n}`;
}

function pageUrl(from, to, anchor) {
  const hash = anchor ? `#${anchor}` : '';
  if (from.page === to.page) return hash || './';
  const base = from.dir === to.dir ? '..' : `../../${to.dir}`;
  return `${base}/${to.slug}/${hash}`;
}

// Finds a class by the name a doc comment gives it: a full name, the short name of an SDK script, or the name of an
// inner class of the current class or of its outer class.
function findClass(name, ctx) {
  if (classes.has(name)) return classes.get(name);
  if (sdkShortNames.has(name)) return classes.get(sdkShortNames.get(name));
  for (const scope of [ctx.name, ctx.outer]) {
    if (scope && classes.has(`${scope}.${name}`)) return classes.get(`${scope}.${name}`);
  }
  return null;
}

function baseOf(c) {
  return classes.get(c.inherits) ?? null;
}

function hasMember(c, kind, name) {
  switch (kind) {
    case 'method': return c.methods.some((m) => m.name === name);
    case 'member': return c.members.some((m) => m.name === name);
    case 'constant': return c.constants.some((k) => k.name === name)
      || c.enums.some((e) => e.values.some((v) => v.name === name))
      || c.scriptConstants.some((k) => k.name === name);
    case 'signal': return c.signals.some((s) => s.name === name);
    case 'enum': return c.enums.some((e) => e.name === name);
    default: return false;
  }
}

// Returns the URL of [kind target] in a doc comment of ctx, or null when the target has no documentation.
function resolveMember(kind, target, ctx) {
  const dot = target.lastIndexOf('.');
  const clsName = dot < 0 ? null : target.slice(0, dot);
  const name = dot < 0 ? target : target.slice(dot + 1);
  if (!isPublic(name)) return null;
  if (clsName) {
    const c = findClass(clsName, ctx);
    if (!c) return godotUrl(clsName, kind, name);
    for (let x = c; x; x = baseOf(x)) {
      if (hasMember(x, kind, name)) return pageUrl(ctx, x, x.anchors.get(`${kind}:${name}`));
    }
    warnings.push(`${ctx.name}: [${kind} ${target}] not found`);
    return null;
  }
  for (const scope of [ctx, ctx.outer && classes.get(ctx.outer)]) {
    for (let x = scope; x; x = baseOf(x)) {
      if (hasMember(x, kind, name)) return pageUrl(ctx, x, x.anchors.get(`${kind}:${name}`));
    }
  }
  if (kind === 'constant' || kind === 'enum' || kind === 'method') return godotUrl('@GlobalScope', kind, name);
  warnings.push(`${ctx.name}: [${kind} ${target}] not found`);
  return null;
}

function resolveClass(name, ctx) {
  const c = findClass(name, ctx);
  if (c) return pageUrl(ctx, c, c.outer ? c.anchors.get('class') : '');
  if (/^@?[A-Z]\w*$/.test(name) || LOWERCASE_CLASSES.has(name)) return godotUrl(name);
  return null;
}

// ---------------------------------------------------------------------------------------------------------------
// BBCode

const codeSpan = (s) => {
  const ticks = s.includes('`') ? '``' : '`';
  const pad = s.startsWith('`') || s.endsWith('`') ? ' ' : '';
  return `${ticks}${pad}${s}${pad}${ticks}`;
};

const escapeText = (s) => s.replace(/([\\`*[\]])/g, '\\$1').replace(/</g, '&lt;');

// The built-in types of Godot whose names are not capitalized.
const LOWERCASE_CLASSES = new Set(['bool', 'int', 'float']);

const MEMBER_TAGS = new Set(['method', 'member', 'constant', 'signal', 'enum', 'annotation', 'constructor',
  'operator', 'theme_item']);

// Converts the BBCode of a doc comment into markdown. With plain, returns text without markup, for frontmatter.
function bbcode(src, ctx, plain = false) {
  const slots = [];
  const slot = (md) => `\u0000${slots.push(md) - 1}\u0000`;
  let s = src;
  // Code blocks; [codeblocks] keeps the GDScript one.
  s = s.replace(/\[codeblocks\][\s\S]*?\[gdscript\]([\s\S]*?)\[\/gdscript\][\s\S]*?\[\/codeblocks\]/g,
    (_, code) => slot(plain ? ' ' : codeBlock(code, 'gdscript')));
  s = s.replace(/\[codeblock(?: lang=(\w+))?\]([\s\S]*?)\[\/codeblock\]/g,
    (_, lang, code) => slot(plain ? ' ' : codeBlock(code, lang === 'text' ? 'text' : lang || 'gdscript')));
  s = s.replace(/\[(code|kbd)\]([\s\S]*?)\[\/\1\]/g, (_, __, code) => slot(plain ? code : codeSpan(code)));
  s = s.replace(/\[url=([^\]]+)\]([\s\S]*?)\[\/url\]/g,
    (_, href, text) => slot(plain ? bbcode(text, ctx, true) : `[${bbcode(text, ctx)}](${href})`));
  s = s.replace(/\[url\]([\s\S]*?)\[\/url\]/g, (_, href) => slot(plain ? href : `<${href}>`));

  const out = [];
  const tokens = s.split(/(\[[^[\]\n]*\])/);
  for (let i = 0; i < tokens.length; i++) {
    const tok = tokens[i];
    const tag = tok.match(/^\[(\/?)([\w@.]+)(?: ([^\]]+))?\]$/);
    if (!tag) {
      out.push(plain ? tok : escapeText(tok));
      continue;
    }
    const [, close, name, arg] = tag;
    if (name === 'br') {
      if (plain) {
        out.push(' ');
      } else if (tokens[i + 1] === '' && tokens[i + 2] === '[br]') {
        out.push('\n\n');
        i += 2;
      } else if (/^\s*- /.test(tokens[i + 1] ?? '')) {
        out.push('\n');
      } else {
        out.push('<br />');
      }
    } else if (name === 'b' || name === 'i' || name === 'u' || name === 's') {
      if (!plain) out.push({ b: '**', i: '*', u: '', s: '~~' }[name]);
    } else if (name === 'lb' || name === 'rb') {
      out.push(plain ? (name === 'lb' ? '[' : ']') : (name === 'lb' ? '\\[' : '\\]'));
    } else if (name === 'param' && arg) {
      out.push(plain ? arg : codeSpan(arg));
    } else if (MEMBER_TAGS.has(name) && arg && !close) {
      const shown = arg.replace(/^@GlobalScope\./, '');
      const text = name === 'method' ? `${shown}()` : shown;
      const url = plain ? null : resolveMember(name, arg, ctx);
      out.push(plain ? text : url ? `[${codeSpan(text)}](${url})` : codeSpan(text));
    } else if (!arg && !close && (/^@?[A-Z][\w.]*$/.test(name) || LOWERCASE_CLASSES.has(name))) {
      const url = plain ? null : resolveClass(name, ctx);
      out.push(plain ? name : url ? `[${name}](${url})` : name);
    } else {
      warnings.push(`${ctx.name}: unknown BBCode ${tok}`);
      out.push(plain ? tok : escapeText(tok));
    }
  }
  // Whitespace is normalized before the slots are filled, so that the content of code blocks keeps its own.
  let md = out.join('');
  if (plain) md = md.replace(/\s+/g, ' ');
  md = md.replace(/[ \t]+\n/g, '\n').replace(/\n\s*\n\s*/g, '\n\n');
  md = md.replace(/\u0000(\d+)\u0000/g, (_, n) => slots[n]).replace(/\n{3,}(?=```)|(?<=```)\n{3,}/g, '\n\n');
  return md.trim();
}

function codeBlock(code, lang) {
  const body = code.replace(/^\n+|\s+$/g, '');
  return `\n\n\`\`\`${lang}\n${body}\n\`\`\`\n\n`;
}

// ---------------------------------------------------------------------------------------------------------------
// Pages

// Assigns heading IDs as github-slugger does, which Starlight uses.
class Slugger {
  constructor() {
    this.seen = new Map();
  }

  slug(text) {
    const base = text.replace(/[*`]/g, '').toLowerCase().replace(/[^\p{L}\p{M}\p{N}\p{Pc} -]/gu, '').replace(/ /g, '-');
    let s = base;
    let n = this.seen.get(base) ?? 0;
    while (this.seen.has(s)) s = `${base}-${++n}`;
    this.seen.set(base, n);
    this.seen.set(s, 0);
    return s;
  }
}

function signature(m, ctx) {
  const params = m.params.map((p) => `${p.name}: ${p.type}${p.default !== undefined ? ` = ${p.default}` : ''}`);
  if (m.name === '_init') return `${ctx.name}.new(${params.join(', ')})`;
  const prefix = m.qualifiers.includes('abstract') ? '@abstract ' : m.qualifiers.includes('static') ? 'static ' : '';
  return `${prefix}func ${m.name}(${params.join(', ')}) -> ${m.returns}`;
}

function memberDecl(m) {
  const def = m.default === undefined || m.default === '<unknown>' ? '' : ` = ${m.default}`;
  return `${m.isStatic ? 'static ' : ''}var ${m.name}: ${m.type}${def}`;
}

const gd = (code) => `\`\`\`gdscript\n${code}\n\`\`\``;

// Renders one class into blocks. h is the heading level of its sections; its items are one level below.
function renderClass(c, slugger, h) {
  const blocks = [];
  const heading = (level, text, key) => {
    const id = slugger.slug(text);
    if (key) c.anchors.set(key, id);
    blocks.push(`${'#'.repeat(level)} ${text}`);
  };
  const desc = (text) => {
    if (text) blocks.push(bbcode(text, c));
  };

  desc(c.brief);
  if (c.inherits) {
    const url = resolveClass(c.inherits, c);
    blocks.push(`Inherits: ${url ? `[${c.inherits}](${url})` : c.inherits}`);
  }
  desc(c.description);

  if (c.scriptConstants.length) {
    heading(h, 'Classes');
    const rows = c.scriptConstants.map((k) => {
      const target = classes.get(`${c.name}.${k.name}`);
      if (!target) {
        warnings.push(`${c.name}.${k.name}: no page`);
        return `| ${c.name}.${k.name} | |`;
      }
      c.anchors.set(`constant:${k.name}`, '');
      const brief = bbcode(target.brief, target).replace(/\n+/g, ' ').replace(/\|/g, '\\|');
      return `| [${target.name}](${pageUrl(c, target)}) | ${brief} |`;
    });
    blocks.push(['| Class | Description |', '| --- | --- |', ...rows].join('\n'));
  }

  if (c.constants.length) {
    heading(h, 'Constants');
    for (const k of c.constants) {
      heading(h + 1, k.name, `constant:${k.name}`);
      blocks.push(gd(`const ${k.name} = ${k.value}`));
      desc(k.description);
    }
  }

  if (c.enums.length) {
    heading(h, 'Enums');
    for (const e of c.enums) {
      heading(h + 1, e.name, `enum:${e.name}`);
      for (const v of e.values) c.anchors.set(`constant:${v.name}`, c.anchors.get(`enum:${e.name}`));
      blocks.push(gd(`enum ${e.name} {\n${e.values.map((v) => `\t${v.name} = ${v.value},`).join('\n')}\n}`));
      desc(e.description);
      const items = e.values.filter((v) => v.description).map((v) => `- ${codeSpan(v.name)}: ${bbcode(v.description, c)}`);
      if (items.length) blocks.push(items.join('\n'));
    }
  }

  if (c.members.length) {
    heading(h, 'Properties');
    for (const m of c.members) {
      heading(h + 1, m.name, `member:${m.name}`);
      blocks.push(gd(memberDecl(m)));
      desc(m.description);
    }
  }

  if (c.signals.length) {
    heading(h, 'Signals');
    for (const s of c.signals) {
      heading(h + 1, s.name, `signal:${s.name}`);
      blocks.push(gd(`signal ${s.name}(${s.params.map((p) => `${p.name}: ${p.type}`).join(', ')})`));
      desc(s.description);
    }
  }

  if (c.ctor) {
    heading(h, 'Constructor');
    heading(h + 1, 'new()', 'constructor:new');
    blocks.push(gd(signature(c.ctor, c)));
    desc(c.ctor.description);
  }

  if (c.methods.length) {
    heading(h, 'Methods');
    for (const m of c.methods) {
      heading(h + 1, `${m.name}()`, `method:${m.name}`);
      blocks.push(gd(signature(m, c)));
      if (m.description) {
        desc(m.description);
      } else {
        // An implementation of a method of a base class, such as ConfigAtlas.bind_refs, links to the base method.
        for (let x = baseOf(c); x; x = baseOf(x)) {
          const base = x.methods.find((b) => b.name === m.name);
          if (!base) continue;
          const verb = base.qualifiers.includes('abstract') ? 'Implements' : 'Overrides';
          desc(`${verb} [method ${x.name}.${m.name}].`);
          break;
        }
      }
    }
  }
  return blocks;
}

function renderPage(p) {
  const slugger = new Slugger();
  const blocks = renderClass(p, slugger, 2);
  if (p.inners.length) {
    blocks.push('## Inner Classes');
    slugger.slug('Inner Classes');
    for (const inner of p.inners) {
      const id = slugger.slug(inner.shortName);
      inner.anchors.set('class', id);
      blocks.push(`### ${inner.shortName}`);
      blocks.push(gd(inner.name));
      blocks.push(...renderClass(inner, slugger, 4));
    }
  }
  const yaml = (s) => `'${s.replace(/'/g, "''")}'`;
  const description = bbcode(p.brief, p, true);
  const front = ['---', `title: ${yaml(p.name)}`];
  if (description) front.push(`description: ${yaml(description)}`);
  front.push('---');
  return `${front.join('\n')}\n\n${blocks.join('\n\n')}\n`;
}

// The first pass assigns the heading IDs, which the links of the second pass use.
for (const p of pages) renderPage(p);
warnings.length = 0;
for (const p of pages) {
  const dir = path.join(contentDir, p.dir);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, `${p.slug}.md`), renderPage(p));
  console.log(`Generated ${p.dir}/${p.slug}.md`);
}

if (warnings.length) {
  for (const w of new Set(warnings)) console.error(`WARNING: ${w}`);
  process.exit(1);
}
