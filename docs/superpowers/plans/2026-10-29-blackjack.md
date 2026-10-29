# Blackjack on Salesforce Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Blackjack game in Salesforce: a Lightning tab with an LWC table that plays rounds against the dealer, Apex that enforces the rules and the funds, and a `Player__c` object that stores fund and stats.

**Architecture:** Apex holds all game rules and database access. `BlackjackEngine` is pure logic with no SOQL or DML, so it can be tested alone. `PlayerService` reads and writes `Player__c`. `BlackjackGameController` is the `@AuraEnabled` layer, which loads and saves each round as a `Blackjack_Round__c` record. The LWC only renders state and sends the player's choices.

**Tech Stack:** Salesforce API 68.0, Apex, Lightning Web Components, Jest (`@salesforce/sfdx-lwc-jest`, already in `package.json`), `sf` CLI for deploy and tests.

**Spec:** `docs/superpowers/specs/2026-10-29-blackjack-design.md`

## Global Constraints

- API version: `68.0` (from `sfdx-project.json`).
- Project source root: `force-app/main/default/`. All metadata goes there.
- Card files: `<Rank>_of_<Suit>.png`, ranks `2`–`10`, `Jack`, `Queen`, `King`, `Ace`; suits `Clubs`, `Diamonds`, `Hearts`, `Spades`. Source folder: `C:\Users\Usuário\Pictures\Cards` (52 files).
- Shoe: 6 decks, reshuffled when fewer than 52 cards remain.
- Dealer hits while total is 16 or less and stands on every 17, including soft 17.
- Blackjack (two-card 21) pays 3:2. Other wins pay 1:1. Push returns the bet.
- Actions: `HIT`, `STAND`, `DOUBLE`, `SPLIT` (same rank pairs only, no re-split), `INSURANCE` (only when dealer up card is an Ace, costs half the bet, pays 2:1 if dealer has blackjack).
- Bet must be greater than 0 and no more than `Fund__c`. A fund of 0 blocks every round.
- `Player__c.Fund__c` default: 1000. Highest Earn = fund minus 1000.
- `Highest_Hand__c` range: 2 to 21, set only by winning hands.
- Card values: 2–10 face value, J/Q/K = 10, Ace = 1 or 11 (best total ≤ 21).
- Do not add `@AuraEnabled` methods beyond the four in Task 7.
- Commit messages end with `Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Bet equal to the full fund: allowed, fund becomes 0 after a loss, and the next round is blocked with a message.
2. Opening a second round for the same player while one is still open: the server returns the existing open round instead of creating a second one.
3. Shoe runs out mid-round: the engine reshuffles a new 6-deck shoe and the round finishes normally.
4. Double or split without enough fund for the extra bet: rejected by Apex with a message, and the round state is unchanged.
5. Page refresh mid-round: the LWC reloads the round from `Blackjack_Round__c` and the next action uses the same state.

Each item is pinned to the task that owns it below.

---

## File Structure

Created:
- `force-app/main/default/objects/Player__c/Player__c.object-meta.xml` (Task 1)
- `force-app/main/default/objects/Blackjack_Round__c/Blackjack_Round__c.object-meta.xml` (Task 5)
- `force-app/main/default/staticresources/Cards.resource-meta.xml` and `Cards.zip` (Task 2)
- `force-app/main/default/classes/BlackjackEngine.cls` and `BlackjackEngineTest.cls` (Tasks 3–4)
- `force-app/main/default/classes/PlayerService.cls` and `PlayerServiceTest.cls` (Task 6)
- `force-app/main/default/classes/BlackjackGameController.cls` and `BlackjackGameControllerTest.cls` (Task 7)
- `force-app/main/default/lwc/blackjackTable/` with `.html`, `.js`, `.css`, `.js-meta.xml`, `__tests__/blackjackTable.test.js` (Task 8)
- `force-app/main/default/tabs/Blackjack.tab-meta.xml`, `Player__c.tab-meta.xml` (Task 9)
- `force-app/main/default/applications/Blackjack.app-meta.xml` (Task 9)
- `force-app/main/default/permissionsets/Blackjack_User.permissionset-meta.xml` (Task 9)

Each task below names its exact files.

---

### Task 1: Player__c object

**Files:**
- Create: `force-app/main/default/objects/Player__c/Player__c.object-meta.xml`
- Create: `force-app/main/default/objects/Player__c/fields/Fund__c.field-meta.xml`
- Create: `force-app/main/default/objects/Player__c/fields/Highest_Bet__c.field-meta.xml`
- Create: `force-app/main/default/objects/Player__c/fields/Highest_Hand__c.field-meta.xml`
- Create: `force-app/main/default/objects/Player__c/fields/Highest_Earn__c.field-meta.xml`

**Interfaces:**
- Consumes: nothing.
- Produces: `Player__c` with `Name` (Text), `Fund__c` (Currency), `Highest_Bet__c` (Currency), `Highest_Hand__c` (Number, precision 2 scale 0, 0 to 21), `Highest_Earn__c` (Currency).

- [ ] **Step 1: Create the object and the five field metadata files**

`Player__c.object-meta.xml`: `nameField` type `Text`, label "Player", plural "Players", sharing `ReadWrite`.
Each field: `Fund__c` defaultValue `1000`, `Highest_Bet__c`, `Highest_Earn__c` as Currency precision 16 scale 2, `Highest_Hand__c` as Number precision 2 scale 0.

- [ ] **Step 2: Validate the metadata**

Run: `sf project deploy start --source-dir force-app/main/default/objects/Player__c --dry-run --target-org <alias>`
Expected: "Deploy Succeeded" with 6 components.

- [ ] **Step 3: Commit**

```bash
git add force-app/main/default/objects/Player__c
git commit -m "feat: add Player__c object with fund and stat fields" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Card static resource

**Files:**
- Create: `force-app/main/default/staticresources/Cards.resource-meta.xml`
- Create: `force-app/main/default/staticresources/Cards.zip` (built from the 52 PNG files)

**Interfaces:**
- Consumes: nothing.
- Produces: static resource `Cards`. A file inside it is reached as `@salesforce/resourceUrl/Cards` plus the file path, e.g. `Ace_of_Spades.png` at the zip root.

- [ ] **Step 1: Zip the 52 PNG files at the root of the archive**

Run (PowerShell): `Compress-Archive -Path "C:\Users\Usuário\Pictures\Cards\*.png" -DestinationPath force-app\main\default\staticresources\Cards.zip`
Expected: archive exists; `Expand-Archive` lists 52 files directly at the root (no subfolder).

- [ ] **Step 2: Write the resource metadata**

`Cards.resource-meta.xml`: `contentType` `application/zip`, `cacheControl` `Public`.

- [ ] **Step 3: Verify the archive**

Run: `tar -tf force-app/main/default/staticresources/Cards.zip | wc -l`
Expected: `52`.

- [ ] **Step 4: Commit**

```bash
git add force-app/main/default/staticresources
git commit -m "feat: add Cards static resource with 52 card images" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Card model, shoe, and hand scoring in BlackjackEngine

**Files:**
- Create: `force-app/main/default/classes/BlackjackEngine.cls`
- Create: `force-app/main/default/classes/BlackjackEngine.cls-meta.xml`
- Create: `force-app/main/default/classes/BlackjackEngineTest.cls`
- Create: `force-app/main/default/classes/BlackjackEngineTest.cls-meta.xml`

**Interfaces:**
- Produces:
  - Inner class `BlackjackEngine.Card` with `String rank`, `String suit`, `Integer value()` (J/Q/K = 10, Ace = 1 as the base value, others face value).
  - Inner class `BlackjackEngine.Shoe` with constructor `Shoe(Integer decks)`, method `Card draw()` (reshuffles a new shoe when fewer than 52 cards remain), method `Integer remaining()`.
  - Static `Integer bestTotal(List<Card> cards)`: highest total ≤ 21 with aces as 11 where possible, else the hard total.
  - Static `Boolean isBlackjack(List<Card> cards)`: exactly two cards with best total 21.

- [ ] **Step 1: Write failing tests**

Tests (in `BlackjackEngineTest`):
- `testBestTotalCountsAceAsEleven`: cards Ace + 5 → `bestTotal` returns 16.
- `testBestTotalFallsBackToHardAce`: Ace + 10 + 5 → returns 16; Ace + King + 5 → 16; Ace + Ace + 9 → 21.
- `testBlackjackIsTwoCardTwentyOne`: Ace + King → `isBlackjack` true; Ace + 5 + 5 + ... (three cards totalling 21) → false.
- `testShoeHasSixDecks`: `new Shoe(6).remaining()` equals 312.
- `testShoeReshufflesWhenLow`: draw 261 cards from a 6-deck shoe; the next `draw()` returns a card and `remaining()` is 312 − 1 = 311 or greater.

- [ ] **Step 2: Run tests to verify they fail**

Run: `sf apex run test --class-names BlackjackEngineTest --target-org <alias> --result-format human`
Expected: FAIL, class `BlackjackEngine` does not exist.

- [ ] **Step 3: Implement the card, shoe and scoring methods**

Build the 52 cards per deck with ranks `2`–`10`, `Jack`, `Queen`, `King`, `Ace` and suits `Clubs`, `Diamonds`, `Hearts`, `Spades`. Shuffle with `Math.random()`. Scoring: sum the base values, then add 10 for each ace while the total stays ≤ 21.

- [ ] **Step 4: Run tests to verify they pass**

Run: same command as Step 2.
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add force-app/main/default/classes/BlackjackEngine.cls force-app/main/default/classes/BlackjackEngine.cls-meta.xml force-app/main/default/classes/BlackjackEngineTest.cls force-app/main/default/classes/BlackjackEngineTest.cls-meta.xml
git commit -m "feat: add card, shoe and hand scoring to BlackjackEngine" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Round rules in BlackjackEngine

**Files:**
- Modify: `force-app/main/default/classes/BlackjackEngine.cls`
- Modify: `force-app/main/default/classes/BlackjackEngineTest.cls`

**Interfaces:**
- Consumes: `Card`, `Shoe`, `bestTotal`, `isBlackjack` from Task 3.
- Produces:
  - `Boolean dealerMustHit(List<Card> cards)`: true when `bestTotal` ≤ 16. Stands on every 17 (soft 17 included).
  - `Decimal payout(Decimal bet, String outcome)`: `BLACKJACK` → `bet * 1.5`, `WIN` → `bet`, `PUSH` → `0`, `LOSE` → `-bet`. Outcome strings are exactly these four values.
  - `String compare(List<Card> player, List<Card> dealer)`: returns `BLACKJACK`, `WIN`, `PUSH` or `LOSE`. A player blackjack against a dealer non-blackjack returns `BLACKJACK`. Both blackjack returns `PUSH`.
  - `Decimal insurancePayout(Decimal insuranceBet, Boolean dealerBlackjack)`: `insuranceBet * 2` when dealer has blackjack, else `-insuranceBet`.
  - `Boolean canSplit(List<Card> cards)`: exactly two cards with the same rank.
  - `Boolean canDouble(List<Card> cards)`: exactly two cards.

- [ ] **Step 1: Write failing tests**

Tests:
- `testDealerStandsOnSoftSeventeen`: Ace + 6 → `dealerMustHit` false.
- `testDealerHitsOnSixteen`: 10 + 6 → true.
- `testPayoutBlackjackIsThreeToTwo`: `payout(100, 'BLACKJACK')` → 150.
- `testPayoutPushReturnsZero`: `payout(100, 'PUSH')` → 0.
- `testCompareBlackjackBeatsTwentyOne`: player Ace+King vs dealer 10+5+6 → `BLACKJACK`.
- `testCompareBothBlackjackIsPush`.
- `testInsuranceLosesWithoutDealerBlackjack`: `insurancePayout(50, false)` → -50.
- `testCanSplitOnlySamePair`: 8+8 true, 8+K false.

- [ ] **Step 2: Run tests to verify they fail**

Run: `sf apex run test --class-names BlackjackEngineTest --target-org <alias> --result-format human`
Expected: FAIL, methods not defined.

- [ ] **Step 3: Implement the methods**

Use `bestTotal` for every comparison. `compare` checks blackjack first, then totals. A total over 21 is a loss, and the comparison is done on `bestTotal`.

- [ ] **Step 4: Run tests to verify they pass**

Run: same as Step 2.
Expected: PASS, 8 new tests plus the 5 from Task 3.

- [ ] **Step 5: Commit**

```bash
git add force-app/main/default/classes/BlackjackEngine.cls force-app/main/default/classes/BlackjackEngineTest.cls
git commit -m "feat: add dealer, payout, split, double and insurance rules" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Blackjack_Round__c object

**Files:**
- Create: `force-app/main/default/objects/Blackjack_Round__c/Blackjack_Round__c.object-meta.xml`
- Create: `force-app/main/default/objects/Blackjack_Round__c/fields/Player__c.field-meta.xml`
- Create: `force-app/main/default/objects/Blackjack_Round__c/fields/Status__c.field-meta.xml`
- Create: `force-app/main/default/objects/Blackjack_Round__c/fields/State_Json__c.field-meta.xml`

**Interfaces:**
- Produces: `Blackjack_Round__c` with `Player__c` (Lookup to `Player__c`), `Status__c` (Picklist: `OPEN`, `SETTLED`, `FAILED`), `State_Json__c` (Long Text Area, length 131072).

- [ ] **Step 1: Create the object and field metadata**

`Name` as Auto Number, prefix `RND-`. `Player__c` is a required lookup, relationship name `Rounds`, delete constraint `Cascade`.

- [ ] **Step 2: Validate**

Run: `sf project deploy start --source-dir force-app/main/default/objects/Blackjack_Round__c --dry-run --target-org <alias>`
Expected: "Deploy Succeeded".

- [ ] **Step 3: Commit**

```bash
git add force-app/main/default/objects/Blackjack_Round__c
git commit -m "feat: add Blackjack_Round__c to store round state" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 6: PlayerService

**Files:**
- Create: `force-app/main/default/classes/PlayerService.cls`
- Create: `force-app/main/default/classes/PlayerService.cls-meta.xml`
- Create: `force-app/main/default/classes/PlayerServiceTest.cls`
- Create: `force-app/main/default/classes/PlayerServiceTest.cls-meta.xml`

**Interfaces:**
- Consumes: `Player__c` (Task 1).
- Produces:
  - `static List<Player__c> listPlayers()`: `Id`, `Name`, `Fund__c` ordered by Name.
  - `static Player__c getPlayer(Id playerId)`.
  - `static void applyRound(Id playerId, Decimal bet, Decimal netChange, Integer bestHandWon)`: updates the player in one DML call.
    - `Fund__c` += `netChange`.
    - `Highest_Bet__c` = max(current, bet).
    - `Highest_Hand__c` = max(current, `bestHandWon`) only when `bestHandWon` is not null. Pass null for losses and pushes.
    - `Highest_Earn__c` = max(current, `Fund__c` − 1000).

- [ ] **Step 1: Write failing tests**

Tests (in `PlayerServiceTest`, using test data created in the test):
- `testWinUpdatesFundAndStats`: fund 1000, `applyRound(id, 100, 100, 19)` → fund 1100, highest bet 100, highest hand 19, highest earn 100.
- `testLossDoesNotChangeHighestHand`: `applyRound(id, 100, -100, null)` → highest hand unchanged.
- `testHighestEarnOnlyRisesAboveBest`: after a win to 1200, a loss to 1100 leaves highest earn at 200.
- `testUnknownPlayerThrows`: `getPlayer` with a random Id throws `QueryException`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `sf apex run test --class-names PlayerServiceTest --target-org <alias> --result-format human`
Expected: FAIL, class not defined.

- [ ] **Step 3: Implement the service**

Use `with sharing`. Read with SOQL, update one record, and call `update` once per round.

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add force-app/main/default/classes/PlayerService.cls force-app/main/default/classes/PlayerService.cls-meta.xml force-app/main/default/classes/PlayerServiceTest.cls force-app/main/default/classes/PlayerServiceTest.cls-meta.xml
git commit -m "feat: add PlayerService to read players and apply round results" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 7: BlackjackGameController

**Files:**
- Create: `force-app/main/default/classes/BlackjackGameController.cls`
- Create: `force-app/main/default/classes/BlackjackGameController.cls-meta.xml`
- Create: `force-app/main/default/classes/BlackjackGameControllerTest.cls`
- Create: `force-app/main/default/classes/BlackjackGameControllerTest.cls-meta.xml`

**Interfaces:**
- Consumes: `BlackjackEngine` (Tasks 3–4), `PlayerService` (Task 6), `Blackjack_Round__c` (Task 5).
- Produces (all `@AuraEnabled`):
  - `static List<Player__c> getPlayers()`.
  - `static Map<String, Object> startRound(Id playerId, Decimal bet)`: validates bet (> 0 and ≤ fund, else `AuraHandledException`). Returns the open round if one exists for the player (Review Focus 2). Otherwise creates a `Blackjack_Round__c` with `Status__c` `OPEN` and the serialized state; the state holds shoe, dealer hand, player hands with bets, insurance, and the round's `Id`. Returns the round `Id` plus the visible state.
  - `static Map<String, Object> playerAction(Id roundId, String action, Integer handIndex)`: runs `HIT`, `STAND`, `DOUBLE`, `SPLIT` or `INSURANCE`, rejects an action not allowed in the current state with `AuraHandledException`, saves the state, and settles the round through `PlayerService.applyRound` when all hands are done. Doubling or splitting checks that the fund covers the extra bet (Review Focus 4).
  - `static Map<String, Object> getRound(Id roundId)`: returns the visible state (for refresh, Review Focus 5). The dealer's hole card is hidden until the dealer plays.
  - Visible state keys: `roundId`, `status`, `dealerCards` (hole card hidden as `null` while `status` is `OPEN`), `dealerTotal`, `hands` (list of `{cards, total, bet, status}`), `insuranceBet`, `result` (list of outcomes per hand when settled), `netChange`.

- [ ] **Step 1: Write failing tests**

Tests (with a `Player__c` created in the test):
- `testStartRoundRejectsBetAboveFund`: fund 1000, bet 1500 → `AuraHandledException`.
- `testStartRoundRejectsZeroFund`: fund 0, any bet → exception.
- `testStartRoundReturnsOpenRound` (Review Focus 2): call `startRound` twice → same `roundId`, one `Blackjack_Round__c` row.
- `testRefreshReturnsSameState` (Review Focus 5): `startRound`, then `getRound` returns the same hands and dealer up card.
- `testDoubleRejectedWithoutFund` (Review Focus 4): fund 150, bet 100 → `DOUBLE` throws and the stored state is unchanged.
- `testStandSettlesAndUpdatesPlayer`: a round finishing with `STAND` → `Blackjack_Round__c.Status__c` `SETTLED` and player fund changed.

- [ ] **Step 2: Run tests to verify they fail**

Run: `sf apex run test --class-names BlackjackGameControllerTest --target-org <alias> --result-format human`
Expected: FAIL.

- [ ] **Step 3: Implement the controller**

Serialize state with `JSON.serialize` into `State_Json__c`. Keep the engine's shoe inside the state: a shuffled list of remaining cards is saved so the shoe is the same across calls (this supports Review Focus 3, where the engine rebuilds the shoe when it runs out). Use `with sharing`.

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add force-app/main/default/classes/BlackjackGameController.cls force-app/main/default/classes/BlackjackGameController.cls-meta.xml force-app/main/default/classes/BlackjackGameControllerTest.cls force-app/main/default/classes/BlackjackGameControllerTest.cls-meta.xml
git commit -m "feat: add BlackjackGameController with round actions" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 8: blackjackTable LWC

**Files:**
- Create: `force-app/main/default/lwc/blackjackTable/blackjackTable.html`
- Create: `force-app/main/default/lwc/blackjackTable/blackjackTable.js`
- Create: `force-app/main/default/lwc/blackjackTable/blackjackTable.css`
- Create: `force-app/main/default/lwc/blackjackTable/blackjackTable.js-meta.xml`
- Create: `force-app/main/default/lwc/blackjackTable/__tests__/blackjackTable.test.js`

**Interfaces:**
- Consumes: `getPlayers`, `startRound`, `playerAction`, `getRound` from Task 7; static resource `Cards` from Task 2.
- Produces: component `c-blackjack-table` with a player combobox, bet input, dealer and player hand areas, and Hit, Stand, Double, Split and Insurance buttons.
- Card image URL: `${cardsUrl}/${rank}_of_${suit}.png`, where `cardsUrl` comes from `@salesforce/resourceUrl/Cards`. Face-down card shows a CSS placeholder.
- Buttons disabled when the server state does not allow the action (for example Split when the first hand is not a pair, Insurance when the dealer's up card is not an Ace).
- On page load, if a round is open for the chosen player, call `getRound` (Review Focus 5).
- `js-meta.xml`: target `lightning__Tab` only.

- [ ] **Step 1: Write failing Jest tests**

Tests in `blackjackTable.test.js` (mock the Apex imports with `jest.mock`):
- `disables Split when the first hand is not a pair`: state with 10 + 6, `Split` button disabled.
- `enables Insurance only when dealer shows an Ace`.
- `renders the card image URL from rank and suit`: a card `{rank: 'King', suit: 'Spades'}` renders `King_of_Spades.png` in the image `src`.
- `shows a bet error from the server` (Review Focus 1): mocked `startRound` rejects → an error message appears.

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx sfdx-lwc-jest -- force-app/main/default/lwc/blackjackTable`
Expected: FAIL, component not found.

- [ ] **Step 3: Implement the component**

Keep the state in one tracked object returned by the server. Disable buttons from the server's allowed-action list. Do not compute game rules in JavaScript.

- [ ] **Step 4: Run tests to verify they pass**

Run: same as Step 2.
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add force-app/main/default/lwc/blackjackTable
git commit -m "feat: add blackjackTable LWC for the game screen" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Tabs, app, and permission set

**Files:**
- Create: `force-app/main/default/tabs/Blackjack.tab-meta.xml`
- Create: `force-app/main/default/tabs/Player__c.tab-meta.xml`
- Create: `force-app/main/default/applications/Blackjack.app-meta.xml`
- Create: `force-app/main/default/permissionsets/Blackjack_User.permissionset-meta.xml`

**Interfaces:**
- Consumes: `c-blackjack-table` (Task 8), `Player__c` (Task 1), Apex classes from Tasks 3–7, `Blackjack_Round__c` (Task 5).
- Produces: a tab "Blackjack" for the LWC (`lightning__Tab` target), a tab "Players" for `Player__c`, an app "Blackjack" with both tabs, and a permission set giving read/write on `Player__c` and `Blackjack_Round__c`, and access to the four Apex classes.

- [ ] **Step 1: Create the metadata**

The Blackjack tab's `customComponent` is the LWC `blackjackTable`. The app's `tabs` list has the Blackjack and Players tabs. The permission set has `objectPermissions` for both objects and `classAccesses` for `BlackjackGameController` and `PlayerService`.

- [ ] **Step 2: Validate**

Run: `sf project deploy start --source-dir force-app/main/default --dry-run --target-org <alias>`
Expected: "Deploy Succeeded". Any failure is listed with its file.

- [ ] **Step 3: Commit**

```bash
git add force-app/main/default/tabs force-app/main/default/applications force-app/main/default/permissionsets
git commit -m "feat: add Blackjack tab, Players tab, app and permission set" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Deploy and end-to-end check

**Files:** none changed.

**Interfaces:**
- Consumes: everything from Tasks 1–9.

- [ ] **Step 1: Run the full Apex test suite**

Run: `sf apex run test --test-level RunLocalTests --target-org <alias> --code-coverage --result-format human`
Expected: all tests pass. Coverage for `BlackjackEngine`, `PlayerService` and `BlackjackGameController` is at least 75%, which Salesforce requires for deploy to production.

- [ ] **Step 2: Run the Jest suite**

Run: `npm run test:unit`
Expected: `blackjackTable` tests pass.

- [ ] **Step 3: Deploy to the scratch or sandbox org**

Run: `sf project deploy start --source-dir force-app --target-org <alias>`
Expected: "Deploy Succeeded".

- [ ] **Step 4: Manual check in the org**

Open the Blackjack app. Pick a player with fund 1000, bet 100, play a round, and check: the card images show, the buttons match the rules, the fund changes, and `Highest_Bet__c`, `Highest_Hand__c` and `Highest_Earn__c` update on the Player record. Refresh mid-round and confirm the round continues.

- [ ] **Step 5: Commit any fixes found in the check**

```bash
git add -A
git commit -m "fix: adjust blackjack game after end-to-end check" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
```

---

## Review Focus coverage

| Review Focus item | Test or check | Task |
|---|---|---|
| 1. Bet equal to full fund | `startRound` allows bet = fund; LWC shows message on a server error | 7, 8 |
| 2. Second round for same player | `testStartRoundReturnsOpenRound` | 7 |
| 3. Shoe runs out mid-round | `testShoeReshufflesWhenLow` | 3 |
| 4. Double or split without fund | `testDoubleRejectedWithoutFund` | 7 |
| 5. Page refresh mid-round | `testRefreshReturnsSameState`, Jest open-round load | 7, 8 |
