// ─────────────────────────────────────────────────────────────────────────────
// spell_check_service.dart
//
// Offline spelling + grammar checking for every text field in the app.
//
// Why offline: the app must behave identically with AI switched off, so the
// checker is a deterministic dictionary + rule engine — no provider, no
// network, no per-check cost that scales with tokens.
//
// How it stays quiet instead of noisy:
//   • Validity comes from a large English word list (assets/config/
//     spell_dictionary.txt, ~230k words). Archaic words being in the list only
//     ever means a word is accepted, never rejected, so the list can err large.
//   • A word is only *underlined* when it is not in the dictionary (plus the
//     user's dictionary, ignored words, the built-in project vocabulary, and
//     contractions / possessives of known words).
//   • Acronyms (NDU, KAZ, WBS), identifiers (PowerBI, kWh), numbers, URLs and
//     e-mails are never flagged.
//   • Grammar rules are limited to rules with no legitimate false positives
//     (repeated words, double spaces, space before punctuation, an
//     uncapitalised sentence start, "could of", "alot"). Ambiguous pairs like
//     its/it's and your/you're are deliberately not flagged — a wrong
//     correction is worse than a missed one.
//
// Nothing is ever changed silently: this service only reports issues and
// suggestions. Applying them is the caller's (the user's) decision.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// The kind of problem reported by [SpellCheckService.check].
enum SpellIssueKind {
  /// The word is not in the dictionary.
  spelling,

  /// A rule matched (repeated word, spacing, capitalization...).
  grammar,
}

/// One problem found in a piece of text.
///
/// [start] and [end] are offsets into the checked string, so callers can
/// replace exactly the flagged range.
class SpellIssue {
  SpellIssue({
    required this.start,
    required this.end,
    required this.word,
    required this.kind,
    required this.message,
    List<String>? suggestions,
    this.replacement,
    SpellCheckService? suggestionSource,
  })  : _suggestions = suggestions,
        _suggestionSource = suggestionSource;

  /// Offset of the first character of the flagged range.
  final int start;

  /// Offset just past the flagged range.
  final int end;

  /// The flagged text exactly as it appears in the source.
  final String word;

  final SpellIssueKind kind;

  /// Short human-readable reason, e.g. `Misspelling` or `Repeated word`.
  final String message;

  final List<String>? _suggestions;
  final SpellCheckService? _suggestionSource;
  List<String>? _computedSuggestions;

  /// Ranked corrections for [word]. Empty when nothing close was found.
  ///
  /// Resolved on FIRST ACCESS, never during the scan. [check] runs on every
  /// keystroke from inside `buildTextSpan`, and building the ~80 one-edit
  /// variants per flagged word there cost ~420 us per word — 4.2 ms of the
  /// 7.5 ms a typo-laden page spent per keystroke, for suggestions the user had
  /// not asked to see.
  List<String> get suggestions =>
      _computedSuggestions ??=
          _suggestions ?? _suggestionSource?.suggest(word) ?? const <String>[];

  /// Set for grammar rules that have exactly one correct fix.
  ///
  /// Spelling issues leave this null and the caller picks from
  /// [suggestions] instead.
  final String? replacement;

  bool get isSpelling => kind == SpellIssueKind.spelling;

  @override
  String toString() {
    // Deliberately does not read [suggestions]: formatting an issue for a log
    // must not trigger the dictionary search.
    final computed = _computedSuggestions;
    final shown = computed != null && computed.isNotEmpty
        ? ', ${computed.join('/')}'
        : '';
    return 'SpellIssue($start..$end, "$word", $message$shown)';
  }
}

/// Dictionary + rule engine backing the app-wide spell checker.
///
/// Use the singleton [instance]. The dictionary loads lazily on first use and
/// is cached for the process; until it is ready, [check] reports nothing so
/// fields never flash false positives during startup.
class SpellCheckService {
  SpellCheckService._();

  static final SpellCheckService instance = SpellCheckService._();

  /// Asset that holds one word per line. Lines starting with `#` are comments.
  static const String dictionaryAssetPath =
      'assets/config/spell_dictionary.txt';

  static const String _userWordsKey = 'spell_check_user_words';
  static const String _ignoredWordsKey = 'spell_check_ignored_words';

  /// Vocabulary the app itself is full of, so it is never underlined.
  ///
  /// Acronyms are skipped generically too (see [_shouldSkipToken]); this list
  /// exists for mixed-case and lowercase domain terms.
  static const Set<String> builtInVocabulary = <String>{
    'ndu',
    'kaz',
    'kanban',
    'scrum',
    'backlog',
    'deliverable',
    'deliverables',
    'stakeholder',
    'stakeholders',
    'milestone',
    'milestones',
    'workstream',
    'workstreams',
    'onboarding',
    'offboarding',
    'signoff',
    'signoffs',
    'roadmap',
    'roadmaps',
    'dashboard',
    'dashboards',
    'checkpoint',
    'checkpoints',
    'charter',
    'charting',
    'budgeting',
    'forecasted',
    'resourcing',
    'estimations',
    'prioritisation',
    'prioritise',
    'prioritised',
    'organisation',
    'organisational',
    'procurement',
    'programme',
    'programmes',
    'utilise',
    'utilised',
    'analyse',
    'analysed',
    'centre',
    'defence',
    'licence',
    'email',
    'emails',
    'online',
    'website',
    'workflow',
    'workflows',
    'datasource',
    'subtask',
    'subtasks',
    'timeframe',
    'timeframes',
    'dropdown',
    'tooltip',
    'usability',
    'scaler',
    'rollout',
    'rollouts',
    'golive',
    'dryrun',
    'lifecycle',
    'lifecycles',
    // Common words the bundled list can miss in newer spellings.
    'ok',
    'okay',
    'scalable',
    'metadata',
    'realtime',
    'middleware',
    'frontend',
    'backend',
    'multi',
    'percent',
    'kilometre',
    'kilometres',
  };

  /// Contractions that do not decompose into `<known word> + suffix`.
  static const Set<String> _irregularContractions = <String>{
    "o'clock",
    "y'all",
    "ma'am",
    "ne'er",
    "e'er",
    "will-o'-the-wisp",
  };

  final Set<String> _words = <String>{};
  final Set<String> _userWords = <String>{};
  final Set<String> _ignoredWords = <String>{};

  Future<void>? _loadFuture;
  int _revision = 0;

  /// Bumped whenever the dictionary, user words or ignored words change, so
  /// callers can invalidate anything derived from [check].
  int get revision => _revision;

  /// True once the bundled dictionary is loaded and checks can run.
  bool get isReady => _words.isNotEmpty;

  /// Words the user added through "Add to dictionary".
  Set<String> get userWords => Set<String>.unmodifiable(_userWords);

  /// Words the user dismissed through "Ignore".
  Set<String> get ignoredWords => Set<String>.unmodifiable(_ignoredWords);

  int get dictionarySize => _words.length;

  /// Loads the bundled dictionary (once) and the persisted user lists.
  Future<void> ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    await _loadUserLists();
    try {
      final raw = await rootBundle.loadString(dictionaryAssetPath);
      for (final line in raw.split('\n')) {
        final word = line.trim().toLowerCase();
        if (word.isEmpty || word.startsWith('#')) continue;
        _words.add(word);
      }
    } catch (error) {
      // A missing asset must not break every text field in the app: without a
      // dictionary we simply report nothing.
      debugPrint('[SpellCheck] dictionary unavailable: $error');
    }
    _revision++;
  }

  Future<void> _loadUserLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userWords
        ..clear()
        ..addAll(prefs.getStringList(_userWordsKey) ?? const <String>[]);
      _ignoredWords
        ..clear()
        ..addAll(prefs.getStringList(_ignoredWordsKey) ?? const <String>[]);
    } catch (error) {
      debugPrint('[SpellCheck] user dictionary unavailable: $error');
    }
  }

  /// Test seam: installs a word list synchronously and marks the service ready.
  @visibleForTesting
  void debugLoadWords(Iterable<String> words, {bool ready = true}) {
    _words
      ..clear()
      ..addAll(words.map((w) => w.trim().toLowerCase()).where((w) => w.isNotEmpty));
    if (!ready) _words.clear();
    _revision++;
  }

  /// Test seam: clears the persisted user lists from memory.
  @visibleForTesting
  void debugClearUserLists() {
    _userWords.clear();
    _ignoredWords.clear();
    _revision++;
  }

  /// Adds [word] to the user's dictionary — it is accepted from now on and
  /// survives restarts.
  Future<void> addToUserDictionary(String word) async {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) return;
    _ignoredWords.remove(normalized);
    if (!_userWords.add(normalized)) return;
    _revision++;
    await _persistUserLists();
  }

  /// Stops flagging [word] without adding it to the dictionary.
  Future<void> ignoreWord(String word) async {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (!_ignoredWords.add(normalized)) return;
    _revision++;
    await _persistUserLists();
  }

  /// Flags [word] again after an [ignoreWord]/[addToUserDictionary].
  Future<void> resetWord(String word) async {
    final normalized = word.trim().toLowerCase();
    final removedUser = _userWords.remove(normalized);
    final removedIgnored = _ignoredWords.remove(normalized);
    if (!removedUser && !removedIgnored) return;
    _revision++;
    await _persistUserLists();
  }

  /// Learns domain vocabulary (project and people names) for this session and
  /// onward. Used so the app's own nouns never look like typos.
  Future<void> learnWords(Iterable<String> words) async {
    var changed = false;
    for (final raw in words) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.length < 3) continue;
      final parts = <String>[
        ...normalized.split(_whitespacePattern),
        ..._splitCompound(normalized),
      ];
      for (final part in parts) {
        if (part.length < 3) continue;
        if (_isKnownWord(part)) continue;
        if (_userWords.add(part)) changed = true;
      }
    }
    if (!changed) return;
    _revision++;
    await _persistUserLists();
  }

  Future<void> _persistUserLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_userWordsKey, _userWords.toList()..sort());
      await prefs.setStringList(
          _ignoredWordsKey, _ignoredWords.toList()..sort());
    } catch (error) {
      debugPrint('[SpellCheck] could not persist user dictionary: $error');
    }
  }

  /// True when [word] is accepted by any of the dictionary sources.
  bool isWordKnown(String word) {
    final normalized = _normalizeApostrophes(word.trim().toLowerCase());
    if (normalized.isEmpty) return true;
    if (_isKnownWord(normalized)) return true;
    return _isKnownCompound(normalized);
  }

  bool _isKnownWord(String normalized) {
    if (_inDictionary(normalized)) return true;
    if (_irregularContractions.contains(normalized)) return true;
    if (_isContractionOrPossessive(normalized)) return true;
    return _isDerivedForm(normalized);
  }

  /// Literal membership in any dictionary source, no morphology.
  bool _inDictionary(String word) =>
      _words.contains(word) ||
      _userWords.contains(word) ||
      builtInVocabulary.contains(word);

  // ── Morphology ─────────────────────────────────────────────────────────────
  //
  // The bundled list is built from /usr/share/dict/web2, which holds BASE forms
  // only: it has "requirement" but not "requirements", "ensure" but not
  // "ensuring". Checking membership alone therefore underlines every regular
  // inflection in generated prose — the paragraph-level false positives that
  // made this useless on a whole Requirements Plan.
  //
  // These rules reduce an inflected word to its base form and accept it when
  // that base is known. They follow English's consonant-doubling rule rather
  // than accepting any stem: "stopped" resolves to "stop", while "occured"
  // stays flagged because "occur" doubles its r. [_noDoublingStems] carries the
  // words that end in consonant-vowel-consonant yet do NOT double (first-syllable
  // stress), so "visited" and "targeted" are not mistaken for typos.

  /// Shortest acceptable base form for a derived word.
  static const int _minDerivedStemLength = 3;

  /// `-ed`/`-ing`/`-er`/`-est` stems that end in consonant-vowel-consonant but
  /// do not double the final consonant, because the stress is not on the last
  /// syllable. Without these, "visited" would be rejected in favour of
  /// "visitted".
  static const Set<String> _noDoublingStems = <String>{
    // -en endings
    'open', 'happen', 'listen', 'tighten', 'shorten', 'widen', 'lengthen',
    'strengthen', 'fasten', 'threaten', 'flatten', 'sharpen', 'deepen',
    // -er / -or endings
    'offer', 'enter', 'order', 'gather', 'differ', 'deliver', 'conquer',
    'cover', 'answer', 'bargain', 'wonder', 'remember', 'consider', 'monitor',
    'audit', 'exhibit', 'inherit', 'visit', 'edit', 'credit', 'merit',
    // -it / -et / -ot endings
    'limit', 'target', 'budget', 'profit', 'deposit', 'pivot', 'ballot',
    'solicit', 'prohibit', 'inhibit', 'orbit', 'comment', 'combat',
    'market', 'focus', 'format', 'benefit', 'compromise', 'comfort',
    // -el / -il / -al / -ol endings (US spellings do not double)
    'model', 'label', 'signal', 'total', 'cancel', 'travel', 'tunnel',
    'channel', 'panel', 'parcel', 'spiral', 'marvel', 'rival', 'level',
    'fuel', 'jewel', 'equal', 'dial', 'initial', 'pedal', 'medal',
  };

  static const Set<String> _vowelLetters = <String>{'a', 'e', 'i', 'o', 'u'};

  static bool _isVowelLetter(String c) => _vowelLetters.contains(c);

  /// Deliberately allocation-free: this runs per word on every keystroke, so it
  /// must not build a RegExp.
  static bool _isConsonantLetter(String c) {
    if (c.length != 1) return false;
    final code = c.codeUnitAt(0);
    return code >= 0x61 &&
        code <= 0x7A &&
        !_vowelLetters.contains(c);
  }

  /// True when [stem] must double its final consonant before a vowel suffix.
  static bool _needsDoubling(String stem) {
    if (stem.length < 3) return false;
    if (_noDoublingStems.contains(stem)) return false;
    final last = stem[stem.length - 1];
    final middle = stem[stem.length - 2];
    final first = stem[stem.length - 3];
    // w, x and y are never doubled (fix -> fixed, play -> played).
    if (last == 'w' || last == 'x' || last == 'y') return false;
    if (!_isConsonantLetter(last)) return false;
    if (!_isVowelLetter(middle)) return false;
    if (!_isConsonantLetter(first)) return false;
    // A preceding vowel means a digraph (look -> looked), which never doubles.
    if (stem.length >= 4 && _isVowelLetter(stem[stem.length - 4])) return false;
    return true;
  }

  /// "stopp" -> "stop", "plann" -> "plan", "travell" -> "travel".
  static String _undoubleFinal(String stem) {
    if (stem.length < 3) return stem;
    final last = stem[stem.length - 1];
    if (last == stem[stem.length - 2]) {
      return stem.substring(0, stem.length - 1);
    }
    return stem;
  }

  /// Accepts a regular English inflection of a known base word.
  bool _isDerivedForm(String word) {
    final length = word.length;
    if (length < 4) return false;

    bool known(String candidate) =>
        candidate.length >= _minDerivedStemLength && _inDictionary(candidate);

    // Plurals and third person singular: requirements, capabilities, policies,
    // processes, goals, halves.
    if (word.endsWith('s') && !word.endsWith('ss')) {
      if (word.endsWith('ies') && length > 4) {
        if (known('${word.substring(0, length - 3)}y')) return true;
      }
      if (word.endsWith('ves') && length > 4) {
        final head = word.substring(0, length - 3);
        if (known('${head}f') || known('${head}fe')) return true;
      }
      if (word.endsWith('es') && known(word.substring(0, length - 2))) {
        return true;
      }
      if (known(word.substring(0, length - 1))) return true;
    }

    // Past tense and past participle: completed, applied, stopped, integrated.
    if (word.endsWith('ed') && length > 4) {
      if (word.endsWith('ied') && known('${word.substring(0, length - 3)}y')) {
        return true;
      }
      final stem = word.substring(0, length - 2);
      if (!_needsDoubling(stem) && known(stem)) return true;
      if (known('${stem}e')) return true;
      final single = _undoubleFinal(stem);
      if (single != stem && known(single)) return true;
    }

    // Present participle: ensuring, planning, utilizing, monitoring, aligning.
    if (word.endsWith('ing') && length > 5) {
      final stem = word.substring(0, length - 3);
      if (!_needsDoubling(stem) && known(stem)) return true;
      if (known('${stem}e')) return true;
      final single = _undoubleFinal(stem);
      if (single != stem && known(single)) return true;
    }

    // Comparative and superlative: larger, earlier, strongest.
    if (length > 4 && (word.endsWith('er') || word.endsWith('est'))) {
      final stem = word.endsWith('est')
          ? word.substring(0, length - 3)
          : word.substring(0, length - 2);
      if (!_needsDoubling(stem) && known(stem)) return true;
      if (known('${stem}e')) return true;
      final single = _undoubleFinal(stem);
      if (single != stem && known(single)) return true;
      if (stem.endsWith('i') &&
          known('${stem.substring(0, stem.length - 1)}y')) {
        return true;
      }
    }

    // Adverbs: successfully, automatically, simply, happily.
    if (word.endsWith('ly') && length > 4) {
      if (word.endsWith('ally') && known(word.substring(0, length - 4))) {
        return true;
      }
      final stem = word.substring(0, length - 2);
      if (known(stem)) return true;
      if (stem.endsWith('i') &&
          known('${stem.substring(0, stem.length - 1)}y')) {
        return true;
      }
      // -le adjectives become -ly: simple -> simply, responsible -> responsibly.
      if (known('${stem}le')) return true;
    }

    return false;
  }

  /// `project's`, `don't`, `you're`, `isn't`, `we've` — a known head word plus
  /// a recognised contraction/possessive suffix.
  bool _isContractionOrPossessive(String normalized) {
    final apostrophe = normalized.indexOf("'");
    if (apostrophe <= 0) return false;
    final suffix = normalized.substring(apostrophe + 1);
    var head = normalized.substring(0, apostrophe);
    if (!const <String>{'s', 't', 're', 've', 'll', 'd', 'm'}.contains(suffix)) {
      return false;
    }
    if (suffix == 't' && head.endsWith('n')) {
      // isn't / aren't / wasn't / couldn't ...
      head = head.substring(0, head.length - 1);
    }
    if (head.isEmpty) return false;
    return _words.contains(head) ||
        _userWords.contains(head) ||
        builtInVocabulary.contains(head);
  }

  bool _isKnownCompound(String normalized) {
    final parts = _splitCompound(normalized);
    if (parts.length < 2) return false;
    // Each part may itself be inflected ("stakeholders", "user-facing").
    return parts.every((part) => part.isEmpty || _isKnownWord(part));
  }

  static List<String> _splitCompound(String value) => value
      .split(_compoundSeparatorPattern)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  static String _normalizeApostrophes(String value) =>
      value.replaceAll('\u2019', "'").replaceAll('\u02BC', "'");

  // ── Checking ───────────────────────────────────────────────────────────────

  // Memoised scan.
  //
  // The same text is checked more than once in a single frame: the field's
  // controller builds its span, the selection menu asks for the issue under the
  // caret, and the review dialog lists everything. Each of those used to pay a
  // full scan. The result now lives here until the text or the dictionary
  // changes, so a frame costs one scan no matter how many callers ask.
  String? _memoText;
  int _memoRevision = -1;
  List<SpellIssue>? _memoIssues;

  /// Reports every problem in [text], ordered by position.
  ///
  /// Returns an empty list while the dictionary is still loading.
  List<SpellIssue> check(String text) {
    if (text.isEmpty || !isReady) return const <SpellIssue>[];

    final memo = _memoIssues;
    if (memo != null && _memoRevision == _revision) {
      // `identical` is the common case — a controller keeps one String
      // instance between edits — and keeps this an O(1) test for long fields.
      final cached = _memoText!;
      if (identical(cached, text) || cached == text) return memo;
    }

    final issues = <SpellIssue>[];
    _scanSpelling(text, issues);
    _scanGrammar(text, issues);
    issues.sort((a, b) => a.start.compareTo(b.start));
    final result = _withoutOverlaps(issues);

    _memoText = text;
    _memoRevision = _revision;
    _memoIssues = result;
    return result;
  }

  /// Spelling issues only — used when the caller wants nothing but typos.
  List<SpellIssue> checkSpelling(String text) {
    if (text.isEmpty || !isReady) return const <SpellIssue>[];
    final issues = <SpellIssue>[];
    _scanSpelling(text, issues);
    return issues;
  }

  static final RegExp _wordPattern =
      RegExp(r"[A-Za-z]+(?:['\u2019][A-Za-z]+)*");

  /// Text the spelling scanner must leave alone: URLs, e-mail addresses and
  /// dotted identifiers such as `nduproject.com`, `design.docx` or `app.dart`.
  ///
  /// Every field in the app is checked, so those show up in sign-in, search and
  /// meeting-note fields constantly — and the fragments inside them (`gmail`,
  /// `nduproject`, `docx`) are not typos the user wants underlined.
  static final RegExp _ignoredContextPattern = RegExp(
    r'https?://\S+' // http://… and https://…
    r'|www\.\S+' // www.…
    r'|\S+@\S+' // name@example.com
    r'|\b[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+\b', // design.docx, nduproject.com
    caseSensitive: false,
  );

  // ── Patterns compiled once, not per call ─────────────────────────────────
  //
  // [check] runs on every keystroke from inside `buildTextSpan`, and Dart parses
  // and compiles a RegExp each time its constructor runs. Building these inside
  // the scan therefore cost a full compile per rule per keystroke — measured at
  // roughly 200 us of the ~1.3 ms scan on a 1.6k-character field. Every pattern
  // here is a constant, so they are compiled exactly once.

  /// Cheap "is there anything to skip at all?" test, run before the real scan.
  static final RegExp _ignoredContextTrigger = RegExp(r'[.@/\\]');
  static final RegExp _whitespacePattern = RegExp(r'\s+');
  static final RegExp _compoundSeparatorPattern = RegExp(r'[-/]');
  static final RegExp _repeatedWordPattern =
      RegExp(r'\b([A-Za-z]+)(\s+)\1\b', caseSensitive: false);
  static final RegExp _spaceBeforePunctuationPattern =
      RegExp(r'[ \t]+([,.!?;:])');
  static final RegExp _sentenceStartPattern = RegExp(r'([.!?])[ \t]+([a-z])');
  static final RegExp _lowercaseIPattern =
      RegExp(r'(?:^|[^A-Za-z])i(?:[^A-Za-z]|$)');
  static final RegExp _couldOfPattern =
      RegExp(r'\b(could|should|would|must|may|might)\s+of\b',
          caseSensitive: false);
  static final RegExp _digitPattern = RegExp(r'[0-9]');
  static final RegExp _letterPattern = RegExp(r'[A-Za-z]');
  static final RegExp _trailingWordPattern = RegExp(r'([A-Za-z]+)$');

  /// Non-overlapping ranges of [text] covered by [_ignoredContextPattern], in
  /// document order.
  List<int> _ignoredRanges(String text) {
    if (!text.contains(_ignoredContextTrigger)) return const <int>[];
    final bounds = <int>[];
    for (final match in _ignoredContextPattern.allMatches(text)) {
      bounds..add(match.start)..add(match.end);
    }
    return bounds;
  }

  void _scanSpelling(String text, List<SpellIssue> issues) {
    // `_ignoredRanges` returns [start, end, start, end, …] in document order, so
    // one forward cursor is enough to test each word against its range.
    final ignored = _ignoredRanges(text);
    var ignoredCursor = 0;
    for (final match in _wordPattern.allMatches(text)) {
      while (ignoredCursor < ignored.length &&
          ignored[ignoredCursor + 1] <= match.start) {
        ignoredCursor += 2;
      }
      if (ignoredCursor < ignored.length &&
          match.start >= ignored[ignoredCursor] &&
          match.end <= ignored[ignoredCursor + 1]) {
        continue;
      }

      final token = match.group(0)!;
      if (_shouldSkipToken(token)) continue;
      if (_isKnownToken(token)) continue;

      // Hyphenated or slashed compounds: report the unknown part so the range
      // still points at something the user can replace.
      final parts = _splitCompound(token.toLowerCase());
      if (parts.length > 1 && parts.any((p) => !_isKnownWord(p))) {
        var localOffset = 0;
        for (final part in parts) {
          final partStart = match.start + localOffset;
          if (!_isKnownWord(part)) {
            issues.add(SpellIssue(
              start: partStart,
              end: partStart + part.length,
              word: part,
              kind: SpellIssueKind.spelling,
              message: 'Unknown word',
              // Deferred: see [SpellIssue.suggestions].
              suggestionSource: this,
            ));
          }
          localOffset += part.length + 1; // +1 for the separator
        }
        continue;
      }

      issues.add(SpellIssue(
        start: match.start,
        end: match.end,
        word: token,
        kind: SpellIssueKind.spelling,
        message: 'Misspelling',
        // Deferred: see [SpellIssue.suggestions].
        suggestionSource: this,
      ));
    }
  }

  /// Bit flags set by [_tokenFlags].
  static const int _flagUpper = 1;
  static const int _flagLower = 2;
  static const int _flagCurlyApostrophe = 4;

  /// One allocation-free pass over [token].
  ///
  /// Nearly every word in generated prose is plain lowercase ASCII, and this
  /// runs per word on every keystroke. Knowing that up front lets the hot path
  /// skip `toLowerCase()` plus two `replaceAll()` calls — three throwaway
  /// strings per word — without ever changing the result for words that do need
  /// normalising.
  static int _tokenFlags(String token) {
    var flags = 0;
    for (var i = 0; i < token.length; i++) {
      final code = token.codeUnitAt(i);
      if (code >= 0x41 && code <= 0x5A) {
        flags |= _flagUpper;
      } else if (code >= 0x61 && code <= 0x7A) {
        flags |= _flagLower;
      } else if (code == 0x2019 || code == 0x02BC) {
        flags |= _flagCurlyApostrophe;
      }
      if (flags == (_flagUpper | _flagLower | _flagCurlyApostrophe)) break;
    }
    return flags;
  }

  bool _isKnownToken(String token) {
    // Already lowercase with a straight apostrophe? Then normalising it would
    // only allocate an identical string.
    final flags = _tokenFlags(token);
    final normalized = flags == _flagLower
        ? token
        : _normalizeApostrophes(token.toLowerCase());
    if (_ignoredWords.contains(normalized)) return true;
    return _isKnownWord(normalized) || _isKnownCompound(normalized);
  }

  /// Tokens that must never be underlined even though the dictionary will not
  /// contain them.
  bool _shouldSkipToken(String token) {
    if (token.length < 2) return true;

    // "All caps" means "no lowercase letters", which the flags already tell us
    // — without building an uppercased copy of every token. Acronyms are
    // skipped below, so this test runs for every word in the document.
    final isAllCaps = (_tokenFlags(token) & _flagLower) == 0;
    if (isAllCaps && token.length <= 7) {
      // Acronyms: NDU, KAZ, WBS, PBS, KPI, USD, ZMW.
      return true;
    }
    if (!isAllCaps) {
      // Identifiers and product names: PowerBI, iPhone, kWh, JavaScript.
      final rest = token.substring(1);
      if (rest != rest.toLowerCase() && rest != rest.toUpperCase()) return true;
    }
    // Sentence-initial capitals are handled by lowercasing at lookup time; a
    // mid-sentence capital that is not a dictionary word is a name, and names
    // are worth flagging (the user can add them), so only skip the obvious
    // sentence-start case here.
    return false;
  }

  /// Winsorises a word to the capitalisation of the typed word: typing
  /// "Recieve" suggests "Receive", not "receive".
  static String _matchCase(String typed, String suggestion) {
    if (typed.isEmpty || suggestion.isEmpty) return suggestion;
    if (typed == typed.toUpperCase() && typed.length > 1) {
      return suggestion.toUpperCase();
    }
    if (typed[0] == typed[0].toUpperCase()) {
      return suggestion[0].toUpperCase() + suggestion.substring(1);
    }
    return suggestion;
  }

  /// Ranked corrections for [word] — the curated map first, then every
  /// dictionary word one edit away (substitution, insertion, deletion or
  /// transposition).
  List<String> suggest(String word, {int limit = 6}) {
    final typed = word.trim();
    if (typed.isEmpty) return const <String>[];
    final lower = _normalizeApostrophes(typed.toLowerCase());

    final results = <String>[];
    final curated = _commonMisspellings[lower];
    if (curated != null) results.add(_matchCase(typed, curated));

    final candidates = <String>[];
    for (final variant in _oneEditVariants(lower)) {
      if (_isKnownWord(variant) || _userWords.contains(variant)) {
        candidates.add(variant);
      }
    }
    candidates.sort((a, b) {
      // Prefer corrections that keep the first letter and the length, which is
      // what a typo usually is.
      final aScore = _candidateScore(lower, a);
      final bScore = _candidateScore(lower, b);
      if (aScore != bScore) return aScore.compareTo(bScore);
      return a.compareTo(b);
    });
    for (final candidate in candidates) {
      final cased = _matchCase(typed, candidate);
      if (!results.contains(cased)) results.add(cased);
      if (results.length >= limit) break;
    }
    return results.length > limit ? results.sublist(0, limit) : results;
  }

  static int _candidateScore(String typed, String candidate) {
    var score = 0;
    if (typed[0] != candidate[0]) score += 4;
    score += (typed.length - candidate.length).abs() * 2;
    if (candidate.length > typed.length) score += 1;
    return score;
  }

  Iterable<String> _oneEditVariants(String word) sync* {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    final seen = <String>{};

    // Transpositions (a swapped pair is the most common typo).
    for (var i = 0; i + 1 < word.length; i++) {
      final chars = word.split('');
      final tmp = chars[i];
      chars[i] = chars[i + 1];
      chars[i + 1] = tmp;
      final variant = chars.join();
      if (seen.add(variant)) yield variant;
    }
    // Substitutions and deletions.
    for (var i = 0; i < word.length; i++) {
      for (var l = 0; l < letters.length; l++) {
        final variant = word.replaceRange(i, i + 1, letters[l]);
        if (seen.add(variant)) yield variant;
      }
      final deleted = word.substring(0, i) + word.substring(i + 1);
      if (deleted.isNotEmpty && seen.add(deleted)) yield deleted;
    }
    // Insertions.
    for (var i = 0; i <= word.length; i++) {
      for (var l = 0; l < letters.length; l++) {
        final variant = word.replaceRange(i, i, letters[l]);
        if (seen.add(variant)) yield variant;
      }
    }
  }

  /// High-confidence misspellings worth correcting even at two edits, plus the
  /// run-together phrases that people expect an autocorrect to split.
  static const Map<String, String> _commonMisspellings = <String, String>{
    'teh': 'the',
    'hte': 'the',
    'adn': 'and',
    'nad': 'and',
    'recieve': 'receive',
    'recieved': 'received',
    'recieving': 'receiving',
    'seperate': 'separate',
    'seperated': 'separated',
    'seperately': 'separately',
    'definately': 'definitely',
    'accomodate': 'accommodate',
    'accomodation': 'accommodation',
    'acomodate': 'accommodate',
    'occured': 'occurred',
    'occuring': 'occurring',
    'begining': 'beginning',
    'biginning': 'beginning',
    'enviroment': 'environment',
    'enviroments': 'environments',
    'goverment': 'government',
    'govermment': 'government',
    'managment': 'management',
    'mangement': 'management',
    'buisness': 'business',
    'bussiness': 'business',
    'sucessful': 'successful',
    'sucessfully': 'successfully',
    'neccessary': 'necessary',
    'necesary': 'necessary',
    'neccessarily': 'necessarily',
    'wierd': 'weird',
    'freind': 'friend',
    'freinds': 'friends',
    'acheive': 'achieve',
    'acheived': 'achieved',
    'acheivement': 'achievement',
    'beleive': 'believe',
    'belive': 'believe',
    'calender': 'calendar',
    'commitee': 'committee',
    'comittee': 'committee',
    'concious': 'conscious',
    'concensus': 'consensus',
    'embarass': 'embarrass',
    'existance': 'existence',
    'foriegn': 'foreign',
    'fourty': 'forty',
    'gaurd': 'guard',
    'happend': 'happened',
    'harrass': 'harass',
    'immediatly': 'immediately',
    'independant': 'independent',
    'intrest': 'interest',
    'knowlege': 'knowledge',
    'liason': 'liaison',
    'maintainance': 'maintenance',
    'maintenence': 'maintenance',
    'millenium': 'millennium',
    'noticable': 'noticeable',
    'occassion': 'occasion',
    'occassionally': 'occasionally',
    'paralell': 'parallel',
    'persistant': 'persistent',
    'personel': 'personnel',
    'posession': 'possession',
    'publically': 'publicly',
    'reccomend': 'recommend',
    'recomend': 'recommend',
    'reccomendation': 'recommendation',
    'refered': 'referred',
    'refering': 'referring',
    'relevent': 'relevant',
    'religous': 'religious',
    'remeber': 'remember',
    'resistence': 'resistance',
    'rythm': 'rhythm',
    'scedule': 'schedule',
    'shedule': 'schedule',
    'sieze': 'seize',
    'similiar': 'similar',
    'succesful': 'successful',
    'supercede': 'supersede',
    'tommorow': 'tomorrow',
    'tomorow': 'tomorrow',
    'tommorrow': 'tomorrow',
    'untill': 'until',
    'vegtable': 'vegetable',
    'wether': 'whether',
    'wich': 'which',
    'writting': 'writing',
    'arguement': 'argument',
    'arguements': 'arguments',
    'apparant': 'apparent',
    'apparantly': 'apparently',
    'avaliable': 'available',
    'availible': 'available',
    'basicly': 'basically',
    'benifit': 'benefit',
    'benifits': 'benefits',
    'catagory': 'category',
    'completly': 'completely',
    'consistant': 'consistent',
    'correspondance': 'correspondence',
    'critera': 'criteria',
    'dependant': 'dependent',
    'descrepancy': 'discrepancy',
    'discrepency': 'discrepancy',
    'dissapoint': 'disappoint',
    'effecient': 'efficient',
    'efficent': 'efficient',
    'equiptment': 'equipment',
    'excersise': 'exercise',
    'exellent': 'excellent',
    'existant': 'existent',
    'expence': 'expense',
    'familier': 'familiar',
    'finacial': 'financial',
    'forcast': 'forecast',
    'garentee': 'guarantee',
    'garantee': 'guarantee',
    'heirarchy': 'hierarchy',
    'hierachy': 'hierarchy',
    'identifyed': 'identified',
    'implementaton': 'implementation',
    'incomming': 'incoming',
    'independance': 'independence',
    'inital': 'initial',
    'intial': 'initial',
    'intergrated': 'integrated',
    'intergration': 'integration',
    'interupt': 'interrupt',
    'invoce': 'invoice',
    'itinery': 'itinerary',
    'leverageage': 'leverage',
    'maintainence': 'maintenance',
    'medeival': 'medieval',
    'millage': 'mileage',
    'moniter': 'monitor',
    'monitering': 'monitoring',
    'necesitate': 'necessitate',
    'negociate': 'negotiate',
    'negociation': 'negotiation',
    'nieghbor': 'neighbor',
    'noticably': 'noticeably',
    'ocassion': 'occasion',
    'oppurtunity': 'opportunity',
    'oppurtunities': 'opportunities',
    'paralel': 'parallel',
    'particulary': 'particularly',
    'perfromance': 'performance',
    'persue': 'pursue',
    'posible': 'possible',
    'postponeing': 'postponing',
    'potatos': 'potatoes',
    'prefered': 'preferred',
    'prefering': 'preferring',
    'priviledge': 'privilege',
    'probaly': 'probably',
    'probablity': 'probability',
    'proceedure': 'procedure',
    'proffesional': 'professional',
    'pronounciation': 'pronunciation',
    'propper': 'proper',
    'publicaly': 'publicly',
    'quaterly': 'quarterly',
    'questionaire': 'questionnaire',
    'reciept': 'receipt',
    'recomended': 'recommended',
    'reccommend': 'recommend',
    'recurrance': 'recurrence',
    'rediculous': 'ridiculous',
    'reguarding': 'regarding',
    'relevently': 'relevantly',
    'rember': 'remember',
    'repitition': 'repetition',
    'requirment': 'requirement',
    'requirments': 'requirements',
    'resourse': 'resource',
    'resourses': 'resources',
    'responsable': 'responsible',
    'responsibilty': 'responsibility',
    'resturant': 'restaurant',
    'satisfactoy': 'satisfactory',
    'secratary': 'secretary',
    'senstive': 'sensitive',
    'sincerly': 'sincerely',
    'speach': 'speech',
    'specfic': 'specific',
    'specificaly': 'specifically',
    'sponser': 'sponsor',
    'stategy': 'strategy',
    'strenght': 'strength',
    'strucutre': 'structure',
    'succesfully': 'successfully',
    'suprise': 'surprise',
    'suprisingly': 'surprisingly',
    'surpise': 'surprise',
    'tendancy': 'tendency',
    'therefor': 'therefore',
    'threshhold': 'threshold',
    'transmition': 'transmission',
    'truely': 'truly',
    'unecessary': 'unnecessary',
    'unfortunatly': 'unfortunately',
    'unfortunatley': 'unfortunately',
    'unforseen': 'unforeseen',
    'usuable': 'usable',
    'utlise': 'utilise',
    'vaccuum': 'vacuum',
    'vaccum': 'vacuum',
    'varience': 'variance',
    'vehical': 'vehicle',
    'verfiy': 'verify',
    'verison': 'version',
    'vunerable': 'vulnerable',
    'whcih': 'which',
    'withold': 'withhold',
    'writen': 'written',
    'yeild': 'yield',
    'yeilding': 'yielding',
    'alot': 'a lot',
    'aswell': 'as well',
    'eachother': 'each other',
    'infront': 'in front',
    'inspite': 'in spite',
    'atleast': 'at least',
    'abit': 'a bit',
    'incase': 'in case',
    'everytime': 'every time',
    'noone': 'no one',
    'upto': 'up to',
  };

  // ── Grammar rules ─────────────────────────────────────────────────────────

  void _scanGrammar(String text, List<SpellIssue> issues) {
    // Grammar and spelling can describe the same characters (e.g. a repeated
    // unknown word). Spelling issues are added first, so anything overlapping
    // them is dropped here.
    void add(SpellIssue issue) {
      final overlaps = issues.any(
          (other) => issue.start < other.end && other.start < issue.end);
      if (!overlaps) issues.add(issue);
    }

    // Repeated word: "the the".
    for (final match in _repeatedWordPattern.allMatches(text)) {
      final first = match.group(1)!;
      add(SpellIssue(
        start: match.end - first.length,
        end: match.end,
        word: text.substring(match.end - first.length, match.end),
        kind: SpellIssueKind.grammar,
        message: 'Repeated word',
        replacement: '',
      ));
    }

    // Runs of two or more spaces between words on the same line.
    for (var i = 0; i < text.length - 1; i++) {
      if (text[i] != ' ') continue;
      if (i > 0 && (text[i - 1] == ' ' || text[i - 1] == '\n')) continue;
      var j = i;
      while (j < text.length && text[j] == ' ') {
        j++;
      }
      final run = j - i;
      if (run < 2 || j >= text.length) continue;
      final next = text[j];
      if (next == '\n' || next == '\r' || next == '\t') continue;
      add(SpellIssue(
        start: i,
        end: j,
        word: text.substring(i, j),
        kind: SpellIssueKind.grammar,
        message: 'Extra space',
        replacement: ' ',
      ));
      i = j - 1;
    }

    // Space before punctuation: "word ,".
    for (final match in _spaceBeforePunctuationPattern.allMatches(text)) {
      final previous = match.start == 0 ? '' : text[match.start - 1];
      if (previous.isEmpty || previous == '\n' || previous == '\r') continue;
      add(SpellIssue(
        start: match.start,
        end: match.start + 1,
        word: match.group(0)!,
        kind: SpellIssueKind.grammar,
        message: 'Remove the space before punctuation',
        replacement: '',
      ));
    }

    // Sentence start not capitalised: after . ! or ?.
    //
    // Line breaks are deliberately not treated as sentence starts — a lowercase
    // word after a hard newline is normal in a list or a wrapped form field.
    for (final match in _sentenceStartPattern.allMatches(text)) {
      final letterStart = match.start + match.group(0)!.length - 1;
      final letter = match.group(2)!;
      if (_endsAbbreviation(text, match.start)) continue;
      add(SpellIssue(
        start: letterStart,
        end: letterStart + 1,
        word: letter,
        kind: SpellIssueKind.grammar,
        message: 'Capitalise the first word of a sentence',
        replacement: letter.toUpperCase(),
      ));
    }

    // Standalone lowercase "i".
    for (final match in _lowercaseIPattern.allMatches(text)) {
      final offset = text.indexOf('i', match.start);
      if (offset < 0) continue;
      final after = offset + 1 < text.length ? text[offset + 1] : '';
      if (after == "'") continue;
      add(SpellIssue(
        start: offset,
        end: offset + 1,
        word: 'i',
        kind: SpellIssueKind.grammar,
        message: 'Use the capital "I"',
        replacement: 'I',
      ));
    }

    // "could of" → "could have", and the friends.
    for (final match in _couldOfPattern.allMatches(text)) {
      final auxiliary = match.group(1)!;
      add(SpellIssue(
        start: match.start,
        end: match.end,
        word: match.group(0)!,
        kind: SpellIssueKind.grammar,
        message: '"of" should be "have" here',
        replacement: '$auxiliary have',
      ));
    }
  }

  /// True when the punctuation at [dotIndex] closes an abbreviation or a
  /// number, so the next word is not a new sentence.
  ///
  /// Covers "e.g. item", "i.e. item", "3.5 mm" and the usual titles.
  static bool _endsAbbreviation(String text, int dotIndex) {
    if (dotIndex > 0 && _digitPattern.hasMatch(text[dotIndex - 1])) {
      return true;
    }
    if (text[dotIndex] != '.') return false;
    // "e.g." / "i.e.": a single letter whose own predecessor is a dot.
    if (dotIndex >= 2 &&
        _letterPattern.hasMatch(text[dotIndex - 1]) &&
        text[dotIndex - 2] == '.') {
      return true;
    }
    final wordMatch =
        _trailingWordPattern.firstMatch(text.substring(0, dotIndex));
    final word = wordMatch?.group(1)?.toLowerCase();
    if (word == null) return false;
    return const <String>{
      'etc',
      'eg',
      'ie',
      'vs',
      'mr',
      'mrs',
      'ms',
      'dr',
      'prof',
      'no',
      'approx',
      'dept',
      'est',
      'fig',
      'inc',
      'ltd',
      'co',
    }.contains(word);
  }

  /// Grammar and spelling can describe the same characters; keep the first.
  static List<SpellIssue> _withoutOverlaps(List<SpellIssue> issues) {
    final kept = <SpellIssue>[];
    for (final issue in issues) {
      final overlaps = kept.any((other) =>
          issue.start < other.end && other.start < issue.end);
      if (!overlaps) kept.add(issue);
    }
    return kept;
  }
}
