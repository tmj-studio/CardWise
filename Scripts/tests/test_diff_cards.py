import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from diff_cards import classify  # noqa: E402


def card(cid="x", fee=95, rewards=None, credits=None):
    return {"id": cid, "name": cid, "annualFee": fee,
            "categoryRewards": rewards or [], "credits": credits or []}


def wrap(cards):
    return {"version": 1, "updatedAt": "2026-06-10", "cards": cards}


class TestClassify(unittest.TestCase):
    def test_no_change(self):
        r = classify(wrap([card()]), wrap([card()]))
        self.assertFalse(r["safe"])
        self.assertFalse(r["suspicious"])

    def test_small_fee_change_is_safe(self):
        r = classify(wrap([card(fee=100)]), wrap([card(fee=110)]))
        self.assertTrue(r["safe"])
        self.assertFalse(r["suspicious"])

    def test_big_fee_change_is_suspicious(self):
        r = classify(wrap([card(fee=100)]), wrap([card(fee=200)]))
        self.assertTrue(r["suspicious"])

    def test_card_added_or_removed_is_suspicious(self):
        self.assertTrue(classify(wrap([card("a")]), wrap([card("a"), card("b")]))["suspicious"])
        self.assertTrue(classify(wrap([card("a"), card("b")]), wrap([card("a")]))["suspicious"])

    def test_multiplier_to_zero_is_suspicious(self):
        old = card(rewards=[{"category": "dining", "multiplier": 3}])
        new = card(rewards=[{"category": "dining", "multiplier": 0}])
        self.assertTrue(classify(wrap([old]), wrap([new]))["suspicious"])

    def test_credit_added_is_safe_removed_is_suspicious(self):
        cr = {"id": "c1", "description": "d", "amount": 10, "cadence": "monthly"}
        self.assertTrue(classify(wrap([card()]), wrap([card(credits=[cr])]))["safe"])
        self.assertTrue(classify(wrap([card(credits=[cr])]), wrap([card()]))["suspicious"])

    def test_credit_amount_swing_is_suspicious(self):
        a = {"id": "c1", "description": "d", "amount": 10, "cadence": "monthly"}
        b = dict(a, amount=20)
        self.assertTrue(classify(wrap([card(credits=[a])]),
                                 wrap([card(credits=[b])]))["suspicious"])


if __name__ == "__main__":
    unittest.main()
