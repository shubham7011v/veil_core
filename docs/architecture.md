# Veil Core Architecture

## Project Overview
Veil Core is a digital implementation of the Indian Bluff (Cheat) card game, built with Flutter.

## Project Structure
- `lib/core/`: Foundation classes, constants, and themes.
- `lib/features/`: Feature-based modular structure.
  - `session/`: Main game gameplay logic and UI.
    - `models/`: Domain models like `Unit` (Card), `Participant`.
    - `state/`: `SessionProvider` using ChangeNotify for state management.
    - `ui/`: Main game screens and widgets.
  - `collection/`: Card deck and collection management.
- `lib/widgets/`: Reusable UI components.

## Key Features
- **Dynamic Fan UI**: Fully custom, responsive card fan arc supporting up to 52 cards.
- **Staging Area**: Efficient space management by moving selected cards to a "ready" pile.
- **Multiplayer Support**: Designed for up to 10 players.
- **State Management**: Provider-driven game flow with real-time UI updates.
