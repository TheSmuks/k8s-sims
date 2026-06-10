"""Tests for E2E validation defects discovered during spec 004 execution.

These tests verify fixes for:
- F002: skctl validate subcommand syntax in sktrace.py
"""

import subprocess
from unittest.mock import patch, MagicMock
import pytest


class TestSkctlValidateSyntax:
    """Verify skctl validate uses correct subcommand syntax."""

    def test_validate_sktrace_uses_check_subcommand(self):
        """validate_sktrace() must call 'skctl validate check <path>' not 'skctl validate <path>'."""
        from utils.sktrace import validate_sktrace

        with patch("utils.sktrace.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stderr="")
            validate_sktrace("/tmp/test.sktrace")
            args = mock_run.call_args[0][0]
            assert args == ["skctl", "validate", "check", "/tmp/test.sktrace"], (
                f"Expected ['skctl', 'validate', 'check', '/tmp/test.sktrace'], got {args}"
            )

    def test_validate_sktrace_degrades_gracefully_without_skctl(self):
        """validate_sktrace() returns True when skctl is not found (FR-011 graceful degradation)."""
        from utils.sktrace import validate_sktrace

        with patch("utils.sktrace.subprocess.run", side_effect=FileNotFoundError):
            assert validate_sktrace("/tmp/test.sktrace") is True
