import 'package:lab1/lab1.dart';

void main() {
  final nextValid = makeCounter();
  final recipes = <Recipe>[];
  final rejected = <String>[];

  for (var index = 0; index < sourceLines.length; index++) {
    final outcome = parseRecipe(sourceLines[index]);
    final recipe = outcome.recipe;
    if (recipe == null) {
      rejected.add('Рядок ${index + 1}: ${outcome.errors.join(', ')}');
    } else {
      recipes.add(recipe);
      nextValid();
    }
  }

  print('Усього вхідних рядків: ${sourceLines.length}');
  print('Коректних рецептів: ${recipes.length}');
  print('Відхилено рядків: ${rejected.length}');
  print('Причини відхилення:');
  rejected.forEach(print);
  print('');
  print(buildReport(recipes, ascending: true));
  print('За назвою (перші три): ${recipeTitles(sortByTitle(recipes)).take(3).join(', ')}');
  print('За часом, спадання (перші три): ${recipeTitles(sortByDuration(recipes, ascending: false)).take(3).join(', ')}');
  print('Знайдено Сирники: ${findByTitle(recipes, 'Сирники') != null}');
  print('Масковані інгредієнти: ${maskAmounts('сир:400г|яйце:2шт')}');
}
