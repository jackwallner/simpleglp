#!/usr/bin/env python3
"""Checks the shared string catalogs against the Swift source.

Run from the repo root: python3 Tools/Localization/check.py

Fails (exit 1) when
  * a localizable literal in the source has no catalog key,
  * a catalog key is missing a language, or
  * a translation's format specifiers do not match its key.

Literals count as localizable when they are used by a SwiftUI text API,
App Intents, or String(localized:). Interpolations are compared loosely
(%@ and %lld match each other), because the type of an interpolated expression
is not visible without the compiler.
"""
import json
import os
import plistlib
import re
import sys

ROOT = os.getcwd()
DIRS = ['SimpleGLP', 'SharedGLP', 'SimpleGLPWidget', 'SimpleGLPWatch']
LANGS = ['pt-BR', 'tr', 'es', 'pl', 'zh-Hant', 'ru', 'hu', 'it', 'de', 'fr']
PLURAL_CATEGORIES = {
    'en': {'one', 'other'},
    'pt-BR': {'one', 'other'}, 'tr': {'one', 'other'}, 'es': {'one', 'other'},
    'pl': {'one', 'few', 'many', 'other'}, 'zh-Hant': {'other'},
    'ru': {'one', 'few', 'many', 'other'}, 'hu': {'one', 'other'},
    'it': {'one', 'other'}, 'de': {'one', 'other'}, 'fr': {'one', 'other'},
}
INFO_PLISTS = ['SimpleGLP/Info.plist', 'SimpleGLPWidget/Info.plist', 'SimpleGLPWatch/Info.plist']
INFO_COPY_KEYS = ['NSHealthShareUsageDescription', 'NSHealthUpdateUsageDescription']
UI_FUNCS = {'Text', 'Button', 'Label', 'Section', 'Toggle', 'TextField', 'NavigationLink', 'navigationTitle', 'accessibilityLabel',
            'alert', 'DatePicker', 'Stepper', 'Link', 'configurationDisplayName', 'description', 'eyebrow',
            'confirmationDialog', 'Picker', 'LocalizedStringKey', 'accessibilityHint', 'SecureField'}
NAMED_COPY_ARGS = {'title', 'subtitle', 'detail', 'headline', 'text', 'shortTitle', 'description', 'message', 'label'}
INTENT_FUNCS = {'IntentDescription', 'LocalizedStringResource', 'result'}
IGNORED = {'0', '·', '–', 'checkmark.circle.fill', 'clock'}


def parse_literal(src, i):
    """src[i] == '"'. Returns (end_index_after, segments) where segments are ('lit', str) or ('interp', expr)."""
    assert src[i] == '"'
    if src.startswith('"""', i):
        j = src.index('"""', i + 3)
        return j + 3, None
    i += 1
    segs = []; buf = ''
    while True:
        c = src[i]
        if c == '"':
            if buf: segs.append(('lit', buf))
            return i + 1, segs
        if c == '\\':
            n = src[i + 1]
            if n == '(':
                if buf: segs.append(('lit', buf)); buf = ''
                depth = 1; j = i + 2; expr = ''
                while depth:
                    ch = src[j]
                    if ch == '"':
                        k, _ = parse_literal(src, j)
                        expr += src[j:k]; j = k; continue
                    if ch == '(': depth += 1
                    elif ch == ')':
                        depth -= 1
                        if depth == 0: break
                    expr += ch; j += 1
                segs.append(('interp', expr.strip()))
                i = j + 1; continue
            if n == 'u':
                j = src.index('}', i)
                buf += chr(int(src[i + 3:j], 16)); i = j + 1; continue
            buf += {'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f', '"': '"', '\\': '\\', "'": "'", '0': '\0'}.get(n, n)
            i += 2; continue
        buf += c; i += 1

def scan(path):
    src = open(path).read()
    out = []
    stack = []  # (funcname, argtext_since_last_comma, argindex)
    i = 0; n = len(src)
    line = 1
    while i < n:
        c = src[i]
        if c == '\n': line += 1
        if src.startswith('//', i):
            j = src.find('\n', i); i = n if j < 0 else j; continue
        if src.startswith('/*', i):
            j = src.index('*/', i); line += src[i:j].count('\n'); i = j + 2; continue
        if c == '"':
            end, segs = parse_literal(src, i)
            if segs is not None:
                fn, argtxt, idx = stack[-1] if stack else ('', '', 0)
                ctx = None
                if fn == 'String' and argtxt.strip().startswith('localized:'):
                    ctx = 'String'
                elif fn in UI_FUNCS and idx == 0 and not re.match(r'\s*[a-zA-Z_]+\s*:', argtxt):
                    ctx = fn
                elif fn in UI_FUNCS and re.match(r'\s*(?:' + '|'.join(NAMED_COPY_ARGS) + r')\s*:', argtxt):
                    ctx = fn
                elif fn in INTENT_FUNCS and (idx == 0 or re.match(r'\s*dialog\s*:', argtxt)):
                    ctx = fn
                elif re.search(r'\b(?:' + '|'.join(NAMED_COPY_ARGS) + r')\s*(?::|=)\s*(?:LocalizedStringResource\s*)?$', src[max(0, i - 100):i]):
                    ctx = 'LocalizedStringResource'
                else:
                    search_start = max(0, i - 1800)
                    phrase_start = src.rfind('phrases:', search_start, i)
                    app_shortcut_start = src.rfind('AppShortcut(', search_start, i)
                    phrase_end = src.rfind(']', search_start, i)
                    if phrase_start > phrase_end and app_shortcut_start < phrase_start:
                        ctx = 'AppShortcut'
                if ctx:
                    out.append((line, ctx, segs))
            line += src[i:end].count('\n')
            if stack:
                f, a, k = stack[-1]; stack[-1] = (f, a + src[i:end], k)
            i = end; continue
        if c == '(':
            m = re.search(r'([A-Za-z_][A-Za-z_0-9]*)\s*$', src[max(0, i - 60):i])
            stack.append((m.group(1) if m else '', '', 0)); i += 1; continue
        if c == ')':
            if stack: stack.pop()
            i += 1; continue
        if c == ',' and stack:
            f, a, k = stack[-1]; stack[-1] = (f, '', k + 1); i += 1; continue
        if stack:
            f, a, k = stack[-1]; stack[-1] = (f, a + c, k)
        i += 1
    return out


def loose(key):
    return re.sub(r'%(\d+\$)?(lld|@)', '%*', key)


def placeholder(expr):
    """Approximate Swift's interpolation type for String Catalog lookup keys."""
    compact = re.sub(r'\s+', '', expr)
    if ('.formatted(' in compact or compact.endswith('.localizedName') or
            compact.endswith('.displayMedicationName') or compact.endswith('.weekdayName') or
            compact.endswith('.localizedDescription') or compact.startswith('time(') or
            compact.startswith('day(') or 'dayDistance(' in compact or
            'DoseScheduleView.format(' in compact or 'intervalLabel(' in compact or
            'GLPDurationText.format(' in compact or 'quickPickDuration(' in compact or
            'glpProPriceLabel' in compact or 'glpProIntroOfferLabel' in compact or
            compact in {'amount', 'slot', 'cadence', 'time', 'date', 'through', 'price', 'trial', 'renew', 'pitch', 'duration', 'formatted', 'name', 'unit', 'error.localizedDescription'}):
        return '%@'
    if (compact == '$0' or re.search(r'\b(?:count|streak|days|minutes|waitMinutes|snoozeMinutes|reminderDay|reminderLeadMinutes|left|remaining|onTime|total|shots|pct|percent|value|n|reminderLeadDays)\b', compact) or
            compact.startswith('period.value') or compact.startswith('summary.') or
            compact.startswith('recent.') or compact.startswith('SupplyMath.daysLeft(') or
            compact.startswith('SupplyMath.reminderLeadDays') or compact.startswith('events.count') or
            compact.endswith('.effectiveWaitMinutes') or
            compact.startswith('ProactiveAlertsEngine.minimumSampleSize') or compact.startswith('Int(')):
        return '%lld'
    return '%@'


def key_from_segments(segs):
    has_interp = any(kind == 'interp' for kind, _ in segs)
    return ''.join((value.replace('%', '%%') if has_interp else value)
                   if kind == 'lit' else placeholder(value)
                   for kind, value in segs)


def specs(value, subs=None):
    found = []
    auto = 0
    for m in re.finditer(r'%(?:(\d+)\$)?(lld|@|%)|%#@(\w+)@', value):
        if m.group(2) == '%':
            continue
        if m.group(3):
            if subs and m.group(3) in subs:
                found.append((subs[m.group(3)]['argNum'], 'lld'))
            continue
        if m.group(1):
            pos = int(m.group(1))
        else:
            auto += 1
            pos = auto
        found.append((pos, m.group(2)))
    return sorted(set(found))


def main():
    catalog_path = os.path.join(ROOT, 'SharedGLP', 'Localizable.xcstrings')
    info_path = os.path.join(ROOT, 'SimpleGLP', 'InfoPlist.xcstrings')
    catalog = json.load(open(catalog_path, encoding='utf-8'))['strings']
    by_loose = {loose(k): k for k in catalog}
    problems = []
    for d in DIRS:
        for dirpath, _, files in os.walk(os.path.join(ROOT, d)):
            for name in files:
                if not name.endswith('.swift'):
                    continue
                path = os.path.join(dirpath, name)
                for line, _, segs in scan(path):
                    key = key_from_segments(segs)
                    if key.strip() and key not in IGNORED and loose(key) not in by_loose:
                        problems.append(f'{os.path.relpath(path, ROOT)}:{line}: no catalog key for "{key}"')
    for path in (catalog_path, info_path):
        if not os.path.exists(path):
            problems.append(f'missing catalog: {os.path.relpath(path, ROOT)}')
            continue
        strings = json.load(open(path, encoding='utf-8'))['strings']
        for key, entry in strings.items():
            locs = entry.get('localizations', {})
            if 'en' not in locs:
                problems.append(f'"{key}": missing en source localization')
            for lang in ['en'] + LANGS:
                loc = locs.get(lang)
                if loc is None:
                    problems.append(f'"{key}": missing {lang}')
                    continue
                want = specs(key)
                if 'variations' in loc:
                    plural = loc['variations'].get('plural', {})
                    missing_categories = PLURAL_CATEGORIES[lang] - set(plural)
                    if missing_categories:
                        problems.append(f'"{key}" [{lang}]: missing plural categories {sorted(missing_categories)}')
                    values = [u['stringUnit']['value'] for category, u in plural.items() if category in PLURAL_CATEGORIES[lang]]
                    bad = [v for v in values if specs(v) != want]
                else:
                    substitutions = loc.get('substitutions', {})
                    value = loc.get('stringUnit', {}).get('value', '')
                    bad = [] if specs(value, substitutions) == want else [value]
                    for substitution_name, substitution in substitutions.items():
                        plural = substitution.get('variations', {}).get('plural')
                        if plural is None:
                            continue
                        missing_categories = PLURAL_CATEGORIES[lang] - set(plural)
                        if missing_categories:
                            problems.append(f'"{key}" [{lang}] substitution {substitution_name}: missing plural categories {sorted(missing_categories)}')
                        for category in PLURAL_CATEGORIES[lang] & set(plural):
                            plural_value = plural[category].get('stringUnit', {}).get('value', '')
                            if plural_value.count('%arg') != 1:
                                problems.append(f'"{key}" [{lang}] substitution {substitution_name} [{category}]: expected one %arg in "{plural_value}"')
                for v in bad:
                    problems.append(f'"{key}" [{lang}]: format specifiers differ in "{v}"')
    info_strings = json.load(open(info_path, encoding='utf-8')).get('strings', {}) if os.path.exists(info_path) else {}
    app_info = plistlib.load(open(INFO_PLISTS[0], 'rb'))
    for key in INFO_COPY_KEYS:
        value = app_info.get(key)
        if not value or key not in info_strings:
            problems.append(f'InfoPlist.xcstrings: missing source key for {key}')
            continue
        english = info_strings[key].get('localizations', {}).get('en', {}).get('stringUnit', {}).get('value')
        if english != value:
            problems.append(f'InfoPlist.xcstrings: English value for {key} does not match Info.plist')
    expected_localizations = {'en', *LANGS}
    for path in INFO_PLISTS:
        plist = plistlib.load(open(path, 'rb'))
        missing = expected_localizations - set(plist.get('CFBundleLocalizations', []))
        if missing:
            problems.append(f'{path}: missing CFBundleLocalizations {sorted(missing)}')
    for p in problems:
        print(p)
    print(f'{len(catalog)} keys, {len(LANGS)} languages, {len(problems)} problems')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
