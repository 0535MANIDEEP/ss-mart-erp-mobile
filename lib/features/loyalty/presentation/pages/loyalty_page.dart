import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/loyalty_bloc.dart';
import '../../domain/entities/loyalty_balance.dart';
import '../../../../injection/injection_container.dart';

class LoyaltyPage extends StatelessWidget {
  final String customerId;
  final String customerName;

  const LoyaltyPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoyaltyBloc>()
        ..add(LoadLoyaltyBalance(customerId: customerId)),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Loyalty - $customerName'),
        ),
        body: BlocBuilder<LoyaltyBloc, LoyaltyState>(
          builder: (context, state) {
            if (state is LoyaltyLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is LoyaltyError) {
              return Center(child: Text('Error: ${state.message}'));
            }
            if (state is LoyaltyBalanceLoaded) {
              return _buildLoyaltyContent(context, state.balance);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLoyaltyContent(BuildContext context, LoyaltyBalance balance) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          Card(
            color: const Color(0xFF1B5E20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Available Points',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${balance.currentBalance}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Earned', '${balance.totalPointsEarned}'),
                      _buildStatColumn('Redeemed', '${balance.totalPointsRedeemed}'),
                      _buildStatColumn('Expiring', '${balance.expiringPoints}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showEarnPointsDialog(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Earn Points'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: balance.currentBalance > 0
                      ? () {
                          _showRedeemPointsDialog(context, balance.currentBalance);
                        }
                      : null,
                  icon: const Icon(Icons.redeem),
                  label: const Text('Redeem Points'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Transactions
          const Text(
            'Recent Transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (balance.recentTransactions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No transactions yet')),
              ),
            )
          else
            ...balance.recentTransactions.map((transaction) => Card(
                  child: ListTile(
                    leading: Icon(
                      transaction.isEarn ? Icons.add_circle : Icons.remove_circle,
                      color: transaction.isEarn ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      transaction.isEarn ? 'Points Earned' : 'Points Redeemed',
                    ),
                    subtitle: Text(
                      '${transaction.customerName} • ${transaction.createdAt.toString().substring(0, 10)}',
                    ),
                    trailing: Text(
                      '${transaction.isEarn ? '+' : '-'}${transaction.points}',
                      style: TextStyle(
                        color: transaction.isEarn ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  void _showEarnPointsDialog(BuildContext context) {
    final pointsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Earn Points'),
        content: TextField(
          controller: pointsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Points to earn',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final points = int.tryParse(pointsController.text) ?? 0;
              if (points > 0) {
                context.read<LoyaltyBloc>().add(
                      EarnPointsRequested(
                        customerId: customerId,
                        points: points,
                      ),
                    );
              }
            },
            child: const Text('Earn'),
          ),
        ],
      ),
    );
  }

  void _showRedeemPointsDialog(BuildContext context, int maxPoints) {
    final pointsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available: $maxPoints points'),
            const SizedBox(height: 8),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Points to redeem',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final points = int.tryParse(pointsController.text) ?? 0;
              if (points > 0 && points <= maxPoints) {
                context.read<LoyaltyBloc>().add(
                      RedeemPointsRequested(
                        customerId: customerId,
                        points: points,
                      ),
                    );
              }
            },
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }
}
