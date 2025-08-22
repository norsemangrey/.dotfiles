# Only run setup if SSH_AUTH_SOCK is not already set to something valid

if [[ -z "$SSH_AUTH_SOCK" || ! -S "$SSH_AUTH_SOCK" ]]; then

  # Build list of keys to load
  SSH_KEYS=()

    # Add keys to list
    for key in ~/.ssh/keys/*_ed25519; do

        # Check file and add
        [[ -f "$key" ]] && SSH_KEYS+=("$key")

    done

    # Load all keys into keychain
    if [[ ${#SSH_KEYS[@]} -gt 0 ]]; then

        # Run keychain, quiet mode, only once per session
        eval "$(keychain --agents ssh --quiet --eval "${SSH_KEYS[@]}")"

    fi

fi
