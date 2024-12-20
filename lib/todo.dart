import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


// Todo 모델 클래스
class Todo {
  String id;
  String title;
  final DateTime date;
  String? memo;
  TimeOfDay? alarmTime;
  String? repeat;
  bool isDone;
  List<DateTime>? futureDates;
  List<String> repeatDays;
  String userEmail;

 //userid받아오는 섹션 추가해야함
  Todo({
    this.id = '',
    required this.title,
    required this.date,
    this.memo,
    this.alarmTime,
    this.repeat,
    this.isDone = false,
    this.futureDates,
    this.repeatDays = const [],
    required this.userEmail,
  });

  // Firestore에서 가져온 데이터를 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),  // DateTime을 Timestamp로 변환
      'memo': memo,
      'alarmTime': alarmTime != null
          ? {'hour': alarmTime!.hour, 'minute': alarmTime!.minute}
          : null,
      'repeat': repeat,
      'isDone': isDone,
      'userEmail': userEmail,
    };
  }

  // Firestore의 데이터를 Todo 객체로 변환
  static Todo fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Todo(
      id: doc.id,
      title: data['title'],
      date: (data['date'] as Timestamp).toDate(),
      memo: data['memo'],
      alarmTime: data['alarmTime'] != null
          ? TimeOfDay(
        hour: data['alarmTime']['hour'],
        minute: data['alarmTime']['minute'],
      )
          : null,
      repeat: data['repeat'],
      isDone: data['isDone'],
      userEmail: data['userEmail'] ?? '',
    );
  }
}

// TodoPage 수정: 콜백 함수 추가
class TodoPage extends StatefulWidget {
  final DateTime selectedDate;
  final Function(Todo) onTodoAdded;
  final Function(Todo) onTodoRemoved;
  final Function(List<Todo>) onTodoListChanged; // 할 일 목록 변경 콜백
  final String userEmail; // 추가된 부분

  TodoPage({
    required this.selectedDate,
    required this.onTodoAdded,
    required this.onTodoRemoved,
    required this.onTodoListChanged,
    required this.userEmail, // 추가된 부분
  });

  @override
  _TodoPageState createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  // 할 일 목록 (Firestore에서 가져온 데이터 저장)
  List<Todo> _todoList = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadTodos(); // 앱 시작 시 Firestore에서 데이터 불러오기
    _initializeNotifications();
  }

  Future<void> _scheduleNotification(Todo todo) async {
    var scheduledNotificationDateTime = DateTime(
      todo.date.year,
      todo.date.month,
      todo.date.day,
      todo.alarmTime!.hour,
      todo.alarmTime!.minute,
    );

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'todo_alarm',
      'Todo Alarms',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // 아래 schedule 메소드 호출을 주석 처리합니다.
    /*
  await flutterLocalNotificationsPlugin.schedule(
    todo.hashCode,
    'Todo Reminder',
    todo.title,
    scheduledNotificationDateTime,
    platformChannelSpecifics,
  );
  */
  }

  Future<void> _initializeNotifications() async {
    var initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showAlarmSettingDialog(Todo todo) async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime != null) {
      setState(() {
        todo.alarmTime = selectedTime;
      });
      await _updateTodoInFirestore(todo); // Firestore에서 할 일 업데이트
    }
  }

  void _updateTodoList() {
    widget.onTodoListChanged(_todoList); // 콜백 함수 호출
    setState(() {}); // 현재 위젯의 상태만 업데
  }
  Future<void> _updateTodoInFirestore(Todo todo) async {
    final todoCollection = FirebaseFirestore.instance.collection('todos');
    try {
      await todoCollection.doc(todo.id).update(todo.toMap());
    } catch (e) {
      print("Error updating todo: $e");
    }
  }

  // Firestore에서 할 일 목록 읽기
  Future<void> _loadTodos() async {
    final todoCollection = FirebaseFirestore.instance.collection('todos');
    QuerySnapshot snapshot = await todoCollection
        .where('userEmail', isEqualTo: widget.userEmail) // 현재 사용자의 Todo만 가져오기
        .get();
    setState(() {
      _todoList = snapshot.docs
          .map((doc) => Todo.fromFirestore(doc))  // Firestore에서 Todo 객체로 변환
          .toList();
      _updateTodoList();
    });
    widget.onTodoListChanged(_todoList); // 상위 위젯에 변경 알림
  }

  // Firestore에 할 일 추가
  Future<void> _addTodoToFirestore(Todo todo) async {
    final todoCollection = FirebaseFirestore.instance.collection('todos');
    try {
      DocumentReference docRef = await todoCollection.add(todo.toMap());
      setState(() {
        todo.id = docRef.id; // Firestore에서 생성된 ID를 Todo에 저장
      });
    } catch (e) {
      print("Error adding todo: $e");
    }
  }

  // Firestore에서 할 일 삭제
  Future<void> _deleteTodoFromFirestore(String todoId) async {
    final todoCollection = FirebaseFirestore.instance.collection('todos');
    try {
      await todoCollection.doc(todoId).delete();
    } catch (e) {
      print("Error deleting todo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTodoList = _todoList.where((todo) =>
        isSameDay(todo.date, widget.selectedDate)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Todo'),
      ),
      body: ListView.builder(
        itemCount: filteredTodoList.length,
        itemBuilder: (context, index) {
          final todo = filteredTodoList[index];
          // 각 Todo 항목을 Dismissible 위젯으로 감싸 스와이프로 삭제 가능하게 함
          return Dismissible(
            key: Key(todo.id),//key: UniqueKey(),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              setState(() {
                _todoList.remove(todo);
                _generateFutureDates(todo);
                _addFutureTodos(todo);
              });
              widget.onTodoRemoved(todo); // 할 일 삭제 콜백 호출
              _deleteTodoFromFirestore(todo.id); // Firestore에서 할 일 삭제
              _updateTodoList();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${todo.title} 삭제됨')),
              );
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 20),
              color: Colors.red,
              child: Icon(Icons.delete, color: Colors.white),
            ),
            child: ListTile(
              title: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  todo.title,
                  style: TextStyle(
                    decoration: todo.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              trailing: _buildTrailingButtons(todo),
              onTap: () => _showTodoDetails(context, todo),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewTodoDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  // 할 일 항목의 우측 버튼 구성
  Widget _buildTrailingButtons(Todo todo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _showEditTitleDialog(context, todo),
        ),
        Checkbox(
          value: todo.isDone,
          onChanged: (bool? value) async {
            setState(() {
              todo.isDone = value ?? false;
            });
            await _updateTodoInFirestore(todo);
            _updateTodoList();
          },
        ),
      ],
    );
  }

  // 제목 수정 다이얼로그
  void _showEditTitleDialog(BuildContext context, Todo todo) {
    TextEditingController _controller = TextEditingController(text: todo.title);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('타이틀 수정'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: '새로운 타이틀'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('수정'),
              onPressed: () {
                setState(() {
                  todo.title = _controller.text;
                });
                _updateTodoList();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 할 일 상세 보기
  void _showTodoDetails(BuildContext context, Todo todo) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.5,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(todo.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              _buildMemoField(todo),
              SizedBox(height: 10),
              _buildAlarmAndRepeatRow(todo),
              SizedBox(height: 20),
              _buildCompletionButton(todo),
              Divider(),
              _buildDeleteButton(todo),
            ],
          ),
        ),
      ),
    );
  }

  // 메모 입력 필드
  Widget _buildMemoField(Todo todo) {
    return TextFormField(
      initialValue: todo.memo,
      onChanged: (value) => setState(() {
        todo.memo = value.trim().isEmpty ? null : value;
        _updateTodoList();
      }),
      decoration: InputDecoration(
        hintText: todo.memo?.isEmpty ?? true ? '메모' : '',
        hintStyle: TextStyle(color: Colors.grey),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      maxLines: 3,
    );
  }

  // 알림 및 반복 설정 버튼
  Widget _buildAlarmAndRepeatRow(Todo todo) {
    return Row(
      children: [
        _buildAlarmOption(todo),
        SizedBox(width: 10),
        _buildRepeatOption(todo),
      ],
    );
  }

  // 알림 옵션 생성 함수
  Widget _buildAlarmOption(Todo todo) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectAlarmTime(context, todo),
        child: _buildOptionBox(
          icon: Icons.alarm,
          text: todo.alarmTime != null
              ? '${todo.alarmTime!.hour}:${todo.alarmTime!.minute.toString().padLeft(2, '0')}'
              : '알람 시간',
        ),
      ),
    );
  }

  // 반복 옵션 생성 함수
  Widget _buildRepeatOption(Todo todo) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectRepeatOption(context, todo),
        child: _buildOptionBox(
          icon: Icons.repeat,
          text: todo.repeat ?? '반복 설정',
        ),
      ),
    );
  }

  // 알림 시간 선택기
  Future<void> _selectAlarmTime(BuildContext context, Todo todo) async {
    TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: todo.alarmTime ?? TimeOfDay.now(),
    );
    if (newTime != null) {
      setState(() {
        todo.alarmTime = newTime;
        _generateFutureDates(todo);
      });
      _updateTodoList();
      // 여기에 알람 설정 로직 추가
      _scheduleNotification(todo);
    }
  }

  // 반복 옵션 선택기
  void _selectRepeatOption(BuildContext context, Todo todo) async {
    String? selectedRepeat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('반복 설정'),
          children: <Widget>[
            _buildRepeatOptionDialog('매일'),
            _buildRepeatOptionDialog('매주'),
            _buildRepeatOptionDialog('매월'),
            _buildRepeatOptionDialog('반복 안함'),
          ],
        );
      },
    );
    if (selectedRepeat != null) {
      setState(() {
        todo.repeat = selectedRepeat == '반복 안함' ? null : selectedRepeat;
        if (selectedRepeat == '매일') {
          todo.repeatDays = ['월', '화', '수', '목', '금', '토', '일'];
        } else if (selectedRepeat == '매주') {
          if (todo.repeatDays.isEmpty) {
            todo.repeatDays = ['월']; // 기본값으로 월요일 선택
          }
          _selectWeekDays(context, todo);
        } else if (selectedRepeat == '매월') {
          todo.repeatDays = [];
        } else if (selectedRepeat == '반복 안함') {
          todo.repeatDays = [];
        }
      });
      await _updateTodoInFirestore(todo);
      _generateFutureDates(todo);
      _updateTodoList();
    }
  }

  Future<void> _generateFutureDates(Todo todo) async {
    if (todo.repeat == null || todo.alarmTime == null) {
      todo.futureDates = null;
      return;
    }

    List<Todo> futureTodos = [];
    DateTime currentDate = todo.date;

    for (int i = 0; i < 52; i++) { // 1년치 생성
      switch (todo.repeat) {
        case '매일':
          currentDate = currentDate.add(Duration(days: 1));
          break;
        case '매주':
          if (todo.repeatDays.isNotEmpty) {
            do {
              currentDate = currentDate.add(Duration(days: 1));
            } while (!todo.repeatDays.contains(['월', '화', '수', '목', '금', '토', '일'][currentDate.weekday - 1]));
          }
          break;
        case '매월':
        // 다음 달의 같은 날짜로 설정
          currentDate = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
          // 만약 다음 달에 해당 날짜가 없다면 (예: 1월 31일 -> 2월 28일)
          if (currentDate.day != todo.date.day) {
            currentDate = DateTime(currentDate.year, currentDate.month, 0); // 해당 월의 마지막 날로 설정
          }
          break;
        default:
          return;
      }

      Todo newTodo = Todo(
        title: todo.title,
        date: currentDate,
        memo: todo.memo,
        alarmTime: todo.alarmTime,
        repeat: todo.repeat,
        repeatDays: todo.repeatDays,
        userEmail: widget.userEmail,
      );
      futureTodos.add(newTodo);
      await _addTodoToFirestore(newTodo); // 새로운 할 일을 Firestore에 추가
    }

    setState(() {
      _todoList.addAll(futureTodos);
    });
    _updateTodoList();
  }

  // 옵션 박스 스타일링
  Widget _buildOptionBox({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  // 완료 버튼
  Widget _buildCompletionButton(Todo todo) {
    return ElevatedButton(
      onPressed: () async{
        setState(() {
          todo.isDone = !todo.isDone;
        });
        await _updateTodoInFirestore(todo);
        Navigator.pop(context);
      },
      child: Text(todo.isDone ? '완료 취소' : '완료하기'),
    );
  }

  // 할 일 삭제 버튼
  Widget _buildDeleteButton(Todo todo) {
    return ElevatedButton.icon(
      onPressed: () {

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('할 일 삭제'),
              content: Text('삭제하시겠습니까?'),
              actions: [
                TextButton(
                  child: Text('취소'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('삭제'),
                  onPressed: () async {
                    await _deleteTodoFromFirestore(todo.id);
                    setState(() {
                      _todoList.remove(todo);
                    });
                    _updateTodoList();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
                if (todo.repeat != null)
                  TextButton(
                    child: Text('일정에서 전체 삭제'),
                    onPressed: () async {
                      // 데이터베이스에서 관련된 모든 일정 삭제
                      List<Todo> relatedTodos = _todoList.where((t) =>
                      t.title == todo.title &&
                          t.repeat == todo.repeat &&
                          t.alarmTime == todo.alarmTime
                      ).toList();

                      for (var relatedTodo in relatedTodos) {
                        await _deleteTodoFromFirestore(relatedTodo.id);
                      }

                      setState(() {
                        _todoList.removeWhere((t) =>
                        t.title == todo.title &&
                            t.repeat == todo.repeat &&
                            t.alarmTime == todo.alarmTime
                        );
                      });
                      _updateTodoList();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            );
          },
        );
      },
      icon: Icon(Icons.delete, color: Colors.red),
      label: Text('삭제'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.8),
      ),
    );
  }

  // 새 할 일 추가 다이얼로그
  void _addNewTodoDialog() {
    TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('새 할 일 추가'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: '할 일 제목'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('추가'),
              onPressed: () async {
                String title = _controller.text.trim();

                if (title.isNotEmpty) {
                  Todo newTodo = Todo(
                    title: title,
                    date: widget.selectedDate,
                    userEmail: widget.userEmail,
                  );

                  try {
                    await _addTodoToFirestore(newTodo);
                    setState(() {
                      _todoList.add(newTodo);
                    });
                    _updateTodoList();
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류가 발생했습니다: $e'))
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('할 일 제목을 입력해주세요!'))
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month &&
        date1.day == date2.day;
  }

// 특정 날짜의 Todo 항목들을 반환하는 함수
  List<Todo> _getEventsForDay(DateTime day) {
    return _todoList.where((todo) =>
    isSameDay(todo.date, day) ||
        (todo.futureDates?.any((futureDate) => isSameDay(futureDate, day)) ??
            false)
    ).toList();
  }

// 미래 날짜의 Todo 항목들을 추가하는 함수
  void _addFutureTodos(Todo originalTodo) {
    if (originalTodo.futureDates == null) return;

    for (DateTime futureDate in originalTodo.futureDates!) {
      Todo newTodo = Todo(
        title: originalTodo.title,
        date: futureDate,
        memo: originalTodo.memo,
        alarmTime: originalTodo.alarmTime,
        repeat: originalTodo.repeat,
        userEmail: originalTodo.userEmail,
      );
      setState(() {
        _todoList.add(newTodo);
      });
    }
    _updateTodoList();
  }
// Todo 페이지의 UI를 구성하는 build 메서드

// Todo 항목의 반복 설정 텍스트를 반환하는 함수
  String _getRepeatText(Todo todo) {
    if (todo.repeat == null) return '반복 없음';
    if (todo.repeat == '매일') return '매일';
    if (todo.repeat == '매주') {
      return '매주 ${todo.repeatDays.join(', ')}';
    }
    if (todo.repeat == '매월') return '매월';
    return '반복 없음';
  }

// 반복 요일을 선택하는 옵션을 생성하는 위젯
  Widget _buildRepeatDaysOption(Todo todo) {
    return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Wrap(
            spacing: 8.0,
            children: ['월', '화', '수', '목', '금', '토', '일'].map((day) {
              return FilterChip(
                label: Text(day),
                selected: todo.repeatDays.contains(day),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      todo.repeatDays.add(day);
                    } else {
                      todo.repeatDays.remove(day);
                    }
                    if (todo.repeatDays.length == 7) {
                      todo.repeat = '매일';
                    } else if (todo.repeatDays.isNotEmpty) {
                      todo.repeat = '매주';
                    } else {
                      todo.repeat = null;
                    }
                    _generateFutureDates(todo);
                  });
                  _updateTodoList();
                },
              );
            }).toList(),
          );
        }
    );
  }

  // 반복 설정을 위한 다이얼로그를 표시하는 함수
  void _showRepeatOptionsDialog(BuildContext context, Todo todo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('반복 설정'),
              content: _buildRepeatCheckboxes(todo, setState), // 반복 체크박스 UI 생성
              actions: <Widget>[
                TextButton(
                  child: Text('취소'),
                  onPressed: () => Navigator.of(context).pop(), // 다이얼로그 닫기
                ),
                TextButton(
                  child: Text('확인'),
                  onPressed: () {
                    _updateTodoList(); // Todo 리스트 업데이트
                    Navigator.of(context).pop(); // 다이얼로그 닫기
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

// 반복 설정을 위한 체크박스 UI를 생성하는 함수
  Widget _buildRepeatCheckboxes(Todo todo, StateSetter setState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(
          title: Text('반복 안함'),
          value: todo.repeat == null,
          onChanged: (bool? value) {
            setState(() {
              todo.repeat = value! ? null : '매주';
              todo.repeatDays = [];
            });
          },
        ),
        CheckboxListTile(
          title: Text('매일'),
          value: todo.repeat == '매일',
          onChanged: (bool? value) {
            setState(() {
              todo.repeat = value! ? '매일' : null;
              todo.repeatDays =
              value ? ['월', '화', '수', '목', '금', '토', '일'] : [];
            });
          },
        ),
        CheckboxListTile(
          title: Text('매주'),
          value: todo.repeat == '매주',
          onChanged: (bool? value) {
            setState(() {
              todo.repeat = value! ? '매주' : null;
              if (!value) todo.repeatDays = [];
            });
          },
        ),
        if (todo.repeat == '매주')
          Wrap(
            spacing: 8.0,
            children: ['월', '화', '수', '목', '금', '토', '일'].map((day) {
              return FilterChip(
                label: Text(day),
                selected: todo.repeatDays.contains(day),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      todo.repeatDays.add(day);
                    } else {
                      todo.repeatDays.remove(day);
                    }
                    if (todo.repeatDays.isEmpty) {
                      todo.repeat = null;
                    }
                  });
                },
              );
            }).toList(),
          ),
        CheckboxListTile(
          title: Text('매월'),
          value: todo.repeat == '매월',
          onChanged: (bool? value) {
            setState(() {
              todo.repeat = value! ? '매월' : null;
              todo.repeatDays = [];
            });
          },
        ),
      ],
    );
  }

  void _selectWeekDays(BuildContext context, Todo todo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('요일 선택'),
              content: Wrap(
                spacing: 5,
                children: ['월', '화', '수', '목', '금', '토', '일'].map((day) {
                  return FilterChip(
                    label: Text(day),
                    selected: todo.repeatDays.contains(day),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          todo.repeatDays.add(day);
                        } else {
                          todo.repeatDays.remove(day);
                        }
                        if (todo.repeatDays.isEmpty) {
                          todo.repeatDays.add(day); // 최소 하나의 요일은 선택되도록 함
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('확인'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _updateTodoInFirestore(todo);
                    _generateFutureDates(todo);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  SimpleDialogOption _buildRepeatOptionDialog(String option) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context, option);
      },
      child: Text(option),
    );
  }
}
