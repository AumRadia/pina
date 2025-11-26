import 'package:flutter/material.dart';
import 'package:pina/data/translation.dart';
import 'package:pina/screens/loginscreen.dart';
import 'package:pina/widgets/hamburger_menu.dart';
import '../services/widget_service.dart';
import '../models/widget_model.dart';

class MyAiScreen extends StatefulWidget {
  final String userName;
  final String userEmail; // REQUIRED: To identify the user in MongoDB

  const MyAiScreen({
    super.key,
    this.userName = "User",
    required this.userEmail,
  });

  @override
  State<MyAiScreen> createState() => _MyAiScreenState();
}

class _MyAiScreenState extends State<MyAiScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final WidgetService _service = WidgetService();

  String selectedLanguage = 'English'; // Keeps drawer and labels in sync.

  // Stores the list of widgets the user has actually saved (from UserWidget.js schema)
  List<dynamic> myWidgets = [];
  bool isLoading = true; // Indicates API work for optimistic updates.

  @override
  void initState() {
    super.initState();
    _fetchMyWidgets();
  }

  // --- 1. FETCH USER'S SAVED WIDGETS ---
  Future<void> _fetchMyWidgets() async {
    // Calls GET /api/widgets/userWidgets
    final widgets = await _service.getUserWidgets(widget.userEmail);
    if (mounted) {
      setState(() {
        myWidgets = widgets;
        isLoading = false;
      });
    }
  }

  // --- 2. OPEN DIALOG & ADD WIDGET ---
  Future<void> _showAddWidgetDialog() async {
    // A. Fetch all available widgets from the Marketplace (MongoDB)
    // This ensures if you add a new widget in Admin, it shows up here immediately.
    List<MarketWidget> allMarketWidgets = await _service.getWidgets();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AddWidgetDialog(
        marketplaceWidgets: allMarketWidgets,
        userWidgets: myWidgets, // Pass current list to avoid duplicates
        getLabel: getLabel,
        onWidgetSelected: (MarketWidget selectedItem) async {
          Navigator.pop(context); // Close dialog
          setState(() => isLoading = true); // Show loading spinner

          // B. Call API to save to User's Collection
          bool success = await _service.addWidgetToUser(
            widget.userEmail,
            selectedItem.visitName,
            selectedItem.id,
          );

          if (success) {
            await _fetchMyWidgets(); // Refresh the list from DB
            if (mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Widget Added!")));
          } else {
            if (mounted) {
              setState(() => isLoading = false);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Failed to add")));
            }
          }
        },
      ),
    );
  }

  // --- 3. REMOVE WIDGET ---
  void removeWidget(String widgetName) async {
    // Optimistic Update (remove from UI first for speed)
    final originalList = List.from(myWidgets);
    setState(() {
      myWidgets.removeWhere((w) => w['widgetName'] == widgetName);
    });

    // Call API
    bool success = await _service.removeWidgetFromUser(
      widget.userEmail,
      widgetName,
    );

    if (!success) {
      // Revert if failed
      setState(() => myWidgets = originalList);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to delete")));
    }
  }

  // --- HELPER FUNCTIONS ---
  String getLabel(String id) {
    return AppLocale.translations[id]?[selectedLanguage] ?? id;
  }

  void _changeLanguage(String lang) {
    setState(() => selectedLanguage = lang);
    Navigator.pop(context);
  }

  void _handleLogout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50,

      drawer: HamburgerMenu(
        userName: widget.userName,
        selectedLanguage: selectedLanguage,
        onLanguageChanged: _changeLanguage,
        onLogout: _handleLogout,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(
                      Icons.menu,
                      size: 28,
                      color: Colors.black87,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddWidgetDialog, // Opens the dynamic dialog
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(getLabel('Add Widget')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 1.5),
              const SizedBox(height: 20),

              // --- MAIN WIDGET LIST ---
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : myWidgets.isEmpty
                    ? Center(
                        child: Text(
                          getLabel('No widgets added yet'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      )
                    : ListView.separated(
                        itemCount: myWidgets.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          final item = myWidgets[index];
                          final String widgetName =
                              item['widgetName'] ?? "Unknown";

                          // Render UI based on name keywords
                          if (widgetName.contains("Search")) {
                            return buildSearchWidgetUI(widgetName);
                          } else if (widgetName.contains("Translate")) {
                            return buildTranslateWidgetUI(widgetName);
                          }

                          // Fallback UI for generic widgets
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widgetName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => removeWidget(widgetName),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI RENDERERS ---

  // Compact search module used for marketplace items tagged with "Search".
  Widget buildSearchWidgetUI(String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              IconButton(
                onPressed: () => removeWidget(title),
                icon: const Icon(Icons.close, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "${getLabel('Type here')} $title...",
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Visual placeholder for translation-type widgets.
  Widget buildTranslateWidgetUI(String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              IconButton(
                onPressed: () => removeWidget(title),
                icon: const Icon(Icons.close, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            height: 80,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text("Translate Text Area")),
          ),
        ],
      ),
    );
  }
}

// --- DYNAMIC ADD WIDGET DIALOG ---

class AddWidgetDialog extends StatefulWidget {
  final List<MarketWidget> marketplaceWidgets; // From DB
  final List<dynamic> userWidgets; // User's current list
  final Function(MarketWidget) onWidgetSelected;
  final Function(String) getLabel;

  const AddWidgetDialog({
    super.key,
    required this.marketplaceWidgets,
    required this.userWidgets,
    required this.onWidgetSelected,
    required this.getLabel,
  });

  @override
  State<AddWidgetDialog> createState() => _AddWidgetDialogState();
}

class _AddWidgetDialogState extends State<AddWidgetDialog> {
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    // Default to the first category found in the DB list
    if (widget.marketplaceWidgets.isNotEmpty) {
      selectedCategory = widget.marketplaceWidgets.first.visitCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Extract unique categories dynamically
    final categories = widget.marketplaceWidgets
        .map((e) => e.visitCategory)
        .toSet()
        .toList();

    // 2. Filter items: Match Category AND Not already owned by user
    final availableItems = widget.marketplaceWidgets.where((item) {
      final matchesCategory = item.visitCategory == selectedCategory;
      final alreadyOwned = widget.userWidgets.any(
        (u) => u['widgetName'] == item.visitName,
      );
      return matchesCategory && !alreadyOwned;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 350,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // --- LEFT: CATEGORY LIST ---
            Container(
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category == selectedCategory;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                      child: Row(
                        children: [
                          Icon(
                            // Simple logic to choose icon (can be expanded)
                            category.contains("Search")
                                ? Icons.search
                                : Icons.widgets,
                            size: 18,
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.black87,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // --- RIGHT: WIDGET OPTIONS ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$selectedCategory",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: availableItems.isEmpty
                          ? Center(
                              child: Text(
                                "No new widgets",
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            )
                          : ListView.builder(
                              itemCount: availableItems.length,
                              itemBuilder: (context, index) {
                                final item = availableItems[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor:
                                        item.widgetPaidOrFree == 'free'
                                        ? Colors.greenAccent
                                        : Colors.amber,
                                    child: const Icon(
                                      Icons.add,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(item.visitName),
                                  subtitle: Text(
                                    item.widgetPaidOrFree,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onTap: () => widget.onWidgetSelected(item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
