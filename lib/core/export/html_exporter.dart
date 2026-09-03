import 'dart:convert';

import 'package:opentranscribe/core/export/export_helpers.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/reflection.dart';

/// Export as a page that reads without any app at all. Nothing is fetched:
/// styles, script and the mark are all carried in the export, and the single
/// link out to the site loads only when a reader taps it. The script is an
/// upgrade over markup that already works without it, so a viewer that runs
/// none still gets a readable journal with playable audio. The palette carries
/// both schemes and follows the reader's machine rather than the exporting
/// device, so the file looks right wherever it ends up.
///
/// A journal is a single `index.html` rather than a page per entry: the value
/// here is reading and finding, which one document does better, and one file
/// at the root has no relative paths to get wrong. A single entry inlines the
/// stylesheet instead, so the `.html` stands alone when it is dragged out of
/// the folder.
final class HtmlExporter implements JournalExporter {
  const HtmlExporter();

  @override
  String get id => 'html';

  @override
  List<ExportFile> exportEntry(ExportEntry entry, ExportContext context) {
    final base = entryFileBaseName(entry.entry, untitled: context.strings.untitledEntry);
    final title = entryTitle(entry.entry, context.strings.untitledEntry);
    final body = StringBuffer()
      ..writeln('<main>')
      ..write(_article(entry, context, level: 1))
      ..writeln('</main>');
    return [
      ExportFile.text(
        '$base.html',
        _document(
          title: title,
          lang: entry.entry.effectiveLocaleId,
          style: '<style>\n$_css</style>',
          script: '<script>\n$_js</script>',
          body: body.toString(),
          context: context,
        ),
      ),
    ];
  }

  @override
  List<ExportFile> exportJournal(ExportSnapshot snapshot, ExportContext context) {
    final timeline = journalTimeline(entries: snapshot.entries, reflections: snapshot.reflections);
    final byMonth = <String, List<TimelineDay>>{};
    for (final day in timeline) {
      byMonth.putIfAbsent(_monthKey(day.day), () => []).add(day);
    }
    final monthKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    final chrome = context.strings.html;
    final body = StringBuffer()
      ..write(_header(snapshot))
      ..write(_tools(searchable: snapshot.entries.isNotEmpty, chrome: chrome))
      ..write(_nav(monthKeys))
      ..writeln('<main>');
    for (final month in monthKeys) {
      body
        ..writeln('<section class="month" id="m-$month">')
        ..writeln('<h2>${_text(month)}</h2>');
      // Day by day, cards over the entries they cover: a document reads the
      // journal in the order home does, not reflections then everything else.
      for (final day in byMonth[month]!) {
        for (final reflection in day.reflections) {
          body.write(_reflection(reflection, context));
        }
        for (final entry in day.entries) {
          body.write(_article(entry, context, level: 3));
        }
      }
      body.writeln('</section>');
    }
    if (monthKeys.isEmpty) {
      body.write(_emptyState(title: _text(chrome.emptyTitle), message: _text(chrome.emptyBody)));
    } else if (snapshot.entries.isNotEmpty) {
      body.write(
        _emptyState(
          title: _text(chrome.noMatchesTitle),
          message: _text(
            chrome.noMatches,
          ).replaceAll(HtmlChromeStrings.termSlot, '<span class="term"></span>'),
          hidden: true,
        ),
      );
    }
    body.writeln('</main>');
    return [
      ExportFile.text(
        'index.html',
        _document(
          title: _pageTitle,
          lang: chrome.languageTag,
          style: '<link rel="stylesheet" href="style.css">',
          script: '<script src="script.js"></script>',
          body: body.toString(),
          context: context,
        ),
      ),
      ExportFile.text('style.css', _css),
      ExportFile.text('script.js', _js),
    ];
  }

  String _header(ExportSnapshot snapshot) {
    final buffer = StringBuffer()
      ..writeln('<header class="journal">')
      // noreferrer so a journal that ends up hosted does not announce its own
      // address to the site it links to.
      ..writeln('<a class="brand" href="$_siteUrl" target="_blank" rel="noopener noreferrer">')
      ..writeln(_waveMark)
      ..writeln('<h1>$_pageTitle</h1>')
      ..writeln('</a>');
    if (snapshot.entries.isNotEmpty) {
      buffer.writeln('<p class="meta">${_text(_span(snapshot.entries))}</p>');
    }
    return (buffer..writeln('</header>')).toString();
  }

  /// Hidden until the script unhides them: a filter that cannot filter and a
  /// switch that cannot switch are worse than neither. Only the field depends
  /// on [searchable], because a journal of nothing but reflections still has a
  /// scheme worth choosing.
  String _tools({required bool searchable, required HtmlChromeStrings chrome}) {
    final buffer = StringBuffer()..writeln('<div class="tools" hidden>');
    if (searchable) {
      final search = _attr(chrome.search);
      buffer.writeln(
        '<input class="search" type="search" placeholder="$search" aria-label="$search">',
      );
    }
    return (buffer
          ..writeln('<div class="scheme" role="group" aria-label="${_attr(chrome.schemeLabel)}">')
          ..writeln(
            '<button data-scheme="" aria-pressed="true">${_text(chrome.schemeAuto)}</button>',
          )
          ..writeln(
            '<button data-scheme="light" aria-pressed="false">${_text(chrome.schemeLight)}</button>',
          )
          ..writeln(
            '<button data-scheme="dark" aria-pressed="false">${_text(chrome.schemeDark)}</button>',
          )
          ..writeln('</div>')
          ..writeln('</div>'))
        .toString();
  }

  /// A lone month needs no way to reach itself.
  String _nav(List<String> monthKeys) {
    if (monthKeys.length < 2) return '';
    final buffer = StringBuffer()..writeln('<nav class="months">');
    for (final month in monthKeys) {
      buffer.writeln('<a href="#m-$month">${_text(month)}</a>');
    }
    return (buffer..writeln('</nav>')).toString();
  }

  String _emptyState({required String title, required String message, bool hidden = false}) =>
      '<div class="empty"${hidden ? ' hidden' : ''}>\n'
      '<div class="empty-mark">$_waveMark</div>\n'
      '<p class="empty-title">$title</p>\n'
      '<p class="empty-message">$message</p>\n'
      '</div>\n';

  String _monthKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}';
  }

  String _span(List<ExportEntry> entries) {
    final days = [for (final e in entries) entryDateStamp(e.entry)]..sort();
    return days.first == days.last ? days.first : '${days.first} - ${days.last}';
  }

  String _article(ExportEntry exportEntry, ExportContext context, {required int level}) {
    final entry = exportEntry.entry;
    final local = entry.createdAt.toLocal();
    final title = entryTitle(entry, context.strings.untitledEntry);
    final locale = entry.effectiveLocaleId;
    final meta = [
      exportClock(entry.duration),
      if (locale != null) _text(locale),
    ].join(' &middot; ');
    final buffer = StringBuffer()
      ..writeln(
        '<article class="entry" id="e-${_attr(entry.id)}"'
        '${locale == null ? '' : ' lang="${_attr(locale)}"'}>',
      )
      ..writeln('<p class="meta">')
      // The attribute carries the local time and its offset, not the UTC
      // instant: the same moment, but a reader near midnight would otherwise
      // find the machine-readable day disagreeing with the one printed.
      ..writeln(
        '<time datetime="${_localIso(local)}">'
        '${entryDateStamp(entry)} ${_timeOfDay(local)}</time> &middot; $meta',
      )
      ..writeln('</p>')
      ..writeln('<h$level>${_text(title)}</h$level>');
    final audio = exportEntry.audioRelativePath;
    if (audio != null) {
      // preload=none because a journal of hundreds of entries must not ask for
      // every recording on open; the length is already known here, so the
      // custom player can show it without loading anything.
      buffer
        ..writeln('<div class="player" data-duration="${entry.duration.inSeconds}">')
        ..writeln('<audio controls preload="none" src="${_attr(urlPath(audio))}"></audio>')
        ..writeln('</div>');
    }
    // Paragraphs rather than a bare isEmpty, which does not trim: a recording
    // of pure silence can hold whitespace, and an empty block is a gap the
    // reader cannot explain.
    final paragraphs = _paragraphs(entry.readableText ?? '');
    if (paragraphs.isNotEmpty) {
      buffer
        ..writeln('<div class="transcript">')
        ..writeln(paragraphs)
        ..writeln('</div>');
    }
    return (buffer..writeln('</article>')).toString();
  }

  String _reflection(Reflection reflection, ExportContext context) {
    final strings = context.strings;
    final heading = '${strings.periodLabel(reflection.period)} ${reflection.periodKey}';
    return '<article class="reflection">\n'
        '<h3>${_text(heading)}</h3>\n'
        '${_paragraphs(reflection.text ?? strings.quietReflection)}\n'
        '</article>\n';
  }

  /// Escaped first, so nothing in a transcript can open a tag.
  String _paragraphs(String text) {
    final blocks = text.trim().split(RegExp(r'\n[ \t]*\n'));
    return [
      for (final block in blocks)
        if (block.trim().isNotEmpty) '<p>${_text(block.trim()).replaceAll('\n', '<br>\n')}</p>',
    ].join('\n');
  }

  String _document({
    required String title,
    required String? lang,
    required String style,
    required String script,
    required String body,
    required ExportContext context,
  }) =>
      '<!doctype html>\n'
      '<html${lang == null ? '' : ' lang="${_attr(lang)}"'}>\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      '<title>${_text(title)}</title>\n'
      '$style\n'
      '</head>\n'
      '<body>\n'
      '$body'
      '<footer>${_text(_appName)} ${_text(context.appVersion)} '
      '&middot; ${context.generatedAt.toUtc().toIso8601String()}</footer>\n'
      '${_labels(context.strings.html)}\n'
      '$script\n'
      '</body>\n'
      '</html>\n';

  /// The player's spoken labels, carried on the page because `script.js` is
  /// the same static file in every export. `<` is escaped so no translation
  /// could ever close the block early.
  String _labels(HtmlChromeStrings chrome) {
    final json = jsonEncode({
      'play': chrome.play,
      'pause': chrome.pause,
      'back': chrome.back,
      'speed': chrome.speed,
      'seek': chrome.seek,
    }).replaceAll('<', r'\u003c');
    return '<script type="application/json" id="l10n">$json</script>';
  }

  /// `2026-08-07T01:00:00.000+04:00`: the local wall clock with the offset
  /// that pins it, so the attribute names the same day its own text does.
  String _localIso(DateTime local) {
    final offset = local.timeZoneOffset;
    final abs = offset.abs();
    final hours = abs.inHours.toString().padLeft(2, '0');
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '${local.toIso8601String()}${offset.isNegative ? '-' : '+'}$hours:$minutes';
  }

  String _timeOfDay(DateTime local) =>
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  static const _appName = 'OpenTranscribe';

  static const _pageTitle = '$_appName Export';

  static const _siteUrl = 'https://opentranscribe.xyz';

  /// The app's wave, inline so the page stays one file that fetches nothing.
  /// Each bar is a fully rounded rect, which approximates the path form in
  /// `web/lib/wave.ts`, spelled shorter.
  static const _waveMark =
      '<svg class="wave" viewBox="0 0 492 481" aria-hidden="true" focusable="false">'
      '<g fill="currentColor">'
      '<rect x="0" y="157" width="42" height="167" rx="21"/>'
      '<rect x="75" y="84" width="42" height="313" rx="21"/>'
      '<rect x="150" y="0" width="42" height="481" rx="21"/>'
      '<rect x="225" y="72" width="42" height="337" rx="21"/>'
      '<rect x="300" y="120" width="42" height="241" rx="21"/>'
      '<rect x="375" y="37" width="42" height="407" rx="21"/>'
      '<rect x="450" y="144" width="42" height="193" rx="21"/>'
      '</g></svg>';

  /// Text nodes and attribute values want different escapes: the default
  /// mode also escapes `/`, which turns a relative path into `a&#47;b`.
  static String _text(String value) => const HtmlEscape(HtmlEscapeMode.element).convert(value);

  static String _attr(String value) => const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

  /// Nothing here fetches, because the page is opened from `file://` as often
  /// as not, where a fetch is refused anyway.
  static const _js = r'''
(function () {
  var root = document.documentElement;

  // The page carries its own labels (the #l10n block); these defaults only
  // cover a page without one.
  var L = { play: 'Play', pause: 'Pause', back: 'Back 15 seconds',
    speed: 'Playback speed', seek: 'Seek' };
  var carried = document.getElementById('l10n');
  if (carried) {
    try {
      var labels = JSON.parse(carried.textContent);
      for (var key in L) if (typeof labels[key] === 'string') L[key] = labels[key];
    } catch (e) {}
  }

  function clock(seconds) {
    if (!isFinite(seconds) || seconds < 0) seconds = 0;
    var s = Math.floor(seconds % 60);
    var m = Math.floor(seconds / 60) % 60;
    var h = Math.floor(seconds / 3600);
    return (h > 0 ? h + ':' + (m < 10 ? '0' : '') : '') + m + ':' + (s < 10 ? '0' : '') + s;
  }

  var PLAY = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M4 2.5v11l9-5.5z"/></svg>';
  var PAUSE = '<svg viewBox="0 0 16 16" aria-hidden="true">' +
    '<path d="M4 2.5h3v11H4zm5 0h3v11H9z"/></svg>';
  var BACK = '<svg viewBox="0 0 16 16" aria-hidden="true">' +
    '<path d="M8 3V1L4.5 3.5 8 6V4a4 4 0 1 1-4 4H2.5a5.5 5.5 0 1 0 5.5-5z"/></svg>';
  var RATES = [1, 1.25, 1.5, 2];
  var playing = null;

  function upgrade(box) {
    var audio = box.querySelector('audio');
    if (!audio) return;
    audio.removeAttribute('controls');
    var total = parseFloat(box.getAttribute('data-duration')) || 0;

    var back = document.createElement('button');
    back.innerHTML = BACK;
    back.setAttribute('aria-label', L.back);
    var play = document.createElement('button');
    play.innerHTML = PLAY;
    play.setAttribute('aria-label', L.play);
    var seek = document.createElement('input');
    seek.type = 'range';
    seek.className = 'seek';
    seek.min = '0';
    seek.step = 'any';
    seek.max = String(total || 1);
    seek.value = '0';
    seek.setAttribute('aria-label', L.seek);
    var time = document.createElement('span');
    time.className = 'time';
    time.textContent = '0:00 / ' + clock(total);
    var rate = document.createElement('button');
    rate.className = 'rate';
    rate.textContent = '1x';
    rate.setAttribute('aria-label', L.speed);

    box.appendChild(play);
    box.appendChild(back);
    box.appendChild(seek);
    box.appendChild(time);
    box.appendChild(rate);
    box.classList.add('ready');

    function paint() {
      var length = isFinite(audio.duration) && audio.duration > 0 ? audio.duration : total;
      seek.max = String(length || 1);
      seek.value = String(audio.currentTime);
      time.textContent = clock(audio.currentTime) + ' / ' + clock(length);
    }

    play.addEventListener('click', function () {
      if (audio.paused) {
        // One at a time: a page of entries playing over each other is noise.
        if (playing && playing !== audio) playing.pause();
        var started = audio.play();
        if (started && started.catch) started.catch(function () {});
      } else {
        audio.pause();
      }
    });
    back.addEventListener('click', function () {
      audio.currentTime = Math.max(0, audio.currentTime - 15);
      paint();
    });
    rate.addEventListener('click', function () {
      var next = RATES[(RATES.indexOf(audio.playbackRate) + 1) % RATES.length];
      audio.playbackRate = next;
      rate.textContent = next + 'x';
    });
    seek.addEventListener('input', function () {
      audio.currentTime = parseFloat(seek.value) || 0;
      paint();
    });
    audio.addEventListener('play', function () {
      playing = audio;
      play.innerHTML = PAUSE;
      play.setAttribute('aria-label', L.pause);
    });
    audio.addEventListener('pause', function () {
      if (playing === audio) playing = null;
      play.innerHTML = PLAY;
      play.setAttribute('aria-label', L.play);
    });
    audio.addEventListener('timeupdate', paint);
    audio.addEventListener('loadedmetadata', paint);
    audio.addEventListener('ended', paint);
  }

  Array.prototype.forEach.call(document.querySelectorAll('.player'), upgrade);

  var tools = document.querySelector('.tools');
  if (tools) tools.hidden = false;

  var scheme = document.querySelectorAll('.scheme button');
  function applyScheme(value) {
    if (value) root.setAttribute('data-scheme', value);
    else root.removeAttribute('data-scheme');
    Array.prototype.forEach.call(scheme, function (button) {
      button.setAttribute('aria-pressed', String(button.getAttribute('data-scheme') === value));
    });
    try { localStorage.setItem('scheme', value); } catch (e) {}
  }
  Array.prototype.forEach.call(scheme, function (button) {
    button.addEventListener('click', function () {
      applyScheme(button.getAttribute('data-scheme'));
    });
  });
  try { applyScheme(localStorage.getItem('scheme') || ''); } catch (e) {}

  var nav = document.querySelector('nav.months');
  var chips = document.querySelectorAll('nav.months a');

  var search = document.querySelector('.search');
  var empty = document.querySelector('.empty');
  var term = document.querySelector('.empty .term');
  var entries = document.querySelectorAll('.entry');
  var sections = document.querySelectorAll('.month');
  var reflections = document.querySelectorAll('.reflection');

  // Not entry.textContent: the player's own time and rate readouts sit inside
  // the entry, so the rendered text matches the chrome rather than the words.
  function haystack(entry) {
    if (entry.searchText === undefined) {
      var heading = entry.querySelector('h1, h2, h3, h4, h5, h6');
      var body = entry.querySelector('.transcript');
      entry.searchText = ((heading ? heading.textContent : '') + ' ' +
        (body ? body.textContent : '')).toLowerCase();
    }
    return entry.searchText;
  }

  if (search) {
    search.addEventListener('input', function () {
      var typed = search.value.trim();
      var needle = typed.toLowerCase();
      var hits = 0;
      Array.prototype.forEach.call(entries, function (entry) {
        var match = !needle || haystack(entry).indexOf(needle) >= 0;
        entry.hidden = !match;
        if (match) hits++;
      });
      Array.prototype.forEach.call(sections, function (month) {
        // Guarded on the needle: a month that holds only reflections has no
        // entry to find, and an unguarded test hides it for good the moment
        // anything is typed and cleared.
        month.hidden = !!needle && !month.querySelector('.entry:not([hidden])');
      });
      // Reflections belong to a period, not to a search: hide them while
      // filtering rather than pretending they matched.
      Array.prototype.forEach.call(reflections, function (card) {
        card.hidden = !!needle;
      });
      // The chips jump to months, and a filter has just hidden most of them;
      // leaving them up offers a reader links that go nowhere.
      if (nav) nav.hidden = !!needle;
      if (empty) empty.hidden = !needle || hits > 0;
      // textContent, never innerHTML: whatever was typed is not markup. The
      // quotes around it belong to the translation, not to this script.
      if (term) term.textContent = typed;
      spy();
    });
  }

  // At the foot of a scrolling page the document stops before the final month
  // can pass under the bar, and that month is the one a reader just jumped to.
  function spy() {
    if (!nav || !chips.length) return;
    // The chips wrap, so the bar is 50px tall at one row and 160 at four.
    // scroll-margin-top reads this, or a jumped-to heading lands under it.
    root.style.setProperty('--nav', nav.offsetHeight + 'px');
    var months = document.querySelectorAll('.month:not([hidden])');
    if (!months.length) return;
    var line = nav.getBoundingClientRect().bottom + 8;
    var active = months[0];
    Array.prototype.forEach.call(months, function (month) {
      if (month.getBoundingClientRect().top <= line) active = month;
    });
    var range = root.scrollHeight - window.innerHeight;
    if (range > window.innerHeight / 2 && window.pageYOffset >= range - 2) {
      active = months[months.length - 1];
    }
    Array.prototype.forEach.call(chips, function (chip) {
      chip.classList.toggle('active', chip.getAttribute('href') === '#' + active.id);
    });
  }

  window.addEventListener('scroll', spy, { passive: true });
  window.addEventListener('resize', spy);
  window.addEventListener('hashchange', spy);
  spy();
})();
''';

  static const _css = r'''
:root {
  --bg: #ffffff;
  --surface: #f4f4f4;
  --surface-border: #d9d9d9;
  --text: #111111;
  --text-secondary: #79797b;
  --hairline: #dedede;
  --accent: #111111;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-scheme="light"]) {
    --bg: #111111;
    --surface: #1c1c1e;
    --surface-border: #2a2a2c;
    --text: #f5f5f5;
    --text-secondary: #98989e;
    --hairline: #2a2a2c;
    --accent: #f5f5f5;
  }
}
:root[data-scheme="dark"] {
  --bg: #111111;
  --surface: #1c1c1e;
  --surface-border: #2a2a2c;
  --text: #f5f5f5;
  --text-secondary: #98989e;
  --hairline: #2a2a2c;
  --accent: #f5f5f5;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
@media (prefers-reduced-motion: reduce) { html { scroll-behavior: auto; } }
:root { color-scheme: light dark; }
:root[data-scheme="light"] { color-scheme: light; }
:root[data-scheme="dark"] { color-scheme: dark; }
/* The attribute alone is only a UA rule, and every author `display` here
   would outrank it, leaving a hidden element on screen. */
[hidden] { display: none !important; }
body {
  margin: 0 auto;
  padding: 24px 20px 48px;
  max-width: 680px;
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
  font-size: 17px;
  line-height: 1.45;
  letter-spacing: -0.4px;
  -webkit-text-size-adjust: 100%;
}
h1 { font-size: 34px; font-weight: 600; letter-spacing: -0.8px; margin: 0 0 4px; }
h2 { font-size: 20px; font-weight: 600; letter-spacing: -0.4px; margin: 32px 0 12px; }
h3 { font-size: 17px; font-weight: 600; letter-spacing: -0.4px; margin: 0 0 8px; }
p { margin: 0 0 12px; }
p:last-child { margin-bottom: 0; }
.meta {
  color: var(--text-secondary);
  font-size: 13px;
  letter-spacing: -0.08px;
  margin: 0 0 4px;
  font-variant-numeric: tabular-nums;
}
header.journal { margin-bottom: 20px; }
nav.months {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding-bottom: 20px;
  border-bottom: 1px solid var(--hairline);
  position: sticky;
  top: 0;
  background: var(--bg);
  z-index: 1;
}
nav.months a {
  color: var(--text-secondary);
  text-decoration: none;
  font-size: 13px;
  letter-spacing: -0.08px;
  padding: 4px 10px;
  border: 1px solid var(--surface-border);
  border-radius: 12px;
}
nav.months a:hover { color: var(--text); }
nav.months a.active { color: var(--text); border-color: var(--text-secondary); }
article.entry, article.reflection {
  background: var(--surface);
  border: 1px solid var(--surface-border);
  border-radius: 20px;
  padding: 16px;
  margin: 0 0 12px;
}
article.reflection { background: none; border-style: dashed; }
.month { scroll-margin-top: calc(var(--nav, 60px) + 8px); }
.transcript { margin-top: 12px; }
footer {
  margin-top: 32px;
  padding-top: 20px;
  border-top: 1px solid var(--hairline);
  color: var(--text-secondary);
  font-size: 13px;
  letter-spacing: -0.08px;
}
.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 48px 0;
  color: var(--text-secondary);
  font-size: 15px;
}
.empty-mark {
  display: grid;
  place-items: center;
  width: 90px;
  height: 90px;
  background: var(--surface);
  border: 1px solid var(--surface-border);
  border-radius: 28px;
}
.empty-mark .wave { width: 42px; height: 42px; }
.empty-title {
  margin: 16px 0 0;
  font-size: 20px;
  font-weight: 600;
  letter-spacing: -0.4px;
}
.empty-message {
  margin: 8px 0 0;
  max-width: 34ch;
  line-height: 1.5;
}
.empty-message .term { color: var(--text); }

.brand {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  color: inherit;
  text-decoration: none;
}
.brand .wave { flex: none; width: 26px; height: 26px; }
.brand:hover h1 { text-decoration: underline; text-underline-offset: 3px; }
.brand:focus-visible { outline: 2px solid var(--accent); outline-offset: 4px; border-radius: 4px; }

.tools { display: flex; gap: 8px; margin: 0 0 16px; }
.search {
  flex: 1;
  min-width: 0;
  font: inherit;
  font-size: 15px;
  color: var(--text);
  background: var(--surface);
  border: 1px solid var(--surface-border);
  border-radius: 12px;
  padding: 8px 12px;
  -webkit-appearance: none;
  appearance: none;
}
.search::placeholder { color: var(--text-secondary); }
.search:focus-visible { outline: 2px solid var(--accent); outline-offset: -1px; }
.scheme { display: flex; gap: 2px; padding: 2px; background: var(--surface); border-radius: 12px; }
.scheme button {
  font: inherit;
  font-size: 13px;
  letter-spacing: -0.08px;
  color: var(--text-secondary);
  background: none;
  border: 0;
  border-radius: 10px;
  padding: 6px 10px;
  cursor: pointer;
}
.scheme button[aria-pressed="true"] { color: var(--text); background: var(--bg); }

.player audio { display: block; width: 100%; margin: 12px 0 0; }
.player.ready audio { display: none; }
.player.ready {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  margin-top: 12px;
  padding: 8px 10px;
  background: var(--bg);
  border: 1px solid var(--surface-border);
  border-radius: 12px;
}
.player button {
  flex: none;
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  color: var(--text);
  background: none;
  border: 0;
  border-radius: 10px;
  cursor: pointer;
  padding: 0;
}
.player button:hover { background: var(--surface); }
.player button svg { width: 16px; height: 16px; fill: currentColor; }
.player .rate {
  width: auto;
  padding: 0 8px;
  font: inherit;
  font-size: 12px;
  letter-spacing: 0;
  color: var(--text-secondary);
  font-variant-numeric: tabular-nums;
}
.player .seek {
  flex: 1;
  min-width: 80px;
  height: 4px;
  border-radius: 2px;
  background: var(--surface-border);
  -webkit-appearance: none;
  appearance: none;
  cursor: pointer;
}
.player .seek::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--accent);
}
.player .seek::-moz-range-thumb {
  width: 12px;
  height: 12px;
  border: 0;
  border-radius: 50%;
  background: var(--accent);
}
.player .time {
  flex: none;
  font-size: 12px;
  letter-spacing: 0;
  color: var(--text-secondary);
  font-variant-numeric: tabular-nums;
}

@media print {
  /* Matched to the dark-scheme selectors above, which a media query alone
     cannot outrank. */
  :root, :root:not([data-scheme="light"]) {
    --bg: #ffffff;
    --surface: #ffffff;
    --surface-border: #cccccc;
    --text: #000000;
    --text-secondary: #444444;
    --hairline: #cccccc;
    --accent: #000000;
  }
  nav.months, .tools, footer { display: none; }
  /* .player.ready outranks a bare .player, and print adds no specificity. */
  .player, .player.ready { display: none; }
  body { max-width: none; }
  article.entry, article.reflection {
    background: none;
    border: 0;
    padding: 0;
    margin-bottom: 20px;
    break-inside: avoid;
  }
}
''';
}
