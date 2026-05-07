from __future__ import annotations

import subprocess
import tempfile
import os
import time
from pathlib import Path

import dashscope

from .base import Provider, TranscriptionResult


class QwenAsrProvider(Provider):
    def __init__(self, model_name: str, api_key: str) -> None:
        self.provider_name = "Qwen"
        self.model_name = model_name
        self._api_key = api_key

    def transcribe(self, audio_path: Path) -> TranscriptionResult:
        started = time.perf_counter()
        qwen_audio_path = self._prepare_audio(audio_path)
        response = dashscope.MultiModalConversation.call(
            api_key=self._api_key,
            model=self.model_name,
            messages=[
                {
                    "role": "system",
                    "content": [{"text": ""}],
                },
                {
                    "role": "user",
                    "content": [{"audio": str(qwen_audio_path)}],
                },
            ],
            result_format="message",
            asr_options={
                "enable_lid": True,
                "enable_itn": False,
            },
        )
        elapsed = time.perf_counter() - started

        text = self._extract_text(response)
        return TranscriptionResult(
            provider=self.provider_name,
            model=self.model_name,
            elapsed_seconds=elapsed,
            text=text,
        )

    @staticmethod
    def _prepare_audio(audio_path: Path) -> Path:
        if audio_path.suffix.lower() == ".wav":
            return audio_path

        temp_dir = Path(tempfile.mkdtemp(prefix="qwen_asr_"))
        wav_path = temp_dir / f"{audio_path.stem}.wav"
        subprocess.run(
            [
                "/usr/bin/afconvert",
                "-f",
                "WAVE",
                "-d",
                "LEI16@16000",
                str(audio_path),
                str(wav_path),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return wav_path

    @staticmethod
    def _extract_text(response: object) -> str:
        if hasattr(response, "output") and getattr(response.output, "choices", None):
            for choice in response.output.choices:
                message = getattr(choice, "message", None)
                if not message:
                    continue
                for item in getattr(message, "content", []) or []:
                    if isinstance(item, dict):
                        text = item.get("text")
                        if text:
                            return str(text).strip()
                    else:
                        text = getattr(item, "text", None)
                        if text:
                            return str(text).strip()

        if isinstance(response, dict):
            output = response.get("output") or {}
            choices = output.get("choices", [])
            for choice in choices:
                message = choice.get("message") or {}
                for item in message.get("content", []) or []:
                    if item is None:
                        continue
                    text = item.get("text")
                    if text:
                        return str(text).strip()

        return str(response).strip()
