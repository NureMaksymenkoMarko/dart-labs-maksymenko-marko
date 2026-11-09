/// Рецепт з датою внесення та інгредієнтами.
typedef Recipe = ({String title, String cuisine, int minutes, String difficulty, List<Ingredient> ingredients, DateTime date});

/// Інгредієнт і одиниця вимірювання.
typedef Ingredient = ({String name, double quantity, String unit});

/// Результат розбору рядка із повідомленнями про помилки.
typedef ParseResult = ({Recipe? recipe, List<String> errors});

const int quickLimit = 60;
const int maxMinutes = 360;
const Set<String> difficulties = {'легко', 'середньо', 'складно'};
const Set<String> units = {'г', 'кг', 'мл', 'л', 'шт'};

final _ingredient = RegExp(r'^(?<name>[А-Яа-яІіЇїЄєҐґA-Za-z][А-Яа-яІіЇїЄєҐґA-Za-z0-9 -]*):(?<quantity>\d+(?:[.,]\d+)?)(?<unit>г|кг|мл|л|шт)$');
final _mask = RegExp(r'(?<name>[А-Яа-яІіЇїЄєҐґA-Za-z][А-Яа-яІіЇїЄєҐґA-Za-z0-9 -]*):(?<quantity>\d+(?:[.,]\d+)?)(?<unit>г|кг|мл|л|шт)');
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Вхідний CSV-подібний набір варіанта 13: 15 коректних і 5 пошкоджених.
const List<String> sourceLines = [
  'Борщ;українська;95;середньо;буряк:300г|капуста:400г;2026-09-05',
  'Вареники;українська;80;середньо;борошно:400г|картопля:600г;2026-09-06',
  'Сирники;українська;30;легко;сир:400г|яйце:2шт;2026-09-07',
  'Деруни;українська;40;легко;картопля:700г|цибуля:100г;2026-09-08',
  'Паста Карбонара;італійська;25;середньо;паста:300г|бекон:150г;2026-09-09',
  'Піца Маргарита;італійська;75;середньо;борошно:500г|сир:220г;2026-09-10',
  'Ризото;італійська;45;складно;рис:250г|гриби:200г;2026-09-11',
  'Салат Капрезе;італійська;15;легко;томат:300г|сир:200г;2026-09-12',
  'Рамен;японська;110;складно;локшина:250г|вода:1л;2026-09-13',
  'Суші;японська;70;складно;рис:300г|риба:180г;2026-09-14',
  'Місо суп;японська;20;легко;вода:800мл|тофу:200г;2026-09-15',
  'Тако;мексиканська;35;легко;тортилья:4шт|мясо:250г;2026-09-16',
  'Кесадилья;мексиканська;25;легко;тортилья:2шт|сир:180г;2026-09-17',
  'Чилі;мексиканська;85;середньо;квасоля:300г|мясо:250г;2026-09-18',
  'Гуакамоле;мексиканська;15;легко;авокадо:2шт|томат:120г;2026-09-19',
  'Без поля;українська;30;легко;сир:100г',
  'Не число;італійська;хвилини;легко;томат:100г;2026-09-20',
  'Не дата;японська;30;легко;рис:150г;не-дата',
  'Не інгредієнт;мексиканська;25;легко;сир-без-кількості;2026-09-21',
  'Не діапазон;італійська;999;легко;сир:100г;2026-09-22',
];

/// Перетворює дату на канонічний рядок YYYY-MM-DD.
String formatDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Перевіряє інваріанти рецепта та повертає всі порушення.
List<String> validateRecipe(Recipe r) {
  final errors = <String>[];
  if (r.title.isEmpty || r.cuisine.isEmpty) errors.add('порожня назва або кухня');
  if (r.minutes < 1 || r.minutes > maxMinutes) errors.add('час поза діапазоном');
  if (!difficulties.contains(r.difficulty)) errors.add('некоректна складність');
  if (r.ingredients.isEmpty) errors.add('немає інгредієнтів');
  for (final i in r.ingredients) {
    if (i.quantity <= 0 || i.quantity > 10000) errors.add('некоректна кількість');
    if (!units.contains(i.unit)) errors.add('некоректна одиниця');
  }
  if (r.date.isAfter(DateTime.now())) errors.add('дата у майбутньому');
  return errors;
}

/// Розбирає рядок [line] без винятків для очікуваних помилок.
ParseResult parseRecipe(String line) {
  final fields = line.split(';');
  if (fields.length != 6) return (recipe: null, errors: ['очікується шість полів']);
  final errors = <String>[];
  final minutes = int.tryParse(fields[2]);
  if (minutes == null) errors.add('час не є числом');
  final date = DateTime.tryParse(fields[5]);
  if (!_datePattern.hasMatch(fields[5]) || date == null ||
      formatDate(date) != fields[5]) {
    errors.add('некоректна дата');
  }
  final ingredients = <Ingredient>[];
  for (final part in fields[4].split('|')) {
    final match = _ingredient.firstMatch(part.trim());
    if (match == null) {
      errors.add('некоректний інгредієнт: $part');
      continue;
    }
    final quantity = double.tryParse((match.namedGroup('quantity') ?? '').replaceAll(',', '.'));
    if (quantity == null) {
      errors.add('некоректна кількість');
      continue;
    }
    ingredients.add((name: match.namedGroup('name') ?? '',
      quantity: quantity, unit: match.namedGroup('unit') ?? ''));
  }
  if (errors.isNotEmpty || minutes == null || date == null) {
    return (recipe: null, errors: errors);
  }
  final recipe = (
    title: fields[0].trim(), cuisine: fields[1].trim(), minutes: minutes,
    difficulty: fields[3].trim(), ingredients: ingredients, date: date,
  );
  errors.addAll(validateRecipe(recipe));
  return (recipe: errors.isEmpty ? recipe : null, errors: errors);
}

/// Створює замикання з власною захопленою змінною count.
int Function() makeCounter() {
  var count = 0;
  return () => ++count;
}

/// Фільтрує рецепти за максимальною тривалістю.
List<Recipe> quickRecipes(Iterable<Recipe> items, {int limit = quickLimit}) =>
    items.where((r) => r.minutes <= limit).toList();

/// Перетворює записи на назви.
List<String> recipeTitles(Iterable<Recipe> items) =>
    items.map((r) => r.title).toList();

/// Підсумовує тривалість через map та fold.
int totalMinutes(Iterable<Recipe> items) =>
    items.map((r) => r.minutes).fold<int>(0, (sum, n) => sum + n);

/// Середня тривалість, а для порожнього набору — 0.
double averageMinutes(Iterable<Recipe> items) {
  final data = items.toList();
  return data.isEmpty ? 0 : totalMinutes(data) / data.length;
}

/// Групує рецепти за кухнею.
Map<String, List<Recipe>> groupByCuisine(Iterable<Recipe> items) {
  final result = <String, List<Recipe>>{};
  for (final r in items) {
    result.putIfAbsent(r.cuisine, () => <Recipe>[]).add(r);
  }
  return result;
}

/// Агрегація середньої тривалості за кухнями.
Map<String, double> cuisineAverages(Iterable<Recipe> items) =>
    groupByCuisine(items).map((key, value) => MapEntry(key, averageMinutes(value)));

/// Сортування за часом, потім за назвою, в обраному напрямку.
List<Recipe> sortByDuration(Iterable<Recipe> items, {bool ascending = true}) {
  final data = items.toList();
  data.sort((a, b) {
    final t = a.minutes.compareTo(b.minutes);
    final c = t == 0 ? a.title.compareTo(b.title) : t;
    return ascending ? c : -c;
  });
  return data;
}

/// Сортування за назвою, потім за часом, в обраному напрямку.
List<Recipe> sortByTitle(Iterable<Recipe> items, {bool ascending = true}) {
  final data = items.toList();
  data.sort((a, b) {
    final t = a.title.compareTo(b.title);
    final c = t == 0 ? a.minutes.compareTo(b.minutes) : t;
    return ascending ? c : -c;
  });
  return data;
}

/// Пошук рецепта за назвою без StateError.
Recipe? findByTitle(Iterable<Recipe> items, String title) {
  for (final r in items) {
    if (r.title == title) return r;
  }
  return null;
}

/// Приховує числа у списку інгредієнтів через replaceAllMapped.
String maskAmounts(String text) => text.replaceAllMapped(
  _mask, (m) => "${m.namedGroup('name')}:***${m.namedGroup('unit')}",
);

/// Вік запису у повних днях із DateTime.difference.
int ageDays(Recipe recipe, {DateTime? now}) =>
    (now ?? DateTime.now()).difference(recipe.date).inDays;

/// Будує звіт, використовуючи StringBuffer та іменовані параметри.
String buildReport(Iterable<Recipe> items, {
  int topCount = 5, bool ascending = true, String separator = ' | ',
  DateTime? now,
}) {
  final data = items.toList();
  final buffer = StringBuffer()
    ..writeln('ЗВІТ ПРО РЕЦЕПТИ')
    ..writeln('Записів: ${data.length}')
    ..writeln('Сумарний час: ${totalMinutes(data)} хв')
    ..writeln('Середній час: ${averageMinutes(data).toStringAsFixed(1)} хв')
    ..writeln('Швидких: ${quickRecipes(data).length}')
    ..writeln('Середній час за кухнями:');
  for (final entry in cuisineAverages(data).entries) {
    buffer.writeln('  ${entry.key}: ${entry.value.toStringAsFixed(1)} хв');
  }
  buffer.writeln('Рецепти за тривалістю:');
  for (final r in sortByDuration(data, ascending: ascending).take(topCount)) {
    buffer.writeln('${r.title}$separator${r.minutes} хв$separator${r.cuisine}$separator${ageDays(r, now: now)} днів');
  }
  return buffer.toString();
}
