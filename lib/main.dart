import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('favorites');
  runApp(const ProviderScope(child: VegRecipeApp()));
}

class VegRecipeApp extends ConsumerWidget {
  const VegRecipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: darkMode ? Brightness.dark : Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: darkMode ? AppColors.darkSurface : Colors.white,
    );

    return MaterialApp(
      title: 'Veg Recipe AI',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(scheme),
      darkTheme: _theme(scheme),
      home: const SplashScreen(),
    );
  }

  ThemeData _theme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: '.SF Pro Text',
      scaffoldBackgroundColor: scheme.brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          height: 1.16,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.42,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}

class AppColors {
  static const primary = Color(0xFFFF7A00);
  static const secondary = Color(0xFFFFE8D6);
  static const accent = Color(0xFF6C63FF);
  static const light = Color(0xFFF8F9FB);
  static const dark = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const green = Color(0xFF31A66A);
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 22.0;
  static const full = 999.0;
}

final recipeRepositoryProvider = Provider((ref) => RecipeRepository());
final aiRepositoryProvider = Provider((ref) => AiRepository());
final darkModeProvider = StateProvider<bool>((ref) => false);
final selectedTabProvider = StateProvider<int>((ref) => 0);
final selectedCategoryProvider = StateProvider<String>((ref) => 'Vegetarian');
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
      (ref) => RecentSearchesNotifier()..load(),
    );
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Map<String, RecipeSummary>>(
      (ref) => FavoritesNotifier()..load(),
    );
final mealPlannerProvider =
    StateNotifierProvider<MealPlannerNotifier, Map<String, PlannedMeal>>(
      (ref) => MealPlannerNotifier()..load(),
    );

final recipesProvider = FutureProvider<List<RecipeSummary>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  return ref.watch(recipeRepositoryProvider).vegetarianRecipes(category);
});

final searchProvider = FutureProvider.family<List<RecipeSummary>, String>((
  ref,
  query,
) async {
  if (query.trim().isEmpty) return const [];
  return ref.watch(recipeRepositoryProvider).search(query.trim());
});

final recipeDetailsProvider = FutureProvider.family<RecipeDetail, String>((
  ref,
  id,
) {
  return ref.watch(recipeRepositoryProvider).detail(id);
});

class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.name,
    required this.image,
    this.category = 'Vegetarian',
    this.area = 'Global',
  });

  final String id;
  final String name;
  final String image;
  final String category;
  final String area;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'category': category,
    'area': area,
  };

  factory RecipeSummary.fromJson(Map<String, dynamic> json) => RecipeSummary(
    id: '${json['idMeal'] ?? json['id']}',
    name: '${json['strMeal'] ?? json['name']}',
    image: '${json['strMealThumb'] ?? json['image']}',
    category: '${json['strCategory'] ?? json['category'] ?? 'Vegetarian'}',
    area: '${json['strArea'] ?? json['area'] ?? 'Global'}',
  );
}

class RecipeDetail extends RecipeSummary {
  const RecipeDetail({
    required super.id,
    required super.name,
    required super.image,
    required this.instructions,
    required this.ingredients,
    required this.youtube,
    required super.category,
    required super.area,
  });

  final String instructions;
  final List<String> ingredients;
  final String youtube;

  factory RecipeDetail.fromMeal(Map<String, dynamic> meal) {
    final ingredients = <String>[];
    for (var i = 1; i <= 20; i++) {
      final ingredient = '${meal['strIngredient$i'] ?? ''}'.trim();
      final measure = '${meal['strMeasure$i'] ?? ''}'.trim();
      if (ingredient.isNotEmpty) {
        ingredients.add(
          [measure, ingredient].where((e) => e.isNotEmpty).join(' '),
        );
      }
    }
    return RecipeDetail(
      id: '${meal['idMeal']}',
      name: '${meal['strMeal']}',
      image: '${meal['strMealThumb']}',
      instructions: '${meal['strInstructions'] ?? ''}',
      ingredients: ingredients,
      youtube: '${meal['strYoutube'] ?? ''}',
      category: '${meal['strCategory'] ?? 'Vegetarian'}',
      area: '${meal['strArea'] ?? 'Global'}',
    );
  }
}

class PlannedMeal {
  const PlannedMeal({required this.day, required this.recipe});

  final String day;
  final RecipeSummary recipe;

  Map<String, dynamic> toJson() => {'day': day, 'recipe': recipe.toJson()};

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
    day: '${json['day']}',
    recipe: RecipeSummary.fromJson(json['recipe']),
  );
}

class AiRecipe {
  const AiRecipe({
    required this.title,
    required this.ingredients,
    required this.steps,
    required this.calories,
    required this.dietNote,
  });

  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String calories;
  final String dietNote;

  factory AiRecipe.fromText(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-*\d.]+\s*'), ''))
        .where((line) => line.isNotEmpty)
        .toList();
    final title = lines.firstWhere(
      (line) =>
          !line.toLowerCase().contains('ingredient') &&
          !line.toLowerCase().contains('step'),
      orElse: () => 'AI Vegetarian Recipe',
    );
    final ingredients = <String>[];
    final steps = <String>[];
    var section = '';
    var calories = 'Approx. 360 kcal per serving';
    var note = 'Pair with protein-rich sides for a balanced plate.';
    for (final line in lines.skip(1)) {
      final lower = line.toLowerCase();
      if (lower.contains('ingredient')) {
        section = 'ingredients';
      } else if (lower.contains('step') || lower.contains('instruction')) {
        section = 'steps';
      } else if (lower.contains('calorie') || lower.contains('kcal')) {
        calories = line;
        section = '';
      } else if (lower.contains('diet') ||
          lower.contains('note') ||
          lower.contains('balanced')) {
        note = line;
        section = '';
      } else if (section == 'ingredients') {
        ingredients.add(line);
      } else if (section == 'steps') {
        steps.add(line);
      }
    }
    return AiRecipe(
      title: title,
      ingredients: ingredients.isEmpty
          ? ['Seasonal vegetables', 'Whole grains', 'Fresh herbs']
          : ingredients,
      steps: steps.isEmpty
          ? ['Prep ingredients.', 'Cook gently with spices.', 'Serve warm.']
          : steps,
      calories: calories,
      dietNote: note,
    );
  }
}

class RecipeRepository {
  static const _base = 'https://www.themealdb.com/api/json/v1/1/';
  final _listCache = <String, List<RecipeSummary>>{};
  final _detailCache = <String, RecipeDetail>{};

  Future<List<RecipeSummary>> vegetarianRecipes(String category) async {
    if (_listCache.containsKey(category)) return _listCache[category]!;
    final data = await _get('filter.php?c=Vegetarian');
    final meals = (data['meals'] as List?) ?? [];
    final allItems = meals
        .whereType<Map<String, dynamic>>()
        .map(RecipeSummary.fromJson)
        .toList();
    final lowerCategory = category.toLowerCase();
    final filtered = category == 'Vegetarian'
        ? allItems
        : allItems
              .where(
                (recipe) =>
                    recipe.name.toLowerCase().contains(lowerCategory) ||
                    recipe.area.toLowerCase().contains(lowerCategory) ||
                    recipe.category.toLowerCase().contains(lowerCategory),
              )
              .toList();
    final items = (filtered.isEmpty ? allItems : filtered).take(30).toList();
    _listCache[category] = items;
    return items;
  }

  Future<List<RecipeSummary>> search(String query) async {
    final data = await _get('search.php?s=${Uri.encodeQueryComponent(query)}');
    final meals = ((data['meals'] as List?) ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .where(_isVegetarianMeal)
        .map(RecipeSummary.fromJson)
        .toList();
    return meals;
  }

  Future<RecipeDetail> detail(String id) async {
    if (_detailCache.containsKey(id)) return _detailCache[id]!;
    final data = await _get('lookup.php?i=$id');
    final meals = (data['meals'] as List?) ?? [];
    if (meals.isEmpty) throw Exception('Recipe not found');
    final detail = RecipeDetail.fromMeal(meals.first);
    if (!_isVegetarianMeal(meals.first)) {
      throw Exception('This item is not marked as vegetarian.');
    }
    _detailCache[id] = detail;
    return detail;
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    try {
      final response = await http
          .get(Uri.parse('$_base$endpoint'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Recipe service failed (${response.statusCode})');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } catch (_) {
      throw Exception(
        'You appear to be offline or the recipe service is unavailable.',
      );
    }
  }

  bool _isVegetarianMeal(Map<String, dynamic> meal) {
    final category = '${meal['strCategory'] ?? ''}'.toLowerCase();
    return category == 'vegetarian' || category == 'vegan';
  }
}

class AiRepository {
  Future<String> generateRecipe(String ingredients) async {
    if (_geminiApiKey.isEmpty) {
      debugPrint('Gemini API key missing. Using offline demo recipe.');
      return _offlineRecipe(ingredients);
    }
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$_geminiApiKey',
    );
    final prompt =
        'Create one vegetarian recipe using these ingredients: $ingredients. '
        'Return title, ingredients, steps, calories, and a balanced diet note.';
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 18));
      debugPrint('Gemini status: ${response.statusCode}');
      debugPrint(
        'Gemini body: ${response.body.length > 900 ? response.body.substring(0, 900) : response.body}',
      );
      if (response.statusCode != 200) {
        throw Exception('Gemini failed with status ${response.statusCode}.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
          ?.toString();
      if (text == null || text.trim().isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }
      return text;
    } on TimeoutException {
      throw Exception('Gemini timed out. Please try again.');
    } on FormatException {
      throw Exception('Gemini returned an invalid response.');
    } catch (error) {
      throw Exception('Gemini request failed: $error');
    }
  }

  Future<String> mealPlanSuggestion(List<RecipeSummary> recipes) async {
    final names = recipes.map((e) => e.name).take(8).join(', ');
    if (_geminiApiKey.isEmpty) {
      return 'Balanced pick: rotate lentils, greens, yogurt, grains, and one light salad. Try $names across the week.';
    }
    return generateRecipe('weekly vegetarian meal plan using $names');
  }

  String _offlineRecipe(String ingredients) {
    final clean = ingredients.trim().isEmpty
        ? 'seasonal vegetables, rice, lentils'
        : ingredients;
    return '''
Garden Bowl Masala

Ingredients
- $clean
- 1 tsp cumin
- 1 tbsp olive oil
- Fresh coriander
- Lemon juice

Steps
1. Saute cumin in oil until aromatic.
2. Add chopped vegetables and cook until tender.
3. Fold in cooked grains or lentils.
4. Finish with coriander and lemon.

Calories
Approx. 360 kcal per serving.

Diet note
Pair with curd or sprouts for extra protein.
''';
  }
}

class FavoritesNotifier extends StateNotifier<Map<String, RecipeSummary>> {
  FavoritesNotifier() : super({});

  Future<void> load() async {
    final box = await _favoritesBox();
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList('favorites_v2') ?? [];
    if (box.isEmpty && legacy.isNotEmpty) {
      for (final item in legacy) {
        if (item.trim().isEmpty) continue;
        final recipe = RecipeSummary.fromJson(
          jsonDecode(item) as Map<String, dynamic>,
        );
        await box.put(recipe.id, jsonEncode(recipe.toJson()));
      }
      await prefs.remove('favorites_v2');
    }
    final raw = box.values.toList();
    final recipes = raw
        .where((item) => item.trim().isNotEmpty)
        .map(
          (item) =>
              RecipeSummary.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
    state = {for (final recipe in recipes) recipe.id: recipe};
  }

  Future<void> toggle(RecipeSummary recipe) async {
    final next = {...state};
    final box = await _favoritesBox();
    if (next.containsKey(recipe.id)) {
      next.remove(recipe.id);
      await box.delete(recipe.id);
    } else {
      next[recipe.id] = recipe;
      await box.put(recipe.id, jsonEncode(recipe.toJson()));
    }
    state = next;
  }

  Future<Box<String>> _favoritesBox() async {
    if (Hive.isBoxOpen('favorites')) return Hive.box<String>('favorites');
    return Hive.openBox<String>('favorites');
  }
}

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('recentSearches') ?? [];
  }

  Future<void> add(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    state = [
      clean,
      ...state.where((e) => e.toLowerCase() != clean.toLowerCase()),
    ].take(6).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', state);
  }
}

class MealPlannerNotifier extends StateNotifier<Map<String, PlannedMeal>> {
  MealPlannerNotifier() : super({});

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mealPlanner');
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    state = decoded.map(
      (key, value) => MapEntry(key, PlannedMeal.fromJson(value)),
    );
  }

  Future<void> setMeal(String day, RecipeSummary recipe) async {
    state = {...state, day: PlannedMeal(day: day, recipe: recipe)};
    await _save();
  }

  Future<void> clear(String day) async {
    state = {...state}..remove(day);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'mealPlanner',
      jsonEncode(state.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _navigationTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(_slideFade(const RecipeShell()));
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOut,
            ),
            child: ScaleTransition(
              scale: Tween(begin: .86, end: 1.0).animate(
                CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .34),
                      ),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Veg Recipe AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fresh ideas from pantry to plate',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecipeShell extends ConsumerWidget {
  const RecipeShell({super.key});

  static const _pages = [
    HomeScreen(),
    SearchScreen(),
    AiRecipeScreen(),
    MealPlannerScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedTabProvider);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _pages[index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          HapticFeedback.selectionClick();
          ref.read(selectedTabProvider.notifier).state = value;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider);
    final categories = ['Vegetarian', 'Indian', 'Salad', 'Pasta', 'Fast Food'];
    final selected = ref.watch(selectedCategoryProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(recipesProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1400&q=80',
                    fit: BoxFit.cover,
                  ),
                  Container(color: Colors.black.withValues(alpha: .28)),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'Veg Recipe AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GlassPanel(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () =>
                                  ref.read(selectedTabProvider.notifier).state =
                                      1,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      'Search vegetarian recipes',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        return ChoiceChip(
                          label: Text(item),
                          selected: selected == item,
                          onSelected: (_) =>
                              ref
                                      .read(selectedCategoryProvider.notifier)
                                      .state =
                                  item,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  AiBanner(
                    onTap: () =>
                        ref.read(selectedTabProvider.notifier).state = 2,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Featured picks',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  recipes.when(
                    loading: () => const RecipeCarouselSkeleton(),
                    error: (error, _) => ErrorPanel(
                      message: 'Recipes are unavailable right now.',
                      onRetry: () => ref.invalidate(recipesProvider),
                    ),
                    data: (items) =>
                        FeaturedCarousel(items: items.take(8).toList()),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Vegetarian recipes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          recipes.when(
            loading: () => const RecipeGridSkeleton(),
            error: (error, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: ErrorPanel(
                  message:
                      'Could not load vegetarian recipes. Please try again.',
                  onRetry: () => ref.invalidate(recipesProvider),
                ),
              ),
            ),
            data: (items) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              sliver: SliverGrid.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 230,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: .74,
                ),
                itemBuilder: (context, index) =>
                    RecipeCard(recipe: items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturedCarousel extends StatelessWidget {
  const FeaturedCarousel({super.key, required this.items});

  final List<RecipeSummary> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const ErrorPanel(message: 'No vegetarian recipes found.');
    }
    return SizedBox(
      height: 190,
      child: PageView.builder(
        controller: PageController(viewportFraction: .86),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final recipe = items[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).push(_slideFade(RecipeDetailScreen(recipe: recipe))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'recipe-${recipe.id}',
                      child: RecipeImage(url: recipe.image),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .72),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Text(
                        recipe.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RecipeCard extends ConsumerWidget {
  const RecipeCard({super.key, required this.recipe});

  final RecipeSummary recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(favoritesProvider).containsKey(recipe.id);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .96, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(
          context,
        ).push(_slideFade(RecipeDetailScreen(recipe: recipe))),
        child: SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                      child: Hero(
                        tag: 'recipe-${recipe.id}',
                        child: RecipeImage(url: recipe.image),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton.filledTonal(
                        tooltip: favorite ? 'Remove favorite' : 'Add favorite',
                        onPressed: () =>
                            ref.read(favoritesProvider.notifier).toggle(recipe),
                        icon: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        Text(
                          ' ${(4.2 + (recipe.id.hashCode.abs() % 7) / 10).toStringAsFixed(1)}',
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.eco_rounded,
                          color: AppColors.green,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final RecipeSummary recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(recipeDetailsProvider(recipe.id));
    final favorite = ref.watch(favoritesProvider).containsKey(recipe.id);
    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: ErrorPanel(
              message: 'This recipe could not be opened.',
              onRetry: () => ref.invalidate(recipeDetailsProvider(recipe.id)),
            ),
          ),
        ),
        data: (item) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              actions: [
                IconButton.filledTonal(
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).toggle(item),
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                ),
                IconButton.filledTonal(
                  onPressed: () => _shareFallback(context, item),
                  icon: const Icon(Icons.share_outlined),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: 'recipe-${recipe.id}',
                  child: RecipeImage(url: item.image),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const Icon(Icons.star_rounded, color: AppColors.primary),
                      const Text(' 4.8'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      InfoPill(icon: Icons.eco_rounded, label: item.category),
                      InfoPill(icon: Icons.public_rounded, label: item.area),
                      InfoPill(
                        icon: Icons.local_fire_department_rounded,
                        label: '${320 + item.ingredients.length * 18} kcal',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...item.ingredients.map(
                    (ingredient) => ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: AppColors.green,
                      ),
                      title: Text(ingredient),
                      dense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Steps',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...item.instructions
                      .split(RegExp(r'\r?\n'))
                      .where((line) => line.trim().isNotEmpty)
                      .map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SoftCard(child: Text(line.trim())),
                        ),
                      ),
                  const SizedBox(height: 18),
                  if (item.youtube.isNotEmpty)
                    GradientButton(
                      icon: Icons.play_circle_outline,
                      label: 'Watch on YouTube',
                      onPressed: () => launchUrl(Uri.parse(item.youtube)),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareFallback(BuildContext context, RecipeDetail item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.name}: ${item.youtube.isEmpty ? 'Recipe saved locally' : item.youtube}',
        ),
      ),
    );
  }
}

class AiRecipeScreen extends ConsumerStatefulWidget {
  const AiRecipeScreen({super.key});

  @override
  ConsumerState<AiRecipeScreen> createState() => _AiRecipeScreenState();
}

class _AiRecipeScreenState extends ConsumerState<AiRecipeScreen> {
  final _controller = TextEditingController(
    text: 'paneer, spinach, tomato, rice',
  );
  final _speech = stt.SpeechToText();
  bool _loading = false;
  bool _listening = false;
  AiRecipe? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(aiRepositoryProvider)
          .generateRecipe(_controller.text);
      if (!mounted) return;
      setState(() {
        _result = AiRecipe.fromText(result);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _listen() async {
    final available = await _speech.initialize();
    if (!available) return;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() => _controller.text = result.recognizedWords);
      },
    );
    Future.delayed(const Duration(seconds: 4), () {
      _speech.stop();
      if (mounted) setState(() => _listening = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'AI Kitchen',
      subtitle: 'Build vegetarian recipes from what you have.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          Stack(
            children: [
              GlassPanel(
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter ingredients',
                        prefixIcon: Icon(Icons.kitchen_outlined),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.sm,
                        0,
                        AppSpace.sm,
                        AppSpace.sm,
                      ),
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Voice input',
                            onPressed: _listen,
                            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                          ),
                          const Spacer(),
                          GradientButton(
                            icon: Icons.auto_awesome,
                            label: 'Generate',
                            onPressed: _loading ? null : _generate,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: .04),
                      child: const Center(
                        child: CupertinoActivityIndicator(radius: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const RecipeResponseSkeleton()
          else if (_error != null)
            ErrorPanel(message: _error!, onRetry: _generate)
          else if (_result != null)
            AiRecipeResult(recipe: _result!),
        ],
      ),
    );
  }
}

class AiRecipeResult extends StatelessWidget {
  const AiRecipeResult({super.key, required this.recipe});

  final AiRecipe recipe;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: Column(
        key: ValueKey(recipe.title),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftCard(
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _AiSection(
            title: 'Ingredients',
            icon: Icons.shopping_basket_outlined,
            items: recipe.ingredients,
          ),
          const SizedBox(height: AppSpace.md),
          _AiSection(
            title: 'Steps',
            icon: Icons.format_list_numbered_rounded,
            items: recipe.steps,
          ),
          const SizedBox(height: AppSpace.md),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoPill(
                  icon: Icons.local_fire_department_rounded,
                  label: recipe.calories,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(recipe.dietNote),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpace.sm),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: AppColors.green),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    _debounce = Timer(const Duration(milliseconds: 260), () {
      ref.read(recentSearchesProvider.notifier).add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentSearchesProvider);
    final results = ref.watch(searchProvider(_query));
    final trending = ['Paneer', 'Pasta', 'Soup', 'Salad', 'Curry', 'Rice'];
    return AppPage(
      title: 'Search',
      subtitle: 'Find vegetarian meals in real time.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              filled: true,
              hintText: 'Try pasta, curry, soup',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty && results.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_query.isEmpty) ...[
            if (recent.isNotEmpty)
              Text(
                'Recent searches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (recent.isNotEmpty) const SizedBox(height: 10),
            if (recent.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recent
                    .map(
                      (item) => ActionChip(
                        label: Text(item),
                        onPressed: () {
                          _controller.text = item;
                          _onChanged(item);
                        },
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 18),
            Text(
              'Suggested searches',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trending
                  .map(
                    (item) => ActionChip(
                      label: Text(item),
                      onPressed: () {
                        _controller.text = item;
                        _onChanged(item);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 28),
            const EmptyState(
              icon: Icons.manage_search_rounded,
              title: 'Search vegetarian recipes',
              message:
                  'Results appear instantly as you type, with strict vegetarian filtering.',
            ),
          ],
          if (_query.isNotEmpty)
            results.when(
              loading: () => const RecipeGridSkeletonBox(),
              error: (error, _) => ErrorPanel(
                message:
                    'Search is having trouble. Check your connection and try again.',
                onRetry: () => ref.invalidate(searchProvider(_query)),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.eco_outlined,
                      title: 'No results found',
                      message:
                          'Try a broader ingredient like paneer, rice, soup, or pasta.',
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 230,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: .74,
                          ),
                      itemBuilder: (context, index) =>
                          RecipeCard(recipe: items[index]),
                    ),
            ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(favoritesProvider).values.toList();
    return AppPage(
      title: 'Favorites',
      subtitle: 'Saved vegetarian meals stay on this device.',
      child: saved.isEmpty
          ? const Center(child: ErrorPanel(message: 'No favorites saved yet.'))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              itemCount: saved.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: .74,
              ),
              itemBuilder: (context, index) => Dismissible(
                key: ValueKey(saved[index].id),
                onDismissed: (_) =>
                    ref.read(favoritesProvider.notifier).toggle(saved[index]),
                child: RecipeCard(recipe: saved[index]),
              ),
            ),
    );
  }
}

class MealPlannerScreen extends ConsumerWidget {
  const MealPlannerScreen({super.key});

  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(mealPlannerProvider);
    final recipes = ref.watch(recipesProvider).valueOrNull ?? [];
    return AppPage(
      title: 'Meal Planner',
      subtitle: 'Drag a recipe into a day slot.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final day = days[index];
                final meal = plan[day];
                return DragTarget<RecipeSummary>(
                  onAcceptWithDetails: (details) => ref
                      .read(mealPlannerProvider.notifier)
                      .setMeal(day, details.data),
                  builder: (context, candidateData, rejectedData) => SoftCard(
                    width: 138,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        Text(
                          meal?.recipe.name ?? 'Drop meal',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (meal != null)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: IconButton(
                              onPressed: () => ref
                                  .read(mealPlannerProvider.notifier)
                                  .clear(day),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          AiBanner(
            title: 'Balanced diet assistant',
            subtitle: 'Use AI ideas to round out the week.',
            onTap: () async {
              final text = await ref
                  .read(aiRepositoryProvider)
                  .mealPlanSuggestion(recipes);
              if (!context.mounted) return;
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(text),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Drag recipes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...recipes
              .take(12)
              .map(
                (recipe) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Draggable<RecipeSummary>(
                    data: recipe,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: 240,
                        height: 86,
                        child: MealTile(recipe: recipe),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: .4,
                      child: MealTile(recipe: recipe),
                    ),
                    child: MealTile(recipe: recipe),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(darkModeProvider);
    return AppPage(
      title: 'Profile',
      subtitle: 'Preferences and app settings.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .26),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vegetarian Chef',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Smart recipes, favorites, and planning',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SettingsGroup(
            title: 'Appearance',
            children: [
              SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Switch between light and dark surfaces.',
                trailing: CupertinoSwitch(
                  value: dark,
                  onChanged: (value) =>
                      ref.read(darkModeProvider.notifier).state = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SettingsGroup(
            title: 'AI & Data',
            children: [
              SettingsTile(
                icon: _geminiApiKey.isEmpty
                    ? Icons.key_off_outlined
                    : Icons.verified_user_outlined,
                title: 'Gemini API Key',
                subtitle: _geminiApiKey.isEmpty
                    ? 'Missing. Run with --dart-define=GEMINI_API_KEY=YOUR_NEW_API_KEY.'
                    : 'Loaded from dart-define.',
              ),
              const SettingsTile(
                icon: Icons.storage_outlined,
                title: 'Favorites Storage',
                subtitle: 'Saved recipes are persisted locally with Hive.',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SettingsGroup(
            title: 'App',
            children: [
              const SettingsTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle:
                    'Veg-only recipes, AI suggestions, favorites, and weekly planning.',
              ),
              SettingsTile(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Demo profile session.',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo profile signed out.')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpace.sm,
            bottom: AppSpace.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: .45),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        toolbarHeight: 78,
      ),
      body: child,
    );
  }
}

class AiBanner extends StatelessWidget {
  const AiBanner({
    super.key,
    required this.onTap,
    this.title = 'AI suggestion banner',
    this.subtitle = 'Turn pantry ingredients into dinner in seconds.',
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            },
      child: AnimatedScale(
        scale: _pressed ? .95 : 1,
        duration: const Duration(milliseconds: 120),
        child: Opacity(
          opacity: widget.onPressed == null ? .55 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: (dark ? Colors.white : Colors.white).withValues(
              alpha: dark ? .09 : .72,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .24)),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .18 : .055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class RecipeImage extends StatelessWidget {
  const RecipeImage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(color: Colors.white),
      ),
      errorWidget: (context, url, error) => const ColoredBox(
        color: AppColors.secondary,
        child: Icon(Icons.restaurant, color: AppColors.primary, size: 42),
      ),
    );
  }
}

class MealTile extends StatelessWidget {
  const MealTile({super.key, required this.recipe});

  final RecipeSummary recipe;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 66,
              height: 66,
              child: RecipeImage(url: recipe.image),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recipe.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const Icon(Icons.drag_indicator),
        ],
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: AppColors.secondary.withValues(alpha: .7),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(message)),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 260),
      child: SoftCard(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeGridSkeleton extends StatelessWidget {
  const RecipeGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverPadding(
      padding: EdgeInsets.all(18),
      sliver: SliverGridSkeleton(),
    );
  }
}

class RecipeGridSkeletonBox extends StatelessWidget {
  const RecipeGridSkeletonBox({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: .74,
      ),
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}

class SliverGridSkeleton extends StatelessWidget {
  const SliverGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: .74,
      ),
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}

class RecipeCarouselSkeleton extends StatelessWidget {
  const RecipeCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 190, child: SkeletonCard());
}

class RecipeResponseSkeleton extends StatelessWidget {
  const RecipeResponseSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          4,
          (_) => Container(
            height: 78,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

PageRouteBuilder<T> _slideFade<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(.08, .02), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        ),
  );
}
