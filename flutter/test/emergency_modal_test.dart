import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agenda_amiga_flutter/widgets/modals.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap() {
    final spoken = <String>[];
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => EmergencyModal(
                  speakText: (t) => spoken.add(t),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('salvar contato aparece na lista e persiste', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar Parente / Cuidador'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Nome (ex: Maria - Filha)'), 'João');
    await tester.enterText(
        find.widgetWithText(TextField, 'Telefone (ex: 11998887766)'), '11999990000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('João'), findsOneWidget);
    expect(find.text('11999990000'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('caregiver_contacts'), contains('João'));
  });

  testWidgets('excluir contato remove da lista e persiste', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final trash = find.byTooltip('Excluir');
    expect(trash, findsWidgets);

    await tester.tap(trash.first);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('caregiver_contacts'), isNot(contains('Maria')));
  });
}