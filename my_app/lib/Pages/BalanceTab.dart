import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_app/CustomerWidgets/AppFloatingButton.dart';
import 'package:my_app/CustomerWidgets/WalletFormSheet.dart';
import 'package:my_app/Pages/Guide/balance_page_guide.dart';
import 'package:my_app/Pages/Guide/guide_manager.dart';
import 'package:my_app/Pages/Transactions/TransactionsPage.dart';
import 'package:my_app/api/DioClient.dart';
import 'package:my_app/api/data/сurrency.dart';
import 'package:my_app/api/sources/local_storage_service.dart';
import 'package:my_app/api/sources/remoteDataSource.dart';
import 'package:my_app/repositories/transaction_repository.dart';
import 'package:my_app/repositories/wallet_repository.dart';

enum BalanceState { loading, guide, ready }

class BalanceTab extends StatefulWidget {
  final bool startGuide;
  final bool isWaitingForParentGuide;

  const BalanceTab({
    super.key,
    this.startGuide = false,
    this.isWaitingForParentGuide = false,
  });

  @override
  State<BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<BalanceTab> {
  final String _guideId = 'balance_page_v1';
  late final WalletRepository walletRepository;
  late final TransactionRepository transactionRepository;
  final LocalStorageService localStorage = LocalStorageService();

  BalanceState _currentState = BalanceState.loading;

  List<dynamic> wallets = [];
  List<Currency> currencies = [];
  bool _guideWasShown = false;

  final GlobalKey _firstWalletCardKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _syncIconKey = GlobalKey();
  final GuideManager _guideManager = GuideManager();

  final List<dynamic> _fakeWallets = [
    {
      'id': -1,
      'name': 'Пример счёта',
      'currentBalance': 1500.0,
      'currencyCode': 'USD',
      'isSynced': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    final remoteSource = UserRemoteDataSource(dio: Dioclient.instance);

    walletRepository = WalletRepository(
      remoteDataSource: remoteSource,
      localDataSource: localStorage,
    );

    transactionRepository = TransactionRepository(remoteSource, localStorage);

    _initPage();
  }

  Future<void> _initPage() async {
    final bool alreadySeen = await _guideManager.hasSeenGuide(_guideId);

    if (!mounted) return;

    if (alreadySeen) {
      setState(() {
        _currentState = BalanceState.loading;
      });
      await _loadRealData();
      return;
    }

    if (widget.isWaitingForParentGuide) {
      setState(() {
        _currentState = BalanceState.guide;
        wallets = List.from(_fakeWallets);
      });
      return;
    }

    if (widget.startGuide) {
      setState(() {
        _currentState = BalanceState.guide;
        wallets = List.from(_fakeWallets);
      });

      await _checkAndStartGuide();

      if (mounted) {
        setState(() {
          _currentState = BalanceState.loading;
        });
        await _loadRealData();
      }
      return;
    }
    setState(() {
      _currentState = BalanceState.loading;
    });
    await _loadRealData();
  }

  Future<void> _loadRealData() async {
    if (!mounted || _currentState == BalanceState.guide) return;

    try {
      final cachedWallets = await localStorage.getWallets();
      if (mounted &&
          cachedWallets.isNotEmpty &&
          _currentState != BalanceState.guide) {
        setState(() {
          wallets = cachedWallets
              .where((w) => w['isDeletedOffline'] != true)
              .toList();
          _currentState = BalanceState.ready;
        });
      }
      final bool isOnline = await transactionRepository.isServerAvailable();
      if (isOnline && _currentState != BalanceState.guide) {
        await transactionRepository.syncOfflineTransactions();
        await walletRepository.syncOfflineWallets();
      }

      if (_currentState == BalanceState.guide) return;

      final w = await walletRepository.getWallets();
      final c = await walletRepository.getCurrencies();

      if (mounted && _currentState != BalanceState.guide) {
        setState(() {
          wallets = w;
          currencies = c;
          _currentState = BalanceState.ready;
        });
      }
    } catch (e) {
      debugPrint("Ошибка загрузки данных: $e");
      if (mounted && _currentState == BalanceState.loading) {
        setState(() => _currentState = BalanceState.ready);
      }
    }
  }

  @override
  void didUpdateWidget(covariant BalanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isWaitingForParentGuide && !widget.isWaitingForParentGuide) {
      _initPage();
    } else if (widget.startGuide && !oldWidget.startGuide) {
      _initPage();
    }
  }

  Future<void> _checkAndStartGuide() async {
    final Completer<void> completer = Completer<void>();
    final bool alreadySeen = await _guideManager.hasSeenGuide(_guideId);
    if (!mounted || _guideWasShown || alreadySeen || !widget.startGuide) {
      return;
    }

    _guideManager.runGuide(
      showGuide: () {
        if (!mounted) {
          if (!completer.isCompleted) completer.complete();
          return;
        }

        _guideWasShown = true;

        BalancePageGuide.show(
          context: context,
          firstWalletKey: _firstWalletCardKey,
          syncIconKey: _syncIconKey,
          fabKey: _fabKey,
          onFinish: () async {
            await _guideManager.markGuideAsSeen(_guideId);
            if (!completer.isCompleted) completer.complete();
          },
          onSkipAll: () async {
            await _guideManager.markGuideAsSeen(_guideId);
            await _guideManager.disableAllGuidesForever();
            if (!completer.isCompleted) completer.complete();
          },
        );
      },
      onSkippedOrFinished: () {
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  int? _getWalletId(Map<String, dynamic>? wallet) {
    if (wallet == null) return null;
    final id = wallet['billId'] ?? wallet['idBills'] ?? wallet['id'];
    return id != null ? int.tryParse(id.toString()) : null;
  }

  Future<void> _refreshData() async {
    if (!mounted ||
        _currentState == BalanceState.guide ||
        widget.isWaitingForParentGuide) {
      return;
    }

    try {
      final cachedWallets = await localStorage.getWallets();

      if (mounted &&
          cachedWallets.isNotEmpty &&
          _currentState != BalanceState.guide) {
        setState(() {
          wallets = cachedWallets
              .where((w) => w['isDeletedOffline'] != true)
              .toList();
        });
      }

      final bool isOnline = await transactionRepository.isServerAvailable();
      if (isOnline && _currentState != BalanceState.guide) {
        await transactionRepository.syncOfflineTransactions();
        await walletRepository.syncOfflineWallets();
      }

      if (_currentState == BalanceState.guide) return;

      final w = await walletRepository.getWallets();
      final c = await walletRepository.getCurrencies();

      if (mounted && _currentState != BalanceState.guide) {
        setState(() {
          wallets = w;
          currencies = c;
        });
      }
    } catch (e) {
      debugPrint("Ошибка обновления данных: $e");
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
              'Удалить счет "$walletName"? Это также удалит все связанные транзакции.',
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
    if (existingWallet != null && existingWallet['id'] == -1) return;

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
            if (await walletRepository.deleteWallet(id)) _loadRealData();
          }
        },
        onSave: (data) async {
          final id = _getWalletId(existingWallet);
          bool ok = (id == null)
              ? await walletRepository.addWallet(data)
              : await walletRepository.updateWallet(id, data);
          if (ok) {
            _loadRealData();
            if (bottomSheetContext.mounted) Navigator.pop(bottomSheetContext);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == BalanceState.loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Загрузка данных...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final bool isGuide = _currentState == BalanceState.guide;

    return AbsorbPointer(
      absorbing: isGuide,
      child: Scaffold(
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

                    final bool isNotSynced = wallet['isSynced'] == false;
                    GlobalKey? itemIconKey;
                    if (isNotSynced && index == 0) {
                      itemIconKey = _syncIconKey;
                    }

                    return Card(
                      key: index == 0 ? _firstWalletCardKey : null,
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
                          if (billId == -1) return;
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
                            _loadRealData();
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
                            if (isNotSynced) ...[
                              const SizedBox(width: 6),
                              Icon(
                                key: itemIconKey,
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
                                color: colorScheme.primary.withValues(
                                  alpha: 0.7,
                                ),
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
          key: _fabKey,
          onPressed: () => _openWalletForm(),
        ),
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
