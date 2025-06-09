#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
SAMPLE_FILE=".env.sample"

# 1. Check file presence
for f in "$ENV_FILE" "$SAMPLE_FILE"; do
  [[ -f "$f" ]] || { echo "❌ ERROR: $f is missing!"; exit 1; }
done

# 2. Extract key=value pairs
sample_kvs=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$SAMPLE_FILE" | sort)
env_kvs=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE" | sort)

# 3. Compare full lines (key=value)
if [[ "$sample_kvs" == "$env_kvs" ]]; then
  echo "✅ .env validated successfully (exact match)."
  exit 0
fi

# 4. Start diff report
echo "❌ ERROR: .env and .env.sample do not match."

# 5. Find missing and extra keys
sample_keys=$(echo "$sample_kvs" | cut -d= -f1 | sort)
env_keys=$(echo "$env_kvs" | cut -d= -f1 | sort)

missing_keys=$(comm -23 <(echo "$sample_keys") <(echo "$env_keys"))
extra_keys=$(comm -13 <(echo "$sample_keys") <(echo "$env_keys"))

if [[ -n "$missing_keys" ]]; then
  echo " ▸ Missing keys in .env:"
  echo "$missing_keys"
fi

if [[ -n "$extra_keys" ]]; then
  echo " ▸ Extra keys in .env:"
  echo "$extra_keys"
fi

# 6. Compare values for matching keys
common_keys=$(comm -12 <(echo "$sample_keys") <(echo "$env_keys"))
mismatched=()

while IFS= read -r key; do
  val_sample=$(grep -m1 "^$key=" "$SAMPLE_FILE" | cut -d= -f2-)
  val_env=$(grep -m1 "^$key=" "$ENV_FILE" | cut -d= -f2-)
  if [[ "$val_sample" != "$val_env" ]]; then
    mismatched+=("$key → expected: '$val_sample', found: '$val_env'")
  fi
done <<< "$common_keys"

if (( ${#mismatched[@]} > 0 )); then
  echo " ▸ Mismatched values:"
  printf '   - %s\n' "${mismatched[@]}"
fi

exit 1
