# Architecture & Development Rules

This document outlines the mandatory architectural patterns, coding standards, and best practices for the Veil Core project. We follow **Clean Architecture** combined with the **BLoC (Business Logic Component)** pattern to ensure scalability, testability, and maintainability.

---

## 1. Core Principles

### Encapsulation & Modularity
- **Feature-First Structure**: Code is organized by feature (e.g., `features/home`, `features/auth`), not by layer (e.g., `controllers`, `views`).
- **Private by Default**: Helpers, internal widgets, and methods should be private (`_methodName`) unless designed for public consumption.
- **Strict Boundaries**:
    - **UI** depends only on **BLoC**.
    - **BLoC** depends on **Repositories** (or Use Cases).
    - **Repositories** depend on **Data Sources**.
    - **Domain** layer is independent of Flutter and Data layers.

### Dependency Injection
- Use `get_it` (via `lib/core/di/service_locator.dart`) for global Singletons (Repositories, Services).
- Avoid creating instances of logic classes (`new Repository()`) inside widgets. Use `sl<Repository>()`.

---

## 2. State Management (BLoC)

We use `flutter_bloc` for all complex state management.

### Rules for BLoCs
1.  **Business Logic Only**: The BLoC handles ALL business logic (e.g., validations, navigation decisions, coin checks). The UI is "dumb" and only renders state.
2.  **Event-Driven**: The UI dispatches **Events** (`HomePlayOnlineClicked`). It never calls methods on the BLoC directly (`bloc.handlePlayOnline()`).
3.  **Immutable State**: All states should be immutable classes extending `Equatable`.
4.  **Single Source of Truth**: The BLoC state is the single source of truth for the feature.

### Handling Side Effects (Navigation, Dialogs, Toasts)
Since BLoC state is persistent, use the **Side Effect Pattern** for ephemeral actions:
1.  Define a `SideEffect` abstract class (e.g., `HomeSideEffect`) and specific effects (`HomeNavigateTo`, `HomeShowDialog`).
2.  Add an `effect` field to the BLoC State (`HomeState`).
3.  Emit the effect, then immediately emit `null` to clear it.
4.  Use `BlocListener` in the UI to react to non-null effects.

**Example:**
```dart
// BLoC
void _onClicked(Event event, Emitter emit) {
  emit(state.copyWith(effect: HomeNavigateTo('/settings')));
  emit(state.copyWith(effect: null)); // Clear immediately
}

// UI
BlocListener<HomeBloc, HomeState>(
  listenWhen: (p, c) => c.effect != null,
  listener: (context, state) {
    if (state.effect is HomeNavigateTo) {
      Navigator.pushNamed(...);
    }
  },
  child: ...
)
```

---

## 3. Layer Responsibilities

### Presentation Layer (`lib/features/x/presentation`)
- **Widgets**: Purely for rendering. Use `BlocBuilder` for state and `BlocListener` for effects. Avoid `setState` for business logic (transient UI animations are okay).
- **BLoCs**: Transformers that convert **Events** into **States**.

### Domain Layer (`lib/features/x/domain`)
- **Entities**: Pure Dart objects (business models).
- **Repositories (Interfaces)**: Abstract definitions of data operations (e.g., `AuthRepository`).

### Data Layer (`lib/features/x/data`)
- **Models (DTOs)**: JSON serialization/deserialization.
- **Repositories (Implementations)**: Concrete implementation of domain interfaces.
- **Data Sources**: APIs, Local Storage, WebSockets.

---

## 4. Code Standards & Best Practices

### Constants & Theming
- **No Magic Values**: Do not hardcode raw colors (`Colors.red`) or random strings.
- **Colors**: Use `AppColorPalette` (via `ThemeBloc` or `AppColors`).
- **Strings**: Use constant files if reused `lib/core/constants`.

### Widget Architecture
- **Composition over Inheritance**: Build complex UIs by composing small, focused widgets.
- **Extract Widgets**: If a `build` method is too long (>100 lines), extract parts into separate files in `widgets/`.
- **Stateless Preferred**: Use `StatelessWidget` unless you absolutely need local ephemeral state (`AnimationController`, `TextEditingController`).

### Clean Code
- **Descriptive Naming**: `onTap` -> `_handlePlayOnlineClicked` (if internal) or just dispatch event.
- **Strong Typing**: Avoid `dynamic`. Define models for everything.

---

## 5. Refactoring Workflow

When moving legacy logic to BLoC:
1.  **Identify Logic**: Find `onTap` handlers containing `if/else`, validations, or router calls.
2.  **Define Events**: Create Events for these interactions (`PlayClicked`).
3.  **Define State/Effects**: Determine if this interactions changes data (State) or triggers action (Effect).
4.  **Move Logic**: Copy logic to BLoC handler. Replace UI dependencies (`context`, `Navigator`) with State/Effects.
5.  **Connect**: Update UI to dispatch Event and listen for State/Effect.
