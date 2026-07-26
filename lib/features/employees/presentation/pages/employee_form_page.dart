import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../bloc/employee_bloc.dart';
import '../../domain/entities/employee_entity.dart';
import '../../../../injection/injection_container.dart';

/// Form page for creating or editing an employee.
///
/// When an [Employee] argument is provided, the form operates in edit mode
/// and pre-populates fields with existing values. Otherwise, it creates
/// a new employee record.
///
/// Uses [Form] with [GlobalKey<FormState>] for validation, and dispatches
/// [CreateEmployee] or [UpdateEmployee] events via [EmployeeBloc].
class EmployeeFormPage extends StatelessWidget {
  final Employee? employee;

  const EmployeeFormPage({super.key, this.employee});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmployeeBloc>(),
      child: _EmployeeFormView(employee: employee),
    );
  }
}

class _EmployeeFormView extends StatefulWidget {
  final Employee? employee;

  const _EmployeeFormView({this.employee});

  @override
  State<_EmployeeFormView> createState() => _EmployeeFormViewState();
}

class _EmployeeFormViewState extends State<_EmployeeFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _pinController;
  late String _selectedRole;
  bool get _isEditMode => widget.employee != null;

  static const _roles = ['admin', 'manager', 'cashier', 'inventory'];

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _nameController = TextEditingController(text: emp?.name ?? '');
    _phoneController = TextEditingController(text: emp?.phone ?? '');
    _emailController = TextEditingController(text: emp?.email ?? '');
    _pinController = TextEditingController();
    _selectedRole = emp?.role ?? 'cashier';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final employee = Employee(
      id: widget.employee?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      role: _selectedRole,
      isActive: widget.employee?.isActive ?? true,
      createdAt: widget.employee?.createdAt ?? now,
      updatedAt: now,
      version: widget.employee?.version ?? 1,
    );

    if (_isEditMode) {
      context.read<EmployeeBloc>().add(UpdateEmployee(employee: employee));
    } else {
      context.read<EmployeeBloc>().add(CreateEmployee(employee: employee));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Employee' : 'Add Employee'),
      ),
      body: BlocListener<EmployeeBloc, EmployeeState>(
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
        child: BlocBuilder<EmployeeBloc, EmployeeState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          if (value.trim().length < 10) {
                            return 'Enter a valid phone number';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final emailRegex = RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role *',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(),
                      ),
                      items: _roles
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(role[0].toUpperCase() + role.substring(1)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Role is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pinController,
                      decoration: InputDecoration(
                        labelText: _isEditMode ? 'New PIN (leave blank to keep)' : 'PIN *',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      validator: (value) {
                        if (!_isEditMode &&
                            (value == null || value.trim().isEmpty)) {
                          return 'PIN is required';
                        }
                        if (value != null &&
                            value.trim().isNotEmpty &&
                            value.trim().length != 4) {
                          return 'PIN must be exactly 4 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: state is EmployeeLoading ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: state is EmployeeLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditMode ? 'Update Employee' : 'Create Employee',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
