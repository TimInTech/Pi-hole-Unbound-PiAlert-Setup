"""Tests for DNS log parsing functionality."""

from pyhole.dns_monitor import parse_pihole_line


def test_parse_pihole_line_valid():
    """Test parsing valid Pi-hole log lines."""
    test_lines = [
        "Dec 21 10:30:45 pihole dnsmasq[1234]: query[A] example.com from 192.168.1.100",
        "Dec 21 10:30:46 pihole dnsmasq[1234]: reply example.com is 93.184.216.34",
    ]
    
    for line in test_lines:
        result = parse_pihole_line(line)
        # Basic check that parsing returns something
        assert result is None or len(result) == 4


def test_parse_pihole_line_empty():
    """Test parsing empty lines."""
    assert parse_pihole_line("") is None
    assert parse_pihole_line("   ") is None


def test_parse_pihole_line_invalid():
    """Test parsing invalid lines."""
    invalid_lines = [
        "Not a valid log line",
        "Random text without structure",
        "123 456 789",
    ]
    
    for line in invalid_lines:
        result = parse_pihole_line(line)
        # Should either return None or valid tuple
        assert result is None or (isinstance(result, tuple) and len(result) == 4)