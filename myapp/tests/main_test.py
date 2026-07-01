"""Sample tests."""

import pytest

from myapp.main import hello


def test_hello_default():
    """Test hello without an argument."""
    assert hello() == "Hello, World!"


@pytest.mark.parametrize(
    ("name", "expected"),
    [
        ("Alice", "Hello, Alice!"),
        ("Bob", "Hello, Bob!"),
    ],
)
def test_hello(name: str, expected: str):
    """Test hello with an argument."""
    assert hello(name) == expected
