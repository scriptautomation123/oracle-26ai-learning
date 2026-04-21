"""Generate six-turn Banking77 transcripts for the conversation table."""

from __future__ import annotations

import argparse
import csv
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd
from openai import OpenAI


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Banking77 CSV path")
    parser.add_argument("--output", default="data/conversations.csv")
    parser.add_argument("--model", default=os.getenv("OPENAI_MODEL", "cohere.command-r-plus"))
    parser.add_argument("--limit", type=int, default=500)
    return parser.parse_args()


def make_client() -> OpenAI:
    api_key = os.getenv("OPENAI_API_KEY", "")
    base_url = os.getenv(
        "OPENAI_BASE_URL",
        "https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20240531/actions/openai/v1",
    )
    return OpenAI(api_key=api_key, base_url=base_url)


def generate_transcript(client: OpenAI, model: str, utterance: str, intent: str) -> str:
    prompt = (
        "Create exactly 6 turns alternating Customer and Agent. Include the original "
        f"utterance: '{utterance}'. Intent: {intent}. Include account specifics, a clear "
        "resolution, and one compliant marketing nudge in the final agent turn. "
        "Format as lines prefixed with 'Customer:' or 'Agent:'."
    )
    try:
        response = client.chat.completions.create(
            model=model,
            temperature=0.3,
            messages=[
                {"role": "system", "content": "You create concise retail banking support transcripts."},
                {"role": "user", "content": prompt},
            ],
        )
        content = response.choices[0].message.content
        if not content:
            raise ValueError("empty response")
        return content.strip()
    except Exception as exc:
        print(f"LLM call failed, using fallback transcript: {exc}", file=sys.stderr)
        return (
            f"Customer: {utterance}\n"
            "Agent: I can help with that right now; let me pull up your account context.\n"
            "Customer: I paused because I was unsure which option is best for my spending.\n"
            "Agent: Based on your recent activity, the standard plan keeps fees lower.\n"
            "Customer: Great, please continue with that option.\n"
            "Agent: Done. If helpful, I can also show a card or offer aligned to this request."
        )


def select_utterance(row: dict[str, Any]) -> tuple[str, str]:
    utterance = str(
        row.get("text")
        or row.get("utterance")
        or row.get("question")
        or "I need help with my account."
    )
    intent = str(row.get("label") or row.get("intent") or "general_query")
    return utterance, intent


def main() -> None:
    args = parse_args()
    df = pd.read_csv(args.input)
    records = df.head(args.limit).to_dict(orient="records")

    client = make_client()
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["conv_id", "customer_id", "channel", "transcript", "conv_ts"],
        )
        writer.writeheader()
        for idx, row in enumerate(records, start=1):
            utterance, intent = select_utterance(row)
            transcript = generate_transcript(client, args.model, utterance, intent)
            writer.writerow(
                {
                    "conv_id": idx,
                    "customer_id": ((idx - 1) % 500) + 1,
                    "channel": "CHAT",
                    "transcript": transcript,
                    "conv_ts": datetime.now(timezone.utc).isoformat(),
                }
            )

    print(f"Generated {len(records)} conversations at {out_path}")


if __name__ == "__main__":
    main()
