from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class TranscriptionResult:
    provider: str
    model: str
    elapsed_seconds: float
    text: str


class Provider:
    provider_name: str
    model_name: str

    def transcribe(self, audio_path: Path) -> TranscriptionResult:
        raise NotImplementedError
