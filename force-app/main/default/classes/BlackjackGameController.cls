public with sharing class BlackjackGameController {

    private static final Integer DECKS = 6;
    private static final Integer RESHUFFLE_THRESHOLD = 52;

    public class HandState {
        public List<String> cards;
        public Decimal bet;
        public String status;
    }

    public class RoundState {
        public String playerId;
        public Decimal initialBet;
        public List<String> shoe;
        public List<String> dealer;
        public List<HandState> hands;
        public Decimal insuranceBet;
        public Boolean peeked;
        public Boolean split;
        public List<String> results;
        public Decimal netChange;
    }

    @AuraEnabled
    public static List<Player__c> getPlayers() {
        return PlayerService.listPlayers();
    }

    @AuraEnabled
    public static Map<String, Object> startRound(Id playerId, Decimal bet) {
        List<Blackjack_Round__c> open = [
            SELECT Id FROM Blackjack_Round__c WHERE Player__c = :playerId AND Status__c = 'OPEN' LIMIT 1
        ];
        if (!open.isEmpty()) {
            return getRound(open[0].Id);
        }

        Decimal fund = orZero(PlayerService.getPlayer(playerId).Fund__c);
        if (bet == null || bet <= 0) {
            throw new AuraHandledException('Bet must be greater than zero.');
        }
        if (bet > fund) {
            throw new AuraHandledException('Not enough funds. Current fund: ' + fund);
        }

        RoundState st = new RoundState();
        st.playerId = String.valueOf(playerId);
        st.initialBet = bet;
        st.shoe = encodeAll(BlackjackEngine.newShoe(DECKS));
        List<String> playerCards = new List<String>{ dealCard(st) };
        st.dealer = new List<String>{ dealCard(st) };
        playerCards.add(dealCard(st));
        st.dealer.add(dealCard(st));
        st.hands = new List<HandState>{ newHand(playerCards, bet) };
        st.insuranceBet = 0;
        st.peeked = !isAce(st.dealer[0]);
        st.split = false;
        st.results = new List<String>();
        st.netChange = 0;

        Blackjack_Round__c round = new Blackjack_Round__c(
            Player__c = playerId,
            Status__c = 'OPEN',
            State_Json__c = JSON.serialize(st)
        );
        insert round;

        Boolean playerBlackjack = BlackjackEngine.isBlackjack(decodeAll(playerCards));
        if (playerBlackjack || (st.peeked && dealerHasBlackjack(st))) {
            settle(round, st);
        }
        return getRound(round.Id);
    }

    @AuraEnabled
    public static Map<String, Object> playerAction(Id roundId, String action, Integer handIndex) {
        Blackjack_Round__c round = getOpenRound(roundId);
        RoundState st = readState(round);
        if (!allowedActions(st).contains(action)) {
            throw new AuraHandledException(action + ' is not allowed in the current state.');
        }

        if (action == 'INSURANCE') {
            st.insuranceBet = st.initialBet / 2;
        }
        if (!st.peeked) {
            st.peeked = true;
            if (dealerHasBlackjack(st)) {
                settle(round, st);
                return getRound(round.Id);
            }
        }
        if (action != 'INSURANCE') {
            applyHandAction(st, action, handIndex == null ? 0 : handIndex);
        }

        if (activeHandIndex(st) == -1) {
            settle(round, st);
        } else {
            saveState(round, st);
        }
        return getRound(round.Id);
    }

    @AuraEnabled
    public static Map<String, Object> getRound(Id roundId) {
        Blackjack_Round__c round = getRoundRecord(roundId);
        return toView(round, readState(round));
    }

    private static void applyHandAction(RoundState st, String action, Integer index) {
        if (index < 0 || index >= st.hands.size() || st.hands[index].status != 'ACTIVE') {
            throw new AuraHandledException('That hand is not active.');
        }
        HandState hand = st.hands[index];

        if (action == 'HIT') {
            hand.cards.add(dealCard(st));
            if (handTotal(hand) > 21) {
                hand.status = 'BUSTED';
            }
        } else if (action == 'STAND') {
            hand.status = 'STOOD';
        } else if (action == 'DOUBLE') {
            if (hand.cards.size() != 2) {
                throw new AuraHandledException('Only a two-card hand can double down.');
            }
            requireFunds(st, hand.bet);
            hand.bet = hand.bet * 2;
            hand.cards.add(dealCard(st));
            hand.status = handTotal(hand) > 21 ? 'BUSTED' : 'STOOD';
        } else if (action == 'SPLIT') {
            if (st.hands.size() != 1 || !BlackjackEngine.canSplit(decodeAll(hand.cards))) {
                throw new AuraHandledException('Only a pair can be split, once per round.');
            }
            requireFunds(st, hand.bet);
            String first = hand.cards[0];
            String second = hand.cards[1];
            st.hands = new List<HandState>{
                newHand(new List<String>{ first, dealCard(st) }, hand.bet),
                newHand(new List<String>{ second, dealCard(st) }, hand.bet)
            };
            st.split = true;
        }
    }

    private static void settle(Blackjack_Round__c round, RoundState st) {
        List<BlackjackEngine.Card> dealerCards = decodeAll(st.dealer);
        Boolean dealerBlackjack = BlackjackEngine.isBlackjack(dealerCards);
        Boolean playerBlackjack = !st.split && st.hands.size() == 1
            && BlackjackEngine.isBlackjack(decodeAll(st.hands[0].cards));

        Boolean anyLiveHand = false;
        for (HandState hand : st.hands) {
            if (hand.status != 'BUSTED') {
                anyLiveHand = true;
            }
        }
        if (anyLiveHand && !dealerBlackjack && !playerBlackjack) {
            while (BlackjackEngine.dealerMustHit(dealerCards)) {
                String card = dealCard(st);
                st.dealer.add(card);
                dealerCards.add(decode(card));
            }
        }

        Decimal net = 0;
        Integer bestWin = null;
        st.results = new List<String>();
        for (HandState hand : st.hands) {
            List<BlackjackEngine.Card> handCards = decodeAll(hand.cards);
            String outcome = BlackjackEngine.compare(handCards, dealerCards);
            if (outcome == 'BLACKJACK' && st.split) {
                outcome = 'WIN';
            }
            st.results.add(outcome);
            net += BlackjackEngine.payout(hand.bet, outcome);
            if (outcome == 'WIN' || outcome == 'BLACKJACK') {
                Integer total = BlackjackEngine.bestTotal(handCards);
                if (bestWin == null || total > bestWin) {
                    bestWin = total;
                }
            }
        }
        net += BlackjackEngine.insurancePayout(st.insuranceBet, dealerBlackjack);

        st.netChange = net;
        round.Status__c = 'SETTLED';
        round.State_Json__c = JSON.serialize(st);
        update round;
        PlayerService.applyRound(Id.valueOf(st.playerId), st.initialBet, net, bestWin);
    }

    private static List<String> allowedActions(RoundState st) {
        List<String> actions = new List<String>();
        Integer index = activeHandIndex(st);
        if (index == -1) {
            return actions;
        }
        HandState hand = st.hands[index];
        Decimal fund = fundOf(st);
        Decimal committed = committedAmount(st);

        actions.add('HIT');
        actions.add('STAND');
        if (hand.cards.size() == 2 && committed + hand.bet <= fund) {
            actions.add('DOUBLE');
        }
        if (st.hands.size() == 1 && BlackjackEngine.canSplit(decodeAll(hand.cards)) && committed + hand.bet <= fund) {
            actions.add('SPLIT');
        }
        if (!st.peeked && isAce(st.dealer[0]) && st.insuranceBet == 0 && committed + st.initialBet / 2 <= fund) {
            actions.add('INSURANCE');
        }
        return actions;
    }

    private static Map<String, Object> toView(Blackjack_Round__c round, RoundState st) {
        Boolean settled = round.Status__c == 'SETTLED';

        List<Object> dealerView = new List<Object>();
        for (Integer i = 0; i < st.dealer.size(); i++) {
            Boolean holeHidden = !settled && i == 1;
            dealerView.add(holeHidden ? null : cardView(st.dealer[i]));
        }

        List<Object> handsView = new List<Object>();
        for (HandState hand : st.hands) {
            List<Object> cards = new List<Object>();
            for (String card : hand.cards) {
                cards.add(cardView(card));
            }
            handsView.add(new Map<String, Object>{
                'cards' => cards,
                'total' => handTotal(hand),
                'bet' => hand.bet,
                'status' => hand.status
            });
        }

        return new Map<String, Object>{
            'roundId' => round.Id,
            'status' => round.Status__c,
            'dealerCards' => dealerView,
            'dealerTotal' => settled ? BlackjackEngine.bestTotal(decodeAll(st.dealer)) : null,
            'hands' => handsView,
            'insuranceBet' => st.insuranceBet,
            'result' => settled ? st.results : null,
            'netChange' => settled ? st.netChange : null,
            'allowedActions' => settled ? new List<String>() : allowedActions(st)
        };
    }

    private static Blackjack_Round__c getRoundRecord(Id roundId) {
        List<Blackjack_Round__c> found = [
            SELECT Id, Status__c, State_Json__c FROM Blackjack_Round__c WHERE Id = :roundId
        ];
        if (found.isEmpty()) {
            throw new AuraHandledException('Round not found.');
        }
        return found[0];
    }

    private static Blackjack_Round__c getOpenRound(Id roundId) {
        Blackjack_Round__c round = getRoundRecord(roundId);
        if (round.Status__c != 'OPEN') {
            throw new AuraHandledException('This round is already settled.');
        }
        return round;
    }

    private static RoundState readState(Blackjack_Round__c round) {
        return (RoundState) JSON.deserialize(round.State_Json__c, RoundState.class);
    }

    private static void saveState(Blackjack_Round__c round, RoundState st) {
        round.State_Json__c = JSON.serialize(st);
        update round;
    }

    private static String dealCard(RoundState st) {
        if (st.shoe.size() < RESHUFFLE_THRESHOLD) {
            st.shoe = encodeAll(BlackjackEngine.newShoe(DECKS));
        }
        return st.shoe.remove(st.shoe.size() - 1);
    }

    private static HandState newHand(List<String> cards, Decimal bet) {
        HandState hand = new HandState();
        hand.cards = cards;
        hand.bet = bet;
        hand.status = 'ACTIVE';
        return hand;
    }

    private static Integer activeHandIndex(RoundState st) {
        for (Integer i = 0; i < st.hands.size(); i++) {
            if (st.hands[i].status == 'ACTIVE') {
                return i;
            }
        }
        return -1;
    }

    private static Integer handTotal(HandState hand) {
        return BlackjackEngine.bestTotal(decodeAll(hand.cards));
    }

    private static Decimal committedAmount(RoundState st) {
        Decimal total = orZero(st.insuranceBet);
        for (HandState hand : st.hands) {
            total += hand.bet;
        }
        return total;
    }

    private static Decimal fundOf(RoundState st) {
        return orZero(PlayerService.getPlayer(Id.valueOf(st.playerId)).Fund__c);
    }

    private static void requireFunds(RoundState st, Decimal extra) {
        if (committedAmount(st) + extra > fundOf(st)) {
            throw new AuraHandledException('Not enough funds for this action.');
        }
    }

    private static Boolean dealerHasBlackjack(RoundState st) {
        return BlackjackEngine.isBlackjack(decodeAll(st.dealer));
    }

    private static Boolean isAce(String encoded) {
        return encoded.startsWith('Ace|');
    }

    private static String encode(BlackjackEngine.Card card) {
        return card.rank + '|' + card.suit;
    }

    private static BlackjackEngine.Card decode(String encoded) {
        List<String> parts = encoded.split('\\|');
        return new BlackjackEngine.Card(parts[0], parts[1]);
    }

    private static List<String> encodeAll(List<BlackjackEngine.Card> cards) {
        List<String> encoded = new List<String>();
        for (BlackjackEngine.Card card : cards) {
            encoded.add(encode(card));
        }
        return encoded;
    }

    private static List<BlackjackEngine.Card> decodeAll(List<String> encoded) {
        List<BlackjackEngine.Card> cards = new List<BlackjackEngine.Card>();
        for (String value : encoded) {
            cards.add(decode(value));
        }
        return cards;
    }

    private static Map<String, Object> cardView(String encoded) {
        List<String> parts = encoded.split('\\|');
        return new Map<String, Object>{ 'rank' => parts[0], 'suit' => parts[1] };
    }

    private static Decimal orZero(Decimal value) {
        return value == null ? 0 : value;
    }
}
