from __future__ import annotations

import time
from pathlib import Path

from openai import OpenAI

from .base import Provider, TranscriptionResult


class OpenAITranscribeProvider(Provider):
    def __init__(self, model_name: str, api_key: str, base_url: str | None = None) -> None:
        self.provider_name = "OpenAI"
        self.model_name = model_name
        client_kwargs = {"api_key": api_key}
        if base_url:
            client_kwargs["base_url"] = base_url
        self._client = OpenAI(**client_kwargs)

    def transcribe(self, audio_path: Path) -> TranscriptionResult:
        started = time.perf_counter()
        with audio_path.open("rb") as audio_file:
            response = self._client.audio.transcriptions.create(
                model=self.model_name,
                file=audio_file,
                response_format="text",
            )
        elapsed = time.perf_counter() - started

        return TranscriptionResult(
            provider=self.provider_name,
            model=self.model_name,
            elapsed_seconds=elapsed,
            text=str(response).strip(),
        )
