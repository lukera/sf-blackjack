public class BlackjackEngine {

    private static final List<String> RANKS = new List<String>{
        'Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King'
    };
    private static final List<String> SUITS = new List<String>{ 'Clubs', 'Diamonds', 'Hearts', 'Spades' };
    private static final Integer RESHUFFLE_THRESHOLD = 52;

    public class Card {
        public String rank { get; private set; }
        public String suit { get; private set; }

        public Card(String rank, String suit) {
            this.rank = rank;
            this.suit = suit;
        }

        public Integer value() {
            if (rank == 'Ace') {
                return 1;
            }
            if (rank == 'Jack' || rank == 'Queen' || rank == 'King') {
                return 10;
            }
            return Integer.valueOf(rank);
        }
    }

    public class Shoe {
        private Integer decks;
        private List<Card> cards;

        public Shoe(Integer decks) {
            this.decks = decks;
            reshuffle();
        }

        public Card draw() {
            if (cards.size() < RESHUFFLE_THRESHOLD) {
                reshuffle();
            }
            return cards.remove(cards.size() - 1);
        }

        public Integer remaining() {
            return cards.size();
        }

        private void reshuffle() {
            cards = new List<Card>();
            for (Integer d = 0; d < decks; d++) {
                for (String suit : SUITS) {
                    for (String rank : RANKS) {
                        cards.add(new Card(rank, suit));
                    }
                }
            }
            for (Integer i = cards.size() - 1; i > 0; i--) {
                Integer j = (Integer) Math.floor(Math.random() * (i + 1));
                Card swap = cards[i];
                cards[i] = cards[j];
                cards[j] = swap;
            }
        }
    }

    public static Integer bestTotal(List<Card> cards) {
        Integer total = 0;
        Integer aces = 0;
        for (Card c : cards) {
            total += c.value();
            if (c.rank == 'Ace') {
                aces++;
            }
        }
        for (Integer i = 0; i < aces; i++) {
            if (total + 10 <= 21) {
                total += 10;
            }
        }
        return total;
    }

    public static Boolean isBlackjack(List<Card> cards) {
        return cards.size() == 2 && bestTotal(cards) == 21;
    }

    public static Boolean dealerMustHit(List<Card> cards) {
        return bestTotal(cards) <= 16;
    }

    public static Decimal payout(Decimal bet, String outcome) {
        if (outcome == 'BLACKJACK') {
            return bet * 1.5;
        }
        if (outcome == 'WIN') {
            return bet;
        }
        if (outcome == 'LOSE') {
            return -bet;
        }
        return 0;
    }

    public static String compare(List<Card> player, List<Card> dealer) {
        Boolean playerBlackjack = isBlackjack(player);
        Boolean dealerBlackjack = isBlackjack(dealer);
        if (playerBlackjack && dealerBlackjack) {
            return 'PUSH';
        }
        if (playerBlackjack) {
            return 'BLACKJACK';
        }
        if (dealerBlackjack) {
            return 'LOSE';
        }
        Integer playerTotal = bestTotal(player);
        Integer dealerTotal = bestTotal(dealer);
        if (playerTotal > 21) {
            return 'LOSE';
        }
        if (dealerTotal > 21 || playerTotal > dealerTotal) {
            return 'WIN';
        }
        if (playerTotal < dealerTotal) {
            return 'LOSE';
        }
        return 'PUSH';
    }

    public static Decimal insurancePayout(Decimal insuranceBet, Boolean dealerBlackjack) {
        return dealerBlackjack ? insuranceBet * 2 : -insuranceBet;
    }

    public static Boolean canSplit(List<Card> cards) {
        return cards.size() == 2 && cards[0].rank == cards[1].rank;
    }

    public static Boolean canDouble(List<Card> cards) {
        return cards.size() == 2;
    }
}
