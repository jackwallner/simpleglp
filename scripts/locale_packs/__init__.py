"""Native App Store copy per fastlane locale."""
from __future__ import annotations

from .core_europe import PACKS as EUROPE
from .asia import PACKS as ASIA
from .nordic_cee import PACKS as NORDIC_CEE
from .india import PACKS as INDIA

ALL_PACKS: dict = {}
for chunk in (EUROPE, ASIA, NORDIC_CEE, INDIA):
    ALL_PACKS.update(chunk)
