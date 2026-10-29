import { LightningElement } from "lwc";
import CARDS from "@salesforce/resourceUrl/Cards";
import getPlayers from "@salesforce/apex/BlackjackGameController.getPlayers";
import getOpenRound from "@salesforce/apex/BlackjackGameController.getOpenRound";
import startRound from "@salesforce/apex/BlackjackGameController.startRound";
import playerAction from "@salesforce/apex/BlackjackGameController.playerAction";

const ACTIONS = [
  { action: "HIT", label: "Hit" },
  { action: "STAND", label: "Stand" },
  { action: "DOUBLE", label: "Double" },
  { action: "SPLIT", label: "Split" },
  { action: "INSURANCE", label: "Insurance" }
];

function cardImage(card) {
  return `${CARDS}/${card.rank}_of_${card.suit}.png`;
}

export default class BlackjackTable extends LightningElement {
  players = [];
  selectedPlayerId;
  bet = 100;
  round;
  errorMessage;

  connectedCallback() {
    getPlayers()
      .then((players) => {
        this.players = players;
      })
      .catch((error) => this.showError(error));
  }

  get playerOptions() {
    return this.players.map((player) => ({
      label: player.Name,
      value: player.Id
    }));
  }

  get dealDisabled() {
    return !this.selectedPlayerId || this.roundOpen || !(this.bet > 0);
  }

  get roundOpen() {
    return !!this.round && this.round.status === "OPEN";
  }

  get roundSettled() {
    return !!this.round && this.round.status === "SETTLED";
  }

  get dealerCards() {
    if (!this.round) {
      return [];
    }
    return this.round.dealerCards.map((card, index) => {
      const key = `dealer-${index}`;
      return card ? { key, src: cardImage(card) } : { key, hidden: true };
    });
  }

  get handViews() {
    if (!this.round) {
      return [];
    }
    return this.round.hands.map((hand, index) => ({
      key: `hand-${index}`,
      cards: hand.cards.map((card, cardIndex) => ({
        key: `hand-${index}-card-${cardIndex}`,
        src: cardImage(card)
      })),
      total: hand.total,
      bet: hand.bet,
      status: hand.status
    }));
  }

  get actionButtons() {
    const allowed = this.round ? this.round.allowedActions : [];
    return ACTIONS.map((item) => ({
      action: item.action,
      label: item.label,
      disabled: !allowed.includes(item.action)
    }));
  }

  get resultText() {
    if (!this.roundSettled) {
      return "";
    }
    return `${this.round.result.join(", ")} | Net: ${this.round.netChange}`;
  }

  get activeHandIndex() {
    const index = this.round
      ? this.round.hands.findIndex((hand) => hand.status === "ACTIVE")
      : -1;
    return index === -1 ? 0 : index;
  }

  handlePlayerChange(event) {
    this.selectedPlayerId = event.detail.value;
    this.errorMessage = undefined;
    this.round = undefined;
    getOpenRound({ playerId: this.selectedPlayerId })
      .then((round) => {
        this.round = round || undefined;
      })
      .catch((error) => this.showError(error));
  }

  handleBetChange(event) {
    this.bet = Number(event.detail.value);
  }

  handleDeal() {
    this.errorMessage = undefined;
    startRound({ playerId: this.selectedPlayerId, bet: this.bet })
      .then((round) => {
        this.round = round;
      })
      .catch((error) => this.showError(error));
  }

  handleAction(event) {
    const action = event.target.dataset.action;
    playerAction({
      roundId: this.round.roundId,
      action,
      handIndex: this.activeHandIndex
    })
      .then((round) => {
        this.round = round;
      })
      .catch((error) => this.showError(error));
  }

  showError(error) {
    this.errorMessage =
      (error && error.body && error.body.message) ||
      (error && error.message) ||
      "Something went wrong.";
  }
}
