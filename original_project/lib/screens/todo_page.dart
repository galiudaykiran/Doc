import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gallery_app/models/todo_item.dart';
import 'package:gallery_app/services/todo_service.dart';
import 'package:gallery_app/services/notification_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class TodoPage extends StatefulWidget {
  final String? folderPath;
  final String? folderName;

  const TodoPage({super.key, this.folderPath, this.folderName});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage>
    with SingleTickerProviderStateMixin {
  final TodoService _todoService = TodoService.instance;
  List<TodoItem> _todos = [];
  List<TodoItem> _filteredTodos = [];
  bool _isLoading = true;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _filterPriority;
  bool _showOnlyOverdue = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTodos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoading = true);

    final todos = await _todoService.getTodosForFolder(widget.folderPath);

    setState(() {
      _todos = todos;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<TodoItem> filtered = List.from(_todos);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((todo) {
        return todo.title.toLowerCase().contains(query) ||
            (todo.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Priority filter
    if (_filterPriority != null) {
      filtered = filtered
          .where((todo) => todo.priority == _filterPriority)
          .toList();
    }

    // Overdue filter
    if (_showOnlyOverdue) {
      final now = DateTime.now();
      filtered = filtered.where((todo) {
        return !todo.isCompleted &&
            todo.dueDate != null &&
            todo.dueDate!.isBefore(now);
      }).toList();
    }

    // Sort by priority (high to low), then by due date
    filtered.sort((a, b) {
      if (a.priority != b.priority) {
        return b.priority.compareTo(a.priority);
      }
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    setState(() => _filteredTodos = filtered);
  }

  Future<void> _showAddTodoDialog({TodoItem? editTodo}) async {
    final titleController = TextEditingController(text: editTodo?.title ?? '');
    final descController = TextEditingController(
      text: editTodo?.description ?? '',
    );
    DateTime? selectedDueDate = editTodo?.dueDate;
    int selectedPriority = editTodo?.priority ?? 1;
    String? selectedCategory = editTodo?.category;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            editTodo == null ? 'Add New Todo' : 'Edit Todo',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    labelStyle: GoogleFonts.poppins(color: Theme.of(context).hintColor),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 2,
                      ),
                    ),
                  ),
                  style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurface),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: GoogleFonts.poppins(color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                  style: GoogleFonts.poppins(color: Colors.black87),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Priority',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PriorityChip(
                        label: 'Low',
                        priority: 0,
                        isSelected: selectedPriority == 0,
                        onTap: () => setDialogState(() => selectedPriority = 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PriorityChip(
                        label: 'Medium',
                        priority: 1,
                        isSelected: selectedPriority == 1,
                        onTap: () => setDialogState(() => selectedPriority = 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PriorityChip(
                        label: 'High',
                        priority: 2,
                        isSelected: selectedPriority == 2,
                        onTap: () => setDialogState(() => selectedPriority = 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedDueDate == null
                            ? 'No due date'
                            : 'Due: ${DateFormat('MMM dd, yyyy').format(selectedDueDate!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDueDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Colors.black,
                                  onPrimary: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        selectedDueDate == null ? 'Set Date' : 'Change',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                    if (selectedDueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () =>
                            setDialogState(() => selectedDueDate = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category (Optional)',
                    labelStyle: GoogleFonts.poppins(color: Colors.black87),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                  style: GoogleFonts.poppins(color: Colors.black87),
                  dropdownColor: Colors.white,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'None',
                        style: GoogleFonts.poppins(color: Colors.black87),
                      ),
                    ),
                    ...[
                      'Work',
                      'Personal',
                      'Shopping',
                      'Health',
                      'Finance',
                      'Education',
                      'Other',
                    ].map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          style: GoogleFonts.poppins(color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedCategory = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  Fluttertoast.showToast(msg: 'Please enter a title');
                  return;
                }

                final todo =
                    editTodo?.copyWith(
                      title: titleController.text.trim(),
                      description: descController.text.trim().isEmpty
                          ? null
                          : descController.text.trim(),
                      priority: selectedPriority,
                      dueDate: selectedDueDate,
                      category: selectedCategory,
                    ) ??
                    TodoItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      description: descController.text.trim().isEmpty
                          ? null
                          : descController.text.trim(),
                      createdAt: DateTime.now(),
                      priority: selectedPriority,
                      dueDate: selectedDueDate,
                      folderPath: widget.folderPath,
                      category: selectedCategory,
                    );

                if (editTodo == null) {
                  await _todoService.addTodo(todo);
                } else {
                  await _todoService.updateTodo(todo);
                }

                // Schedule notification if due date is set
                if (todo.dueDate != null) {
                  await NotificationService.instance.scheduleTodoReminder(todo);
                  await NotificationService.instance.showNotification(
                    title: 'Reminder Set',
                    body: 'Reminder set for "${todo.title}" on ${DateFormat('MMM dd, yyyy').format(todo.dueDate!)}',
                  );
                } else {
                  await NotificationService.instance.cancelTodoReminder(
                    todo.id,
                  );
                }

                if (!mounted) return;
                Navigator.pop(context);
                _loadTodos();
                Fluttertoast.showToast(
                  msg: editTodo == null ? 'Todo added!' : 'Todo updated!',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                editTodo == null ? 'Add' : 'Update',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Todo',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${todo.title}"?',
          style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Theme.of(context).hintColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onSurface,
              foregroundColor: Theme.of(context).colorScheme.surface,
            ),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationService.instance.cancelTodoReminder(todo.id);
      await _todoService.deleteTodo(todo.id);
      _loadTodos();
      Fluttertoast.showToast(msg: 'Todo deleted');
    }
  }

  Future<void> _toggleTodoCompletion(TodoItem todo) async {
    await _todoService.toggleTodoCompletion(todo.id);
    // Cancel notification if completed, reschedule if uncompleted
    if (!todo.isCompleted) {
      await NotificationService.instance.cancelTodoReminder(todo.id);
    } else if (todo.dueDate != null) {
      await NotificationService.instance.scheduleTodoReminder(todo);
    }
    _loadTodos();
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Options',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Priority',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text(
                      'All',
                      style: GoogleFonts.poppins(
                        color: _filterPriority == null
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: _filterPriority == null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: _filterPriority == null,
                    onSelected: (selected) {
                      setSheetState(() => _filterPriority = null);
                      setState(() {
                        _filterPriority = null;
                        _applyFilters();
                      });
                    },
                    selectedColor: Colors.black,
                    backgroundColor: Colors.grey[200],
                    side: BorderSide(color: Colors.black.withOpacity(0.05)),
                    labelStyle: GoogleFonts.poppins(
                      color: _filterPriority == null
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: _filterPriority == null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  FilterChip(
                    label: Text(
                      'Low',
                      style: GoogleFonts.poppins(
                        color: _filterPriority == 0
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: _filterPriority == 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: _filterPriority == 0,
                    onSelected: (selected) {
                      setSheetState(() => _filterPriority = 0);
                      setState(() {
                        _filterPriority = 0;
                        _applyFilters();
                      });
                    },
                    selectedColor: Colors.black87,
                    backgroundColor: Colors.grey[200],
                    side: BorderSide(color: Colors.black.withOpacity(0.05)),
                    labelStyle: GoogleFonts.poppins(
                      color: _filterPriority == 0
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: _filterPriority == 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  FilterChip(
                    label: Text(
                      'Medium',
                      style: GoogleFonts.poppins(
                        color: _filterPriority == 1
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: _filterPriority == 1
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: _filterPriority == 1,
                    onSelected: (selected) {
                      setSheetState(() => _filterPriority = 1);
                      setState(() {
                        _filterPriority = 1;
                        _applyFilters();
                      });
                    },
                    selectedColor: Colors.black87,
                    backgroundColor: Colors.grey[200],
                    side: BorderSide(color: Colors.black.withOpacity(0.05)),
                    labelStyle: GoogleFonts.poppins(
                      color: _filterPriority == 1
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: _filterPriority == 1 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  FilterChip(
                    label: Text(
                      'High',
                      style: GoogleFonts.poppins(
                        color: _filterPriority == 2
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: _filterPriority == 2
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: _filterPriority == 2,
                    onSelected: (selected) {
                      setSheetState(() => _filterPriority = 2);
                      setState(() {
                        _filterPriority = 2;
                        _applyFilters();
                      });
                    },
                    selectedColor: Colors.black,
                    backgroundColor: Colors.grey[200],
                    side: BorderSide(color: Colors.black.withOpacity(0.05)),
                    labelStyle: GoogleFonts.poppins(
                      color: _filterPriority == 2
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: _filterPriority == 2 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  'Show Only Overdue',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                value: _showOnlyOverdue,
                activeColor: Colors.black,
                activeTrackColor: Colors.black.withOpacity(0.5),
                onChanged: (value) {
                  setSheetState(() => _showOnlyOverdue = value);
                  setState(() {
                    _showOnlyOverdue = value;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterPriority = null;
                        _showOnlyOverdue = false;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Done', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingTodos = _filteredTodos.where((t) => !t.isCompleted).toList();
    final completedTodos = _filteredTodos.where((t) => t.isCompleted).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarTextColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarTextColor),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                gradient: LinearGradient(
                  colors: [
                    isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    isDark ? Colors.transparent : Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.folderName != null
                  ? '${widget.folderName} - Todos'
                  : 'My Todos',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: appBarTextColor,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '${pendingTodos.length} pending, ${completedTodos.length} completed',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: appBarTextColor.withOpacity(0.85),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color:
                        Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search todos...',
                    hintStyle: GoogleFonts.inter(
                      color: Theme.of(context).hintColor.withOpacity(0.5),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor:
                        Theme.of(context).cardTheme.color ??
                        const Color(0xFF1E1E1E),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.search_rounded,
                        color: Theme.of(context).hintColor.withOpacity(0.5),
                        size: 22,
                      ),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _applyFilters();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                indicatorColor: isDark ? Colors.white : Colors.black,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(),
                tabs: [
                  Tab(text: 'Pending (${pendingTodos.length})'),
                  Tab(text: 'Completed (${completedTodos.length})'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.filter_list, color: appBarTextColor),
                if (_filterPriority != null || _showOnlyOverdue)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                    isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF1F5F9),
                    isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
                  ],
                ),
              ),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTodoList(pendingTodos),
                    _buildTodoList(completedTodos, isCompleted: true),
                  ],
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTodoDialog(),
        backgroundColor: Theme.of(context).colorScheme.onSurface,
        foregroundColor: Theme.of(context).colorScheme.surface,
        icon: const Icon(Icons.add),
        label: Text(
          'Add Todo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTodoList(List<TodoItem> todos, {bool isCompleted = false}) {
    if (todos.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 180,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCompleted ? Icons.check_circle_outline : Icons.inbox_outlined,
                size: 100,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                isCompleted ? 'No completed todos' : 'No pending todos',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCompleted
                    ? 'Complete some tasks to see them here'
                    : 'Tap the + button to add a new todo',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ), // End Padding
      ); // End Center
    }

    return RefreshIndicator(
      onRefresh: _loadTodos,
      color: Colors.black,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 180,
          left: 16,
          right: 16,
          bottom: 100,
        ),
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return _TodoCard(
            todo: todo,
            onToggle: () => _toggleTodoCompletion(todo),
            onEdit: () => _showAddTodoDialog(editTodo: todo),
            onDelete: () => _deleteTodo(todo),
          );
        },
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final int priority;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.priority,
    required this.isSelected,
    required this.onTap,
  });

  Color get _priorityColor {
    switch (priority) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.black87;
      case 2:
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _priorityColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _priorityColor : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TodoCard({
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _priorityColor {
    switch (todo.priority) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.black87;
      case 2:
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  String get _priorityLabel {
    switch (todo.priority) {
      case 0:
        return 'Low';
      case 1:
        return 'Medium';
      case 2:
        return 'High';
      default:
        return 'Unknown';
    }
  }

  bool get _isOverdue {
    if (todo.dueDate == null || todo.isCompleted) return false;
    return todo.dueDate!.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 2,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isOverdue ? onSurface.withOpacity(0.5) : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: todo.isCompleted,
            onChanged: (_) => onToggle(),
            activeColor: onSurface,
            checkColor: Theme.of(context).colorScheme.surface,
            side: BorderSide(color: onSurface, width: 2.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        title: Text(
          todo.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? Theme.of(context).hintColor : onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (todo.description != null && todo.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                todo.description!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: todo.isCompleted ? Theme.of(context).hintColor : onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _priorityColor, width: 1),
                  ),
                  child: Text(
                    _priorityLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _priorityColor,
                    ),
                  ),
                ),
                if (todo.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: onSurface.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      todo.category!,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                  ),
                if (todo.dueDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isOverdue
                          ? onSurface.withOpacity(0.15)
                          : onSurface.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 10,
                          color: _isOverdue ? onSurface : Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd').format(todo.dueDate!),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _isOverdue ? onSurface : Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: onEdit,
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 12),
                  Text('Edit', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            PopupMenuItem(
              onTap: onDelete,
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 20),
                  const SizedBox(width: 12),
                  Text('Delete', style: GoogleFonts.poppins()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
