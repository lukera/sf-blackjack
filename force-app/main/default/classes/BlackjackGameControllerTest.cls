@IsTest
private class BlackjackGameControllerTest {

    private static Id createPlayer(Decimal fund) {
        Player__c player = new Player__c(Name = 'Test Player', Fund__c = fund);
        insert player;
        return player.Id;
    }

    // Starts rounds until one is open for play, so the test never depends on a
    // blackjack deal that settles the round before the first action.
    private static Map<String, Object> openRound(Id playerId, Decimal bet) {
        for (Integer i = 0; i < 200; i++) {
            Map<String, Object> state = BlackjackGameController.startRound(playerId, bet);
            if (state.get('status') == 'OPEN') {
                return state;
            }
        }
        Assert.fail('No open round after 200 attempts');
        return null;
    }

    @IsTest
    static void testStartRoundRejectsBetAboveFund() {
        Id playerId = createPlayer(1000);
        Boolean thrown = false;
        try {
            BlackjackGameController.startRound(playerId, 1500);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Assert.isTrue(thrown);
    }

    @IsTest
    static void testStartRoundRejectsZeroFund() {
        Id playerId = createPlayer(0);
        Boolean thrown = false;
        try {
            BlackjackGameController.startRound(playerId, 10);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Assert.isTrue(thrown);
    }

    @IsTest
    static void testStartRoundReturnsOpenRound() {
        Id playerId = createPlayer(1000);
        Map<String, Object> first = openRound(playerId, 100);

        Map<String, Object> second = BlackjackGameController.startRound(playerId, 100);

        Assert.areEqual(first.get('roundId'), second.get('roundId'));
        Integer openRounds = [
            SELECT COUNT() FROM Blackjack_Round__c WHERE Player__c = :playerId AND Status__c = 'OPEN'
        ];
        Assert.areEqual(1, openRounds);
    }

    @IsTest
    static void testRefreshReturnsSameState() {
        Id playerId = createPlayer(1000);
        Map<String, Object> started = openRound(playerId, 100);

        Map<String, Object> refreshed = BlackjackGameController.getRound((Id) started.get('roundId'));

        Assert.areEqual(started.get('hands'), refreshed.get('hands'));
        Assert.areEqual(started.get('dealerCards'), refreshed.get('dealerCards'));
    }

    @IsTest
    static void testDoubleRejectedWithoutFund() {
        Id playerId = createPlayer(150);
        Map<String, Object> started = openRound(playerId, 100);
        Id roundId = (Id) started.get('roundId');
        String before = [SELECT State_Json__c FROM Blackjack_Round__c WHERE Id = :roundId].State_Json__c;

        Boolean thrown = false;
        try {
            BlackjackGameController.playerAction(roundId, 'DOUBLE', 0);
        } catch (AuraHandledException e) {
            thrown = true;
        }

        Assert.isTrue(thrown);
        String after = [SELECT State_Json__c FROM Blackjack_Round__c WHERE Id = :roundId].State_Json__c;
        Assert.areEqual(before, after);
    }

    @IsTest
    static void testStandSettlesAndUpdatesPlayer() {
        Id playerId = createPlayer(1000);
        Map<String, Object> started = openRound(playerId, 100);
        Id roundId = (Id) started.get('roundId');

        Map<String, Object> settled = BlackjackGameController.playerAction(roundId, 'STAND', 0);

        Assert.areEqual('SETTLED', settled.get('status'));
        Player__c player = PlayerService.getPlayer(playerId);
        Assert.areEqual(1000 + (Decimal) settled.get('netChange'), player.Fund__c);
    }

    @IsTest
    static void testGetOpenRoundIsNullWithoutOpenRound() {
        Id playerId = createPlayer(1000);
        Assert.isNull(BlackjackGameController.getOpenRound(playerId));
    }

    @IsTest
    static void testGetOpenRoundReturnsTheOpenRound() {
        Id playerId = createPlayer(1000);
        Map<String, Object> started = openRound(playerId, 100);

        Map<String, Object> found = BlackjackGameController.getOpenRound(playerId);

        Assert.areEqual(started.get('roundId'), found.get('roundId'));
    }
}
