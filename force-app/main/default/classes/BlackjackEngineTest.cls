@IsTest
private class BlackjackEngineTest {

    private static BlackjackEngine.Card card(String rank) {
        return new BlackjackEngine.Card(rank, 'Spades');
    }

    @IsTest
    static void testBestTotalCountsAceAsEleven() {
        List<BlackjackEngine.Card> cards = new List<BlackjackEngine.Card>{ card('Ace'), card('5') };
        Assert.areEqual(16, BlackjackEngine.bestTotal(cards));
    }

    @IsTest
    static void testBestTotalFallsBackToHardAce() {
        Assert.areEqual(16, BlackjackEngine.bestTotal(new List<BlackjackEngine.Card>{ card('Ace'), card('10'), card('5') }));
        Assert.areEqual(16, BlackjackEngine.bestTotal(new List<BlackjackEngine.Card>{ card('Ace'), card('King'), card('5') }));
        Assert.areEqual(21, BlackjackEngine.bestTotal(new List<BlackjackEngine.Card>{ card('Ace'), card('Ace'), card('9') }));
    }

    @IsTest
    static void testBlackjackIsTwoCardTwentyOne() {
        Assert.isTrue(BlackjackEngine.isBlackjack(new List<BlackjackEngine.Card>{ card('Ace'), card('King') }));
        Assert.isFalse(BlackjackEngine.isBlackjack(new List<BlackjackEngine.Card>{ card('7'), card('7'), card('7') }));
    }

    @IsTest
    static void testShoeHasSixDecks() {
        Assert.areEqual(312, new BlackjackEngine.Shoe(6).remaining());
    }

    @IsTest
    static void testShoeReshufflesWhenLow() {
        BlackjackEngine.Shoe shoe = new BlackjackEngine.Shoe(6);
        for (Integer i = 0; i < 261; i++) {
            shoe.draw();
        }
        Assert.isNotNull(shoe.draw());
        Assert.areEqual(311, shoe.remaining());
    }

    @IsTest
    static void testDealerStandsOnSoftSeventeen() {
        Assert.isFalse(BlackjackEngine.dealerMustHit(new List<BlackjackEngine.Card>{ card('Ace'), card('6') }));
    }

    @IsTest
    static void testDealerHitsOnSixteen() {
        Assert.isTrue(BlackjackEngine.dealerMustHit(new List<BlackjackEngine.Card>{ card('10'), card('6') }));
    }

    @IsTest
    static void testPayoutBlackjackIsThreeToTwo() {
        Assert.areEqual(150.0, BlackjackEngine.payout(100, 'BLACKJACK'));
    }

    @IsTest
    static void testPayoutPushReturnsZero() {
        Assert.areEqual(0.0, BlackjackEngine.payout(100, 'PUSH'));
    }

    @IsTest
    static void testCompareBlackjackBeatsTwentyOne() {
        String result = BlackjackEngine.compare(
            new List<BlackjackEngine.Card>{ card('Ace'), card('King') },
            new List<BlackjackEngine.Card>{ card('10'), card('5'), card('6') }
        );
        Assert.areEqual('BLACKJACK', result);
    }

    @IsTest
    static void testCompareBothBlackjackIsPush() {
        String result = BlackjackEngine.compare(
            new List<BlackjackEngine.Card>{ card('Ace'), card('King') },
            new List<BlackjackEngine.Card>{ card('Ace'), card('Queen') }
        );
        Assert.areEqual('PUSH', result);
    }

    @IsTest
    static void testInsuranceLosesWithoutDealerBlackjack() {
        Assert.areEqual(-50.0, BlackjackEngine.insurancePayout(50, false));
    }

    @IsTest
    static void testCanSplitOnlySamePair() {
        Assert.isTrue(BlackjackEngine.canSplit(new List<BlackjackEngine.Card>{ card('8'), card('8') }));
        Assert.isFalse(BlackjackEngine.canSplit(new List<BlackjackEngine.Card>{ card('8'), card('King') }));
    }
}
