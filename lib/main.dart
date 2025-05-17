// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider<ThemeProvider>(
      create: (context) => ThemeProvider(),
      child: ChangeNotifierProvider<TransactionData>(
        create: (context) => TransactionData(),
        builder: (context, child) => const MyApp(),
      ),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class Transaction {
  String description;
  double amount;
  TransactionType type;
  DateTime date;

  Transaction({
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'type': type.index,
      'date': date.toIso8601String(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      description: json['description'],
      amount: json['amount'],
      type: TransactionType.values[json['type']],
      date: DateTime.parse(json['date']),
    );
  }
}

enum TransactionType { income, expense }

class TransactionData extends ChangeNotifier {
  Map<String, List<Transaction>> monthlyTransactions = {};

  TransactionData() {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (String key in keys) {
      if (key.startsWith('transactions_')) {
        final String? jsonString = prefs.getString(key);
        if (jsonString != null) {
          final List<dynamic> decodedJson = jsonDecode(jsonString);
          monthlyTransactions[key.substring(13)] =
              decodedJson
                  .map<Transaction>((item) => Transaction.fromJson(item))
                  .toList();
        }
      }
    }
    notifyListeners();
  }

  Future<void> saveTransactions(String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      monthlyTransactions[monthKey]
              ?.map<Map<String, dynamic>>((item) => item.toJson())
              .toList() ??
          [],
    );
    await prefs.setString('transactions_$monthKey', jsonString);
  }

  void addTransaction(
    String description,
    double amount,
    TransactionType type,
    DateTime date,
  ) {
    final monthKey = DateFormat('yyyy-MM').format(date);
    monthlyTransactions.putIfAbsent(monthKey, () => []);
    monthlyTransactions[monthKey]!.add(
      Transaction(
        description: description,
        amount: amount,
        type: type,
        date: date,
      ),
    );
    saveTransactions(monthKey);
    notifyListeners();
  }

  void updateTransaction(
    int index,
    String description,
    double amount,
    TransactionType type,
    DateTime date,
    String monthKey,
  ) {
    monthlyTransactions[monthKey]![index] = Transaction(
      description: description,
      amount: amount,
      type: type,
      date: date,
    );
    saveTransactions(monthKey);
    notifyListeners();
  }

  void deleteTransaction(int index, String monthKey) {
    monthlyTransactions[monthKey]!.removeAt(index);
    saveTransactions(monthKey);
    notifyListeners();
  }

  Future<void> clearTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('transactions_')) {
        await prefs.remove(key);
      }
    }
    monthlyTransactions.clear();
    notifyListeners();
  }

  double getTotalForMonth(String monthKey) {
    double totalIncome = 0;
    double totalExpense = 0;
    if (monthlyTransactions[monthKey] != null) {
      for (var transaction in monthlyTransactions[monthKey]!) {
        if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
        } else {
          totalExpense += transaction.amount;
        }
      }
    }
    return totalIncome - totalExpense;
  }

  String getCurrentBalanceDescription(String monthKey) {
    return 'Balance: ${NumberFormat.currency(locale: 'en_US', symbol: '\$').format(getTotalForMonth(monthKey))}';
  }

  List<Transaction> getTransactionsForMonth(String monthKey) {
    return monthlyTransactions[monthKey] ?? [];
  }

  void refresh() {
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'EasyMoney',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white),
            ),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.deepPurple),
            drawerTheme: const DrawerThemeData(backgroundColor: Colors.black54),
          ),
          home: const GetStartedScreen(),
        );
      },
    );
  }
}

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFirstLaunch = prefs.getBool('already_launched') ?? true;
    });

    if (_isFirstLaunch) {
      await prefs.setBool('already_launched', false);
      // Stay on the GetStartedScreen
    } else {
      // Navigate to MyHomePage after a delay
      Future.delayed(const Duration(milliseconds: 10), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MyHomePage()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isFirstLaunch
        ? Scaffold(
          backgroundColor: Colors.deepPurple,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'EasyMoney!',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const MyHomePage(),
                      ),
                    );
                  },
                  child: const Text('Iniciar'),
                ),
              ],
            ),
          ),
        )
        : const Scaffold(
          body: Center(child: CircularProgressIndicator()), // Loading indicator
        );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100.0,
        backgroundColor: Colors.deepPurple,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EasyMoney', style: TextStyle(color: Colors.white)),
            const Text(
              'Controla tu efectivo',
              style: TextStyle(color: Colors.white70, fontSize: 12.0),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Consumer<TransactionData>(
                builder: (context, transactionData, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        transactionData.getCurrentBalanceDescription(
                          selectedMonth,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.brightness_4),
                      const SizedBox(width: 16),
                      const Text('Dark Mode'),
                      const Spacer(), // Aligns the switch to the right
                      Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme(value);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Historial'),
              onTap: () {
                Navigator.pop(context);
                _showMonthSelectionDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Reiniciar App'),
              onTap: () {
                Navigator.pop(context);
                _showClearDataConfirmationDialog(context);
              },
            ),
          ],
        ),
      ),
      body: TransactionList(monthKey: selectedMonth),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 1.0,
        elevation: 0.0,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const <Widget>[],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddTransactionDialog(context, -1);
        },
        tooltip: 'Agregar Transacción',
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _showAddTransactionDialog(BuildContext context, int index) {
    String description = '';
    double amount = 0.0;
    bool isIncome = false;
    bool isExpense = true;
    DateTime selectedDate = DateTime.now();

    if (index != -1) {
      final transaction =
          Provider.of<TransactionData>(
            context,
            listen: false,
          ).monthlyTransactions[selectedMonth]![index];
      description = transaction.description;
      amount = transaction.amount;
      isIncome = transaction.type == TransactionType.income;
      isExpense = transaction.type == TransactionType.expense;
      selectedDate = transaction.date;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            index == -1 ? 'Agregar Transacción' : 'Editar Transacción',
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: description),
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        description = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController(
                        text: amount.toString(),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        amount = double.tryParse(value) ?? 0.0;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isIncome,
                          onChanged: (bool? newValue) {
                            setState(() {
                              isIncome = newValue ?? false;
                              if (newValue == true) {
                                isExpense = false;
                              }
                            });
                          },
                        ),
                        const Text('Ingreso'),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: isExpense,
                          onChanged: (bool? newValue) {
                            setState(() {
                              isExpense = newValue ?? false;
                              if (newValue == true) {
                                isIncome = false;
                              }
                            });
                          },
                        ),
                        const Text('Gasto'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2050),
                            );

                            if (pickedDate != selectedDate) {
                              setState(() {
                                selectedDate = pickedDate!;
                              });
                            }
                          },
                          child: const Text('Seleccione Fecha'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text(index == -1 ? 'Agregar' : 'Actualizar'),
              onPressed: () {
                bool formatValid(double numero) {
                String numeroStr = numero.toString();
                RegExp regex = RegExp(r'^\d+(\.\d{1,2})?$');
                return regex.hasMatch(numeroStr);
                }
                bool isFormatValid = formatValid(amount);
                String descriptionText1 = 'Por favor, complete la descripción y el monto.';
                if (description.isEmpty || amount == 0.0 || !isFormatValid) {
                  if(!isFormatValid){
                    descriptionText1 = 'El monto ingresado es inválido';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        descriptionText1,
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                if (isIncome == isExpense) {
                  return;
                }
                if (index == -1) {
                  Provider.of<TransactionData>(
                    context,
                    listen: false,
                  ).addTransaction(
                    description,
                    amount,
                    isIncome ? TransactionType.income : TransactionType.expense,
                    selectedDate,
                  );
                } else {
                  Provider.of<TransactionData>(
                    context,
                    listen: false,
                  ).updateTransaction(
                    index,
                    description,
                    amount,
                    isIncome ? TransactionType.income : TransactionType.expense,
                    selectedDate,
                    selectedMonth,
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showMonthSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccione el mes'),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer<TransactionData>(
              builder: (context, transactionData, child) {
                final months =
                    transactionData.monthlyTransactions.keys.toList();
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final month = months[index];
                    return ListTile(
                      title: Text(month),
                      onTap: () {
                        setState(() {
                          selectedMonth = month;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showClearDataConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar historial de transacciones'),
          content: const Text(
            '¿Seguro que desea eliminar todo el historial de transacciones? Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Borrar todos los datos',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Provider.of<TransactionData>(
                  context,
                  listen: false,
                ).clearTransactions();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class TransactionList extends StatelessWidget {
  final String monthKey;
  const TransactionList({super.key, required this.monthKey});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionData>(
      builder: (context, transactionData, child) {
        final transactions = transactionData.getTransactionsForMonth(monthKey);
        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.description,
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            transaction.type == TransactionType.income
                                ? 'Ingreso'
                                : 'Gasto',
                            style: TextStyle(
                              color:
                                  transaction.type == TransactionType.income
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                          Text(
                            DateFormat('yyyy-MM-dd').format(transaction.date),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(
                        locale: 'en_US',
                        symbol: '\$',
                      ).format(transaction.amount),
                      style: TextStyle(
                        fontSize: 16.0,
                        color:
                            transaction.type == TransactionType.income
                                ? Colors.green
                                : Colors.red,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _showEditTransactionDialog(context, index);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _showDeleteConfirmationDialog(
                              context,
                              index,
                              monthKey,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTransactionDialog(BuildContext context, int index) {
    String description = '';
    double amount = 0.0;
    bool isIncome = true;
    bool isExpense = false;
    DateTime selectedDate = DateTime.now();

    final transaction =
        Provider.of<TransactionData>(
          context,
          listen: false,
        ).monthlyTransactions[monthKey]![index];
    description = transaction.description;
    amount = transaction.amount;
    isIncome = transaction.type == TransactionType.income;
    isExpense = transaction.type == TransactionType.expense;
    selectedDate = transaction.date;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editar Transacción'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: description),
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        description = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController(
                        text: amount.toString(),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        amount = double.tryParse(value) ?? 0.0;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isIncome,
                          onChanged: (bool? newValue) {
                            setState(() {
                              isIncome = newValue ?? false;
                              if (newValue == true) {
                                isExpense = false;
                              }
                            });
                          },
                        ),
                        const Text('Ingreso'),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: isExpense,
                          onChanged: (bool? newValue) {
                            setState(() {
                              isExpense = newValue ?? false;
                              if (newValue == true) {
                                isIncome = false;
                              }
                            });
                          },
                        ),
                        const Text('Gasto'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2050),
                            );

                            if (pickedDate != selectedDate) {
                              setState(() {
                                selectedDate = pickedDate!;
                              });
                            }
                          },
                          child: const Text('Seleccione Fecha'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Actualizar'),
              onPressed: () {
                if (description.isEmpty || amount == 0.0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Por favor, complete la descripción y el monto.',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                if (isIncome == isExpense) {
                  return;
                }
                Provider.of<TransactionData>(
                  context,
                  listen: false,
                ).updateTransaction(
                  index,
                  description,
                  amount,
                  isIncome ? TransactionType.income : TransactionType.expense,
                  selectedDate,
                  monthKey,
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    int index,
    String monthKey,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Transacción'),
          content: const Text(
            '¿Seguro que desea eliminar esta transacción? Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Provider.of<TransactionData>(
                  context,
                  listen: false,
                ).deleteTransaction(index, monthKey);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
