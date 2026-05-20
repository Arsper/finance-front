import 'package:flutter/material.dart';
import 'package:my_app/CustomerWidgets/AppFloatingButton.dart';
import 'package:my_app/CustomerWidgets/WalletFormSheet.dart';
import 'package:my_app/Pages/Transactions/TransactionsPage.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/сurrency.dart';
import 'package:my_app/api/sources/local_storage_service.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/repositories/transaction_repository.dart';
import 'package:my_app/repositories/wallet_repository.dart';

class BalanceTab extends StatefulWidget {
  const BalanceTab({super.key});

  @override
  State<BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<BalanceTab> {
  late final WalletRepository walletRepository;
  late final TransactionRepository transactionRepository;
  final LocalStorageService localStorage = LocalStorageService();

  List<dynamic> wallets = [];
  List<Currency> currencies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final remoteSource = UserRemoteDataSource(dio: Dioclient.instance);

    walletRepository = WalletRepository(
      remoteDataSource: remoteSource,
      localDataSource: localStorage,
    );

    transactionRepository = TransactionRepository(remoteSource, localStorage);

    _refreshData();
  }

  int? _getWalletId(Map<String, dynamic>? wallet) {
    if (wallet == null) return null;
    final id = wallet['billId'] ?? wallet['idBills'] ?? wallet['id'];
    return id != null ? int.tryParse(id.toString()) : null;
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final cachedWallets = await localStorage.getWallets();

      if (mounted && cachedWallets.isNotEmpty) {
        setState(() {
          wallets = cachedWallets
              .where((w) => w['isDeletedOffline'] != true)
              .toList();
          isLoading = false;
        });
      }

      final bool isOnline = await transactionRepository.isServerAvailable();

      if (isOnline) {
        await transactionRepository.syncOfflineTransactions();

        await walletRepository.syncOfflineWallets();
      } else {
        debugPrint(
          "BALANCE_TAB: Сервер недоступен. Работаем в оффлайн-режиме.",
        );
      }

      final w = await walletRepository.getWallets();
      final c = await walletRepository.getCurrencies();

      if (mounted) {
        setState(() {
          wallets = w;
          currencies = c;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Ошибка при полном обновлении данных BalanceTab: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<bool> _showDeleteConfirmDialog(String walletName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Удаление счета'),
            content: Text(
              'Удалить счет "$walletName"? Это также удалит все связанные транзакции и платежи.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'ОТМЕНА',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'УДАЛИТЬ',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openWalletForm({Map<String, dynamic>? existingWallet}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => WalletFormSheet(
        existingWallet: existingWallet,
        currencies: currencies,
        onDelete: () async {
          final id = _getWalletId(existingWallet);
          if (id == null) return;

          bool confirm = await _showDeleteConfirmDialog(
            existingWallet!['name'] ?? '',
          );

          if (confirm && bottomSheetContext.mounted) {
            Navigator.pop(bottomSheetContext);

            final success = await walletRepository.deleteWallet(id);
            if (success) {
              _refreshData();
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Не удалось удалить счет.")),
              );
            }
          }
        },
        onSave: (data) async {
          final id = _getWalletId(existingWallet);

          bool ok = (id == null)
              ? await walletRepository.addWallet(data)
              : await walletRepository.updateWallet(id, data);

          if (ok) {
            _refreshData();
            if (bottomSheetContext.mounted) Navigator.pop(bottomSheetContext);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Ошибка при сохранении данных")),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: wallets.isEmpty
            ? const Center(child: Text("Счетов пока нет"))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: wallets.length,
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  final int? billId = _getWalletId(wallet);
                  final String name = wallet['name'] ?? 'Без названия';
                  final String balance =
                      wallet['currentBalance']?.toString() ?? '0';
                  final double balanceValue = double.tryParse(balance) ?? 0.0;
                  final String code = wallet['currencyCode'] ?? '???';

                  final List<Currency> fallbackCurrencies = [
                    Currency(
                      idCurrencies: 1,
                      code: 'USD',
                      name: 'US Dollar',
                      symbol: '\$',
                    ),

                    Currency(
                      idCurrencies: 2,
                      code: 'EUR',
                      name: 'Euro',
                      symbol: '€',
                    ),
                    Currency(
                      idCurrencies: 3,
                      code: 'RUB',
                      name: 'Russian Ruble',
                      symbol: '₽',
                    ),
                    Currency(
                      idCurrencies: 4,
                      code: 'BYN',
                      name: 'Belarusian Ruble',
                      symbol: 'Б',
                    ),
                  ];

                  final List<Currency> effectiveCurrencies =
                      currencies.isNotEmpty ? currencies : fallbackCurrencies;

                  final String symbol = effectiveCurrencies
                      .firstWhere(
                        (c) => c.code == code,
                        orElse: () => Currency(
                          idCurrencies: 0,
                          code: code,
                          name: '',
                          symbol: code,
                        ),
                      )
                      .symbol;

                  final Color balanceColor = balanceValue == 0
                      ? colorScheme.onSurface
                      : (balanceValue > 0 ? Colors.green : Colors.red);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      onTap: () async {
                        if (billId != null) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionsPage(
                                billId: billId,
                                billName: name,
                                currencySymbol: symbol,
                              ),
                            ),
                          );
                          _refreshData();
                        }
                      },
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: colorScheme.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (wallet['isSynced'] == false) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.cloud_off,
                              size: 16,
                              color: Colors.orange,
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBalanceInfo(
                            balance,
                            symbol,
                            code,
                            balanceColor,
                            colorScheme,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.edit_note,
                              color: colorScheme.primary.withValues(alpha: 0.7),
                              size: 22,
                            ),
                            onPressed: () =>
                                _openWalletForm(existingWallet: wallet),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: AppFloatingButton(
        onPressed: () => _openWalletForm(),
      ),
    );
  }

  Widget _buildBalanceInfo(
    String balance,
    String symbol,
    String code,
    Color balanceColor,
    ColorScheme colorScheme,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: balance,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: balanceColor,
                ),
              ),
              TextSpan(
                text: " $symbol",
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(code, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
