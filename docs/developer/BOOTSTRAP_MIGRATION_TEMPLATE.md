# Bootstrap Migration Template

## Old Pattern (to be replaced):

```bash
# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Find bootstrap helper
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/lib/serversentry-bootstrap.sh" ]]; then
      source "$current_dir/lib/serversentry-bootstrap.sh"
      load_serversentry_bootstrap true false # quiet, no auto-init
      break
    elif [[ -f "$current_dir/serversentry-env.sh" ]]; then
      export SERVERSENTRY_QUIET=true
      export SERVERSENTRY_AUTO_INIT=false
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done
fi
```

## New Pattern (standardized):

```bash
# Load ServerSentry environment
if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
  # Set bootstrap control variables
  export SERVERSENTRY_QUIET=true
  export SERVERSENTRY_AUTO_INIT=false
  export SERVERSENTRY_INIT_LEVEL=minimal

  # Find and source the main bootstrap file
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/serversentry-env.sh" ]]; then
      source "$current_dir/serversentry-env.sh"
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done

  # Verify bootstrap succeeded
  if [[ -z "${SERVERSENTRY_ENV_LOADED:-}" ]]; then
    echo "❌ ERROR: Failed to load ServerSentry environment" >&2
    exit 1
  fi
fi
```

## Benefits of New Pattern:

1. **Single bootstrap path** - Only uses `serversentry-env.sh`
2. **Control variables** - Set before sourcing for consistent behavior
3. **Error handling** - Verifies bootstrap succeeded
4. **Minimal initialization** - Only loads essential components
5. **Quiet mode** - Reduces noise in tests and utilities

## Migration Steps:

1. Replace old pattern with new pattern in each file
2. Adjust `SERVERSENTRY_INIT_LEVEL` if needed:
   - `minimal` - Basic environment only
   - `standard` - Core libraries loaded
   - `full` - All modules loaded
3. Test the file to ensure it works correctly
4. Remove any references to `lib/serversentry-bootstrap.sh`
