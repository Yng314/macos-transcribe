from __future__ import annotations

import argparse
import os
from pathlib import Path

from dotenv import load_dotenv

from providers import OpenAITranscribeProvider, QwenAsrProvider


def build_providers() -> list:
    providers = []

    openai_api_key = os.getenv("OPENAI_API_KEY")
    openai_base_url = os.getenv("OPENAI_BASE_URL")
    if openai_api_key:
        providers.append(
            OpenAITranscribeProvider(
                model_name="gpt-4o-transcribe",
                api_key=openai_api_key,
                base_url=openai_base_url,
            )
        )
        providers.append(
            OpenAITranscribeProvider(
                model_name="gpt-4o-mini-transcribe",
                api_key=openai_api_key,
                base_url=openai_base_url,
            )
        )

    qwen_api_key = os.getenv("QWEN_API_KEY")
    qwen_model = os.getenv("QWEN_MODEL", "qwen3-asr-flash")
    if qwen_api_key:
        providers.append(QwenAsrProvider(model_name=qwen_model, api_key=qwen_api_key))

    return providers


def main() -> int:
    load_dotenv()

    parser = argparse.ArgumentParser(description="Run speech-to-text across multiple providers.")
    parser.add_argument("audio_path", nargs="?", default="speech_sample/sample_1.m4a")
    args = parser.parse_args()

    audio_path = Path(args.audio_path).expanduser().resolve()
    if not audio_path.is_file():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    providers = build_providers()
    if not providers:
        raise RuntimeError("No providers configured. Add API keys to .env first.")

    print(f"Audio: {audio_path}")
    print()

    for provider in providers:
        print(f"{provider.provider_name} / {provider.model_name}")
        try:
            result = provider.transcribe(audio_path)
            print(f"Elapsed: {result.elapsed_seconds:.2f}s")
            print("Transcript:")
            print(result.text or "<empty>")
        except Exception as exc:
            print("Elapsed: n/a")
            print("Transcript:")
            print(f"<error: {exc}>")
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
