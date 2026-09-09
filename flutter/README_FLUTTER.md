# Agenda Amiga - Versão Flutter para Smartphones (Android & iOS)

Este diretório (`/flutter`) contém o código-fonte completo em **Flutter** para gerar o aplicativo nativo instalável no seu smartphone (Android APK ou iOS IPA).

## Como Instalar e Compilar no seu Celular:

1. **Instale o Flutter SDK** no seu computador (https://docs.flutter.dev/get-started/install).
2. Abra o terminal na pasta `/flutter`:
   ```bash
   cd flutter
   ```
3. Instale as dependências:
   ```bash
   flutter pub get
   ```
4. Conecte seu celular via USB (com Depuração USB ativada no Android) ou abra um emulador e execute:
   ```bash
   flutter run
   ```
5. Para gerar o arquivo instalável **APK** para Android:
   ```bash
   flutter build apk --release
   ```
   O arquivo APK estará pronto em `build/app/outputs/flutter-apk/app-release.apk`, pronto para ser transferido e instalado em qualquer smartphone Android.
