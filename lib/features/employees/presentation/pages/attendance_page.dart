import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/employee_bloc.dart';
import '../../../../injection/injection_container.dart';

class AttendancePage extends StatelessWidget {
  final String? employeeId;
  const AttendancePage({super.key, this.employeeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmployeeBloc>()..add(LoadEmployees()),
      child: AttendanceView(employeeId: employeeId),
    );
  }
}

class AttendanceView extends StatefulWidget {
  final String? employeeId;
  const AttendanceView({super.key, this.employeeId});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  @override
  void initState() {
    super.initState();
    if (widget.employeeId != null) {
      context.read<EmployeeBloc>().add(
        LoadAttendance(employeeId: widget.employeeId),
      );
    } else {
      context.read<EmployeeBloc>().add(LoadAttendance());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: BlocConsumer<EmployeeBloc, EmployeeState>(
        listener: (context, state) {
          if (state is ClockInSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Clocked in successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _refreshAttendance();
          } else if (state is ClockOutSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Clocked out successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _refreshAttendance();
          } else if (state is EmployeeError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is EmployeeLoading || state is ClockInOutLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is EmployeesLoaded) {
            return _buildEmployeeList(context, state.employees);
          }

          if (state is AttendanceLoaded) {
            return _buildAttendanceList(context, state.attendance);
          }

          if (state is EmployeeError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshAttendance,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return const Center(child: Text('No data available'));
        },
      ),
    );
  }

  void _refreshAttendance() {
    if (widget.employeeId != null) {
      context.read<EmployeeBloc>().add(
        LoadAttendance(employeeId: widget.employeeId),
      );
    } else {
      context.read<EmployeeBloc>().add(LoadEmployees());
    }
  }

  Widget _buildEmployeeList(BuildContext context, List employees) {
    if (employees.isEmpty) {
      return const Center(child: Text('No employees found'));
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshAttendance(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: employees.length,
        itemBuilder: (context, index) {
          final employee = employees[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: employee.isActive ? Colors.green : Colors.grey,
                child: Text(
                  employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(employee.name),
              subtitle: Text(employee.role.toUpperCase()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (employee.isActive) ...[
                    IconButton(
                      icon: const Icon(Icons.login, color: Colors.green),
                      onPressed: () => _showPinDialog(context, 'clockIn', employee.id),
                      tooltip: 'Clock In',
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      onPressed: () => _showPinDialog(context, 'clockOut', employee.id),
                      tooltip: 'Clock Out',
                    ),
                  ] else ...[
                    const Icon(Icons.person_off, color: Colors.grey),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceList(BuildContext context, List attendanceList) {
    if (attendanceList.isEmpty) {
      return const Center(child: Text('No attendance records for today'));
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshAttendance(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: attendanceList.length,
        itemBuilder: (context, index) {
          final attendance = attendanceList[index];
          final clockInTime = attendance.clockIn != null
              ? TimeOfDay.fromDateTime(attendance.clockIn!).format(context)
              : '--:--';
          final clockOutTime = attendance.clockOut != null
              ? TimeOfDay.fromDateTime(attendance.clockOut!).format(context)
              : '--:--';
          final isClockedIn = attendance.clockIn != null && attendance.clockOut == null;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isClockedIn ? Colors.green : Colors.grey,
                child: Icon(
                  isClockedIn ? Icons.access_time : Icons.access_time_filled,
                  color: Colors.white,
                ),
              ),
              title: Text('Employee: ${attendance.employeeId.substring(0, 8)}...'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clock In: $clockInTime'),
                  Text('Clock Out: $clockOutTime'),
                  Text(
                    'Status: ${attendance.status.toUpperCase()}',
                    style: TextStyle(
                      color: attendance.isPresent
                          ? Colors.green
                          : attendance.isLate
                              ? Colors.orange
                              : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.login, color: Colors.green),
                    onPressed: isClockedIn
                        ? null
                        : () => _showPinDialog(
                            context, 'clockIn', attendance.employeeId),
                    tooltip: 'Clock In',
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: isClockedIn
                        ? () => _showPinDialog(
                            context, 'clockOut', attendance.employeeId)
                        : null,
                    tooltip: 'Clock Out',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPinDialog(BuildContext context, String action, String employeeId) {
    final pinController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'clockIn' ? 'Clock In' : 'Clock Out'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter PIN',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (action == 'clockIn') {
                context.read<EmployeeBloc>().add(
                  ClockInRequested(
                    employeeId: employeeId,
                    pin: pinController.text,
                  ),
                );
              } else {
                context.read<EmployeeBloc>().add(
                  ClockOutRequested(
                    employeeId: employeeId,
                    pin: pinController.text,
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
