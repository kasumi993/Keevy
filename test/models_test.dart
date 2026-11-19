import 'package:flutter_test/flutter_test.dart';
import 'package:keevy/features/boards/domain/board.dart';
import 'package:keevy/features/boards/domain/card_item.dart';
import 'package:keevy/features/contacts/domain/contact.dart';
import 'package:keevy/features/planning/domain/task.dart';
import 'package:keevy/features/planning/domain/templates.dart';

void main() {
  test('Board.fromJson reads the board_overview view', () {
    final b = Board.fromJson({
      'id': 'b1',
      'owner_id': 'u1',
      'name': 'Mariage',
      'color': '#C084A0',
      'mode': 'projet',
      'event_type': 'mariage',
      'target_date': '2027-06-12',
      'is_owner': true,
      'card_count': 12,
      'task_count': 10,
      'task_done_count': 4,
      'previews': [
        {'image_path': 'b1/a.jpg', 'image_url': null},
        {'image_path': null, 'image_url': 'https://cdn/x.jpg'},
        {'image_path': null, 'image_url': null},
      ],
    });
    expect(b.isProjet, isTrue);
    expect(b.eventType, EventType.mariage);
    expect(b.displayEmoji, '💍');
    expect(b.targetDate, DateTime(2027, 6, 12));
    expect(b.progress, closeTo(0.4, 1e-9));
    expect(b.previews, hasLength(2));
    expect(b.color.toARGB32(), 0xFFC084A0);
  });

  test('CardItem round-trips insert columns', () {
    final c = CardItem.fromJson({
      'id': 'c1',
      'board_id': 'b1',
      'kind': 'link',
      'url': 'https://www.instagram.com/p/x',
      'source': 'instagram',
      'image_width': 1080,
      'image_height': 1350,
      'boards': {'name': 'Mariage', 'color': '#B07860'},
    });
    expect(c.boardName, 'Mariage');
    expect(c.aspectRatio, closeTo(0.8, 1e-9));
    final insert = c.toInsert();
    expect(insert['kind'], 'link');
    expect(insert.containsKey('boards'), isFalse);
    expect(c.copyWith(clearSection: true).sectionId, isNull);
  });

  test('Contact.bestStatus ignores Inspiration boards', () {
    final contact = Contact.fromJson({
      'id': 'k1',
      'owner_id': 'u1',
      'name': 'Atelier Rosa',
      'board_contacts': [
        {'board_id': 'b1', 'contact_id': 'k1', 'status': 'confirme', 'boards': {'name': 'Déco', 'mode': 'inspiration'}},
        {'board_id': 'b2', 'contact_id': 'k1', 'status': 'devis', 'boards': {'name': 'Mariage', 'mode': 'projet'}},
      ],
    });
    expect(contact.initials, 'AR');
    expect(contact.bestStatus, VendorStatus.devis);
    expect(contact.links.first.showsStatus, isFalse);
  });

  test('TaskItem overdue logic', () {
    final now = DateTime(2026, 11, 19);
    final late = TaskItem(id: 't', boardId: 'b', title: 'x', dueDate: DateTime(2026, 11, 1));
    expect(late.isOverdue(now: now), isTrue);
    expect(late.copyWith(done: true).isOverdue(now: now), isFalse);
    expect(late.copyWith(clearDueDate: true).isOverdue(now: now), isFalse);
  });

  group('Checklist templates', () {
    test('every event type has a template', () {
      for (final type in EventType.values) {
        expect(ChecklistTemplates.forType(type).tasks, isNotEmpty, reason: type.id);
      }
    });

    test('due dates are relative to the event and never in the past', () {
      final tpl = ChecklistTemplates.forType(EventType.mariage);
      final now = DateTime(2026, 11, 19);
      final event = DateTime(2027, 9, 18);
      final first = tpl.dueDateFor(tpl.tasks.first, event, now: now)!;
      expect(first, DateTime(2026, 11, 19)); // 365 days before is already past → today
      final last = tpl.dueDateFor(tpl.tasks.last, event, now: now)!;
      expect(last, DateTime(2027, 9, 16));
      expect(tpl.dueDateFor(tpl.tasks.first, null), isNull);
    });
  });

  test('default sections follow the event type', () {
    expect(defaultSectionsFor(EventType.mariage, isFr: true), contains('Fleurs'));
    expect(defaultSectionsFor(null, isFr: false), ['Ideas']);
  });
}
