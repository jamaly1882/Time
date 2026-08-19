import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notifications = FlutterLocalNotificationsPlugin();
final tts = FlutterTts();

const dayNames = ['السبت','الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة'];

class Task {
  final int day; // 0=Saturday
  final int hour, minute;
  final String title;
  final String message;
  final bool enabled;
  Task(this.day,this.hour,this.minute,this.title,this.message,{this.enabled=true});

  Map<String,dynamic> toJson()=>{'day':day,'hour':hour,'minute':minute,'title':title,'message':message,'enabled':enabled};
  static Task fromJson(Map<String,dynamic> j)=>Task(j['day'],j['hour'],j['minute'],j['title'],j['message'],enabled:j['enabled'] ?? true);
}

List<Task> defaultTasks() => [
  Task(0,16,0,'تطبيق الإيجار','حان الآن وقت العمل على تطبيق الإيجار'),
  Task(0,18,30,'تطبيق الإيجار','حان الآن وقت الجلسة الثانية على تطبيق الإيجار'),
  Task(0,21,0,'تطبيق السفريات','حان الآن وقت العمل على تطبيق السفريات'),
  Task(0,23,0,'مراجعة','حان الآن وقت المراجعة اليومية'),
  Task(1,16,0,'تطبيق السفريات','حان الآن وقت العمل على تطبيق السفريات'),
  Task(1,18,30,'تطبيق السفريات','حان الآن وقت الجلسة الثانية على تطبيق السفريات'),
  Task(1,21,0,'تطبيق التحويل','حان الآن وقت العمل على تطبيق التحويل'),
  Task(1,23,0,'تطبيق التحويل','حان الآن وقت الجلسة الثانية على تطبيق التحويل'),
  Task(2,16,0,'تطبيق الإيجار','حان الآن وقت العمل على تطبيق الإيجار'),
  Task(2,18,30,'تطبيق الإيجار','حان الآن وقت الجلسة الثانية على تطبيق الإيجار'),
  Task(2,21,0,'Desktop','حان الآن وقت العمل على تحويل المساحة إلى Desktop'),
  Task(2,23,0,'Desktop','حان الآن وقت الجلسة الثانية على Desktop'),
  Task(3,16,0,'تطبيق المياه','حان الآن وقت مراجعة تطبيق المياه'),
  Task(3,18,30,'تطبيق المياه','حان الآن وقت تطوير وتحسين تطبيق المياه'),
  Task(3,21,0,'تطبيق الإيجار','حان الآن وقت العمل على تطبيق الإيجار'),
  Task(3,23,0,'تطبيق الإيجار','حان الآن وقت الجلسة الثانية على تطبيق الإيجار'),
  Task(4,16,0,'تطبيق التحويل','حان الآن وقت العمل على تطبيق التحويل'),
  Task(4,18,30,'تطبيق التحويل','حان الآن وقت الجلسة الثانية على تطبيق التحويل'),
  Task(4,21,0,'Desktop','حان الآن وقت العمل على Desktop'),
  Task(4,23,0,'Desktop','حان الآن وقت الجلسة الثانية على Desktop'),
  Task(5,16,0,'الدورة التدريبية','حان الآن وقت الدورة التدريبية'),
  Task(5,18,30,'الدورة التدريبية','حان الآن وقت الدورة التدريبية'),
  Task(5,21,0,'المراجعة والاختبار','حان الآن وقت المراجعة والاختبار'),
  Task(5,23,0,'المراجعة والاختبار','حان الآن وقت المراجعة والاختبار'),
];

Future<void> speak(String text) async {
  await tts.setLanguage('ar');
  await tts.setSpeechRate(0.48);
  await tts.speak(text);
}

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await notifications.initialize(settings);
  await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
}

Future<void> scheduleTask(Task task) async {
  if (!task.enabled) return;
  // Android weekday: Monday=1 ... Sunday=7. Our day: Saturday=0 ... Friday=6.
  final weekday = task.day == 6 ? DateTime.friday : task.day + 2;
  final now = tz.TZDateTime.now(tz.local);
  var date = now;
  while (date.weekday != weekday) date = date.add(const Duration(days:1));
  var scheduled = tz.TZDateTime(tz.local,date.year,date.month,date.day,task.hour,task.minute);
  if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days:7));
  final id = task.day*10000 + task.hour*100 + task.minute;
  await notifications.zonedSchedule(
    id, 'منظم وقتي — ${task.title}', task.message,
    scheduled,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'schedule_channel','جدول العمل',
        channelDescription:'تنبيهات جدول العمل الأسبوعي',
        importance: Importance.max, priority: Priority.high,
        playSound: true, enableVibration: true,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

Future<void> rescheduleAll(List<Task> tasks) async {
  await notifications.cancelAll();
  for (final t in tasks) await scheduleTask(t);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'منظم وقتي',
    theme:ThemeData(useMaterial3:true, colorSchemeSeed:Colors.indigo, fontFamily:'sans'),
    home:const HomePage(),
  );
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }

class _HomePageState extends State<HomePage> {
  List<Task> tasks=[];
  int selectedDay=(DateTime.now().weekday + 1)%7; // Saturday=0
  bool loading=true;

  @override void initState(){super.initState(); load();}
  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    final raw=p.getStringList('tasks');
    tasks=raw==null ? defaultTasks() : raw.map((s)=>Task.fromJson(jsonDecode(s))).toList();
    if(raw==null) await save();
    await rescheduleAll(tasks);
    setState(()=>loading=false);
  }
  Future<void> save() async {
    final p=await SharedPreferences.getInstance();
    await p.setStringList('tasks',tasks.map((t)=>jsonEncode(t.toJson())).toList());
  }

  @override Widget build(BuildContext context){
    if(loading) return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final dayTasks=tasks.where((t)=>t.day==selectedDay).toList()
      ..sort((a,b)=>(a.hour*60+a.minute).compareTo(b.hour*60+b.minute));
    return Scaffold(
      appBar:AppBar(title:const Text('منظم وقتي'), actions:[
        IconButton(onPressed:() async {await speak('اختبار التنبيه الصوتي منظم وقتي');}, icon:const Icon(Icons.volume_up))
      ]),
      body:Column(children:[
        const SizedBox(height:8),
        SizedBox(height:50,child:ListView.builder(scrollDirection:Axis.horizontal,itemCount:7,itemBuilder:(c,i){
          return Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:ChoiceChip(label:Text(dayNames[i]),selected:selectedDay==i,onSelected:(_)=>setState(()=>selectedDay=i)));
        })),
        Expanded(child:dayTasks.isEmpty
          ? const Center(child:Text('لا توجد مهام لهذا اليوم — راحة'))
          : ListView.builder(itemCount:dayTasks.length,itemBuilder:(c,i){
            final t=dayTasks[i];
            return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ListTile(
              leading:CircleAvatar(child:Text('${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}')),
              title:Text(t.title,style:const TextStyle(fontWeight:FontWeight.bold)),
              subtitle:Text(t.message),
              trailing:Switch(value:t.enabled,onChanged:(v) async {
                final idx=tasks.indexOf(t);
                tasks[idx]=Task(t.day,t.hour,t.minute,t.title,t.message,enabled:v);
                await save(); await rescheduleAll(tasks); setState((){});
              }),
              onTap:()=>speak(t.message),
            ));
          })),
        Padding(padding:const EdgeInsets.all(12),child:FilledButton.icon(
          onPressed:() async { await rescheduleAll(tasks); if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تحديث جميع التنبيهات'))); },
          icon:const Icon(Icons.notifications_active), label:const Text('تحديث التنبيهات')
        ))
      ])
    );
  }
}
