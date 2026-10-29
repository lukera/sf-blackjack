@IsTest
private class PlayerServiceTest {

    private static Id createPlayer() {
        Player__c player = new Player__c(Name = 'Test Player');
        insert player;
        return player.Id;
    }

    @IsTest
    static void testWinUpdatesFundAndStats() {
        Id playerId = createPlayer();

        PlayerService.applyRound(playerId, 100, 100, 19);

        Player__c player = PlayerService.getPlayer(playerId);
        Assert.areEqual(1100.0, player.Fund__c);
        Assert.areEqual(100.0, player.Highest_Bet__c);
        Assert.areEqual(19, player.Highest_Hand__c);
        Assert.areEqual(100.0, player.Highest_Earn__c);
    }

    @IsTest
    static void testLossDoesNotChangeHighestHand() {
        Id playerId = createPlayer();
        PlayerService.applyRound(playerId, 100, 100, 19);

        PlayerService.applyRound(playerId, 100, -100, null);

        Assert.areEqual(19, PlayerService.getPlayer(playerId).Highest_Hand__c);
    }

    @IsTest
    static void testHighestEarnOnlyRisesAboveBest() {
        Id playerId = createPlayer();
        PlayerService.applyRound(playerId, 200, 200, 21);

        PlayerService.applyRound(playerId, 100, -100, null);

        Assert.areEqual(200.0, PlayerService.getPlayer(playerId).Highest_Earn__c);
    }

    @IsTest
    static void testUnknownPlayerThrows() {
        Player__c player = new Player__c(Name = 'Deleted Player');
        insert player;
        Id deletedId = player.Id;
        delete player;

        Boolean thrown = false;
        try {
            PlayerService.getPlayer(deletedId);
        } catch (QueryException e) {
            thrown = true;
        }
        Assert.isTrue(thrown);
    }
}
