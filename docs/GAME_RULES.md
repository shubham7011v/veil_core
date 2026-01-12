# Game Rules - Complete Reference

## Core Gameplay Rules

### 1. **Objective**
Be the first player to get rid of all your cards.

### 2. **Setup**
- 2-10 players (standard 52-card deck)
- All cards are dealt evenly to players
- Suits are ignored - only ranks matter
- Random player starts

### 3. **Turn Structure**

#### Playing Cards
- On your turn, you must either **play cards** or **pass**
- Play 1-4 cards face-down on the pile
- Declare a rank (e.g., "2 Queens")
- **First player in a round can choose any rank**
- **Subsequent players must match that rank** (or bluff!)

#### Example Round:
```
Player 1: Plays 2 cards, declares "2 Kings" (starts round)
Player 2: Must play "Kings" (or claim to play Kings)  
Player 3: Must play "Kings" (or claim to play Kings)
...until someone challenges or all pass
```

### 4. **Bluffing**
- You can lie about what cards you're playing!
- **Only the NEXT player can call your bluff**
- If challenged:
  - **Bluff caught** (you lied): You pick up the entire pile
  - **False alarm** (you told truth): Challenger picks up the pile
- Winner of challenge starts the next round

### 5. **Passing**
- If you don't want to play or challenge, you can **pass**
- If **everyone passes** (full cycle back to last player):
  - Entire pile is **discarded**
  - Last player who played starts a new round

### 6. **Challenging Rules**
⚠️ **CRITICAL RULE:**
- **Only the player whose turn it is can challenge**
- You cannot challenge out of turn
- Challenge must happen before next player's action
- Once you pass, you cannot challenge that move

### 7. **Winning**
- First player to play their last card wins
- **Special case:** If you play your last card, opponents get one chance to challenge
  - If bluff: You pick up pile and continue
  - If truth: You win immediately

### 8. **Turn Timer** (Online Only)
- 25 seconds per turn
- Auto-pass if time runs out
- No timer in offline/practice mode

---

## Quick Reference

| Action | Rule |
|--------|------|
| Card count | 1-4 cards per play |
| Rank matching | Must match round rank after 1st play |
| Who can challenge | Only next player in turn order |
| Challenge timing | After cards played, before next turn |
| Bluff penalty | Loser takes entire pile |
| All pass | Pile discarded, last player starts new round |
| Win condition | First to 0 cards (after challenge check) |

---

## Strategy Tips

### When to Bluff
✅ **Good times:**
- When you're close to winning (few cards left)
- When pile is small
- Against conservative players

❌ **Bad times:**
- When pile is huge
- Against aggressive challengers
- When you have the actual cards

### When to Challenge
✅ **Challenge if:**
- Player is close to winning
- They played many cards (3-4)
- They hesitated or acted suspiciously
- Pile is small and worth risking

❌ **Don't challenge if:**
- Pile is very large
- You'll pick up too many cards
- Player tends to play truthfully

### When to Pass
- Don't have matching cards
- Don't want to bluff with current pile size
- Waiting for better opportunity
- Forcing pile to discard

---

## Common Scenarios

### Scenario 1: Challenge at 0 Cards
```
Player A: 1 card left, plays it as "1 Ace"
Player B: Challenges
Result: Cards revealed
  - If truth: Player A wins
  - If bluff: Player A picks up pile, game continues
```

### Scenario 2: All Pass Cycle
```
Player A: Plays 2 "Kings"
Player B: Pass
Player C: Pass  
Player D: Pass
Turn back to Player A → Pile discarded
Player A starts new round with any rank
```

### Scenario 3: Consecutive Challenges
```
Round 1: Player A plays "Queens"
Player B: Challenges → Bluff caught, A picks up pile
Round 2: Player B starts new round
(Challenge resets each round)
```

---

## Differences: Online vs Offline

| Feature | Online | Offline (Practice) |
|---------|--------|-------------------|
| Turn timer | 25s (auto-pass) | No limit |
| Opponents | Real players + Bots | Local bots only |
| Coins | Wagered (100/player) | No coins |
| Match history | Saved to database | Session only |
| **All game rules** | ✅ **Identical** | ✅ **Identical** |

---

## Advanced Rules

### Round Rank Locked
- Once first player chooses a rank, everyone must claim that rank
- Rank resets when:
  - Someone picks up the pile (after challenge)
  - Everyone passes (pile discarded)

### Pass Flag Reset
- Playing cards resets all pass flags
- New move cycle starts
- Players who passed can now act again

### Turn Order
- Clockwise around the table
- Fixed at game start (randomized)
- Maintains order throughout game

---

## Remember
1. **Practice makes perfect** - Try offline mode first!
2. **Watch opponents** - Learn their bluffing patterns
3. **Manage your hand** - Don't bluff with cards you need
4. **Calculate risks** - Weigh pile size vs card advantage
5. **Stay unpredictable** - Mix truth and bluffs

Good luck, and may your bluffs be bold! 🎴✨
