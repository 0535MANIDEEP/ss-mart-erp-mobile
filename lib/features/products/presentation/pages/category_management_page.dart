import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/search_bar_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../../domain/entities/category_entity.dart';
import '../../data/datasources/category_local_datasource.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import 'package:get_it/get_it.dart';
import '../../../../database/app_database.dart';

/// Page for managing product categories with CRUD operations.
class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  List<CategoryEntity> _categories = [];
  List<CategoryEntity> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final local = CategoryLocalDataSourceImpl(database: GetIt.instance<AppDatabase>());
    final repo = CategoryRepositoryImpl(localDataSource: local);
    final result = await GetCategoriesUseCase(repo)(const NoParams());
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      (categories) => setState(() { _categories = categories; _filtered = categories; _isLoading = false; }),
    );
  }

  void _search(String query) {
    setState(() {
      _filtered = _categories.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  Future<void> _showCategoryDialog({CategoryEntity? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    final isEdit = category != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Category' : 'New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 12),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final local = CategoryLocalDataSourceImpl(database: GetIt.instance<AppDatabase>());
      final repo = CategoryRepositoryImpl(localDataSource: local);
      if (isEdit) {
        await repo.update(category.id, {'name': nameController.text.trim(), 'description': descController.text.trim()});
      } else {
        await repo.create(CategoryEntity(
          id: const Uuid().v4(), name: nameController.text.trim(),
          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ));
      }
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SearchBarWidget(hintText: 'Search categories...', onChanged: _search),
                Expanded(
                  child: _filtered.isEmpty
                      ? const EmptyStateWidget(icon: Icons.category, title: 'No categories found')
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final cat = _filtered[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(int.parse('0xFF${cat.colorCode.replaceAll('#', '')}')),
                                  child: Text(cat.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                                ),
                                title: Text(cat.name),
                                subtitle: Text(cat.description ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: PopupMenuButton(
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'edit') _showCategoryDialog(category: cat);
                                    if (value == 'delete') {
                                      final local = CategoryLocalDataSourceImpl(database: GetIt.instance<AppDatabase>());
                                      CategoryRepositoryImpl(localDataSource: local).delete(cat.id).then((_) => _loadCategories());
                                    }
                                  },
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
}
