import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/employee_bloc.dart';
import '../../domain/entities/employee_entity.dart';
import '../../../../injection/injection_container.dart';
import 'employee_form_page.dart';
import 'employee_detail_page.dart';

class EmployeeListPage extends StatelessWidget {
  const EmployeeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmployeeBloc>()..add(const LoadEmployees()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Employees'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => const EmployeeFormPage(),
                  ),
                );
                if (result == true && context.mounted) {
                  context.read<EmployeeBloc>().add(const LoadEmployees());
                }
              },
            ),
          ],
        ),
        body: BlocBuilder<EmployeeBloc, EmployeeState>(
          builder: (context, state) {
            if (state is EmployeeLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is EmployeeError) {
              return Center(child: Text('Error: ${state.message}'));
            }
            if (state is EmployeesLoaded) {
              if (state.employees.isEmpty) {
                return const Center(child: Text('No employees found'));
              }
              return ListView.builder(
                itemCount: state.employees.length,
                itemBuilder: (context, index) {
                  final employee = state.employees[index];
                  return EmployeeCard(employee: employee);
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class EmployeeCard extends StatelessWidget {
  final Employee employee;

  const EmployeeCard({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(employee.role),
          child: Text(
            employee.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Role: ${employee.role.toUpperCase()} | ${employee.phone ?? 'No phone'}',
        ),
        trailing: Icon(
          employee.isActive ? Icons.check_circle : Icons.cancel,
          color: employee.isActive ? Colors.green : Colors.red,
        ),
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => EmployeeDetailPage(employeeId: employee.id),
            ),
          );
          if (result == true && context.mounted) {
            context.read<EmployeeBloc>().add(const LoadEmployees());
          }
        },
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
