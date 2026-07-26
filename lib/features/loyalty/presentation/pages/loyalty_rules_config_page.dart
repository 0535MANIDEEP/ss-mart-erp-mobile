import 'package:flutter/material.dart';

/// Page for configuring loyalty program rules (earn rate, redeem policy, tiers).
class LoyaltyRulesConfigPage extends StatefulWidget {
  const LoyaltyRulesConfigPage({super.key});

  @override
  State<LoyaltyRulesConfigPage> createState() => _LoyaltyRulesConfigPageState();
}

class _LoyaltyRulesConfigPageState extends State<LoyaltyRulesConfigPage> {
  final _pointsPerRupeeController = TextEditingController(text: '1');
  final _minRedemptionController = TextEditingController(text: '10');
  final _maxRedemptionPercentController = TextEditingController(text: '50');
  final _pointsExpiryDaysController = TextEditingController(text: '365');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty Rules'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earn Rules', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    TextField(
                      controller: _pointsPerRupeeController,
                      decoration: const InputDecoration(
                        labelText: 'Points per Rupee',
                        helperText: 'Number of loyalty points earned per ₹1 spent',
                      ),
                      keyboardType: TextInputType.number,
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
                    Text('Redeem Rules', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    TextField(
                      controller: _minRedemptionController,
                      decoration: const InputDecoration(labelText: 'Minimum Points to Redeem'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _maxRedemptionPercentController,
                      decoration: const InputDecoration(
                        labelText: 'Max Redemption %',
                        helperText: 'Maximum bill percentage payable with points',
                      ),
                      keyboardType: TextInputType.number,
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
                    Text('Expiry Rules', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    TextField(
                      controller: _pointsExpiryDaysController,
                      decoration: const InputDecoration(
                        labelText: 'Points Validity (Days)',
                        helperText: 'Points expire after this many days from earn date',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loyalty rules saved')),
                );
                Navigator.pop(context);
              },
              child: const Text('Save Rules'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pointsPerRupeeController.dispose();
    _minRedemptionController.dispose();
    _maxRedemptionPercentController.dispose();
    _pointsExpiryDaysController.dispose();
    super.dispose();
  }
}
