# Bot Match Refactoring Walkthrough

## Overview
This walkthrough details the refactoring of the Bot Match module to improve encapsulation, modularity, and adherence to the Interface Segregation Principle (ISP). The changes involve separating voice logic from game session logic and encapsulating bot decision-making into a dedicated `BotBrain`.

## Changes Implemented

### 1. Interface Segregation
*   **Split `GameSessionHandler`**: Extracted voice-related methods (`raiseHand`, `sendVoiceSDP`, `sendVoiceICE`) into a new `VoiceSessionHandler` interface.
*   **Updated `GameSessionHandler`**: Removed voice methods, keeping it focused on game logic.
*   **Updated `WebSocketSessionHandler`**: Now implements both `GameSessionHandler` and `VoiceSessionHandler`.
*   **Updated `LocalBotSessionHandler`**: Removed unused voice stubs.

### 2. Bot Abstraction
*   **Created `BotBrain` Interface**: Defined the contract for bot decision-making (`decideAction`).
*   **Implemented `DefaultBotBrain`**: Provided a concrete implementation with personality-based logic (Conservative, Aggressive, Balanced, Ghost).
*   **Refactored `LocalBotSessionHandler`**: Injected `BotBrain` to handle game moves, removing hardcoded logic and personality/name handling.

### 3. State Management Updates
*   **Updated `SessionState`**: Added `currentRank` to tracking.
*   **Updated `BaseAuthoritativeHandler`**: Ensured `currentRank` is correctly propagated during game events.
*   **Updated `SessionBloc`**: Adapted to `currentRank` availability and improved event handling.

### 4. Integration & UI
*   **`ServiceLocator`**: Exposed `voiceSessionHandler` explicitly.
*   **`AppRouter`**: Injected `VoiceSessionHandler` into `VoiceBloc`.
*   **`VoiceOverlay`**: Updated to use `VoiceSessionHandler`.
*   **`VoiceAudioManager`**: Updated to depend on `VoiceSessionHandler`.
*   **`WebSocketVoiceRepository`**: Updated to use `VoiceSessionHandler`.

## Architectural Improvements

### 1. Local-Only Bot Architecture
*   **Selective Initialization**: `AppRouter` was updated to only instantiate `VoiceBloc` when a `WebSocketSessionHandler` is in use. This prevents voice-related singleton resource initialization during local play.
*   **Conditional Rendering**: `SessionScreen` now dynamically checks for `VoiceSessionHandler` support before mounting the `VoiceOverlay` widget.
*   **Zero-Voice Surface Area**: By strictly separating the handlers in the DI layer, local bot matches have zero runtime overhead or UI footprint from voice features.

### 2. Implementation Summary
*   **`BaseAuthoritativeHandler`**: Serves as the strictly local "Game Master", managing internal hidden state (pile, individual hands) that is never exposed to the client-facing `SessionState`.
*   **Logic Separation**: Bot decisions are made by `BotBrain` using local handler state, ensuring the "Bot Mode" flow is entirely contained within the device with no network or voice dependencies.

### 3. Bug Fix: Bot Match Hanging
*   **Issue**: Bot matches would sometimes hang forever in waiting state after game start.
*   **Root Cause**: After `startGame()` initialized the game, `onTurnActive()` was never called for the initial active participant. This meant if a bot went first, its turn was never scheduled.
*   **Solution**: Added `onTurnActive(initialActiveId)` call in `BaseAuthoritativeHandler.startGame()` after the initial setup completes (line 192-195).
*   **Result**: Bot turns are now properly scheduled from the very first turn, eliminating the infinite wait state.

### 4. UI Polish: Shuffle Animation Fixed
*   **Issue**: The "Shuffling" phase was just a static text wait for 1.8 seconds with no visual feedback.
*   **Fix**: Implemented the missing `_triggerCardAnimation` logic in `SessionScreen` and reduced the total shuffle delay to 1.2 seconds.
*   **Result**: Cards now visually fly from the center deck to each player's position during game start, creating a premium "dealing" feel while reducing unnecessary waiting time by 600ms.

## Verification

### Automated Tests
*   **`BotBrain` Unit Tests**: Verified decision logic for different scenarios (created `test/core/engine/domain/logic/bot_brain_test.dart`).
*   **`SessionBloc` Integration Tests**: Verified session state management and event propagation, ensuring no regressions (ran `test/features/session/bloc/session_bloc_test.dart`).

### Test Results
All tests passed successfully.

## Conclusion
The refactoring has resulted in a more modular and testable codebase. Voice and Game responsibilities are now clearly separated, and Bot logic is encapsulated and easily extensible.
