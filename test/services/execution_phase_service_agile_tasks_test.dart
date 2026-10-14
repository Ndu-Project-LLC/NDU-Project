// A kanban board identifies each card by its story id: the card is keyed
// `ValueKey('kanban_card_${story.id}')`, it is moved with
// `indexWhere((s) => s.id == story.id)`, and `AgileTask.operator==` compares
// ids. When several stories share one id — the clock-minted ids every seeded
// batch got before `newId()` — the keys collide, Flutter's sliver child order
// breaks, and dragging a card moves whichever story matched first (on the board
// only the first few cards stayed draggable). The decode point must hand back
// ids that are unique, so these tests pin that. See `lib/utils/unique_id.dart`.

import 'package:flutter_test/flutter_test.dart';

import 'package:ndu_project/services/execution_phase_service.dart';

List<AgileTaskProbe> _probe(Object? raw) => [
      for (final task in ExecutionPhaseService.decodeAgileTasks(raw))
        AgileTaskProbe(task.id, task.userStory),
    ];

class AgileTaskProbe {
  const AgileTaskProbe(this.id, this.title);
  final String id;
  final String title;
}

void main() {
  test('stories saved sharing one id come back with distinct ids', () {
    // The shape that broke the board: one seeded batch, one millisecond, one id.
    final raw = [
      for (var i = 0; i < 25; i++)
        {'id': '1787939312317000', 'userStory': 'Story $i'},
    ];

    final stories = _probe(raw);

    expect(stories, hasLength(25));
    expect(
      stories.map((s) => s.id).toSet(),
      hasLength(25),
      reason: 'duplicate ids collapse the board keys, which is what stops the '
          'later cards from dragging',
    );
    // The first row keeps its id, so anything referencing these stories by id
    // still resolves to it.
    expect(stories.first.id, '1787939312317000');
  });

  test('a numeric id is healed the same as a string one', () {
    final stories = _probe([
      {'id': 1787939312317000, 'userStory': 'A'},
      {'id': 1787939312317000, 'userStory': 'B'},
    ]);

    expect(stories.map((s) => s.id).toSet(), hasLength(2));
  });

  test('blank and missing ids are minted, not left to collide', () {
    final stories = _probe([
      {'id': '', 'userStory': 'A'},
      {'id': '', 'userStory': 'B'},
      {'userStory': 'C'},
    ]);

    expect(stories.map((s) => s.id).toSet(), hasLength(3));
    expect(stories.every((s) => s.id.isNotEmpty), isTrue);
  });

  test('distinct ids are preserved, so linkages keep resolving', () {
    final stories = _probe([
      {'id': 'story-1', 'userStory': 'A'},
      {'id': 'story-2', 'userStory': 'B'},
    ]);

    expect(stories.map((s) => s.id), ['story-1', 'story-2']);
  });

  test('a healed list round-trips without reintroducing duplicates', () {
    // Saving the board writes the ids back; they must stay unique so the next
    // load does not have to heal them again.
    final first = ExecutionPhaseService.decodeAgileTasks([
      {'id': 'dup', 'userStory': 'A'},
      {'id': 'dup', 'userStory': 'B'},
    ]);
    final saved = first.map((task) => task.toJson()).toList();

    final second = ExecutionPhaseService.decodeAgileTasks(saved);
    expect(second.map((task) => task.id).toSet(), hasLength(2));
    expect(second.map((task) => task.userStory), ['A', 'B']);
  });

  test('the decode reports whether it had to re-mint an id', () {
    // `loadAgileTasks(persistRepairs: true)` writes the list back only when
    // this flag is set, so it must be exact: a false positive writes on every
    // load, a false negative leaves the duplicate ids on disk.
    final clean = ExecutionPhaseService.decodeAgileTasksWithRepair([
      {'id': 'story-1', 'userStory': 'A'},
      {'id': 'story-2', 'userStory': 'B'},
    ]);
    expect(clean.repaired, isFalse);

    final duplicated = ExecutionPhaseService.decodeAgileTasksWithRepair([
      {'id': 'dup', 'userStory': 'A'},
      {'id': 'dup', 'userStory': 'B'},
    ]);
    expect(duplicated.repaired, isTrue);

    expect(
      ExecutionPhaseService.decodeAgileTasksWithRepair([
        {'userStory': 'no id at all'},
      ]).repaired,
      isTrue,
    );
    expect(
      ExecutionPhaseService.decodeAgileTasksWithRepair(const []).repaired,
      isFalse,
    );
  });

  test('a malformed payload never throws and keeps the readable rows', () {
    expect(ExecutionPhaseService.decodeAgileTasks(null), isEmpty);
    expect(ExecutionPhaseService.decodeAgileTasks('nope'), isEmpty);
    expect(
      ExecutionPhaseService.decodeAgileTasks([
        'not a map',
        {'id': 'ok', 'userStory': 'Kept'},
      ]).map((task) => task.id),
      ['ok'],
    );
  });
}
