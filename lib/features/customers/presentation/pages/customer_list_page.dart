import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/customer_bloc.dart';
import '../../domain/entities/customer_entity.dart';
import '../../../../injection/injection_container.dart';
import 'customer_form_page.dart';
import 'customer_detail_page.dart';

class CustomerListPage extends StatelessWidget {
  const CustomerListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerBloc>()..add(const LoadCustomers()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customers'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(context: context, delegate: CustomerSearchDelegate());
              },
            ),
          ],
        ),
        body: BlocBuilder<CustomerBloc, CustomerState>(
          builder: (context, state) {
            if (state is CustomerLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is CustomerError) {
              return Center(child: Text('Error: ${state.message}'));
            }
            if (state is CustomerLoaded) {
              if (state.customers.isEmpty) {
                return const Center(child: Text('No customers found'));
              }
              return ListView.builder(
                itemCount: state.customers.length,
                itemBuilder: (context, index) {
                  final customer = state.customers[index];
                  return CustomerCard(customer: customer);
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerFormPage()),
            );
            if (result == true) {
              context.read<CustomerBloc>().add(const LoadCustomers());
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class CustomerCard extends StatelessWidget {
  final Customer customer;

  const CustomerCard({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: customer.isB2B ? Colors.blue : Colors.green,
          child: Text(
            customer.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Phone: ${customer.phone ?? 'N/A'} | Points: ${customer.loyaltyPoints}',
        ),
        trailing: customer.hasOutstanding
            ? Text(
                '₹${customer.currentBalance}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerDetailPage(customerId: customer.id),
            ),
          );
          if (result == true && context.mounted) {
            context.read<CustomerBloc>().add(const LoadCustomers());
          }
        },
      ),
    );
  }
}

class CustomerSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Search customers...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    context.read<CustomerBloc>().add(SearchCustomers(query: query));
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        if (state is CustomerLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is CustomerLoaded) {
          return ListView.builder(
            itemCount: state.customers.length,
            itemBuilder: (context, index) {
              final customer = state.customers[index];
              return ListTile(
                title: Text(customer.name),
                subtitle: Text(customer.phone ?? 'No phone'),
                onTap: () {
                  close(context, customer.id);
                },
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Type to search customers'),
    );
  }
}
