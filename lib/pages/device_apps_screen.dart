import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:io';

class DeviceAppsScreen extends StatefulWidget {
  const DeviceAppsScreen({super.key});

  @override
  State<DeviceAppsScreen> createState() => _DeviceAppsScreenState();
}

class _DeviceAppsScreenState extends State<DeviceAppsScreen> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  final List<String> _azIndex = List.generate(
    26,
    (i) => String.fromCharCode(65 + i),
  );
  Map<String, int> _letterPositions = {};
  String? _currentLetter;
  bool _isAnimatingToLetter = false;
  final Map<String, GlobalKey> _itemKeys = {};
  final Set<AppInfo> _selectedApps = {};

  @override
  void initState() {
    super.initState();
    _loadApps();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      if (!mounted) return;
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) {
        setState(() {
          _apps = apps;
          _filteredApps = apps;
          _isLoading = false;
        });
        _calculateLetterPositions(apps);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterApps(String query) {
    if (!mounted) return;
    setState(() {
      _searchQuery = query;
      _filteredApps =
          query.isEmpty
              ? _apps
              : _apps
                  .where(
                    (app) =>
                        app.name.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
    });
    if (query.isEmpty) _calculateLetterPositions(_apps);
  }

  void _calculateLetterPositions(List<AppInfo> apps) {
    _letterPositions.clear();
    for (int i = 0; i < apps.length; i++) {
      String firstLetter =
          apps[i].name.isNotEmpty ? apps[i].name[0].toUpperCase() : '';
      if (_azIndex.contains(firstLetter) &&
          !_letterPositions.containsKey(firstLetter)) {
        _letterPositions[firstLetter] = i;
      }
    }
  }

  void _onAppSelected(AppInfo app) {
    setState(() {
      if (_selectedApps.contains(app)) {
        _selectedApps.remove(app);
      } else {
        _selectedApps.add(app);
      }
    });
  }

  void _onDoneSelecting() {
    Navigator.pop(context, _selectedApps.toList());
  }

  void _onScroll() {
    if (_isAnimatingToLetter) return;
    final offset = _scrollController.offset;
    final index = (offset / 72.0).round().clamp(0, _filteredApps.length - 1);
    if (_filteredApps.isEmpty) return;
    final app = _filteredApps[index];
    final letter = app.name.isNotEmpty ? app.name[0].toUpperCase() : null;
    if (letter != null &&
        _azIndex.contains(letter) &&
        letter != _currentLetter) {
      setState(() {
        _currentLetter = letter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF2C1D4D),
      appBar: AppBar(
        // backgroundColor: const Color(0xFF2C1D4D),
        title: const Text(
          'Add Apps',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (_selectedApps.isNotEmpty)
            TextButton(
              onPressed: _onDoneSelecting,
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  onChanged: _filterApps,
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFF3A2C5F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Apps: ${_filteredApps.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (_selectedApps.isNotEmpty)
                      Text(
                        'Selected: ${_selectedApps.length}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                        : _filteredApps.isEmpty
                        ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No apps found'
                                : 'No apps match your search',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        )
                        : ListView.builder(
                          controller: _scrollController,
                          itemCount: _filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = _filteredApps[index];
                            final key = _itemKeys.putIfAbsent(
                              app.packageName,
                              () => GlobalKey(),
                            );
                            final firstLetter =
                                app.name.isNotEmpty
                                    ? app.name[0].toUpperCase()
                                    : '';
                            final showHeader =
                                index == 0 ||
                                (_filteredApps[index - 1].name.isNotEmpty &&
                                    _filteredApps[index - 1].name[0]
                                            .toUpperCase() !=
                                        firstLetter);
                            return Column(
                              key: key,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showHeader &&
                                    _azIndex.contains(firstLetter))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      firstLetter,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                Card(
                                  color:
                                      _selectedApps.contains(app)
                                          ? Colors.orange.withOpacity(0.2)
                                          : const Color(0xFF3A2C5F),
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    onTap: () => _onAppSelected(app),
                                    leading:
                                        app.icon != null
                                            ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                app.icon!,
                                                width: 40,
                                                height: 45,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                            : Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[700],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.smartphone,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            app.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Checkbox(
                                          value: _selectedApps.contains(app),
                                          onChanged:
                                              (val) => _onAppSelected(app),
                                          activeColor: Colors.orange,
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${app.packageName}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),

                                        if (app.versionName != null)
                                          Text(
                                            'v${app.versionName}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:installed_apps/installed_apps.dart';
// import 'package:installed_apps/app_info.dart';

// class DeviceAppsScreen extends StatefulWidget {
//   const DeviceAppsScreen({super.key});

//   @override
//   State<DeviceAppsScreen> createState() => _DeviceAppsScreenState();
// }

// class _DeviceAppsScreenState extends State<DeviceAppsScreen> {
//   List<AppInfo> _apps = [];
//   List<AppInfo> _filteredApps = [];
//   bool _isLoading = true;
//   String _searchQuery = '';
//   final ScrollController _scrollController = ScrollController();
//   final List<String> _azIndex = List.generate(
//     26,
//     (i) => String.fromCharCode(65 + i),
//   );
//   Map<String, int> _letterPositions = {};
//   String? _currentLetter;
//   bool _isAnimatingToLetter = false;
//   final Map<String, GlobalKey> _itemKeys = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadApps();
//     _scrollController.addListener(_onScroll);
//   }

//   @override
//   void dispose() {
//     _scrollController.removeListener(_onScroll);
//     _scrollController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadApps() async {
//     if (!mounted) return;
//     setState(() => _isLoading = true);

//     try {
//       List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
//       if (!mounted) return;
//       apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
//       if (mounted) {
//         setState(() {
//           _apps = apps;
//           _filteredApps = apps;
//           _isLoading = false;
//         });
//         _calculateLetterPositions(apps);
//       }
//     } catch (e) {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   void _filterApps(String query) {
//     if (!mounted) return;
//     setState(() {
//       _searchQuery = query;
//       _filteredApps =
//           query.isEmpty
//               ? _apps
//               : _apps
//                   .where(
//                     (app) =>
//                         app.name.toLowerCase().contains(query.toLowerCase()),
//                   )
//                   .toList();
//     });
//     if (query.isEmpty) _calculateLetterPositions(_apps);
//   }

//   void _calculateLetterPositions(List<AppInfo> apps) {
//     _letterPositions.clear();
//     for (int i = 0; i < apps.length; i++) {
//       String firstLetter =
//           apps[i].name.isNotEmpty ? apps[i].name[0].toUpperCase() : '';
//       if (_azIndex.contains(firstLetter) &&
//           !_letterPositions.containsKey(firstLetter)) {
//         _letterPositions[firstLetter] = i;
//       }
//     }
//   }

//   void _onAppSelected(AppInfo app) {
//     Navigator.pop(context, app);
//   }

//   //SIDE
//   // void _scrollToLetter(String letter) async {
//   //   if (_letterPositions.containsKey(letter)) {
//   //     final index = _letterPositions[letter]!;
//   //     final app = _filteredApps[index];
//   //     final key = _itemKeys[app.packageName];
//   //     if (key != null && key.currentContext != null) {
//   //       setState(() {
//   //         _isAnimatingToLetter = true;
//   //         _currentLetter = letter;
//   //       });
//   //       await Scrollable.ensureVisible(
//   //         key.currentContext!,
//   //         duration: const Duration(milliseconds: 400),
//   //         curve: Curves.easeInOutCubic,
//   //         alignment: 0.1,
//   //       );
//   //       Future.delayed(const Duration(milliseconds: 400), () {
//   //         if (mounted) setState(() => _isAnimatingToLetter = false);
//   //       });
//   //     }
//   //   }
//   // }

//   void _onScroll() {
//     if (_isAnimatingToLetter) return;
//     final offset = _scrollController.offset;
//     final index = (offset / 72.0).round().clamp(0, _filteredApps.length - 1);
//     if (_filteredApps.isEmpty) return;
//     final app = _filteredApps[index];
//     final letter = app.name.isNotEmpty ? app.name[0].toUpperCase() : null;
//     if (letter != null &&
//         _azIndex.contains(letter) &&
//         letter != _currentLetter) {
//       setState(() {
//         _currentLetter = letter;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF2C1D4D),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF2C1D4D),
//         title: const Text(
//           'Add Apps',
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         iconTheme: const IconThemeData(color: Colors.white),
//         elevation: 0,
//       ),
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: TextField(
//                   style: const TextStyle(color: Colors.white),
//                   onChanged: _filterApps,
//                   decoration: InputDecoration(
//                     hintText: 'Search apps...',
//                     hintStyle: TextStyle(color: Colors.grey[400]),
//                     prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
//                     filled: true,
//                     fillColor: const Color(0xFF3A2C5F),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide: BorderSide.none,
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(vertical: 16),
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child:
//                     _isLoading
//                         ? const Center(
//                           child: CircularProgressIndicator(color: Colors.white),
//                         )
//                         : _filteredApps.isEmpty
//                         ? Center(
//                           child: Text(
//                             _searchQuery.isEmpty
//                                 ? 'No apps found'
//                                 : 'No apps match your search',
//                             style: TextStyle(
//                               color: Colors.grey[600],
//                               fontSize: 16,
//                             ),
//                           ),
//                         )
//                         : ListView.builder(
//                           controller: _scrollController,
//                           itemCount: _filteredApps.length,
//                           itemBuilder: (context, index) {
//                             final app = _filteredApps[index];
//                             final key = _itemKeys.putIfAbsent(
//                               app.packageName,
//                               () => GlobalKey(),
//                             );
//                             final firstLetter =
//                                 app.name.isNotEmpty
//                                     ? app.name[0].toUpperCase()
//                                     : '';
//                             final showHeader =
//                                 index == 0 ||
//                                 (_filteredApps[index - 1].name.isNotEmpty &&
//                                     _filteredApps[index - 1].name[0]
//                                             .toUpperCase() !=
//                                         firstLetter);
//                             return Column(
//                               key: key,
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 if (showHeader &&
//                                     _azIndex.contains(firstLetter))
//                                   Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 16,
//                                       vertical: 4,
//                                     ),
//                                     child: Text(
//                                       firstLetter,
//                                       style: const TextStyle(
//                                         color: Colors.white70,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16,
//                                       ),
//                                     ),
//                                   ),
//                                 Card(
//                                   color: const Color(0xFF3A2C5F),
//                                   elevation: 2,
//                                   margin: const EdgeInsets.symmetric(
//                                     horizontal: 12,
//                                     vertical: 4,
//                                   ),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   child: ListTile(
//                                     onTap: () => _onAppSelected(app),
//                                     leading:
//                                         app.icon != null
//                                             ? ClipRRect(
//                                               borderRadius:
//                                                   BorderRadius.circular(8),
//                                               child: Image.memory(
//                                                 app.icon!,
//                                                 width: 40,
//                                                 height: 40,
//                                                 fit: BoxFit.cover,
//                                               ),
//                                             )
//                                             : Container(
//                                               width: 40,
//                                               height: 40,
//                                               decoration: BoxDecoration(
//                                                 color: Colors.grey[700],
//                                                 borderRadius:
//                                                     BorderRadius.circular(8),
//                                               ),
//                                               child: const Icon(
//                                                 Icons.smartphone,
//                                                 color: Colors.white,
//                                                 size: 24,
//                                               ),
//                                             ),
//                                     title: Text(
//                                       app.name,
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                     // trailing: const Icon(
//                                     //   Icons.arrow_forward_ios,
//                                     //   color: Colors.white,
//                                     //   size: 18,
//                                     // ),
//                                   ),
//                                 ),
//                               ],
//                             );
//                           },
//                         ),
//               ),
//             ],
//           ),

//           // A-Z index bar (hide when searching)
//           // if (_searchQuery.isEmpty && _filteredApps.isNotEmpty && !_isLoading)
//           //   Positioned(
//           //     right: 10,
//           //     top: 80, // below the search bar (approximate height)
//           //     bottom: 24, // leave some space at the bottom
//           //     child: LayoutBuilder(
//           //       builder: (context, constraints) {
//           //         final indexHeight = _azIndex.length * 20.0;
//           //         final availableHeight = constraints.maxHeight;
//           //         final topPadding =
//           //             (availableHeight > indexHeight)
//           //                 ? (availableHeight - indexHeight) / 2
//           //                 : 0.0;
//           //         return Container(
//           //           width: 40,
//           //           decoration: BoxDecoration(
//           //             color: Colors.white.withOpacity(0.08),
//           //             borderRadius: BorderRadius.circular(16),
//           //             border: Border.all(color: Colors.white24, width: 1),
//           //             boxShadow: [
//           //               BoxShadow(
//           //                 color: Colors.black.withOpacity(0.08),
//           //                 blurRadius: 8,
//           //                 offset: const Offset(2, 2),
//           //               ),
//           //             ],
//           //           ),
//           //           alignment: Alignment.center,
//           //           padding: EdgeInsets.only(
//           //             top: topPadding,
//           //             bottom: topPadding,
//           //           ),
//           //           child: SingleChildScrollView(
//           //             physics: const NeverScrollableScrollPhysics(),
//           //             child: Column(
//           //               mainAxisSize: MainAxisSize.min,
//           //               children:
//           //                   _azIndex.map((letter) {
//           //                     final isActive = _letterPositions.containsKey(
//           //                       letter,
//           //                     );
//           //                     final isSelected = letter == _currentLetter;
//           //                     return GestureDetector(
//           //                       onTap:
//           //                           isActive
//           //                               ? () => _scrollToLetter(letter)
//           //                               : null,
//           //                       child: AnimatedContainer(
//           //                         duration: const Duration(milliseconds: 200),
//           //                         padding: const EdgeInsets.symmetric(
//           //                           vertical: 1,
//           //                           horizontal: 1,
//           //                         ),
//           //                         // margin: const EdgeInsets.symmetric(
//           //                         //   vertical: 2,
//           //                         // ),
//           //                         decoration: BoxDecoration(
//           //                           color:
//           //                               isSelected && isActive
//           //                                   ? Colors.orange
//           //                                   : Colors.transparent,
//           //                           // borderRadius: BorderRadius.circular(8),
//           //                         ),
//           //                         child: Text(
//           //                           letter,
//           //                           style: TextStyle(
//           //                             color:
//           //                                 isSelected
//           //                                     ? Colors.white
//           //                                     : isActive
//           //                                     ? Colors.white
//           //                                     : Colors.white24,
//           //                             fontWeight: FontWeight.bold,
//           //                             fontSize: 13,
//           //                           ),
//           //                         ),
//           //                       ),
//           //                     );
//           //                   }).toList(),
//           //             ),
//           //           ),
//           //         );
//           //       },
//           //     ),
//           //   ),
//         ],
//       ),
//     );
//   }
// }
