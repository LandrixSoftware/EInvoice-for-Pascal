// Parses Markdown files with commonmark.js (the CommonMark reference
// implementation) and prints, per file, one JSON line:
//   {"file": ..., "nodes": [types outside the allowed set],
//    "lines": [[kind, depth, section, label, value], ...]}
// Kinds as TEvent of tests/LandrixEInvoiceTestRenderMarkdown.pas: 't' the
// level 1 heading, 'h' a level 3 heading, 'p' a top-level paragraph that is
// one strong text, 'l' / 'b' a list item ('-' / '*') whose paragraph is one
// strong text, 'v' a list item whose paragraph starts with strong text
// ending in ':' (the label; the value is the rest of the paragraph, or the
// fenced code block that follows it, one trailing LF dropped). depth is the
// number of list items the line sits in, itself included; section the text
// of the last level 2 heading. Used by tools/render/md-oracle.py.
//
// Usage: node md-walk.js <commonmark.js> <list file>   (one path per line)

'use strict';
const fs = require('fs');
const commonmark = require(process.argv[2]);

const ALLOWED = new Set(['document', 'heading', 'list', 'item', 'paragraph', 'strong', 'text', 'code_block',
  'thematic_break']);

function textOf(node) {
  let s = '';
  const w = node.walker();
  let e;
  while ((e = w.next())) {
    if (e.entering && e.node.type === 'text') s += e.node.literal;
    else if (e.entering && e.node.type === 'softbreak') s += '\n';
  }
  return s;
}

function depthOf(node) {
  let d = 0;
  for (let n = node; n; n = n.parent) if (n.type === 'item') d++;
  return d;
}

function analyse(file) {
  const parser = new commonmark.Parser();
  const doc = parser.parse(fs.readFileSync(file, 'utf8'));
  const nodes = new Set();
  const lines = [];
  let section = '';
  const w = doc.walker();
  let e;
  while ((e = w.next())) {
    if (!e.entering) continue;
    const n = e.node;
    if (!ALLOWED.has(n.type)) nodes.add(n.type);
    if (n.type === 'heading') {
      if (n.level === 1) lines.push(['t', 0, section, textOf(n), '']);
      else if (n.level === 2) section = textOf(n);
      else if (n.level === 3) lines.push(['h', 0, section, textOf(n), '']);
      continue;
    }
    if (n.type === 'paragraph' && n.parent.type === 'document' && n.firstChild && n.firstChild.type === 'strong' &&
        !n.firstChild.next) {
      lines.push(['p', 0, section, textOf(n.firstChild), '']);
      continue;
    }
    if (n.type !== 'item') continue;
    const p = n.firstChild;
    if (!p || p.type !== 'paragraph' || !p.firstChild || p.firstChild.type !== 'strong') continue;
    const label = textOf(p.firstChild);
    if (!label.endsWith(':')) {
      // the bullet character is kept only in the parser's private list data
      if (!p.firstChild.next) lines.push([n._listData.bulletChar === '-' ? 'l' : 'b', depthOf(n), section, label, '']);
      continue;
    }
    let value = '';
    if (p.firstChild.next) {
      for (let c = p.firstChild.next; c; c = c.next) value += c.type === 'text' ? c.literal : textOf(c);
      if (value.startsWith(' ')) value = value.substring(1);
    } else if (p.next && p.next.type === 'code_block') {
      value = p.next.literal.endsWith('\n') ? p.next.literal.slice(0, -1) : p.next.literal;
    }
    lines.push(['v', depthOf(n), section, label.slice(0, -1), value]);
  }
  return { file, nodes: [...nodes].sort(), lines };
}

const files = fs.readFileSync(process.argv[3], 'utf8').split('\n').filter((l) => l !== '');
for (const file of files) process.stdout.write(JSON.stringify(analyse(file)) + '\n');
