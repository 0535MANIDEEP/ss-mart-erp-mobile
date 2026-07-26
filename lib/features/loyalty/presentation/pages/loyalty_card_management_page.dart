import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import '../../../../database/app_database.dart';

/// Page for managing loyalty cards (issuance, activation, blocking).
class LoyaltyCardManagementPage extends StatefulWidget {
  const LoyaltyCardManagementPage({super.key});

  @override
  State<LoyaltyCardManagementPage> createState() => _LoyaltyCardManagementPageState();
}

class _LoyaltyCardManagementPageState extends State<LoyaltyCardManagementPage> {
  List<LoyaltyCard> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final db = GetIt.instance<AppDatabase>();
    final cards = await db.select(db.loyaltyCards).get();
    setState(() { _cards = cards; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty Cards'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _issueCard,
        child: const Icon(Icons.add_card),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? const Center(child: Text('No loyalty cards issued yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cards.length,
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    final statusColor = card.status == 'active'
                        ? Colors.green
                        : card.status == 'blocked'
                            ? Colors.red
                            : Colors.grey;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Icon(Icons.credit_card, color: statusColor),
                        ),
                        title: Text('Card: ${card.cardNumber}'),
                        subtitle: Text(
                          card.customerName.isNotEmpty
                              ? 'Customer: ${card.customerName}'
                              : 'Unassigned',
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            if (card.status == 'active')
                              const PopupMenuItem(value: 'block', child: Text('Block Card')),
                            if (card.status == 'blocked')
                              const PopupMenuItem(value: 'activate', child: Text('Activate Card')),
                          ],
                          onSelected: (value) async {
                            final db = GetIt.instance<AppDatabase>();
                            await (db.update(db.loyaltyCards)
                              ..where((t) => t.id.equals(card.id)))
                                .write(LoyaltyCardsCompanion(
                                  status: Value(value == 'block' ? 'blocked' : 'active'),
                                  updatedAt: Value(DateTime.now()),
                                  version: Value(card.version + 1),
                                  syncStatus: const Value('pending'),
                                ));
                            _loadCards();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _issueCard() {
    final cardNumberController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Issue New Card'),
        content: TextField(
          controller: cardNumberController,
          decoration: const InputDecoration(labelText: 'Card Number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (cardNumberController.text.trim().isEmpty) return;
              final db = GetIt.instance<AppDatabase>();
              await db.into(db.loyaltyCards).insert(LoyaltyCardsCompanion.insert(
                id: const Uuid().v4(),
                cardNumber: cardNumberController.text.trim(),
                customerName: const Value(''),
                status: const Value('active'),
                cardType: const Value('standard'),
                issuedDate: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                version: const Value(1),
                syncStatus: const Value('pending'),
              ));
              Navigator.pop(context);
              _loadCards();
            },
            child: const Text('Issue'),
          ),
        ],
      ),
    );
  }
}
