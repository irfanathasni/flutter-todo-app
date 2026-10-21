import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Task {
  String title;
  bool done;
  Task({required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'title': title, 'done': done};

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'] as String,
      done: json['done'] as bool? ?? false,
    );
  }
}

enum TaskFilter { all, active, done }

void main() => runApp(const MaterialApp(home: TaskScreen()));

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class TaskRow extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              task.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.done ? Colors.green : Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                decoration: task.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete)),
        ],
      ),
    );
  }
}

class _TaskScreenState extends State<TaskScreen> {
  final List<Task> tasks = [];

  final TextEditingController controller = TextEditingController();
  TaskFilter filter = TaskFilter.all;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('tasks');
    if (saved == null) return;

    final List<dynamic> decoded = jsonDecode(saved);
    setState(() {
      tasks.addAll(
        decoded.map((item) => Task.fromJson(item as Map<String, dynamic>)),
      );
    });
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString('tasks', encoded);
  }

  List<Task> get visibleTasks {
    Iterable<Task> result = tasks;

    switch (filter) {
      case TaskFilter.active:
        result = result.where((t) => !t.done);
        break;
      case TaskFilter.done:
        result = result.where((t) => t.done);
        break;
      case TaskFilter.all:
        break;
    }

    if (searchQuery.isNotEmpty) {
      result = result.where(
        (t) => t.title.toLowerCase().contains(searchQuery.toLowerCase()),
      );
    }
    return result.toList();
  }

  void addTask() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      tasks.add(Task(title: text));
    });
    controller.clear();
    saveTasks();
  }

  void toggleTask(Task task) {
    setState(() {
      task.done = !task.done;
    });
    saveTasks();
  }

  void deleteTask(Task task) {
    setState(() {
      tasks.remove(task);
    });
    saveTasks();
  }

  Future<void> editTask(Task task) async {
    final editController = TextEditingController(text: task.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit task'),
        content: TextField(controller: editController, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      setState(() {
        task.title = newTitle;
      });
      saveTasks();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'New task',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: addTask, child: const Text('Add')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SegmentedButton<TaskFilter>(
              segments: const [
                ButtonSegment(value: TaskFilter.all, label: Text('All')),
                ButtonSegment(value: TaskFilter.active, label: Text('Active')),
                ButtonSegment(value: TaskFilter.done, label: Text('Done')),
              ],
              selected: {filter},
              onSelectionChanged: (selection) {
                setState(() {
                  filter = selection.first;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final task = visible[index];
                return TaskRow(
                  task: task,
                  onToggle: () => toggleTask(task),
                  onEdit: () => editTask(task),
                  onDelete: () => deleteTask(task),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
