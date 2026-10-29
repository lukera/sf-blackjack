public with sharing class PlayerService {

    private static final Decimal STARTING_FUND = 1000;

    public static List<Player__c> listPlayers() {
        return [SELECT Id, Name, Fund__c FROM Player__c ORDER BY Name];
    }

    public static Player__c getPlayer(Id playerId) {
        List<Player__c> found = [
            SELECT Id, Name, Fund__c, Highest_Bet__c, Highest_Hand__c, Highest_Earn__c
            FROM Player__c
            WHERE Id = :playerId
        ];
        if (found.isEmpty()) {
            throw new QueryException('Player not found: ' + playerId);
        }
        return found[0];
    }

    public static void applyRound(Id playerId, Decimal bet, Decimal netChange, Integer bestHandWon) {
        Player__c player = getPlayer(playerId);
        Decimal fund = orZero(player.Fund__c) + netChange;

        player.Fund__c = fund;
        player.Highest_Bet__c = maxOf(player.Highest_Bet__c, bet);
        if (bestHandWon != null) {
            player.Highest_Hand__c = maxOf(player.Highest_Hand__c, bestHandWon).intValue();
        }
        player.Highest_Earn__c = maxOf(player.Highest_Earn__c, fund - STARTING_FUND);
        update player;
    }

    private static Decimal orZero(Decimal value) {
        return value == null ? 0 : value;
    }

    private static Decimal maxOf(Decimal current, Decimal candidate) {
        return Math.max(orZero(current), candidate);
    }
}
