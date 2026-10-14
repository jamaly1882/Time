import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const dayNames = [
  'السبت',
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
];

const categoryColors = {
  'عمل': Color(0xFF2563EB),
  'دراسة': Color(0xFF7C3AED),
  'مراجعة': Color(0xFF16A34A),
  'رياضة': Color(0xFFF59E0B),
  'أخرى': Color(0xFF64748B),
};

class Task {
  final int day;
  final int hour;
  final int minute;
  final String title;
  final String message;
  final bool enabled;
  final String category;

  Task(
    this.day,
    this.hour,
    this.minute,
    this.title,
    this.message, {
    this.enabled = true,
    this.category = 'أخرى',
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'hour': hour,
        'minute': minute,
        'title': title,
        'message': message,
        'enabled': enabled,
        'category': category,
      };

  static Task fromJson(Map<String, dynamic> json) {
    return Task(
      json['day'] as int,
      json['hour'] as int,
      json['minute'] as int,
      json['title'] as String,
      json['message'] as String,
      enabled: json['enabled'] ?? true,
      category: json['category'] ?? 'أخرى',
    );
  }

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

List<Task> defaultTasks() => [
  Task(0, 16, 0, 'تطبيق الإيجار', 'حان الآن وقت العمل على تطبيق الإيجار', category: 'عمل'),
  Task(0, 18, 30, 'تطبيق الإيجار', 'حان الآن وقت الجلسة الثانية على تطبيق الإيجار', category: 'عمل'),
  Task(1, 17, 0, 'تطبيق السفريات', 'حان الآن وقت العمل على تطبيق السفريات', category: 'عمل'),
  Task(1, 20, 30, 'تطبيق السفريات', 'حان الآن وقت الجلسة الثانية على تطبيق السفريات', category: 'عمل'),
  Task(2, 16, 0, 'Desktop', 'حان الآن وقت العمل على Desktop', category: 'عمل'),
  Task(2, 18, 30, 'Desktop', 'حان الآن و��ت الجلسة الثانية على Desktop', category: 'عمل'),
  Task(3, 17, 0, 'تطبيق المياه', 'حان الآن وقت مراجعة تطبيق المياه', category: 'مراجعة'),
  Task(3, 21, 0, 'تطبيق الإيجار', 'حان الآن وقت العمل على تطبيق الإيجار', category: 'عمل'),
  Task(4, 16, 0, 'تطبيق التحويل', 'حان الآن وقت العمل على تطبيق التحويل', category: 'عمل'),
  Task(4, 18, 30, 'تطبيق التحويل', 'حان الآن وقت الجلسة الثانية على تطبيق التحويل', category: 'عمل'),
  Task(5, 16, 0, 'الدورة التدريبية', 'حان الآن وقت الدورة التدريبية', category: 'دراسة'),
  Task(5, 18, 30, 'المراجعة', 'حان الآن وقت مراجعة ما تم تعلمه', category: 'مراجعة'),
  Task(6, 21, 0, 'تمارين', 'حان الآن وقت التمارين اليومية', category: 'رياضة'),
];

Future<void> speakText(String text) async {
  try {
    final speech = html.window.speechSynthesis;
    final utterance = html.SpeechSynthesisUtterance(text);
    utterance.lang = 'ar-SA';
    utterance.rate = 0.9;
    speech.speak(utterance);
  } catch (_) {
    debugPrint('SpeechSynthesis unavailable in this browser');
  }
}

Future<void> showBrowserNotification(String title, String body) async {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, {'body': body});
      return;
    }

    final permission = await html.Notification.requestPermission();
    if (permission == 'granted') {
      html.Notification(title, {'body': body});
    }
  } catch (_) {
    debugPrint('Browser notifications are unavailable');
  }
}

DateTime nextOccurrenceForTask(int day, int hour, int minute) {
  final now = DateTime.now();

  // day: 0=Saturday ... 6=Friday
  final targetWeekday = (day == 6) ? DateTime.friday : day + 2;

  DateTime candidate =
      DateTime(now.year, now.month, now.day, hour, minute);

  while (candidate.weekday != targetWeekday || !candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }

  return candidate;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منظم الوقت',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0.7,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
        fontFamily: 'sans',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> tasks = [];
  int selectedDay = (DateTime.now().weekday + 1) % 7;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('tasks');

    if (raw == null || raw.isEmpty) {
      tasks = defaultTasks();
      await save();
    } else {
      tasks = raw
          .map((item) => Task.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    }

    scheduleAllTasks();
    setState(() {
      loading = false;
    });
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'tasks',
      tasks.map((task) => jsonEncode(task.toJson())).toList(),
    );
  }

  void scheduleAllTasks() {
    final tasksToSchedule = tasks.where((task) => task.enabled).toList();
    for (final task in tasksToSchedule) {
      final next = nextOccurrenceForTask(task.day, task.hour, task.minute);
      final key = 'task-${task.day}-${task.hour}-${task.minute}-${task.title}';

      // Schedule in browser using Timer
      Timer(next.difference(DateTime.now()), () {
        showBrowserNotification('منظم وقتي — ${task.title}', task.message);
        speakText(task.message);
      });

      // For repeated rescheduling, schedule next weeks using a simple delayed loop
      // Note: This only works while the page is open. For background push notifications, a server + service worker is needed.
      void scheduleNextWeek(DateTime occurrence) {
        final nextWeek = occurrence.add(const Duration(days: 7));
        Timer(nextWeek.difference(DateTime.now()), () {
          showBrowserNotification('منظم وقتي — ${task.title}', task.message);
          speakText(task.message);
          scheduleNextWeek(nextWeek);
        });
      }

      scheduleNextWeek(next);
    }
  }

  Future<void> openTaskForm([Task? taskToEdit]) async {
    final newTask = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (_) => TaskFormPage(task: taskToEdit)),
    );

    if (newTask == null) return;

    setState(() {
      if (taskToEdit != null) {
        final index = tasks.indexWhere((task) =>
            task.title == taskToEdit.title &&
            task.day == taskToEdit.day &&
            task.hour == taskToEdit.hour &&
            task.minute == taskToEdit.minute);
        if (index >= 0) {
          tasks[index] = newTask;
        }
      } else {
        tasks.add(newTask);
      }
    });

    await save();
    scheduleAllTasks();
  }

  void deleteTask(Task task) async {
    setState(() {
      tasks.remove(task);
    });
    await save();
    scheduleAllTasks();
  }

  List<Task> get dayTasks {
    final result = tasks.where((task) => task.day == selectedDay).toList();
    result.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return result;
  }

  int get enabledCount => tasks.where((task) => task.enabled).length;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('منظم الوقت', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => speakText('اختبار التشغيل الصوتي'),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          IconButton(
            onPressed: () async {
              await showBrowserNotification('منظم الوقت', 'تم تحديث التنبيهات');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث التنبيهات بنجاح')),
                );
              }
            },
            icon: const Icon(Icons.notifications_active_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTaskForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة مهمة'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _SummaryRow(enabledCount: enabledCount, totalCount: tasks.length),
              const SizedBox(height: 18),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final selected = selectedDay == index;
                    return ChoiceChip(
                      label: Text(dayNames[index]),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: const Color(0xFF2563EB),
                      onSelected: (_) => setState(() => selectedDay = index),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مهام ${dayNames[selectedDay]}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${dayTasks.length} مهمة',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: dayTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('لا توجد مهام لهذا اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 8),
                            const Text('أضف مهمة جديدة للاستفادة من جدولك اليومي', style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: dayTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final task = dayTasks[index];
                          return TaskCard(
                            task: task,
                            onToggle: (value) async {
                              final idx = tasks.indexOf(task);
                              if (idx == -1) return;

                              tasks[idx] = Task(
                                task.day,
                                task.hour,
                                task.minute,
                                task.title,
                                task.message,
                                enabled: value,
                                category: task.category,
                              );

                              await save();
                              scheduleAllTasks();
                              setState(() {});
                            },
                            onEdit: () => openTaskForm(task),
                            onDelete: () => deleteTask(task),
                            onSpeak: () => speakText(task.message),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int enabledCount;
  final int totalCount;

  const _SummaryRow({required this.enabledCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'المفعلة',
            value: '$enabledCount',
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'إجمالي المهام',
            value: '$totalCount',
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSpeak;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColors[task.category] ?? categoryColors['أخرى'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: (color ?? Colors.blue).withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  task.timeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (color ?? Colors.blue).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          task.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: color ?? Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 17,
                        color: task.enabled ? const Color(0xFF2563EB) : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        task.enabled ? 'مفعّل' : 'متوقف',
                        style: TextStyle(
                          color: task.enabled ? const Color(0xFF2563EB) : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: task.enabled,
                  onChanged: onToggle,
                  activeColor: const Color(0xFF2563EB),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onSpeak,
                      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF2563EB)),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TaskFormPage extends StatefulWidget {
  final Task? task;

  const TaskFormPage({super.key, this.task});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final messageController = TextEditingController();

  TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int selectedDay = 0;
  String selectedCategory = 'أخرى';

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      final task = widget.task!;
      titleController.text = task.title;
      messageController.text = task.message;
      selectedDay = task.day;
      selectedTime = TimeOfDay(hour: task.hour, minute: task.minute);
      selectedCategory = task.category;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      helpText: 'اختر الوقت',
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'إضافة مهمة' : 'تعديل المهمة'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اسم المهمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'مثال: مراجعة المشروع',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'أدخل اسم المهمة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('الوصف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'اكتب وصفًا مختصرًا للمهمة',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'أدخل وصفًا للمهمة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text('الفئة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['عمل', 'دراسة', 'مراجعة', 'رياضة', 'أخرى'].map((category) {
                    final selected = selectedCategory == category;
                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (_) => setState(() => selectedCategory = category),
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isSelected = selectedDay == index;
                      return ChoiceChip(
                        label: Text(dayNames[index]),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => selectedDay = index),
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text('الوقت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickTime,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                        const Icon(Icons.access_time_rounded, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      final task = Task(
                        selectedDay,
                        selectedTime.hour,
                        selectedTime.minute,
                        titleController.text.trim(),
                        messageController.text.trim(),
                        category: selectedCategory,
                      );

                      Navigator.pop(context, task);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('حفظ المهمة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
