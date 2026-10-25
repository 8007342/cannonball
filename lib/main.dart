import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const CannonballApp());
}

class CannonballApp extends StatelessWidget {
  const CannonballApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cannonball',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const FoundationScreen(),
  );
}

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight > constraints.maxWidth) {
          return const Center(child: Text('Rotate your device to landscape'));
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: CannonballGame()),
            const SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.key, size: 48, color: Color(0xFFE7B76D)),
                      SizedBox(height: 16),
                      Text(
                        'CANNONBALL',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text('NEW YORK → REDONDO BEACH'),
                      SizedBox(height: 24),
                      Text('The journey starts with a set of keys.'),
                      SizedBox(height: 8),
                      Text(
                        'Foundation preview · game design in progress',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Rendering and simulation will be added after the design interview.
class CannonballGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF241A14);
}
