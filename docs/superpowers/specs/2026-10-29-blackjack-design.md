# Blackjack on Salesforce: Design

Date: 2026-10-29
Status: Approved

## 1. Goal

Build a Blackjack game inside Salesforce. Players are stored as `Player__c` records, and the game is played in a Lightning tab against the dealer. Each round checks the player's fund, places the bet, plays the hand, settles the result, and saves the stats back to the player's record.

## 2. Scope

**In scope (v1, full rule set):**
- Hit, Stand, Double Down, Split (same-rank pairs, no re-split), Insurance (when the dealer shows an ace).
- Blackjack pays 3:2. Other wins pay 1:1. Pushes return the bet.
- Dealer hits until 17 or more and stands on all 17s, including soft 17.
- Shoe of 6 decks, reshuffled when it runs low.
- Card images from a static resource.

**Out of scope:**
- Multiplayer or several players at one table.
- Saving a round in progress across sessions. Each round is played in one sitting. (See section 9.)
- Sound, animations, and mobile-specific layout.

## 3. Data model

### `Player__c` (custom object)

| Field | API name | Type | Notes |
|---|---|---|---|
| Name | `Name` | Text | Player name. Required. |
| Fund | `Fund__c` | Currency | Current balance. Default 1000. |
| Highest Bet | `Highest_Bet__c` | Currency | Largest single bet placed. |
| Highest Hand | `Highest_Hand__c` | Number | Best value of a winning hand: the highest total (2 to 21) the player won a round with. Pushes and losses don't count. |
| Highest Earn | `Highest_Earn__c` | Currency | Largest net profit: current fund minus the starting fund of 1000. |

Highest Earn is updated when the fund goes above the previous high. Fund changes from a round are the only source of updates.

## 4. Card assets

- The 52 PNG files in `C:\Users\Usuário\Pictures\Cards` are packaged as one static resource named `Cards`.
- File names follow the pattern `<Rank>_of_<Suit>.png`, with ranks `2`–`10`, `Jack`, `Queen`, `King`, `Ace` and suits `Clubs`, `Diamonds`, `Hearts`, `Spades`.
- The static resource is deployed as a zip (`force-app/main/default/staticresources/Cards.resource-meta.xml` plus the zip). The LWC references it with `@salesforce/resourceUrl/Cards`.
- Face-down (hole) card: the back image is not in the folder, so v1 shows a plain placeholder styled in CSS. The face-down card is replaced by the real card when the dealer reveals it.

## 5. Apex components

### `BlackjackEngine` (pure logic, no DML)
- Card and shoe model: builds the 52-card decks, shuffles, and deals from a 6-deck shoe.
- Hand scoring: returns the best total ≤ 21, counting aces as 1 or 11.
- Round rules: blackjack check, dealer draw rule, split and double rules, insurance, payouts.
- Holds no SOQL and no DML, so it's easy to test.

### `PlayerService`
- Reads the available players and loads one player's fund.
- After a round, updates `Fund__c`, `Highest_Bet__c`, `Highest_Hand__c` and `Highest_Earn__c` in a single DML call.

### `BlackjackGameController` (`@AuraEnabled` entry points used by the LWC)
- `getPlayers()`: returns `Id` and `Name` for the picker.
- `startRound(playerId, bet)`: validates `bet` ≤ `Fund__c` and `bet` > 0, deals the first cards, and returns the game state.
- `playerAction(gameId, action, handIndex)`: `HIT`, `STAND`, `DOUBLE`, `SPLIT`, `INSURANCE`. Returns the new state.
- `finishRound(gameId)`: settles all hands, updates the player record, returns the result.

## 6. Game state and where it lives

The state (shoe, dealer hand, player hands, bets, insurance) is held in memory on the server, keyed by a `gameId` that the LWC sends back on each action.

The state is stored in a `Blackjack_Round__c` record, so a page refresh or a new call can continue the round. Approved.

## 7. LWC

### `blackjackTable` (the game tab)
- Player picker (combobox fed by `getPlayers`).
- Bet input, validated against the player's fund on the client and again on the server.
- Dealer area: the up card, the hole card (hidden until the dealer plays), and the dealer total once revealed.
- Player area: one or more hands (after split), each with its total and bet.
- Action buttons: Hit, Stand, Double, Split, Insurance. A button is disabled when the action is not allowed in the current state.
- Result panel: outcome per hand and the change to the fund.

Card images are shown with `<img src={cardUrl}>` built from the rank and suit.

## 8. Salesforce metadata

- `Player__c` object, fields as in section 3, plus a default list view and a tab.
- `Blackjack_Round__c` object: stores the round state as JSON, plus the player lookup and status.
- Lightning tab "Blackjack" that displays `blackjackTable`.
- Custom app "Blackjack" that includes the Blackjack tab and the Players tab.
- Static resource `Cards`.
- Apex classes (section 5), and their test classes.
- Permission set granting read and write access to `Player__c` and the Apex classes.

## 9. Error handling

- Bet larger than the fund, or zero or negative: the server returns an error and the UI shows the message. No round starts. (Approved: block play when the fund is too low.)
- A fund of zero blocks every round until the record is edited.
- An action not allowed in the current state (for example, split on a non-pair, double after a hit) is rejected by Apex and disabled in the UI.
- Any DML error on settlement rolls back the round and the player record stays unchanged. The round is marked as failed.

## 10. Testing

- **Apex unit tests** (BlackjackEngine): ace handling (1 and 11), blackjack detection, 3:2 payout, dealer stops at 17, dealer bust, split and double rules, insurance payout, push returns the bet.
- **Apex tests** (PlayerService and controller): bet larger than the fund is rejected; stats update correctly after a win, a loss and a push; Highest Earn only changes when the fund goes above its previous high.
- **Jest tests** (`blackjackTable`): buttons enabled and disabled by state, the card image URL built from rank and suit.

## 11. Decisions

All open points are resolved:
1. Highest Hand is the best value of a winning hand (section 3).
2. Round state is stored in a `Blackjack_Round__c` record (section 6).
3. Shoe size: 6 decks.
4. Dealer stands on soft 17.
