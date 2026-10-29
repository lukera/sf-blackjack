import { createElement } from "lwc";
import BlackjackTable from "c/blackjackTable";
import getPlayers from "@salesforce/apex/BlackjackGameController.getPlayers";
import getOpenRound from "@salesforce/apex/BlackjackGameController.getOpenRound";
import startRound from "@salesforce/apex/BlackjackGameController.startRound";

jest.mock(
  "@salesforce/apex/BlackjackGameController.getPlayers",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/BlackjackGameController.getOpenRound",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/BlackjackGameController.startRound",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/BlackjackGameController.playerAction",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock("@salesforce/resourceUrl/Cards", () => ({ default: "Cards" }), {
  virtual: true
});

async function flush() {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
}

function openRound({ hands, dealerCards, allowedActions }) {
  return {
    roundId: "a0R000000000001AAA",
    status: "OPEN",
    dealerCards,
    dealerTotal: null,
    hands,
    insuranceBet: 0,
    result: null,
    netChange: null,
    allowedActions
  };
}

async function renderWithRound(round) {
  getPlayers.mockResolvedValue([
    { Id: "a00000000000001AAA", Name: "Ana", Fund__c: 1000 }
  ]);
  getOpenRound.mockResolvedValue(round);

  const element = createElement("c-blackjack-table", { is: BlackjackTable });
  document.body.appendChild(element);
  await flush();

  const combobox = element.shadowRoot.querySelector("lightning-combobox");
  combobox.dispatchEvent(
    new CustomEvent("change", { detail: { value: "a00000000000001AAA" } })
  );
  await flush();
  return element;
}

function actionButton(element, action) {
  return element.shadowRoot.querySelector(
    `lightning-button[data-action="${action}"]`
  );
}

function clearDocumentBody() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

afterEach(() => {
  clearDocumentBody();
  jest.clearAllMocks();
});

describe("c-blackjack-table", () => {
  it("disables Split when the first hand is not a pair", async () => {
    const element = await renderWithRound(
      openRound({
        hands: [
          {
            cards: [
              { rank: "10", suit: "Hearts" },
              { rank: "6", suit: "Clubs" }
            ],
            total: 16,
            bet: 100,
            status: "ACTIVE"
          }
        ],
        dealerCards: [{ rank: "9", suit: "Spades" }, null],
        allowedActions: ["HIT", "STAND", "DOUBLE"]
      })
    );

    expect(actionButton(element, "SPLIT").disabled).toBe(true);
    expect(actionButton(element, "HIT").disabled).toBe(false);
  });

  it("enables Insurance only when the server allows it", async () => {
    const allowed = await renderWithRound(
      openRound({
        hands: [
          {
            cards: [
              { rank: "10", suit: "Hearts" },
              { rank: "6", suit: "Clubs" }
            ],
            total: 16,
            bet: 100,
            status: "ACTIVE"
          }
        ],
        dealerCards: [{ rank: "Ace", suit: "Spades" }, null],
        allowedActions: ["HIT", "STAND", "INSURANCE"]
      })
    );
    expect(actionButton(allowed, "INSURANCE").disabled).toBe(false);

    clearDocumentBody();
    const notAllowed = await renderWithRound(
      openRound({
        hands: [
          {
            cards: [
              { rank: "10", suit: "Hearts" },
              { rank: "6", suit: "Clubs" }
            ],
            total: 16,
            bet: 100,
            status: "ACTIVE"
          }
        ],
        dealerCards: [{ rank: "9", suit: "Spades" }, null],
        allowedActions: ["HIT", "STAND"]
      })
    );
    expect(actionButton(notAllowed, "INSURANCE").disabled).toBe(true);
  });

  it("renders the card image URL from rank and suit", async () => {
    const element = await renderWithRound(
      openRound({
        hands: [
          {
            cards: [
              { rank: "King", suit: "Spades" },
              { rank: "6", suit: "Clubs" }
            ],
            total: 16,
            bet: 100,
            status: "ACTIVE"
          }
        ],
        dealerCards: [{ rank: "9", suit: "Spades" }, null],
        allowedActions: ["HIT", "STAND"]
      })
    );

    const sources = Array.from(element.shadowRoot.querySelectorAll("img")).map(
      (img) => img.getAttribute("src")
    );
    expect(sources).toContain("Cards/King_of_Spades.png");
  });

  it("shows a bet error from the server", async () => {
    getPlayers.mockResolvedValue([
      { Id: "a00000000000001AAA", Name: "Ana", Fund__c: 50 }
    ]);
    getOpenRound.mockResolvedValue(null);
    startRound.mockRejectedValue({
      body: { message: "Not enough funds. Current fund: 50" }
    });

    const element = createElement("c-blackjack-table", { is: BlackjackTable });
    document.body.appendChild(element);
    await flush();
    element.shadowRoot
      .querySelector("lightning-combobox")
      .dispatchEvent(
        new CustomEvent("change", { detail: { value: "a00000000000001AAA" } })
      );
    await flush();

    element.shadowRoot
      .querySelector('lightning-button[data-id="deal"]')
      .dispatchEvent(new CustomEvent("click"));
    await flush();

    const error = element.shadowRoot.querySelector('[data-id="error"]');
    expect(error).not.toBeNull();
    expect(error.textContent).toContain("Not enough funds");
  });
});
