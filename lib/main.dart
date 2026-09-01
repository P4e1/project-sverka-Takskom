import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'state/app_state.dart';
import 'theme.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1360, 880),
      minimumSize: Size(1100, 720),
      center: true,
      title: 'Сверка розничных продаж',
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  final state = AppState();
  await state.restore();

  runApp(ChangeNotifierProvider.value(
    value: state,
    child: const ReconApp(),
  ));
}

class ReconApp extends StatelessWidget {
  const ReconApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Сверка розничных продаж',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const HomeScreen(),
      );
}