import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/college.dart';
import '../models/item.dart';
import '../models/item_college.dart';
import '../models/revision_slot.dart';
import '../models/work_schedule.dart';
import '../models/calendar_event.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('med_planning.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add calendar_events table
      await db.execute('''
        CREATE TABLE calendar_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          event_type TEXT NOT NULL,
          item_college_id INTEGER,
          scheduled_date TEXT NOT NULL,
          scheduled_start_time TEXT NOT NULL,
          scheduled_end_time TEXT NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          completed_date TEXT,
          notes TEXT,
          FOREIGN KEY (item_college_id) REFERENCES item_colleges (id) ON DELETE SET NULL
        )
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    // College table
    await db.execute('''
      CREATE TABLE colleges (
        id $idType,
        name $textType
      )
    ''');

    // Item table
    await db.execute('''
      CREATE TABLE items (
        id $idType,
        item_number $integerType,
        name $textType
      )
    ''');

    // ItemCollege table (relationship between items and colleges)
    await db.execute('''
      CREATE TABLE item_colleges (
        id $idType,
        item_id $integerType,
        college_id $integerType,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE,
        FOREIGN KEY (college_id) REFERENCES colleges (id) ON DELETE CASCADE
      )
    ''');

    // RevisionSlot table
    await db.execute('''
      CREATE TABLE revision_slots (
        id $idType,
        item_college_id $integerType,
        revision_type $textType,
        scheduled_date TEXT NOT NULL,
        scheduled_start_time TEXT NOT NULL,
        scheduled_end_time TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_date TEXT,
        notes TEXT,
        FOREIGN KEY (item_college_id) REFERENCES item_colleges (id) ON DELETE CASCADE
      )
    ''');

    // WorkSchedule table
    await db.execute('''
      CREATE TABLE work_schedules (
        id $idType,
        day_of_week $integerType,
        start_hour $integerType,
        start_minute $integerType,
        end_hour $integerType,
        end_minute $integerType
      )
    ''');

    // CalendarEvent table
    await db.execute('''
      CREATE TABLE calendar_events (
        id $idType,
        name $textType,
        event_type $textType,
        item_college_id INTEGER,
        scheduled_date TEXT NOT NULL,
        scheduled_start_time TEXT NOT NULL,
        scheduled_end_time TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_date TEXT,
        notes TEXT,
        FOREIGN KEY (item_college_id) REFERENCES item_colleges (id) ON DELETE SET NULL
      )
    ''');

    // Create default work schedule (7 days, 14h-22h)
    for (int day = 1; day <= 7; day++) {
      await db.insert('work_schedules', {
        'day_of_week': day,
        'start_hour': 14,
        'start_minute': 0,
        'end_hour': 22,
        'end_minute': 0,
      });
    }
  }

  // College CRUD
  Future<College> createCollege(College college) async {
    final db = await database;
    final id = await db.insert('colleges', college.toMap());
    return college.copyWith(id: id);
  }

  Future<College?> readCollege(int id) async {
    final db = await database;
    final maps = await db.query('colleges', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return College.fromMap(maps.first);
    }
    return null;
  }

  Future<List<College>> readAllColleges() async {
    final db = await database;
    const orderBy = 'name ASC';
    final result = await db.query('colleges', orderBy: orderBy);
    return result.map((json) => College.fromMap(json)).toList();
  }

  Future<int> updateCollege(College college) async {
    final db = await database;
    return db.update(
      'colleges',
      college.toMap(),
      where: 'id = ?',
      whereArgs: [college.id],
    );
  }

  Future<int> deleteCollege(int id) async {
    final db = await database;
    return await db.delete('colleges', where: 'id = ?', whereArgs: [id]);
  }

  // Item CRUD
  Future<Item> createItem(Item item) async {
    final db = await database;
    final id = await db.insert('items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<Item?> readItem(int id) async {
    final db = await database;
    final maps = await db.query('items', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Item.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Item>> readAllItems() async {
    final db = await database;
    const orderBy = 'item_number ASC';
    final result = await db.query('items', orderBy: orderBy);
    return result.map((json) => Item.fromMap(json)).toList();
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    return db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // ItemCollege CRUD
  Future<ItemCollege> createItemCollege(ItemCollege itemCollege) async {
    final db = await database;
    final id = await db.insert('item_colleges', itemCollege.toMap());
    return itemCollege.copyWith(id: id);
  }

  Future<ItemCollege?> readItemCollege(int id) async {
    final db = await database;
    final maps = await db.query(
      'item_colleges',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ItemCollege.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ItemCollege>> readAllItemColleges() async {
    final db = await database;
    final result = await db.query('item_colleges');
    return result.map((json) => ItemCollege.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getItemsWithColleges() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        ic.id as item_college_id,
        i.id as item_id,
        i.item_number,
        i.name as item_name,
        c.id as college_id,
        c.name as college_name
      FROM item_colleges ic
      INNER JOIN items i ON ic.item_id = i.id
      INNER JOIN colleges c ON ic.college_id = c.id
      ORDER BY i.item_number, c.name
    ''');
    return result;
  }

  /// Get items grouped by item_number with all their colleges
  Future<List<Map<String, dynamic>>> getGroupedItems() async {
    final db = await database;

    // First, get all unique items
    final items = await db.rawQuery('''
      SELECT DISTINCT i.id, i.item_number, i.name
      FROM items i
      ORDER BY i.item_number
    ''');

    List<Map<String, dynamic>> groupedItems = [];

    for (final item in items) {
      // Get all colleges for this item
      final colleges = await db.rawQuery(
        '''
        SELECT 
          ic.id as item_college_id,
          c.id as college_id,
          c.name as college_name
        FROM item_colleges ic
        INNER JOIN colleges c ON ic.college_id = c.id
        WHERE ic.item_id = ?
        ORDER BY c.name
      ''',
        [item['id']],
      );

      // Get revision count for this item
      final revisionCount = await _getRevisionCountForItem(item['id'] as int);
      final completedCount = await _getCompletedRevisionCountForItem(
        item['id'] as int,
      );

      groupedItems.add({
        'item_id': item['id'],
        'item_number': item['item_number'],
        'item_name': item['name'],
        'colleges': colleges,
        'college_count': colleges.length,
        'revision_count': revisionCount,
        'completed_count': completedCount,
      });
    }

    return groupedItems;
  }

  Future<int> _getRevisionCountForItem(int itemId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM revision_slots rs
      INNER JOIN item_colleges ic ON rs.item_college_id = ic.id
      WHERE ic.item_id = ?
    ''',
      [itemId],
    );
    return result.first['count'] as int;
  }

  Future<int> _getCompletedRevisionCountForItem(int itemId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM revision_slots rs
      INNER JOIN item_colleges ic ON rs.item_college_id = ic.id
      WHERE ic.item_id = ? AND rs.is_completed = 1
    ''',
      [itemId],
    );
    return result.first['count'] as int;
  }

  /// Search items by number or name
  Future<List<Map<String, dynamic>>> searchItems(
    String query, {
    int? collegeId,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    // Check if query is a number (item number search)
    final itemNumber = int.tryParse(query);
    if (itemNumber != null) {
      whereClause = 'i.item_number = ?';
      whereArgs.add(itemNumber);
    } else if (query.isNotEmpty) {
      whereClause = 'LOWER(i.name) LIKE ?';
      whereArgs.add('%${query.toLowerCase()}%');
    }

    if (collegeId != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'ic.college_id = ?';
      whereArgs.add(collegeId);
    }

    final sqlWhere = whereClause.isNotEmpty ? 'WHERE $whereClause' : '';

    final result = await db.rawQuery('''
      SELECT DISTINCT
        i.id as item_id,
        i.item_number,
        i.name as item_name
      FROM items i
      LEFT JOIN item_colleges ic ON i.id = ic.item_id
      $sqlWhere
      ORDER BY i.item_number
      LIMIT 50
    ''', whereArgs);

    // Now get colleges for each item
    List<Map<String, dynamic>> groupedItems = [];

    for (final item in result) {
      String collegeWhere = 'ic.item_id = ?';
      List<dynamic> collegeArgs = [item['item_id']];

      if (collegeId != null) {
        collegeWhere += ' AND ic.college_id = ?';
        collegeArgs.add(collegeId);
      }

      final colleges = await db.rawQuery('''
        SELECT 
          ic.id as item_college_id,
          c.id as college_id,
          c.name as college_name
        FROM item_colleges ic
        INNER JOIN colleges c ON ic.college_id = c.id
        WHERE $collegeWhere
        ORDER BY c.name
      ''', collegeArgs);

      final revisionCount = await _getRevisionCountForItem(
        item['item_id'] as int,
      );
      final completedCount = await _getCompletedRevisionCountForItem(
        item['item_id'] as int,
      );

      groupedItems.add({
        'item_id': item['item_id'],
        'item_number': item['item_number'],
        'item_name': item['item_name'],
        'colleges': colleges,
        'college_count': colleges.length,
        'revision_count': revisionCount,
        'completed_count': completedCount,
      });
    }

    return groupedItems;
  }

  Future<int> updateItemCollege(ItemCollege itemCollege) async {
    final db = await database;
    return db.update(
      'item_colleges',
      itemCollege.toMap(),
      where: 'id = ?',
      whereArgs: [itemCollege.id],
    );
  }

  Future<int> deleteItemCollege(int id) async {
    final db = await database;
    return await db.delete('item_colleges', where: 'id = ?', whereArgs: [id]);
  }

  // RevisionSlot CRUD
  Future<RevisionSlot> createRevisionSlot(RevisionSlot slot) async {
    final db = await database;
    final id = await db.insert('revision_slots', slot.toMap());
    return slot.copyWith(id: id);
  }

  Future<RevisionSlot?> readRevisionSlot(int id) async {
    final db = await database;
    final maps = await db.query(
      'revision_slots',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return RevisionSlot.fromMap(maps.first);
    }
    return null;
  }

  Future<List<RevisionSlot>> readAllRevisionSlots() async {
    final db = await database;
    const orderBy = 'scheduled_date ASC, scheduled_start_time ASC';
    final result = await db.query('revision_slots', orderBy: orderBy);
    return result.map((json) => RevisionSlot.fromMap(json)).toList();
  }

  Future<List<RevisionSlot>> readRevisionSlotsForDate(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();
    final result = await db.query(
      'revision_slots',
      where: 'scheduled_date LIKE ?',
      whereArgs: ['${dateStr.substring(0, 10)}%'],
      orderBy: 'scheduled_start_time ASC',
    );
    return result.map((json) => RevisionSlot.fromMap(json)).toList();
  }

  Future<List<RevisionSlot>> readUncompletedRevisionSlots() async {
    final db = await database;
    final result = await db.query(
      'revision_slots',
      where: 'is_completed = ?',
      whereArgs: [0],
      orderBy: 'scheduled_date ASC, scheduled_start_time ASC',
    );
    return result.map((json) => RevisionSlot.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getRevisionSlotsWithDetails() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        rs.*,
        i.id as item_id,
        i.item_number,
        i.name as item_name,
        c.name as college_name
      FROM revision_slots rs
      INNER JOIN item_colleges ic ON rs.item_college_id = ic.id
      INNER JOIN items i ON ic.item_id = i.id
      INNER JOIN colleges c ON ic.college_id = c.id
      ORDER BY rs.scheduled_date ASC, rs.scheduled_start_time ASC
    ''');
    return result;
  }

  Future<int> updateRevisionSlot(RevisionSlot slot) async {
    final db = await database;
    return db.update(
      'revision_slots',
      slot.toMap(),
      where: 'id = ?',
      whereArgs: [slot.id],
    );
  }

  Future<int> deleteRevisionSlot(int id) async {
    final db = await database;
    return await db.delete('revision_slots', where: 'id = ?', whereArgs: [id]);
  }

  // Get revision slots in a date range
  Future<List<RevisionSlot>> readRevisionSlotsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final startStr = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).toIso8601String();
    final endStr = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    ).toIso8601String();

    final result = await db.query(
      'revision_slots',
      where: 'scheduled_date >= ? AND scheduled_date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'scheduled_date ASC, scheduled_start_time ASC',
    );
    return result.map((json) => RevisionSlot.fromMap(json)).toList();
  }

  // Get all revision slots for an item-college
  Future<List<RevisionSlot>> readRevisionSlotsForItemCollege(
    int itemCollegeId,
  ) async {
    final db = await database;
    final result = await db.query(
      'revision_slots',
      where: 'item_college_id = ?',
      whereArgs: [itemCollegeId],
      orderBy: 'scheduled_date ASC',
    );
    return result.map((json) => RevisionSlot.fromMap(json)).toList();
  }

  // Delete all non-completed revisions for an item-college
  Future<int> deleteNonCompletedRevisionsForItemCollege(
    int itemCollegeId,
  ) async {
    final db = await database;
    return await db.delete(
      'revision_slots',
      where: 'item_college_id = ? AND is_completed = 0',
      whereArgs: [itemCollegeId],
    );
  }

  // Get revision slots with details in date range
  Future<List<Map<String, dynamic>>> getRevisionSlotsWithDetailsInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final startStr = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).toIso8601String();
    final endStr = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    ).toIso8601String();

    final result = await db.rawQuery(
      '''
      SELECT 
        rs.*,
        i.id as item_id,
        i.item_number,
        i.name as item_name,
        c.name as college_name
      FROM revision_slots rs
      INNER JOIN item_colleges ic ON rs.item_college_id = ic.id
      INNER JOIN items i ON ic.item_id = i.id
      INNER JOIN colleges c ON ic.college_id = c.id
      WHERE rs.scheduled_date >= ? AND rs.scheduled_date <= ?
      ORDER BY rs.scheduled_date ASC, rs.scheduled_start_time ASC
    ''',
      [startStr, endStr],
    );
    return result;
  }

  // Get revision slots for an item with details
  Future<List<Map<String, dynamic>>> getRevisionSlotsForItemWithDetails(
    int itemId,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        rs.*,
        i.id as item_id,
        i.item_number,
        i.name as item_name,
        c.name as college_name,
        c.id as college_id
      FROM revision_slots rs
      INNER JOIN item_colleges ic ON rs.item_college_id = ic.id
      INNER JOIN items i ON ic.item_id = i.id
      INNER JOIN colleges c ON ic.college_id = c.id
      WHERE i.id = ?
      ORDER BY rs.scheduled_date ASC, rs.scheduled_start_time ASC
    ''',
      [itemId],
    );
    return result;
  }

  // Get item details with colleges
  Future<Map<String, dynamic>?> getItemWithColleges(int itemId) async {
    final db = await database;

    final itemResult = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [itemId],
    );

    if (itemResult.isEmpty) return null;

    final item = itemResult.first;

    final colleges = await db.rawQuery(
      '''
      SELECT 
        ic.id as item_college_id,
        c.id as college_id,
        c.name as college_name
      FROM item_colleges ic
      INNER JOIN colleges c ON ic.college_id = c.id
      WHERE ic.item_id = ?
      ORDER BY c.name
    ''',
      [itemId],
    );

    return {
      'item_id': item['id'],
      'item_number': item['item_number'],
      'item_name': item['name'],
      'colleges': colleges,
    };
  }

  // Get conflicting slots for a time range
  Future<List<RevisionSlot>> getConflictingSlots(
    DateTime startTime,
    DateTime endTime,
  ) async {
    final date = DateTime(startTime.year, startTime.month, startTime.day);

    // Get all slots for the day first
    final daySlots = await readRevisionSlotsForDate(date);

    // Filter to find overlapping slots
    return daySlots.where((slot) {
      return startTime.isBefore(slot.scheduledEndTime) &&
          endTime.isAfter(slot.scheduledStartTime);
    }).toList();
  }

  // Update multiple revision slots
  Future<void> updateRevisionSlots(List<RevisionSlot> slots) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final slot in slots) {
        await txn.update(
          'revision_slots',
          slot.toMap(),
          where: 'id = ?',
          whereArgs: [slot.id],
        );
      }
    });
  }

  // Get total scheduled time for a date
  Future<Duration> getTotalScheduledTimeForDate(DateTime date) async {
    final slots = await readRevisionSlotsForDate(date);
    Duration total = Duration.zero;
    for (final slot in slots) {
      if (!slot.isCompleted) {
        total += slot.duration;
      }
    }
    return total;
  }

  // WorkSchedule CRUD
  Future<WorkSchedule> createWorkSchedule(WorkSchedule schedule) async {
    final db = await database;
    final id = await db.insert('work_schedules', schedule.toMap());
    return schedule.copyWith(id: id);
  }

  Future<WorkSchedule?> readWorkSchedule(int id) async {
    final db = await database;
    final maps = await db.query(
      'work_schedules',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return WorkSchedule.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WorkSchedule>> readAllWorkSchedules() async {
    final db = await database;
    const orderBy = 'day_of_week ASC';
    final result = await db.query('work_schedules', orderBy: orderBy);
    return result.map((json) => WorkSchedule.fromMap(json)).toList();
  }

  Future<WorkSchedule?> readWorkScheduleForDay(int dayOfWeek) async {
    final db = await database;
    final maps = await db.query(
      'work_schedules',
      where: 'day_of_week = ?',
      whereArgs: [dayOfWeek],
    );

    if (maps.isNotEmpty) {
      return WorkSchedule.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateWorkSchedule(WorkSchedule schedule) async {
    final db = await database;
    return db.update(
      'work_schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> deleteWorkSchedule(int id) async {
    final db = await database;
    return await db.delete('work_schedules', where: 'id = ?', whereArgs: [id]);
  }

  // CalendarEvent CRUD
  Future<CalendarEvent> createCalendarEvent(CalendarEvent event) async {
    final db = await database;
    final id = await db.insert('calendar_events', event.toMap());
    return event.copyWith(id: id);
  }

  Future<CalendarEvent?> readCalendarEvent(int id) async {
    final db = await database;
    final maps = await db.query(
      'calendar_events',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return CalendarEvent.fromMap(maps.first);
    }
    return null;
  }

  Future<List<CalendarEvent>> readAllCalendarEvents() async {
    final db = await database;
    const orderBy = 'scheduled_date ASC, scheduled_start_time ASC';
    final result = await db.query('calendar_events', orderBy: orderBy);
    return result.map((json) => CalendarEvent.fromMap(json)).toList();
  }

  Future<List<CalendarEvent>> readCalendarEventsForDate(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();
    final result = await db.query(
      'calendar_events',
      where: 'scheduled_date LIKE ?',
      whereArgs: ['${dateStr.substring(0, 10)}%'],
      orderBy: 'scheduled_start_time ASC',
    );
    return result.map((json) => CalendarEvent.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getCalendarEventsWithDetails() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        ce.*,
        i.id as item_id,
        i.item_number,
        i.name as item_name,
        c.name as college_name
      FROM calendar_events ce
      LEFT JOIN item_colleges ic ON ce.item_college_id = ic.id
      LEFT JOIN items i ON ic.item_id = i.id
      LEFT JOIN colleges c ON ic.college_id = c.id
      ORDER BY ce.scheduled_date ASC, ce.scheduled_start_time ASC
    ''');
    return result;
  }

  Future<List<Map<String, dynamic>>> getCalendarEventsWithDetailsForDate(
    DateTime date,
  ) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT 
        ce.*,
        i.id as item_id,
        i.item_number,
        i.name as item_name,
        c.name as college_name
      FROM calendar_events ce
      LEFT JOIN item_colleges ic ON ce.item_college_id = ic.id
      LEFT JOIN items i ON ic.item_id = i.id
      LEFT JOIN colleges c ON ic.college_id = c.id
      WHERE ce.scheduled_date LIKE ?
      ORDER BY ce.scheduled_start_time ASC
    ''',
      ['${dateStr.substring(0, 10)}%'],
    );
    return result;
  }

  Future<int> updateCalendarEvent(CalendarEvent event) async {
    final db = await database;
    return db.update(
      'calendar_events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteCalendarEvent(int id) async {
    final db = await database;
    return await db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
  }

  // CSV Import
  Future<void> importFromCSV(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Parse CSV
        final csvData = utf8.decode(response.bodyBytes);
        final List<List<dynamic>> rows = const CsvToListConverter().convert(
          csvData,
        );

        // Skip header row
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty) continue;

          final itemNumber = int.tryParse(row[0].toString()) ?? 0;
          final itemName = row[1].toString();

          // Create item
          Item item = Item(itemNumber: itemNumber, name: itemName);
          item = await createItem(item);

          // Create colleges and relationships
          for (int j = 2; j < row.length && j < 6; j++) {
            final collegeName = row[j].toString().trim();
            if (collegeName.isEmpty) continue;

            // Check if college exists
            final colleges = await readAllColleges();
            College? college = colleges.firstWhere(
              (c) => c.name == collegeName,
              orElse: () => College(name: ''),
            );

            if (college.id == null) {
              college = await createCollege(College(name: collegeName));
            }

            // Create item-college relationship
            await createItemCollege(
              ItemCollege(itemId: item.id!, collegeId: college.id!),
            );
          }
        }
      }
    } catch (e) {
      print('Error importing CSV: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDatabaseBackup() async {
    final db = await database;
    final Map<String, dynamic> backup = {};

    final tables = [
      'colleges',
      'items',
      'item_colleges',
      'revision_slots',
      'work_schedules',
      'calendar_events',
    ];

    for (final table in tables) {
      final data = await db.query(table);
      backup[table] = data;
    }

    return backup;
  }

  Future<void> restoreDatabaseBackup(Map<String, dynamic> backup) async {
    final db = await database;

    await db.transaction((txn) async {
      // Order is important for foreign keys
      final tablesToClear = [
        'calendar_events',
        'revision_slots',
        'item_colleges',
        'items',
        'colleges',
        'work_schedules',
      ];

      for (final table in tablesToClear) {
        await txn.delete(table);
      }

      // Restore data - handle dependencies implicitly by checking backup keys
      final tablesToRestore = [
        'colleges',
        'items',
        'work_schedules',
        'item_colleges',
        'revision_slots',
        'calendar_events',
      ];

      for (final table in tablesToRestore) {
        if (backup.containsKey(table)) {
          final List<dynamic> rows = backup[table];
          for (final row in rows) {
            await txn.insert(table, row);
          }
        }
      }
    });
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
