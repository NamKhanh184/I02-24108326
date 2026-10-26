def isqrt_bitwise(x, width=8):
    x = int(x) & ((1 << width) - 1)
    root = 0
    rem = 0
    trace = []
    for i in range(width // 2):
        shift = width - 2 - 2 * i
        pair = (x >> shift) & 0x3
        rem_shift = (rem << 2) | pair
        trial = (root << 2) | 1
        if rem_shift >= trial:
            rem = rem_shift - trial
            bit = 1
        else:
            rem = rem_shift
            bit = 0
        root = (root << 1) | bit
        trace.append({
            "iteration": i + 1,
            "pair": pair,
            "rem_shift": rem_shift,
            "trial": trial,
            "bit": bit,
            "root": root,
            "remainder": rem
        })
    return root, rem, trace


def test_full_domain():
    import math

    for x in range(256):
        root, _, trace = isqrt_bitwise(x, 8)
        assert root == math.isqrt(x)
        assert root * root <= x < (root + 1) * (root + 1)
        assert len(trace) == 4


def test_boundaries():
    values = [
        0, 1, 2, 3, 4, 8, 9, 15, 16, 24, 25, 26, 63, 64, 65,
        80, 81, 82, 224, 225, 226, 254, 255
    ]
    for x in values:
        root, _, _ = isqrt_bitwise(x, 8)
        assert root * root <= x < (root + 1) * (root + 1)


def test_perfect_squares():
    for root in range(16):
        result, _, _ = isqrt_bitwise(root * root, 8)
        assert result == root


def test_cycle_count():
    for x in [0, 1, 2, 4, 63, 64, 65, 255]:
        _, _, trace = isqrt_bitwise(x, 8)
        assert len(trace) == 4


def test_trial_recurrence():
    x = 0xA5
    root, _, trace = isqrt_bitwise(x, 8)
    assert root == 12
    assert len(trace) == 4
    previous_root = 0
    for row in trace:
        assert row["trial"] == ((previous_root << 2) | 1)
        assert row["root"] == ((previous_root << 1) | row["bit"])
        previous_root = row["root"]


def test_16bit_scaling():
    for x in [0, 1, 4, 255, 256, 65535]:
        root, _, trace = isqrt_bitwise(x, 16)
        assert root * root <= x < (root + 1) * (root + 1)
        assert len(trace) == 8


def test_random():
    import math
    import random

    random.seed(2026)
    for _ in range(10000):
        x = random.randrange(256)
        root, _, _ = isqrt_bitwise(x, 8)
        assert root == math.isqrt(x)


if __name__ == "__main__":
    test_full_domain()
    test_boundaries()
    test_perfect_squares()
    test_cycle_count()
    test_trial_recurrence()
    test_16bit_scaling()
    test_random()
    print("I02 golden reference PASS")