import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Types of wallet operations that can be tracked
enum OperationType {
  send,
  receiveBolt12,
  receiveOnchain,
  receiveBolt11,
}

/// Status of an operation through its lifecycle
enum OperationStatus {
  pending,    // Created but not started
  preparing,  // Calling prepare*() on SDK
  executing,  // Calling send/receive on SDK
  completed,  // Successfully finished
  failed,     // Failed with error
  unknown,    // Interrupted - need to check SDK
}

/// Represents the state of an in-flight operation
class OperationState {
  final String id;
  final OperationType type;
  final String? destination;
  final int? amountSat;
  final OperationStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? error;
  final String? txId;
  final Map<String, dynamic>? metadata;

  OperationState({
    required this.id,
    required this.type,
    this.destination,
    this.amountSat,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.error,
    this.txId,
    this.metadata,
  });

  OperationState copyWith({
    OperationStatus? status,
    DateTime? completedAt,
    String? error,
    String? txId,
    Map<String, dynamic>? metadata,
  }) {
    return OperationState(
      id: id,
      type: type,
      destination: destination,
      amountSat: amountSat,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
      txId: txId ?? this.txId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'destination': destination,
    'amountSat': amountSat,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'error': error,
    'txId': txId,
    'metadata': metadata,
  };

  factory OperationState.fromJson(Map<String, dynamic> json) {
    return OperationState(
      id: json['id'] as String,
      type: OperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OperationType.send,
      ),
      destination: json['destination'] as String?,
      amountSat: json['amountSat'] as int?,
      status: OperationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OperationStatus.unknown,
      ),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      error: json['error'] as String?,
      txId: json['txId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  bool get isIncomplete =>
      status == OperationStatus.pending ||
      status == OperationStatus.preparing ||
      status == OperationStatus.executing ||
      status == OperationStatus.unknown;

  bool get isComplete => status == OperationStatus.completed;
  bool get isFailed => status == OperationStatus.failed;

  bool get isSend => type == OperationType.send;
  bool get isReceive =>
      type == OperationType.receiveBolt12 ||
      type == OperationType.receiveOnchain ||
      type == OperationType.receiveBolt11;

  @override
  String toString() =>
      'OperationState(id: $id, type: ${type.name}, status: ${status.name})';
}

/// Service for persisting operation state to survive app crashes
class OperationStateService {
  static const String _fileName = 'operation_state.json';
  File? _stateFile;
  List<OperationState> _operations = [];

  /// Initialize the service and load existing state
  Future<void> initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    _stateFile = File('${directory.path}/$_fileName');

    if (await _stateFile!.exists()) {
      await _loadState();
    }
  }

  /// Generate a unique operation ID
  String generateOperationId() {
    final now = DateTime.now();
    final random = now.microsecondsSinceEpoch.toRadixString(36);
    return '${now.millisecondsSinceEpoch.toRadixString(36)}_$random';
  }

  /// Create a new operation and persist it
  Future<OperationState> createOperation({
    required OperationType type,
    String? destination,
    int? amountSat,
    Map<String, dynamic>? metadata,
  }) async {
    final operation = OperationState(
      id: generateOperationId(),
      type: type,
      destination: destination,
      amountSat: amountSat,
      status: OperationStatus.pending,
      startedAt: DateTime.now(),
      metadata: metadata,
    );

    _operations.add(operation);
    await _saveState();

    debugPrint('Operation created: ${operation.id} (${type.name})');
    return operation;
  }

  /// Update operation status to preparing (calling SDK prepare method)
  Future<void> markPreparing(String operationId) async {
    await _updateStatus(operationId, OperationStatus.preparing);
  }

  /// Update operation status to executing (calling SDK send/receive method)
  Future<void> markExecuting(String operationId) async {
    await _updateStatus(operationId, OperationStatus.executing);
  }

  /// Mark operation as successfully completed
  Future<void> markCompleted(String operationId, {String? txId}) async {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _operations[index] = _operations[index].copyWith(
        status: OperationStatus.completed,
        completedAt: DateTime.now(),
        txId: txId,
      );
      await _saveState();
      debugPrint('Operation completed: $operationId');
    }
  }

  /// Mark operation as failed
  Future<void> markFailed(String operationId, String error) async {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _operations[index] = _operations[index].copyWith(
        status: OperationStatus.failed,
        completedAt: DateTime.now(),
        error: error,
      );
      await _saveState();
      debugPrint('Operation failed: $operationId - $error');
    }
  }

  /// Mark operation as unknown (interrupted, need to check)
  Future<void> markUnknown(String operationId) async {
    await _updateStatus(operationId, OperationStatus.unknown);
  }

  /// Get all incomplete operations (for resume on app start)
  List<OperationState> getIncompleteOperations() {
    return _operations.where((op) => op.isIncomplete).toList();
  }

  /// Get incomplete send operations specifically (highest risk)
  List<OperationState> getIncompleteSends() {
    return _operations
        .where((op) => op.isIncomplete && op.isSend)
        .toList();
  }

  /// Get operation by ID
  OperationState? getOperation(String operationId) {
    try {
      return _operations.firstWhere((op) => op.id == operationId);
    } catch (_) {
      return null;
    }
  }

  /// Get all operations (for history/debugging)
  List<OperationState> getAllOperations() => List.unmodifiable(_operations);

  /// Clear completed operations older than specified duration
  Future<void> cleanupOldOperations({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    _operations.removeWhere((op) =>
        !op.isIncomplete && op.completedAt != null && op.completedAt!.isBefore(cutoff));
    await _saveState();
  }

  /// Remove a specific operation (after user acknowledges)
  Future<void> removeOperation(String operationId) async {
    _operations.removeWhere((op) => op.id == operationId);
    await _saveState();
  }

  /// Clear all operations (for testing/reset)
  Future<void> clearAll() async {
    _operations.clear();
    await _saveState();
  }

  Future<void> _updateStatus(String operationId, OperationStatus status) async {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _operations[index] = _operations[index].copyWith(status: status);
      await _saveState();
      debugPrint('Operation $operationId -> ${status.name}');
    }
  }

  Future<void> _loadState() async {
    try {
      final content = await _stateFile!.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      _operations = jsonList
          .map((e) => OperationState.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('Loaded ${_operations.length} operations from disk');
    } catch (e) {
      debugPrint('Failed to load operation state: $e');
      _operations = [];
    }
  }

  Future<void> _saveState() async {
    if (_stateFile == null) return;

    try {
      final jsonList = _operations.map((op) => op.toJson()).toList();
      await _stateFile!.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Failed to save operation state: $e');
    }
  }
}
