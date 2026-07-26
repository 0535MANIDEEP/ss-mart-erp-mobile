import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/search_bar_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../../domain/entities/supplier_entity.dart';
import '../../domain/usecases/get_suppliers_usecase.dart';
import '../../../purchases/data/datasources/supplier_local_datasource.dart';
import '../../../purchases/data/datasources/supplier_remote_datasource.dart';
import '../../../purchases/data/repositories/supplier_repository_impl.dart';
import '../../../../injection/injection_container.dart';

/// Page displaying all suppliers with search and CRUD navigation.
class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  List<SupplierEntity> _suppliers = [];
  List<SupplierEntity> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final local = SupplierLocalDataSourceImpl(database: sl());
      final remote = SupplierRemoteDataSourceImpl(client: sl());
      final repo = SupplierRepositoryImpl(localDataSource: local, remoteDataSource: remote);
      final result = await GetSuppliersUseCase(repo)(const NoParams());
      result.fold(
        (failure) => setState(() { _error = failure.message; _isLoading = false; }),
        (suppliers) => setState(() { _suppliers = suppliers; _filtered = suppliers; _isLoading = false; }),
      );
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _search(String query) {
    setState(() {
      _filtered = _suppliers.where((s) =>
        s.name.toLowerCase().contains(query.toLowerCase()) ||
        (s.contactPerson?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
        (s.phone?.contains(query) ?? false)
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/suppliers/new'),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Column(
                  children: [
                    SearchBarWidget(
                      hintText: 'Search suppliers...',
                      onChanged: _search,
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const EmptyStateWidget(
                              icon: Icons.business,
                              title: 'No suppliers found',
                              subtitle: 'Add your first supplier to get started',
                            )
                          : ListView.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final supplier = _filtered[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Text(supplier.name[0].toUpperCase()),
                                    ),
                                    title: Text(supplier.name),
                                    subtitle: Text(
                                      supplier.contactPerson ?? supplier.phone ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => context.go('/suppliers/${supplier.id}'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
