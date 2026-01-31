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
import '../models/difficulty.dart';
import '../models/difficulty_config.dart';

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
      version: 1,
      onCreate: _createDB,
    );
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

    // ItemCollege table (relationship between items and colleges with user data)
    await db.execute('''
      CREATE TABLE item_colleges (
        id $idType,
        item_id $integerType,
        college_id $integerType,
        difficulty $textType,
        first_seen_date TEXT,
        needs_group_revision INTEGER NOT NULL DEFAULT 0,
        group_revision_date TEXT,
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

    // DifficultyConfig table
    await db.execute('''
      CREATE TABLE difficulty_configs (
        id $idType,
        difficulty $textType UNIQUE,
        first_seen_duration_minutes $integerType
      )
    ''');

    // RevisionSlotConfig table
    await db.execute('''
      CREATE TABLE revision_slot_configs (
        id $idType,
        difficulty_config_id $integerType,
        slot_order $integerType,
        days_after_first_seen $integerType,
        duration_minutes $integerType,
        FOREIGN KEY (difficulty_config_id) REFERENCES difficulty_configs (id) ON DELETE CASCADE
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

    // Create default difficulty configurations
    await _createDefaultDifficultyConfigs(db);
  }

  Future<void> _createDefaultDifficultyConfigs(Database db) async {
    for (final difficulty in Difficulty.values) {
      final defaultConfig = DifficultyConfig.getDefault(difficulty);
      final configId = await db.insert('difficulty_configs', defaultConfig.toMap());
      
      final defaultSlots = DifficultyConfig.getDefaultRevisionSlots(configId, difficulty);
      for (final slot in defaultSlots) {
        await db.insert('revision_slot_configs', slot.copyWith(difficultyConfigId: configId).toMap());
      }
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
    final maps = await db.query(
      'colleges',
      where: 'id = ?',
      whereArgs: [id],
    );

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
    return await db.delete(
      'colleges',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Item CRUD
  Future<Item> createItem(Item item) async {
    final db = await database;
    final id = await db.insert('items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<Item?> readItem(int id) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );

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
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
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
        c.name as college_name,
        ic.difficulty,
        ic.first_seen_date,
        ic.needs_group_revision,
        ic.group_revision_date
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
      final colleges = await db.rawQuery('''
        SELECT 
          ic.id as item_college_id,
          c.id as college_id,
          c.name as college_name,
          ic.difficulty,
          ic.first_seen_date,
          ic.needs_group_revision,
          ic.group_revision_date
        FROM item_colleges ic
        INNER JOIN colleges c ON ic.college_id = c.id
        WHERE ic.item_id = ?
        ORDER BY c.name
      ''', [item['id']]);
      
      // Check if any college has been seen
      final hasSeenAny = colleges.any((c) => c['first_seen_date'] != null);
      final allSeen = colleges.isNotEmpty && colleges.every((c) => c['first_seen_date'] != null);
      final seenCount = colleges.where((c) => c['first_seen_date'] != null).length;
      
      groupedItems.add({
        'item_id': item['id'],
        'item_number': item['item_number'],
        'item_name': item['name'],
        'colleges': colleges,
        'college_count': colleges.length,
        'seen_count': seenCount,
        'has_seen_any': hasSeenAny,
        'all_seen': allSeen,
      });
    }
    
    return groupedItems;
  }

  /// Search items by number or name
  Future<List<Map<String, dynamic>>> searchItems(String query, {int? collegeId}) async {
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
          c.name as college_name,
          ic.difficulty,
          ic.first_seen_date,
          ic.needs_group_revision,
          ic.group_revision_date
        FROM item_colleges ic
        INNER JOIN colleges c ON ic.college_id = c.id
        WHERE $collegeWhere
        ORDER BY c.name
      ''', collegeArgs);
      
      final hasSeenAny = colleges.any((c) => c['first_seen_date'] != null);
      final allSeen = colleges.isNotEmpty && colleges.every((c) => c['first_seen_date'] != null);
      final seenCount = colleges.where((c) => c['first_seen_date'] != null).length;
      
      groupedItems.add({
        'item_id': item['item_id'],
        'item_number': item['item_number'],
        'item_name': item['item_name'],
        'colleges': colleges,
        'college_count': colleges.length,
        'seen_count': seenCount,
        'has_seen_any': hasSeenAny,
        'all_seen': allSeen,
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
    return await db.delete(
      'item_colleges',
      where: 'id = ?',
      whereArgs: [id],
    );
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
        i.item_number,
        i.name as item_name,
        c.name as college_name,
        ic.difficulty
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
    return await db.delete(
      'revision_slots',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get revision slots in a date range
  Future<List<RevisionSlot>> readRevisionSlotsInRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startStr = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final endStr = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String();
    
    final result = await db.query(
      'revision_slots',
      where: 'scheduled_date >= ? AND scheduled_date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'scheduled_date ASC, scheduled_start_time ASC',
    );
    return result.map((json) => RevisionSlot.fromMap(json)).toList();
  }

  // Get all revision slots for an item-college
  Future<List<RevisionSlot>> readRevisionSlotsForItemCollege(int itemCollegeId) async {
    final db = await database;
    final result = await db.query(
      'revision_slots',
      where: 'item_college_id = ?',
      whereArgs: [itemCollegeId],
      orderBy: 'scheduled_date ASC',
    );
    return result.map((json) => RevisionSlot.fromMap(json)).toList();
  }

  // Delete all non-completed revisions for an item-college (except first seen)
  Future<int> deleteNonCompletedRevisionsForItemCollege(int itemCollegeId) async {
    final db = await database;
    return await db.delete(
      'revision_slots',
      where: 'item_college_id = ? AND is_completed = 0 AND revision_type != ?',
      whereArgs: [itemCollegeId, RevisionType.firstSeen.name],
    );
  }

  // Get revision slots with details in date range (with first seen info for priority)
  Future<List<Map<String, dynamic>>> getRevisionSlotsWithDetailsInRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startStr = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final endStr = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT 
        rs.*,
        i.item_number,
        i.name as item_name,
        c.name as college_name,
        ic.difficulty,
        ic.first_seen_date
      FROM revision_slots rs
      INNER JOIN item_colleges ic ON rs.item_college_id = ic.id
      INNER JOIN items i ON ic.item_id = i.id
      INNER JOIN colleges c ON ic.college_id = c.id
      WHERE rs.scheduled_date >= ? AND rs.scheduled_date <= ?
      ORDER BY rs.scheduled_date ASC, rs.scheduled_start_time ASC
    ''', [startStr, endStr]);
    return result;
  }

  // Get conflicting slots for a time range
  Future<List<RevisionSlot>> getConflictingSlots(DateTime startTime, DateTime endTime) async {
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
    return await db.delete(
      'work_schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CSV Import
  Future<void> importFromCSV(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Parse CSV
        final csvData = utf8.decode(response.bodyBytes);
        final List<List<dynamic>> rows = const CsvToListConverter().convert(csvData);

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
            await createItemCollege(ItemCollege(
              itemId: item.id!,
              collegeId: college.id!,
              difficulty: Difficulty.medium,
            ));
          }
        }
      }
    } catch (e) {
      print('Error importing CSV: $e');
      rethrow;
    }
  }

  // DifficultyConfig CRUD
  Future<DifficultyConfig?> readDifficultyConfig(Difficulty difficulty) async {
    final db = await database;
    final maps = await db.query(
      'difficulty_configs',
      where: 'difficulty = ?',
      whereArgs: [difficulty.name],
    );

    if (maps.isNotEmpty) {
      final configId = maps.first['id'] as int;
      final slots = await readRevisionSlotConfigsForDifficulty(configId);
      return DifficultyConfig.fromMap(maps.first, slots);
    }
    return null;
  }

  Future<List<DifficultyConfig>> readAllDifficultyConfigs() async {
    final db = await database;
    final result = await db.query('difficulty_configs');
    
    final List<DifficultyConfig> configs = [];
    for (final map in result) {
      final configId = map['id'] as int;
      final slots = await readRevisionSlotConfigsForDifficulty(configId);
      configs.add(DifficultyConfig.fromMap(map, slots));
    }
    return configs;
  }

  Future<int> updateDifficultyConfig(DifficultyConfig config) async {
    final db = await database;
    return db.update(
      'difficulty_configs',
      config.toMap(),
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  // RevisionSlotConfig CRUD
  Future<List<RevisionSlotConfig>> readRevisionSlotConfigsForDifficulty(int difficultyConfigId) async {
    final db = await database;
    final result = await db.query(
      'revision_slot_configs',
      where: 'difficulty_config_id = ?',
      whereArgs: [difficultyConfigId],
      orderBy: 'slot_order ASC',
    );
    return result.map((json) => RevisionSlotConfig.fromMap(json)).toList();
  }

  Future<RevisionSlotConfig> createRevisionSlotConfig(RevisionSlotConfig slot) async {
    final db = await database;
    final id = await db.insert('revision_slot_configs', slot.toMap());
    return slot.copyWith(id: id);
  }

  Future<int> updateRevisionSlotConfig(RevisionSlotConfig slot) async {
    final db = await database;
    return db.update(
      'revision_slot_configs',
      slot.toMap(),
      where: 'id = ?',
      whereArgs: [slot.id],
    );
  }

  Future<int> deleteRevisionSlotConfig(int id) async {
    final db = await database;
    return await db.delete(
      'revision_slot_configs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllRevisionSlotConfigsForDifficulty(int difficultyConfigId) async {
    final db = await database;
    await db.delete(
      'revision_slot_configs',
      where: 'difficulty_config_id = ?',
      whereArgs: [difficultyConfigId],
    );
  }

  Future<void> updateDifficultyConfigWithSlots(DifficultyConfig config, List<RevisionSlotConfig> slots) async {
    final db = await database;
    await db.transaction((txn) async {
      // Update the main config
      await txn.update(
        'difficulty_configs',
        config.toMap(),
        where: 'id = ?',
        whereArgs: [config.id],
      );

      // Delete existing slots
      await txn.delete(
        'revision_slot_configs',
        where: 'difficulty_config_id = ?',
        whereArgs: [config.id],
      );

      // Insert new slots
      for (int i = 0; i < slots.length; i++) {
        final slot = slots[i].copyWith(
          difficultyConfigId: config.id,
          order: i + 1,
        );
        await txn.insert('revision_slot_configs', slot.toMap());
      }
    });
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
      'difficulty_configs',
      'revision_slot_configs'
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
        'revision_slots',
        'revision_slot_configs',
        'item_colleges',
        'items',
        'colleges',
        'difficulty_configs',
        'work_schedules'
      ];

      for (final table in tablesToClear) {
        await txn.delete(table);
      }

      // Restore data - handle dependencies implicitly by checking backup keys
      // Ideally we insert independent tables first
      final tablesToRestore = [
        'colleges',
        'items',
        'work_schedules',
        'difficulty_configs',
        'item_colleges', // Depends on items, colleges
        'revision_slot_configs', // Depends on difficulty_configs
        'revision_slots' // Depends on item_colleges
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
