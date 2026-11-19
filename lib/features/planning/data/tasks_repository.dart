import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/task.dart';

class TasksRepository {
  TasksRepository(this._db);
  final SupabaseClient _db;

  Future<List<TaskItem>> fetchForBoard(String boardId) async {
    final rows = await _db
        .from('tasks')
        .select()
        .eq('board_id', boardId)
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    return rows.map(TaskItem.fromJson).toList();
  }

  Future<List<TaskItem>> fetchForContact(String contactId) async {
    final rows = await _db
        .from('tasks')
        .select('*, boards(name)')
        .eq('contact_id', contactId)
        .order('due_date', ascending: true, nullsFirst: false);
    return rows.map(TaskItem.fromJson).toList();
  }

  Future<TaskItem> insert(TaskItem task) async {
    final row = await _db.from('tasks').insert(task.toInsert()).select().single();
    return TaskItem.fromJson(row);
  }

  Future<List<TaskItem>> insertMany(List<TaskItem> tasks) async {
    if (tasks.isEmpty) return const [];
    final rows = await _db.from('tasks').insert([for (final t in tasks) t.toInsert()]).select();
    return rows.map(TaskItem.fromJson).toList();
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _db.from('tasks').update(patch).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _db.from('tasks').delete().eq('id', id);
  }
}
