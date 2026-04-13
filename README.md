# Flutter Pong

Simple Pong game in Flutter with keyboard controls, a stats page, and difficulty settings.

## Controls

- `W` / `S` or Arrow Up / Arrow Down: Move your paddle
- `P`: Pause / Resume
- `R`: Restart match

## Stats & Settings

Open the Stats tab in the app to view your total matches, wins, recent results, and adjust the AI difficulty.

## Run

1. Install Flutter SDK.
2. In this folder run:

```bash
flutter pub get
```

3. If this folder does not yet contain platform folders (`android`, `ios`, `web`, etc.), generate them once:

```bash
flutter create .
```

4. Run the game:

```bash
flutter run -d chrome
```

You can also run on desktop/mobile if those targets are enabled in your Flutter setup.
