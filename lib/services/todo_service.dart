import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery_app/models/todo_item.dart';
import 'package:gallery_app/services/notification_service.dart';

class TodoService {
  static const String _todosKey = 'todos_list';

  static TodoService? _instance;
  static TodoService get instance {
    _instance ??= TodoService._();
    return _instance!;
  }

  TodoService._();

  // Get all todos
  Future<List<TodoItem>> getAllTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todosJson = prefs.getString(_todosKey);

    if (todosJson == null) return [];

    final List<dynamic> decodedList = jsonDecode(todosJson);
    return decodedList
        .map((json) => TodoItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Get todos for a specific folder
  Future<List<TodoItem>> getTodosForFolder(String? folderPath) async {
    final allTodos = await getAllTodos();
    return allTodos.where((todo) => todo.folderPath == folderPath).toList();
  }

  // Get global todos (not associated with any folder)
  Future<List<TodoItem>> getGlobalTodos() async {
    return getTodosForFolder(null);
  }

  // Add a new todo
  Future<void> addTodo(TodoItem todo) async {
    final todos = await getAllTodos();
    todos.add(todo);
    await _saveTodos(todos);
    if (todo.dueDate != null && !todo.isCompleted) {
      await NotificationService.instance.scheduleTodoReminder(todo);
    }
  }

  // Update an existing todo
  Future<void> updateTodo(TodoItem updatedTodo) async {
    final todos = await getAllTodos();
    final index = todos.indexWhere((todo) => todo.id == updatedTodo.id);

    if (index != -1) {
      todos[index] = updatedTodo;
      await _saveTodos(todos);
      if (updatedTodo.dueDate != null && !updatedTodo.isCompleted) {
        await NotificationService.instance.scheduleTodoReminder(updatedTodo);
      } else {
        await NotificationService.instance.cancelTodoReminder(updatedTodo.id);
      }
    }
  }

  // Delete a todo
  Future<void> deleteTodo(String todoId) async {
    final todos = await getAllTodos();
    todos.removeWhere((todo) => todo.id == todoId);
    await _saveTodos(todos);
    await NotificationService.instance.cancelTodoReminder(todoId);
  }

  // Toggle todo completion status
  Future<void> toggleTodoCompletion(String todoId) async {
    final todos = await getAllTodos();
    final index = todos.indexWhere((todo) => todo.id == todoId);

    if (index != -1) {
      final updated = todos[index].copyWith(
        isCompleted: !todos[index].isCompleted,
      );
      todos[index] = updated;
      await _saveTodos(todos);
      
      if (updated.isCompleted) {
        await NotificationService.instance.cancelTodoReminder(todoId);
      } else if (updated.dueDate != null) {
        await NotificationService.instance.scheduleTodoReminder(updated);
      }
    }
  }

  // Delete all completed todos
  Future<void> deleteCompletedTodos({String? folderPath}) async {
    final todos = await getAllTodos();
    todos.removeWhere(
      (todo) => todo.isCompleted && todo.folderPath == folderPath,
    );
    await _saveTodos(todos);
  }

  // Get statistics
  Future<Map<String, int>> getTodoStats({String? folderPath}) async {
    final todos = await getTodosForFolder(folderPath);
    final completed = todos.where((todo) => todo.isCompleted).length;
    final pending = todos.where((todo) => !todo.isCompleted).length;
    final highPriority = todos
        .where((todo) => !todo.isCompleted && todo.priority == 2)
        .length;

    return {
      'total': todos.length,
      'completed': completed,
      'pending': pending,
      'highPriority': highPriority,
    };
  }

  // Save todos to storage
  Future<void> _saveTodos(List<TodoItem> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = todos
        .map((todo) => todo.toJson())
        .toList();
    await prefs.setString(_todosKey, jsonEncode(jsonList));
  }

  // Search todos by title or description
  Future<List<TodoItem>> searchTodos(String query, {String? folderPath}) async {
    final todos = await getTodosForFolder(folderPath);
    final lowerQuery = query.toLowerCase();

    return todos.where((todo) {
      final titleMatch = todo.title.toLowerCase().contains(lowerQuery);
      final descMatch =
          todo.description?.toLowerCase().contains(lowerQuery) ?? false;
      return titleMatch || descMatch;
    }).toList();
  }

  // Get overdue todos
  Future<List<TodoItem>> getOverdueTodos({String? folderPath}) async {
    final todos = await getTodosForFolder(folderPath);
    final now = DateTime.now();

    return todos.where((todo) {
      if (todo.isCompleted || todo.dueDate == null) return false;
      return todo.dueDate!.isBefore(now);
    }).toList();
  }

  // Get upcoming todos (due in next 7 days)
  Future<List<TodoItem>> getUpcomingTodos({String? folderPath}) async {
    final todos = await getTodosForFolder(folderPath);
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    return todos.where((todo) {
      if (todo.isCompleted || todo.dueDate == null) return false;
      return todo.dueDate!.isAfter(now) && todo.dueDate!.isBefore(weekFromNow);
    }).toList();
  }
}
