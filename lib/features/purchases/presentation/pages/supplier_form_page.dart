import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/utils/validators.dart';
import '../../data/datasources/supplier_local_datasource.dart';
import '../../data/datasources/supplier_remote_datasource.dart';
import '../../data/repositories/supplier_repository_impl.dart';
import '../../domain/entities/supplier_entity.dart';
import '../../domain/usecases/create_supplier_usecase.dart';
import '../../../../injection/injection_container.dart';

/// Form page for creating and editing suppliers.
class SupplierFormPage extends StatefulWidget {
  final String? supplierId;

  const SupplierFormPage({super.key, this.supplierId});

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  final _creditDaysController = TextEditingController(text: '30');

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) _loadSupplier();
  }

  Future<void> _loadSupplier() async {
    setState(() => _isLoading = true);
    try {
      final local = SupplierLocalDataSourceImpl(database: sl());
      final supplier = await local.getById(widget.supplierId!);
      if (supplier != null) {
        _nameController.text = supplier.name;
        _contactPersonController.text = supplier.contactPerson ?? '';
        _phoneController.text = supplier.phone ?? '';
        _emailController.text = supplier.email ?? '';
        _addressController.text = supplier.address ?? '';
        _cityController.text = supplier.city ?? '';
        _stateController.text = supplier.state ?? '';
        _pincodeController.text = supplier.pincode ?? '';
        _gstinController.text = supplier.gstin ?? '';
        _panController.text = supplier.pan ?? '';
        _creditDaysController.text = supplier.creditDays.toString();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final local = SupplierLocalDataSourceImpl(database: sl());
      final remote = SupplierRemoteDataSourceImpl(client: sl());
      final repo = SupplierRepositoryImpl(localDataSource: local, remoteDataSource: remote);
      final data = {
        'name': _nameController.text.trim(),
        'contactPerson': _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        'pincode': _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
        'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim().toUpperCase(),
        'pan': _panController.text.trim().isEmpty ? null : _panController.text.trim().toUpperCase(),
        'creditDays': int.tryParse(_creditDaysController.text) ?? 30,
      };

      if (widget.supplierId != null) {
        await repo.update(widget.supplierId!, data);
      } else {
        final supplier = SupplierEntity(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          contactPerson: data['contactPerson'] as String?,
          phone: data['phone'] as String?,
          email: data['email'] as String?,
          address: data['address'] as String?,
          city: data['city'] as String?,
          state: data['state'] as String?,
          pincode: data['pincode'] as String?,
          gstin: data['gstin'] as String?,
          pan: data['pan'] as String?,
          creditDays: data['creditDays'] as int,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.create(supplier);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier saved successfully')));
        context.go('/suppliers');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _creditDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplierId != null ? 'Edit Supplier' : 'New Supplier'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Supplier Name *'),
                      validator: Validators.required('Name is required'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(labelText: 'Contact Person'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(labelText: 'City'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(labelText: 'State'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pincodeController,
                            decoration: const InputDecoration(labelText: 'Pincode'),
                            keyboardType: TextInputType.number,
                            validator: Validators.pincode(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _creditDaysController,
                            decoration: const InputDecoration(labelText: 'Credit Days'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gstinController,
                      decoration: const InputDecoration(labelText: 'GSTIN'),
                      textCapitalization: TextCapitalization.characters,
                      validator: Validators.gstin(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _panController,
                      decoration: const InputDecoration(labelText: 'PAN'),
                      textCapitalization: TextCapitalization.characters,
                      validator: Validators.pan(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Supplier'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
