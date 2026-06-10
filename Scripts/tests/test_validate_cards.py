import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from validate_cards import validate  # noqa: E402


def wrap(cards, version=5):
    return {"version": version, "updatedAt": "2026-06-10", "cards": cards}


def card(**kw):
    c = {"id": "x-1", "name": "X", "issuer": "X", "network": "visa", "annualFee": 95,
         "rewardType": "cashback", "baseReward": 1, "baseIsPercentage": True,
         "categoryRewards": [], "imageColor": "#000000"}
    c.update(kw)
    return c


class TestValidate(unittest.TestCase):
    def test_valid_passes(self):
        self.assertEqual(validate(wrap([card()])), [])

    def test_missing_field_fails(self):
        c = card()
        del c["name"]
        self.assertTrue(any("name" in e for e in validate(wrap([c]))))

    def test_bad_cadence_and_category(self):
        c = card(credits=[{"id": "c1", "description": "d", "amount": 10,
                           "cadence": "weekly", "category": "dining"}])
        self.assertTrue(any("cadence" in e for e in validate(wrap([c]))))
        c2 = card(credits=[{"id": "c2", "description": "d", "amount": 10,
                            "cadence": "monthly", "category": "nope"}])
        self.assertTrue(any("category" in e for e in validate(wrap([c2]))))

    def test_credit_amount_bounds(self):
        c = card(credits=[{"id": "c3", "description": "d", "amount": 0, "cadence": "monthly"}])
        self.assertTrue(validate(wrap([c])))
        c2 = card(annualFee=95, credits=[{"id": "c4", "description": "d",
                                          "amount": 1000, "cadence": "annual"}])
        self.assertTrue(any("3x" in e for e in validate(wrap([c2]))))

    def test_duplicate_ids(self):
        self.assertTrue(any("duplicate" in e.lower()
                            for e in validate(wrap([card(), card()]))))
        c = card(credits=[{"id": "dup", "description": "d", "amount": 1, "cadence": "monthly"},
                          {"id": "dup", "description": "d", "amount": 1, "cadence": "monthly"}])
        self.assertTrue(any("duplicate" in e.lower() for e in validate(wrap([c]))))

    def test_zero_multiplier_rejected(self):
        c = card(categoryRewards=[{"category": "dining", "multiplier": 0,
                                   "isPercentage": True, "cap": None, "capPeriod": None}])
        self.assertTrue(any("multiplier" in e for e in validate(wrap([c]))))

    def test_version_must_increase(self):
        self.assertTrue(any("version" in e.lower()
                            for e in validate(wrap([card()], version=3), old_version=3)))
        self.assertEqual(validate(wrap([card()], version=4), old_version=3), [])


if __name__ == "__main__":
    unittest.main()
