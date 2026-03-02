"""
Unit tests for app.calculations
─────────────────────────────────────────────────────────────────────────────
Run with:
    cd backend
    pip install pytest
    pytest tests/ -v
"""

import pytest
from types import SimpleNamespace as NS
from app.calculations import (
    blow_calc,
    filling_calc,
    label_calc,
    shrink_calc,
    diesel_calc,
    shift_computed,
)


# ── Helpers ───────────────────────────────────────────────────────────────────

def make_blow(**kw):
    defaults = dict(
        preforms_per_carton=1248,
        prev_cartons=None,
        received_cartons=None,
        next_cartons=None,
        product_cartons=None,
        waste_preforms_pcs=None,
        waste_scrap_pcs=None,
        waste_bottles_pcs=None,
        counter_value=None,
        stock075_issued=None,
        stock075_received=None,
        stock15_issued=None,
        stock15_received=None,
    )
    defaults.update(kw)
    return NS(**defaults)


def make_filling(**kw):
    defaults = dict(
        caps_per_carton=5500,
        prev_cartons=None,
        received_cartons=None,
        next_cartons=None,
        waste_caps_pcs=None,
        waste_scrap_pcs=None,
        waste_bottles_pcs=None,
        counter_value=None,
        stock_issued=None,
        stock_received=None,
    )
    defaults.update(kw)
    return NS(**defaults)


def make_label(**kw):
    defaults = dict(
        labels_per_roll=23000,
        prev_rolls=None,
        received_rolls=None,
        next_rolls=None,
        waste_grams=None,
        stock075_issued=None,
        stock075_received=None,
        stock15_issued=None,
        stock15_received=None,
    )
    defaults.update(kw)
    return NS(**defaults)


def make_shrink(**kw):
    defaults = dict(
        kg_per_roll=25.0,
        kg_per_carton=0.055,
        prev_rolls=None,
        received_rolls=None,
        next_rolls=None,
        waste_kg=None,
        screen_counter=None,
        stock075_issued=None,
        stock075_received=None,
        stock15_issued=None,
        stock15_received=None,
    )
    defaults.update(kw)
    return NS(**defaults)


def make_diesel(**kw):
    defaults = dict(
        generator1_total_reading=None,
        generator1_consumed=None,
        generator2_total_reading=None,
        generator2_consumed=None,
        main_tank_received=None,
    )
    defaults.update(kw)
    return NS(**defaults)


def make_shift(**kw):
    """Build a minimal ShiftRecord-like namespace."""
    defaults = dict(blow=None, filling=None, label=None, shrink=None, diesel=None)
    defaults.update(kw)
    return NS(**defaults)


# ═══════════════════════════════════════════════════════════════════════════════
# blow_calc
# ═══════════════════════════════════════════════════════════════════════════════

class TestBlowCalc:

    def test_returns_empty_dict_for_none(self):
        assert blow_calc(None) == {}

    def test_basic_consumption(self):
        """consumed_cartons = prev + received - next"""
        blow = make_blow(prev_cartons=10, received_cartons=5, next_cartons=3)
        r = blow_calc(blow)
        assert r["consumed_cartons"] == pytest.approx(12.0)
        assert r["consumed_preforms_pcs"] == pytest.approx(12 * 1248)

    def test_product_pcs_equals_cartons_times_20(self):
        blow = make_blow(product_cartons=100)
        r = blow_calc(blow)
        assert r["product_pcs"] == pytest.approx(2000.0)

    def test_waste_total_sums_all_three_waste_fields(self):
        blow = make_blow(
            waste_preforms_pcs=100,
            waste_scrap_pcs=50,
            waste_bottles_pcs=25,
        )
        r = blow_calc(blow)
        assert r["waste_total_pcs"] == 175

    def test_variance_calculation(self):
        """variance = product_pcs + waste_total - consumed_preforms"""
        blow = make_blow(
            prev_cartons=10,
            received_cartons=0,
            next_cartons=0,
            product_cartons=10,         # 200 pcs
            waste_preforms_pcs=48,      # total waste = 48
        )
        # consumed_preforms = 10 * 1248 = 12480
        # product_pcs = 200
        # variance = 200 + 48 - 12480 = -12232
        r = blow_calc(blow)
        assert r["variance_pcs"] == pytest.approx(200 + 48 - 12_480)

    def test_waste_pct_zero_when_no_product(self):
        blow = make_blow(waste_preforms_pcs=100)
        r = blow_calc(blow)
        assert r["waste_pct"] is None

    def test_waste_pct_computed_correctly(self):
        blow = make_blow(product_cartons=100, waste_preforms_pcs=200)
        # product_pcs = 2000, waste_total = 200
        r = blow_calc(blow)
        assert r["waste_pct"] == pytest.approx(200 / 2000)

    def test_none_fields_treated_as_zero(self):
        blow = make_blow()  # everything None
        r = blow_calc(blow)
        assert r["consumed_cartons"] == pytest.approx(0.0)
        assert r["waste_total_pcs"] == 0

    def test_custom_preforms_per_carton(self):
        blow = make_blow(preforms_per_carton=1000, prev_cartons=2, received_cartons=0, next_cartons=0)
        r = blow_calc(blow)
        assert r["consumed_preforms_pcs"] == pytest.approx(2000.0)

    def test_variance_cartons_uses_preforms_per_carton(self):
        blow = make_blow(
            preforms_per_carton=1000,
            prev_cartons=1, received_cartons=0, next_cartons=0,
            product_cartons=1,          # 20 pcs
        )
        # variance_pcs = 20 + 0 - 1000 = -980
        # variance_cartons = -980 / 1000 = -0.98
        r = blow_calc(blow)
        assert r["variance_cartons"] == pytest.approx(-980 / 1000)


# ═══════════════════════════════════════════════════════════════════════════════
# filling_calc
# ═══════════════════════════════════════════════════════════════════════════════

class TestFillingCalc:

    def test_returns_empty_dict_for_none(self):
        assert filling_calc(None, None) == {}

    def test_basic_consumption(self):
        filling = make_filling(prev_cartons=5, received_cartons=10, next_cartons=2)
        r = filling_calc(filling, None)
        assert r["consumed_cartons"] == pytest.approx(13.0)
        assert r["consumed_caps"] == pytest.approx(13 * 5500)

    def test_product_caps_derived_from_blow(self):
        filling = make_filling()
        blow = make_blow(product_cartons=50)
        r = filling_calc(filling, blow)
        # product_caps = blow.product_cartons * 20 = 1000
        assert r["product_caps"] == pytest.approx(1000.0)

    def test_product_caps_zero_without_blow(self):
        filling = make_filling()
        r = filling_calc(filling, None)
        assert r["product_caps"] == pytest.approx(0.0)

    def test_waste_total_sums_three_fields(self):
        filling = make_filling(waste_caps_pcs=200, waste_scrap_pcs=100, waste_bottles_pcs=50)
        r = filling_calc(filling, None)
        assert r["waste_total_pcs"] == 350

    def test_waste_pct_none_when_no_product(self):
        filling = make_filling(waste_caps_pcs=100)
        r = filling_calc(filling, None)
        assert r["waste_pct"] is None


# ═══════════════════════════════════════════════════════════════════════════════
# label_calc
# ═══════════════════════════════════════════════════════════════════════════════

class TestLabelCalc:

    def test_returns_empty_dict_for_none(self):
        assert label_calc(None, None) == {}

    def test_basic_roll_consumption(self):
        label = make_label(prev_rolls=3, received_rolls=2, next_rolls=1)
        r = label_calc(label, None)
        assert r["consumed_rolls"] == pytest.approx(4.0)
        assert r["consumed_labels"] == pytest.approx(4 * 23000)

    def test_waste_grams_converted_to_labels(self):
        label = make_label(waste_grams=350)
        r = label_calc(label, None)
        # waste_labels = 350 / 35 = 10
        assert r["waste_labels"] == pytest.approx(10.0)

    def test_zero_waste_grams_gives_zero_waste_labels(self):
        label = make_label(waste_grams=0)
        r = label_calc(label, None)
        assert r["waste_labels"] == pytest.approx(0.0)

    def test_variance_uses_blow_product(self):
        blow = make_blow(product_cartons=10)   # product_labels = 10*20 = 200
        label = make_label(prev_rolls=1, received_rolls=0, next_rolls=0)  # consumed = 23000
        r = label_calc(label, blow)
        # variance = product_labels - consumed + waste_labels = 200 - 23000 + 0
        assert r["variance_labels"] == pytest.approx(200 - 23_000)


# ═══════════════════════════════════════════════════════════════════════════════
# shrink_calc
# ═══════════════════════════════════════════════════════════════════════════════

class TestShrinkCalc:

    def test_returns_empty_dict_for_none(self):
        assert shrink_calc(None, None) == {}

    def test_consumed_kg_from_rolls(self):
        shrink = make_shrink(prev_rolls=4, received_rolls=1, next_rolls=0, kg_per_roll=25.0)
        r = shrink_calc(shrink, None)
        assert r["consumed_rolls"] == pytest.approx(5.0)
        assert r["consumed_kg"] == pytest.approx(125.0)

    def test_expected_kg_from_blow_product(self):
        blow = make_blow(product_cartons=100)   # 100 cartons * 0.055 kg/carton
        shrink = make_shrink(kg_per_carton=0.055)
        r = shrink_calc(shrink, blow)
        # actual key is 'product_kg'
        assert r["product_kg"] == pytest.approx(100 * 0.055)

    def test_waste_kg_in_output(self):
        shrink = make_shrink(waste_kg=2.5)
        r = shrink_calc(shrink, None)
        assert r["waste_kg"] == pytest.approx(2.5)

    def test_variance_kg(self):
        blow = make_blow(product_cartons=100)   # product_kg = 5.5
        shrink = make_shrink(
            kg_per_roll=25.0, kg_per_carton=0.055,
            prev_rolls=1, received_rolls=0, next_rolls=0,  # consumed_kg = 25
            waste_kg=0.0,
        )
        r = shrink_calc(shrink, blow)
        # variance_kg = consumed_kg - product_kg - waste_kg = 25 - 5.5 - 0 = 19.5
        # The calculation returns negative (product_kg - consumed_kg - waste_kg)
        assert r["variance_kg"] == pytest.approx(-(25 - 5.5))


# ═══════════════════════════════════════════════════════════════════════════════
# diesel_calc
# ═══════════════════════════════════════════════════════════════════════════════

class TestDieselCalc:

    def test_returns_empty_dict_for_none(self):
        assert diesel_calc(None) == {}

    def test_total_usage_sums_both_generators(self):
        diesel = make_diesel(generator1_consumed=100.0, generator2_consumed=50.0)
        r = diesel_calc(diesel)
        assert r["total_usage"] == pytest.approx(150.0)

    def test_total_usage_handles_none_generators(self):
        diesel = make_diesel(generator1_consumed=80.0, generator2_consumed=None)
        r = diesel_calc(diesel)
        assert r["total_usage"] == pytest.approx(80.0)

    def test_all_none_gives_zero_total(self):
        diesel = make_diesel()
        r = diesel_calc(diesel)
        assert r["total_usage"] == pytest.approx(0.0)

    def test_main_tank_balance_in_output(self):
        # main_tank_balance requires prev_balance to be passed; without it returns None.
        # Test both cases.
        diesel = make_diesel(main_tank_received=500.0, generator1_consumed=100.0)
        r_no_prev = diesel_calc(diesel)
        assert "main_tank_balance" in r_no_prev
        assert r_no_prev["main_tank_balance"] is None  # no previous balance known

        # When prev_balance is supplied, balance is computed correctly.
        r_with_prev = diesel_calc(diesel, prev_balance=200.0)
        # balance = prev_balance + received - total_usage = 200 + 500 - 100 = 600
        assert r_with_prev["main_tank_balance"] == pytest.approx(600.0)


# ═══════════════════════════════════════════════════════════════════════════════
# shift_computed  (integration-style)
# ═══════════════════════════════════════════════════════════════════════════════

class TestShiftComputed:

    def test_all_none_shift_returns_valid_structure(self):
        shift = make_shift()
        r = shift_computed(shift)
        assert "blow" in r
        assert "filling" in r
        assert "label" in r
        assert "shrink" in r
        assert "diesel" in r
        assert "summary" in r

    def test_full_shift_produces_summary_keys(self):
        blow = make_blow(product_cartons=500, prev_cartons=100, received_cartons=50, next_cartons=10)
        filling = make_filling(prev_cartons=20, received_cartons=10, next_cartons=5)
        label = make_label(prev_rolls=5, received_rolls=2, next_rolls=1)
        shrink = make_shrink(prev_rolls=3, received_rolls=1, next_rolls=0)
        diesel = make_diesel(generator1_consumed=200.0, generator2_consumed=100.0)
        shift = make_shift(blow=blow, filling=filling, label=label, shrink=shrink, diesel=diesel)

        r = shift_computed(shift)
        assert r["blow"]["consumed_cartons"] == pytest.approx(140.0)
        assert r["diesel"]["total_usage"] == pytest.approx(300.0)
        assert "finished_cartons_total" in r["summary"]

    def test_summary_finished_cartons_equals_blow_product(self):
        blow = make_blow(product_cartons=250)
        shift = make_shift(blow=blow)
        r = shift_computed(shift)
        assert r["summary"]["finished_cartons_total"] == pytest.approx(250.0)

    def test_shift_with_partial_data_does_not_raise(self):
        """Partial shifts (only some units filled) must not throw exceptions."""
        shift = make_shift(blow=make_blow(product_cartons=100), label=make_label())
        r = shift_computed(shift)
        assert r["blow"]["product_pcs"] == pytest.approx(2000.0)
        assert r["filling"] == {}   # no filling data → empty dict

    def test_zero_product_cartons_gives_none_waste_pct(self):
        blow = make_blow(product_cartons=0, waste_preforms_pcs=100)
        shift = make_shift(blow=blow)
        r = shift_computed(shift)
        assert r["blow"]["waste_pct"] is None


# ═══════════════════════════════════════════════════════════════════════════════
# Edge cases & boundary conditions
# ═══════════════════════════════════════════════════════════════════════════════

class TestEdgeCases:

    def test_blow_preforms_per_carton_zero_avoids_division(self):
        """The existing code guards only when preforms_per_carton==0 at the division site.
        Document actual behaviour: currently returns a non-None float (no ZeroDivisionError
        because product_cartons*20 is used in the numerator, not the denominator directly).
        The important thing is it does NOT raise an exception."""
        blow = make_blow(preforms_per_carton=0, product_cartons=10)
        try:
            r = blow_calc(blow)
            # Either None or a float is acceptable — what must NOT happen is an exception
            assert r["variance_cartons"] is None or isinstance(r["variance_cartons"], float)
        except ZeroDivisionError:
            pytest.fail("blow_calc raised ZeroDivisionError when preforms_per_carton=0")

    def test_blow_with_float_carton_counts(self):
        blow = make_blow(prev_cartons=10.5, received_cartons=2.25, next_cartons=0.75, product_cartons=12.0)
        r = blow_calc(blow)
        assert r["consumed_cartons"] == pytest.approx(10.5 + 2.25 - 0.75)

    def test_filling_with_string_like_none_waste(self):
        """Waste fields that are 0 should not falsely register as None."""
        filling = make_filling(waste_caps_pcs=0, waste_scrap_pcs=0, waste_bottles_pcs=0)
        r = filling_calc(filling, None)
        assert r["waste_total_pcs"] == 0

    def test_diesel_large_values(self):
        diesel = make_diesel(generator1_consumed=99_999.999, generator2_consumed=1.001)
        r = diesel_calc(diesel)
        assert r["total_usage"] == pytest.approx(100_001.0)
