"""Sample tests."""

from src.main import hello


def test_hello_1() -> None:
    """Test hello function without argument."""
    assert hello() == "Hello, World!"


def test_hello_2() -> None:
    """Test hello function with argument."""
    assert hello("Alice") == "Hello, Alice!"
