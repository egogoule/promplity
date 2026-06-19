# Promplity Client

**Free and open-source SSH/SFTP client for Windows.**

![Version](https://img.shields.io/badge/version-0.0.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)

---

## About

Promplity Client is a lightweight, fast, and feature-rich SSH/SFTP client built with Flutter. It provides a modern interface for managing remote servers, transferring files, and executing commands — all in a single application.

**This is an open-source project provided free of charge. The creator assumes no responsibility for its use by others.**

---

## Features

### SSH Terminal
- **Full PTY terminal emulator** with xterm-256color support
- **Simple mode** for basic SSH sessions without PTY
- **Command history** with automatic output capture — see what each command returned
- **Keyboard shortcuts** — customizable keybindings for copy, paste, interrupt, and more
- **Auto-reconnect** — automatically reconnects when connection drops
- **Live uptime display** — shows how long you've been connected

### SFTP File Manager
- **Dual-pane interface** — local files on the left, remote files on the right (like FileZilla)
- **Upload/Download** — transfer files between local and remote with progress tracking
- **Edit remote files** — download to temp, open in your default editor, auto-upload changes back
- **Edit local files** — open local files in notepad, auto-sync to server on save
- **Create folders** — create new directories locally and on the server
- **Create files** — create empty files locally and on the server
- **Rename** — rename files and folders on both local and remote
- **Delete** — delete files and folders with confirmation dialog
- **Copy path** — copy the current directory path to clipboard
- **Navigate by path** — type or paste a path directly in the address bar
- **Auto-scroll** — scrollable file lists with smooth navigation

### Connection Management
- **Quick connect** — type `ssh user@host -p 22` and connect instantly
- **Saved connections** — save server credentials for one-click access
- **Password & key authentication** — support for both password and SSH key auth
- **Server profiles** — organize connections with labels and profiles
- **Connection states** — see which servers are connected, disconnected, or errored

### Command History
- **Automatic capture** — commands and their outputs are saved automatically
- **Copy output** — one-click copy of any command's output
- **Re-run commands** — quickly re-execute any previous command
- **Clear history** — clear all saved command history
- **ANSI-clean output** — escape sequences and control characters are stripped

### User Interface
- **Tab-based navigation** — manage multiple SSH sessions in tabs
- **Dark theme** — eye-friendly monochrome dark interface
- **Disclaimer banner** — open-source notice with donation link
- **Settings** — keybindings and general configuration

---

## Installation

### Windows

1. Download the latest release from [Releases](https://github.com/egogoule/promplity/releases)
2. Run the installer (`PromplityClient-Setup.exe`)
3. Follow the installation wizard
4. Launch Promplity Client from Start Menu or Desktop

### Linux / macOS

1. Clone the repository:
   ```bash
   git clone https://github.com/egogoule/promplity.git
   cd promplity
   ```
2. Install Flutter SDK (3.10+)
3. Run the app:
   ```bash
   flutter pub get
   flutter run
   ```

---

## Building from Source

### Prerequisites
- Flutter SDK 3.10 or later
- Dart SDK 3.0 or later
- For Windows: Visual Studio 2022 with C++ build tools
- For Linux: GTK3 development libraries
- For macOS: Xcode 14+

### Build Steps

```bash
# Get dependencies
flutter pub get

# Build for Windows
flutter build windows

# Build for Linux
flutter build linux

# Build for macOS
flutter build macos
```

The built application will be in `build/<platform>/`.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+Shift+C | Copy selected text |
| Ctrl+Shift+V | Paste from clipboard |
| Ctrl+V | Paste (standard) |
| Ctrl+L | Clear terminal screen |
| Ctrl+C | Interrupt (SIGINT) |
| Ctrl+A | Copy all terminal text |

Customize shortcuts in Settings → Keybindings.

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, tab management
├── models/
│   └── models.dart              # Data models (Server, KeymapBinding, etc.)
├── screens/
│   ├── home_screen.dart         # Server list & quick connect
│   ├── terminal_screen.dart     # SSH terminal with command history
│   ├── sftp_screen.dart         # Dual-pane SFTP file manager
│   ├── settings_screen.dart     # Settings & keybindings
│   ├── connect_screen.dart      # Add/edit server connections
│   ├── profiles_screen.dart     # Credential profiles
│   └── unlock_screen.dart       # Master password screen
├── services/
│   └── ssh_service.dart         # SSH/SFTP session management
├── repositories/
│   ├── database.dart            # SQLite database layer
│   └── repositories.dart        # Data access repositories
├── bloc/
│   ├── server_bloc.dart         # Server connection state management
│   ├── keymap_bloc.dart         # Keyboard shortcuts state
│   └── profile_bloc.dart        # Credential profiles state
├── widgets/
│   ├── command_history_panel.dart  # Command history sidebar
│   ├── disclaimer_banner.dart   # Open-source disclaimer banner
│   ├── server_card.dart         # Server list item widget
│   └── simple_terminal.dart     # Simple terminal widget
└── utils/
    └── theme.dart               # App theme (colors, styles)
```

---

## Tech Stack

- **Flutter** — cross-platform UI framework
- **dartssh2** — pure Dart SSH2 client
- **xterm** — terminal emulator widget
- **flutter_bloc** — state management
- **sqflite** — local SQLite database
- **open_file_plus** — open files in system default editor
- **url_launcher** — open URLs in browser

---

## Donations

All donations go **exclusively** to project development.

### Boosty
Support the project on Boosty:
**[boosty.to/egogoule/donate](https://boosty.to/egogoule/donate)**

### Crypto (USDT / TON)
```
UQAiawglSWOeXBhrq-0RiSorwHjg7QfgvFOiqkesXopGEzZt
```

---

## Contributing

Contributions are welcome! Here's how to contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/your-username/promplity.git
cd promplity

# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze
```

---

## License

This project is open-source. Use it however you like.

**The creator assumes no responsibility for its use by others.**

---

## Acknowledgments

- [dartssh2](https://github.com/TerminalStudio/dartssh2) — SSH2 protocol implementation
- [xterm.dart](https://github.com/TerminalStudio/xterm.dart) — Terminal emulator
- [Flutter](https://flutter.dev) — Cross-platform UI framework

---

## Disclaimer

This software is provided "as is", without warranty of any kind. The author is not responsible for any damage or issues caused by the use of this software. Use at your own risk.

---

# 🇷🇺 Русская версия

## О проекте

**Бесплатный open-source SSH/SFTP клиент для Windows.**

Promplity Client — лёгкий, бы функциональный SSH/SFTP клиент на Flutter. Современный интерфейс для управления удалёнными серверами, передачи файлов и выполнения команд — всё в одном приложении.

**Это open-source проект, предоставляемый бесплатно. Создатель не несёт ответственности за его использование другими лицами.**

---

## Возможности

### SSH Терминал
- **Полноценный PTY эмулятор терминала** с поддержкой xterm-256color
- **Простой режим** для базовых SSH сессий без PTY
- **История команд** с автоматическим захватом вывода — видите что вернул каждый запрос
- **Горячие клавиши** — настраиваемые комбинации для копирования, вставки, прерывания и другого
- **Авто-переподключение** — автоматически переподключается при обрыве соединения
- **Отображение аптайма** — показывает как долго вы подключены

### SFTP Файловый менеджер
- **Двухпанельный интерфейс** — локальные файлы слева, удалённые справа (как в FileZilla)
- **Загрузка/Скачивание** — передача файлов между локальным и удалённым сервером с прогрессом
- **Редактирование удалённых файлов** — скачивает во временную папку, открывает в вашем редакторе, автоматически загружает изменения обратно
- **Редактирование локальных файлов** — открывает локальные файлы в блокноте, автоматически синхронизирует с сервером при сохранении
- **Создание папок** — создание новых директорий локально и на сервере
- **Создание файлов** — создание пустых файлов локально и на сервере
- **Переименование** — переименование файлов и папок локально и на удалённом сервере
- **Удаление** — удаление файлов и папок с диалогом подтверждения
- **Копирование пути** — копирование текущего пути директории в буфер обмена
- **Навигация по пути** — ввод или вставка пути напрямую в адресную строку
- **Автоскролл** — прокручиваемые списки файлов с плавной навигацией

### Управление подключениями
- **Быстрое подключение** — введите `ssh user@host -p 22` и подключитесь мгновенно
- **Сохранённые подключения** — сохраняйте учётные данные сервера для доступа в один клик
- **Аутентификация по паролю и ключу** — поддержка парольной и ключевой аутентификации SSH
- **Профили серверов** — организация подключений с метками и профилями
- **Состояния подключений** — видите какие серверы подключены, отключены или с ошибкой

### История команд
- **Автоматический захват** — команды и их выводы сохраняются автоматически
- **Копирование вывода** — копирование вывода любой команды в один клик
- **Повтор команд** — быстрое повторное выполнение любой предыдущей команды
- **Очистка истории** — удаление всей сохранённой истории команд
- **Чистый вывод** — escape-последовательности и управляющие символы удаляются

### Интерфейс
- **Навигация по вкладкам** — управление несколькими SSH сессиями во вкладках
- **Тёмная тема** — удобный для глаз монохромный тёмный интерфейс
- **Баннер дисклеймера** — уведомление об open-source проекте со ссылкой на донат
- **Настройки** — горячие клавиши и общая конфигурация

---

## Установка

### Windows

1. Скачайте последний релиз из [Releases](https://github.com/egogoule/promplity/releases)
2. Запустите установщик (`PromplityClient-Setup.exe`)
3. Следуйте инструкциям мастера установки
4. Запустите Promplity Client из меню Пуска или с рабочего стола

### Linux / macOS

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/egogoule/promplity.git
   cd promplity
   ```
2. Установите Flutter SDK (3.10+)
3. Запустите приложение:
   ```bash
   flutter pub get
   flutter run
   ```

---

## Сборка из исходников

### Требования
- Flutter SDK 3.10 или позже
- Dart SDK 3.0 или позже
- Windows: Visual Studio 2022 с C++ инструментами сборки
- Linux: GTK3 библиотеки для разработки
- macOS: Xcode 14+

### Шаги сборки

```bash
# Установка зависимостей
flutter pub get

# Сборка для Windows
flutter build windows

# Сборка для Linux
flutter build linux

# Сборка для macOS
flutter build macos
```

Собранное приложение будет в `build/<platform>/`.

---

## Горячие клавиши

| Комбинация | Действие |
|------------|----------|
| Ctrl+Shift+C | Копировать выделенный текст |
| Ctrl+Shift+V | Вставить из буфера обмена |
| Ctrl+V | Вставить (стандартно) |
| Ctrl+L | Очистить экран терминала |
| Ctrl+C | Прервать (SIGINT) |
| Ctrl+A | Копировать весь текст терминала |

Настройте горячие клавиши в Настройки → Привязки клавиш.

---

## Структура проекта

```
lib/
├── main.dart                    # Точка входа, управление вкладками
├── models/
│   └── models.dart              # Модели данных (Server, KeymapBinding и др.)
├── screens/
│   ├── home_screen.dart         # Список серверов и быстрое подключение
│   ├── terminal_screen.dart     # SSH терминал с историей команд
│   ├── sftp_screen.dart         # Двухпанельный SFTP файловый менеджер
│   ├── settings_screen.dart     # Настройки и привязки клавиш
│   ├── connect_screen.dart      # Добавление/редактирование подключений
│   ├── profiles_screen.dart     # Профили учётных данных
│   └── unlock_screen.dart       # Экран мастер-пароля
├── services/
│   └── ssh_service.dart         # Управление SSH/SFTP сессиями
├── repositories/
│   ├── database.dart            # Слой SQLite базы данных
│   └── repositories.dart        # Репозитории доступа к данным
├── bloc/
│   ├── server_bloc.dart         # Управление состоянием подключений
│   ├── keymap_bloc.dart         # Состояние горячих клавиш
│   └── profile_bloc.dart        # Состояние профилей учётных данных
├── widgets/
│   ├── command_history_panel.dart  # Боковая панель истории команд
│   ├── disclaimer_banner.dart   # Баннер дисклеймера open-source
│   ├── server_card.dart         # Виджет элемента списка серверов
│   └── simple_terminal.dart     # Простой виджет терминала
└── utils/
    └── theme.dart               # Тема приложения (цвета, стили)
```

---

## Технологии

- **Flutter** — кроссплатформенный UI фреймворк
- **dartssh2** — SSH2 клиент на чистом Dart
- **xterm** — виджет эмулятора терминала
- **flutter_bloc** — управление состоянием
- **sqflite** — локальная SQLite база данных
- **open_file_plus** — открытие файлов в системном редакторе
- **url_launcher** — открытие ссылок в браузере

---

## Донаты

Все донаты идут **исключительно** на развитие проекта.

### Boosty
Поддержите проект на Boosty:
**[boosty.to/egogoule/donate](https://boosty.to/egogoule/donate)**

### Криптовалюта (USDT / TON)
```
UQAiawglSWOeXBhrq-0RiSorwHjg7QfgvFOiqkesXopGEzZt
```

---

## Участие в разработке

Приветствуется! Вот как внести вклад:

1. Форкните репозиторий
2. Создайте ветку с функцией (`git checkout -b feature/amazing-feature`)
3. Зафиксируйте изменения (`git commit -m 'Add amazing feature'`)
4. Отправьте в ветку (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

### Настройка окружения разработки

```bash
# Клонируйте ваш форк
git clone https://github.com/your-username/promplity.git
cd promplity

# Установите зависимости
flutter pub get

# Запустите в режиме отладки
flutter run

# Запустите тесты
flutter test

# Анализ кода
flutter analyze
```

---

## Лицензия

Этот проект open-source. Используйте как хотите.

**Создатель не несёт ответственности за его использование другими лицами.**

---

## Благодарности

- [dartssh2](https://github.com/TerminalStudio/dartssh2) — реализация протокола SSH2
- [xterm.dart](https://github.com/TerminalStudio/xterm.dart) — эмулятор терминала
- [Flutter](https://flutter.dev) — кроссплатформенный UI фреймворк

---

## Дисклеймер

Это программное обеспечение предоставляется «как есть», без каких-либо гарантий. Автор не несёт ответственности за любой ущерб или проблемы, вызванные использованием этого программного обеспечения. Используйте на свой страх и риск.
