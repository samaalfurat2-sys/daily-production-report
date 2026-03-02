import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'graph_client.dart';

/// OneDrive-as-Database service
/// Stores all app data as JSON files in OneDrive ProductionReports/db/ folder
class OneDriveDb {
  final GraphClient graph;
  
  static const _folder = 'ProductionReports/db';
  static const _usersFile = '\$_folder/users.json';
  static const _shiftsFile = '\$_folder/shifts.json';
  static const _inventoryFile = '\$_folder/inventory.json';
  static const _configFile = '\$_folder/config.json';
  
  OneDriveDb(this.graph);
  
  /// Initialize database files with default data if they don't exist
  Future<void> initialize() async {
    try {
      await graph.readJsonFile(_usersFile);
    } catch (e) {
      // Users file doesn't exist, create with default users
      await graph.writeJsonFile(_usersFile, _getDefaultUsers());
    }
    
    try {
      await graph.readJsonFile(_shiftsFile);
    } catch (e) {
      await graph.writeJsonFile(_shiftsFile, []);
    }
    
    try {
      await graph.readJsonFile(_inventoryFile);
    } catch (e) {
      await graph.writeJsonFile(_inventoryFile, _getDefaultInventory());
    }
    
    try {
      await graph.readJsonFile(_configFile);
    } catch (e) {
      await graph.writeJsonFile(_configFile, {
        'shift_order': ['A', 'B', 'C'],
        'app_version': '2.2.0',
      });
    }
  }
  
  List<Map<String, dynamic>> _getDefaultUsers() {
    return [
      {
        'id': 1,
        'username': 'admin',
        'password_hash': _hashPassword('Admin1234'),
        'roles': ['admin'],
        'unit_permissions': {},
        'preferred_locale': 'en',
      },
      {
        'id': 2,
        'username': 'supervisor',
        'password_hash': _hashPassword('Supervisor123'),
        'roles': ['supervisor', 'warehouse_supervisor'],
        'unit_permissions': {},
        'preferred_locale': 'en',
      },
      {
        'id': 3,
        'username': 'operator',
        'password_hash': _hashPassword('Operator123'),
        'roles': ['operator'],
        'unit_permissions': {
          'blow': true,
          'filling': true,
          'label': true,
          'shrink': true,
          'diesel': true,
        },
        'preferred_locale': 'en',
      },
      {
        'id': 4,
        'username': 'viewer',
        'password_hash': _hashPassword('Viewer123'),
        'roles': ['viewer'],
        'unit_permissions': {},
        'preferred_locale': 'en',
      },
    ];
  }
  
  Map<String, dynamic> _getDefaultInventory() {
    return {
      'warehouses': [
        {'code': 'RAW', 'name': 'Raw Materials'},
        {'code': 'FG', 'name': 'Finished Goods'},
      ],
      'items': [
        {'code': 'PREFORM', 'name': 'Preforms', 'warehouse_code': 'RAW', 'stock': 0.0},
        {'code': 'CAP', 'name': 'Caps', 'warehouse_code': 'RAW', 'stock': 0.0},
        {'code': 'LABEL', 'name': 'Labels', 'warehouse_code': 'RAW', 'stock': 0.0},
        {'code': 'SHRINK', 'name': 'Shrink Film', 'warehouse_code': 'RAW', 'stock': 0.0},
        {'code': 'WATER', 'name': 'Bottled Water', 'warehouse_code': 'FG', 'stock': 0.0},
      ],
      'transactions': [],
    };
  }
  
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // ===== USER OPERATIONS =====
  
  /// Login - verify username and password against users.json
  /// Returns user data with roles and permissions
  Future<Map<String, dynamic>> login(String username, String password) async {
    final users = await graph.readJsonFile(_usersFile) as List<dynamic>;
    final passwordHash = _hashPassword(password);
    
    for (final user in users) {
      final userMap = user as Map<String, dynamic>;
      if (userMap['username'] == username && userMap['password_hash'] == passwordHash) {
        return userMap;
      }
    }
    
    throw Exception('Invalid username or password');
  }
  
  /// Get user info by username (for /me equivalent)
  Future<Map<String, dynamic>> getMe(String username) async {
    final users = await graph.readJsonFile(_usersFile) as List<dynamic>;
    
    for (final user in users) {
      final userMap = user as Map<String, dynamic>;
      if (userMap['username'] == username) {
        return userMap;
      }
    }
    
    throw Exception('User not found');
  }
  
  // ===== SHIFT OPERATIONS =====
  
  /// Get shifts with optional filtering
  Future<List<dynamic>> getShifts({String? status, int limit = 100}) async {
    final shifts = await graph.readJsonFile(_shiftsFile) as List<dynamic>;
    
    var filtered = shifts;
    if (status != null) {
      filtered = shifts.where((s) => (s as Map)['status'] == status).toList();
    }
    
    // Sort by report_date descending
    filtered.sort((a, b) {
      final dateA = (a as Map)['report_date'] as String? ?? '';
      final dateB = (b as Map)['report_date'] as String? ?? '';
      return dateB.compareTo(dateA);
    });
    
    return filtered.take(limit).toList();
  }
  
  /// Get single shift by ID
  Future<Map<String, dynamic>> getShift(String id) async {
    final shifts = await graph.readJsonFile(_shiftsFile) as List<dynamic>;
    
    for (final shift in shifts) {
      if ((shift as Map)['id'] == id) {
        return shift as Map<String, dynamic>;
      }
    }
    
    throw Exception('Shift not found: \$id');
  }
  
  /// Create new shift
  Future<Map<String, dynamic>> createShift({
    required String reportDate,
    required String shiftCode,
    required String createdBy,
  }) async {
    final shifts = await graph.readJsonFile(_shiftsFile) as List<dynamic>;
    
    final newShift = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'report_date': reportDate,
      'shift_code': shiftCode,
      'status': 'open',
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
      'blow': null,
      'filling': null,
      'label': null,
      'shrink': null,
      'diesel': null,
    };
    
    shifts.add(newShift);
    await graph.writeJsonFile(_shiftsFile, shifts);
    
    return newShift;
  }
  
  /// Update a unit (blow, filling, label, shrink, diesel) in a shift
  Future<Map<String, dynamic>> updateUnit(
    String shiftId,
    String unitPath,
    Map<String, dynamic> payload,
  ) async {
    final shifts = await graph.readJsonFile(_shiftsFile) as List<dynamic>;
    
    for (var i = 0; i < shifts.length; i++) {
      final shift = shifts[i] as Map<String, dynamic>;
      if (shift['id'] == shiftId) {
        shift[unitPath] = payload;
        await graph.writeJsonFile(_shiftsFile, shifts);
        return shift;
      }
    }
    
    throw Exception('Shift not found: \$shiftId');
  }
  
  /// Submit shift (change status to submitted)
  Future<Map<String, dynamic>> submitShift(String shiftId) async {
    return await _updateShiftStatus(shiftId, 'submitted');
  }
  
  /// Approve shift (change status to approved)
  Future<Map<String, dynamic>> approveShift(String shiftId) async {
    return await _updateShiftStatus(shiftId, 'approved');
  }
  
  /// Lock shift (change status to locked)
  Future<Map<String, dynamic>> lockShift(String shiftId) async {
    return await _updateShiftStatus(shiftId, 'locked');
  }
  
  Future<Map<String, dynamic>> _updateShiftStatus(String shiftId, String newStatus) async {
    final shifts = await graph.readJsonFile(_shiftsFile) as List<dynamic>;
    
    for (var i = 0; i < shifts.length; i++) {
      final shift = shifts[i] as Map<String, dynamic>;
      if (shift['id'] == shiftId) {
        shift['status'] = newStatus;
        await graph.writeJsonFile(_shiftsFile, shifts);
        return shift;
      }
    }
    
    throw Exception('Shift not found: \$shiftId');
  }
  
  /// Get pending approvals (submitted shifts)
  Future<List<dynamic>> getPendingApprovals() async {
    return await getShifts(status: 'submitted');
  }
  
  // ===== INVENTORY OPERATIONS =====
  
  /// List all warehouses
  Future<List<dynamic>> listWarehouses() async {
    final inventory = await graph.readJsonFile(_inventoryFile) as Map<String, dynamic>;
    return inventory['warehouses'] as List<dynamic>;
  }
  
  /// List all items
  Future<List<dynamic>> listItems() async {
    final inventory = await graph.readJsonFile(_inventoryFile) as Map<String, dynamic>;
    return inventory['items'] as List<dynamic>;
  }
  
  /// Create inventory transaction
  Future<Map<String, dynamic>> createTransaction({
    required String warehouseCode,
    required String itemCode,
    required String txnType,
    required double qty,
    required String txnDate,
    String? note,
  }) async {
    final inventory = await graph.readJsonFile(_inventoryFile) as Map<String, dynamic>;
    final transactions = inventory['transactions'] as List<dynamic>;
    
    final newTxn = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'warehouse_code': warehouseCode,
      'item_code': itemCode,
      'txn_type': txnType,
      'qty': qty,
      'txn_date': txnDate,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    transactions.add(newTxn);
    
    // Update stock
    final items = inventory['items'] as List<dynamic>;
    for (var i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      if (item['code'] == itemCode) {
        final currentStock = (item['stock'] as num?)?.toDouble() ?? 0.0;
        if (txnType == 'in') {
          item['stock'] = currentStock + qty;
        } else if (txnType == 'out') {
          item['stock'] = currentStock - qty;
        }
        break;
      }
    }
    
    await graph.writeJsonFile(_inventoryFile, inventory);
    return newTxn;
  }
  
  // ===== DASHBOARD STATS =====
  
  /// Get dashboard statistics
  Future<Map<String, dynamic>> getStats() async {
    final shifts = await graph.readJsonFile(_shiftsFile) as List<dynamic>;
    
    final totalShifts = shifts.length;
    final openShifts = shifts.where((s) => (s as Map)['status'] == 'open').length;
    final submittedShifts = shifts.where((s) => (s as Map)['status'] == 'submitted').length;
    final approvedShifts = shifts.where((s) => (s as Map)['status'] == 'approved').length;
    
    return {
      'total_shifts': totalShifts,
      'open_shifts': openShifts,
      'submitted_shifts': submittedShifts,
      'approved_shifts': approvedShifts,
    };
  }
}
