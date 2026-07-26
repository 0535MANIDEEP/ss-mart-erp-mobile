import 'package:flutter/material.dart';
import 'ledger_page.dart';
import 'trial_balance_page.dart';
import 'journal_entry_form_page.dart';

/// Main page for the Accounting feature with tabbed navigation.
///
/// Provides three tabs:
/// - **Ledger**: Scrollable list of all ledger entries with date range filter
///   and debit/credit badge indicators.
/// - **Trial Balance**: Table view showing each account head with debit/credit
///   totals and net balance, with totals at the bottom.
/// - **Journal Entry**: Manual journal entry form for creating double-entry
///   bookkeeping records.
///
/// This page serves as the entry point for all accounting operations in
/// the ERP system. The ledger entries are auto-generated from bills and
/// purchases, supplemented by manual journal entries.
class AccountingPage extends StatelessWidget {
  const AccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accounting'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ledger', icon: Icon(Icons.menu_book)),
              Tab(text: 'Trial Balance', icon: Icon(Icons.balance)),
              Tab(text: 'Journal Entry', icon: Icon(Icons.edit_note)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LedgerPage(),
            TrialBalancePage(),
            JournalEntryFormPage(),
          ],
        ),
      ),
    );
  }
}
