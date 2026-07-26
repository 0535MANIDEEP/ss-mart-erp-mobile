import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';

/// Page for managing employee shift schedules.
///
/// Allows managers to view, create, and edit shift assignments
/// for employees on specific dates.
class ShiftSchedulePage extends StatefulWidget {
  const ShiftSchedulePage({super.key});

  @override
  State<ShiftSchedulePage> createState() => _ShiftSchedulePageState();
}

class _ShiftSchedulePageState extends State<ShiftSchedulePage> {
  List<Employee> _employees = [];
  List<Shift> _shifts = [];
  List<ShiftSchedule> _schedules = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = GetIt.instance<AppDatabase>();
    final employees = await (db.select(db.employees)..where((t) => t.isActive.equals(true))).get();
    final shifts = await db.select(db.shifts).get();
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
    final schedules = await (db.select(db.shiftSchedules)
      ..where((t) => t.scheduleDate.isBetweenValues(startOfDay, endOfDay))).get();
    setState(() {
      _employees = employees;
      _shifts = shifts;
      _schedules = schedules;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Schedule'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context, initialDate: _selectedDate,
                firstDate: DateTime(2020), lastDate: DateTime(2030),
              );
              if (picked != null) setState(() { _selectedDate = picked; _loadData(); });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAssignShiftDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_shifts.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No shifts configured'),
                          Text('Create shifts in Settings first', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _employees.length,
                      itemBuilder: (context, index) {
                        final employee = _employees[index];
                        final schedule = _schedules.where((s) => s.employeeId == employee.id).firstOrNull;
                        final shift = schedule != null
                            ? _shifts.where((s) => s.id == schedule.shiftId).firstOrNull
                            : null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(employee.name[0].toUpperCase())),
                            title: Text(employee.name),
                            subtitle: Text(shift != null
                                ? '${shift.name} (${shift.startTime} - ${shift.endTime})'
                                : 'No shift assigned'),
                            trailing: IconButton(
                              icon: Icon(
                                schedule != null ? Icons.edit : Icons.add_circle_outline,
                                color: schedule != null ? Colors.blue : Colors.grey,
                              ),
                              onPressed: () => _showAssignShiftDialog(employee: employee, existingSchedule: schedule),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  void _showAssignShiftDialog({Employee? employee, ShiftSchedule? existingSchedule}) {
    String? selectedEmployeeId = employee?.id;
    String? selectedShiftId = existingSchedule?.shiftId;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (employee == null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Employee'),
                value: selectedEmployeeId,
                items: _employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                onChanged: (v) => selectedEmployeeId = v,
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Shift'),
              value: selectedShiftId,
              items: _shifts.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.startTime}-${s.endTime})'))).toList(),
              onChanged: (v) => selectedShiftId = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (selectedEmployeeId == null || selectedShiftId == null) return;
              final db = GetIt.instance<AppDatabase>();
              final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
              if (existingSchedule != null) {
                await (db.update(db.shiftSchedules)..where((t) => t.id.equals(existingSchedule.id)))
                    .write(ShiftSchedulesCompanion(
                      shiftId: Value(selectedShiftId!),
                      updatedAt: Value(DateTime.now()),
                      syncStatus: const Value('pending'),
                    ));
              } else {
                await db.into(db.shiftSchedules).insert(ShiftSchedulesCompanion.insert(
                  id: const Uuid().v4(),
                  employeeId: selectedEmployeeId!,
                  shiftId: selectedShiftId!,
                  scheduleDate: startOfDay,
                  isActive: const Value(true),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  version: const Value(1),
                  syncStatus: const Value('pending'),
                ));
              }
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
