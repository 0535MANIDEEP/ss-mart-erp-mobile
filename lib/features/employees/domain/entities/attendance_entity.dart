import 'package:equatable/equatable.dart';

/// Domain entity representing a single attendance record for an employee.
///
/// Attendance records track daily clock-in/clock-out events for workforce
/// management and payroll calculation. Each record is unique per employee
/// per day (one [Attendance] instance per [attendanceDate] per [employeeId]).
///
/// The [status] field can be: 'present', 'absent', 'late', or 'on_leave'.
/// 'late' status is determined by comparing [clockIn] against the store's
/// configured shift start time.
class Attendance extends Equatable {
  /// Unique identifier for this attendance record (UUID format).
  final String id;

  /// Foreign key to the [Employee] this record belongs to.
  final String employeeId;

  /// The calendar date this attendance record covers (time component ignored).
  final DateTime attendanceDate;

  /// Timestamp when the employee clocked in for the day.
  /// Null if the employee hasn't clocked in yet (e.g., future-dated leave).
  final DateTime? clockIn;

  /// Timestamp when the employee clocked out at end of shift.
  /// Null if the employee is still clocked in or hasn't clocked in yet.
  final DateTime? clockOut;

  /// Attendance status for the day: 'present', 'absent', 'late', or 'on_leave'.
  final String status;

  /// Free-form notes — typically used for late reasons, half-day notes, etc.
  final String? notes;

  const Attendance({
    required this.id,
    required this.employeeId,
    required this.attendanceDate,
    this.clockIn,
    this.clockOut,
    this.status = 'present',
    this.notes,
  });

  /// Returns true if the employee's status is 'present' (on time).
  bool get isPresent => status == 'present';

  /// Returns true if the employee was marked absent for the day.
  bool get isAbsent => status == 'absent';

  /// Returns true if the employee clocked in after the scheduled shift start.
  bool get isLate => status == 'late';

  /// Returns true if the employee is on approved leave for the day.
  bool get isOnLeave => status == 'on_leave';

  /// Calculates the total work duration between clock-in and clock-out.
  /// Returns null if either timestamp is missing.
  Duration? get workDuration =>
      clockIn != null && clockOut != null ? clockOut!.difference(clockIn!) : null;

  @override
  List<Object?> get props => [
        id, employeeId, attendanceDate, clockIn,
        clockOut, status, notes,
      ];
}
