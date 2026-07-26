import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/employee_bloc.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../../../injection/injection_container.dart';
import 'employee_form_page.dart';

/// Detail page displaying employee information and attendance history.
///
/// Loads the employee by [employeeId] using [LoadEmployeeById] and fetches
/// their attendance records via [LoadAttendance]. Provides edit and delete
/// actions in the app bar.
class EmployeeDetailPage extends StatelessWidget {
  final String employeeId;

  const EmployeeDetailPage({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmployeeBloc>()
        ..add(LoadEmployeeById(employeeId: employeeId))
        ..add(LoadAttendance(employeeId: employeeId)),
      child: const _EmployeeDetailView(),
    );
  }
}

class _EmployeeDetailView extends StatelessWidget {
  const _EmployeeDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        actions: [
          BlocBuilder<EmployeeBloc, EmployeeState>(
            builder: (context, state) {
              if (state is EmployeeDetailLoaded) {
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => EmployeeFormPage(
                          employee: state.employee,
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      context.read<EmployeeBloc>().add(
                            LoadEmployeeById(employeeId: state.employee.id),
                          );
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<EmployeeBloc, EmployeeState>(
        listener: (context, state) {
          if (state is EmployeeOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
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
          if (state is EmployeeLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is EmployeeDetailLoaded) {
            return _buildDetail(context, state.employee, state);
          }
          return const Center(child: Text('Employee not found'));
        },
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    Employee employee,
    EmployeeState currentState,
  ) {
    List<Attendance> attendanceList = [];
    if (currentState is AttendanceLoaded) {
      attendanceList = currentState.attendance;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: _getRoleColor(employee.role),
              child: Text(
                employee.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              employee.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(employee.role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getRoleColor(employee.role)),
              ),
              child: Text(
                employee.role.toUpperCase(),
                style: TextStyle(
                  color: _getRoleColor(employee.role),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  _infoRow(Icons.phone, 'Phone', employee.phone ?? 'Not provided'),
                  const SizedBox(height: 8),
                  _infoRow(Icons.email, 'Email', employee.email ?? 'Not provided'),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.check_circle,
                    'Status',
                    employee.isActive ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  if (attendanceList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No attendance records found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...attendanceList.map(
                      (record) => _attendanceRow(record),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmDelete(context, employee),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.delete),
              label: const Text(
                'Delete Employee',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attendanceRow(Attendance record) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            record.isPresent
                ? Icons.check_circle
                : record.isLate
                    ? Icons.warning
                    : record.isOnLeave
                        ? Icons.event_busy
                        : Icons.cancel,
            size: 20,
            color: record.isPresent
                ? Colors.green
                : record.isLate
                    ? Colors.orange
                    : record.isOnLeave
                        ? Colors.blue
                        : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.attendanceDate.day}/${record.attendanceDate.month}/${record.attendanceDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${record.status.toUpperCase()}'
                  '${record.clockIn != null ? ' | In: ${record.clockIn!.hour}:${record.clockIn!.minute.toString().padLeft(2, '0')}' : ''}'
                  '${record.clockOut != null ? ' | Out: ${record.clockOut!.hour}:${record.clockOut!.minute.toString().padLeft(2, '0')}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (record.workDuration != null)
            Text(
              '${record.workDuration!.inHours}h ${record.workDuration!.inMinutes % 60}m',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Employee employee) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text(
          'Are you sure you want to delete "${employee.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<EmployeeBloc>().add(
                    DeleteEmployee(employeeId: employee.id),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'cashier':
        return Colors.green;
      case 'inventory':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
