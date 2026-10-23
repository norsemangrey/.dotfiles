#!/bin/bash
set -euo pipefail

sourceDirectory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "${fixture}"' EXIT
mkdir -p "${fixture}/repo/utils/bash" "${fixture}/repo/app" "${fixture}/repo/test"
cp "${sourceDirectory}/deploy-config-linux.sh" "${fixture}/repo/"
cp "${sourceDirectory}/utils/bash/logging-and-output-function.sh" "${fixture}/repo/utils/bash/"
# Mirror stderr redirection without using the handler's shared /tmp error file.
printf '%s\n' 'exec 2>"${HOME}/errors.log"' > "${fixture}/repo/utils/bash/error-handling-function.sh"
printf 'common\n' > "${fixture}/repo/app/common"
cp "${fixture}/repo/app/common" "${fixture}/repo/test/common"
cat > "${fixture}/repo/app/paths.txt" <<'EOF'
l common $HOME/links/common
l $DOTFILES_WORK/source $HOME/links/work
l ${DOTFILES_WORK}/source $HOME/links/work-braced
l $DOTFILES_CLOUD/source $HOME/links/personal
l ${DOTFILES_CLOUD}/source $HOME/links/personal-braced
l common $DOTFILES_WORK/destination
l common ${DOTFILES_CLOUD}/destination
l $DOTFILES_WORK/keys/* $HOME/keys *
l missing $HOME/links/missing
EOF
printf '%s\n' 'l common $HOME/links/test-only' > "${fixture}/repo/test/paths.txt"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    tail -n 30 "${fixture}/output" >&2
    exit 1
}
newHome() {
    HOME="${fixture}/$1"
    export HOME
    mkdir -p "${HOME}/work/keys" "${HOME}/personal" "${HOME}/links"
    printf 'work\n' > "${HOME}/work/source"
    printf 'secret\n' > "${HOME}/work/keys/key"
    printf 'personal\n' > "${HOME}/personal/source"
    printf 'DOTFILES_WORK=%s/work\nDOTFILES_CLOUD=%s/personal\n' "${HOME}" "${HOME}" > "${fixture}/repo/.env.linux"
    cp "${fixture}/repo/.env.linux" "${fixture}/repo/.env.wsl"
}
deploy() {
    bash "${fixture}/repo/deploy-config-linux.sh" "$@" > "${fixture}/output" 2>&1
}
hasLog() { grep -Fq -- "$1" "${fixture}/output" || fail "Missing log: $1"; }

for scope in work personal both none; do
    newHome "${scope}"
    DOTFILES_SCOPE="${scope}" deploy --debug </dev/null
    [[ -L "${HOME}/links/common" ]] || fail "${scope}: common mapping"
    hasLog "Mapping scope: ${scope}"
    hasLog "does not exist."
    if [[ "${scope}" == work || "${scope}" == both ]]; then
        [[ -L "${HOME}/links/work" && -L "${HOME}/links/work-braced" &&
           -L "${HOME}/work/destination" && -f "${HOME}/keys/key" &&
           ! -L "${HOME}/keys/key" ]] || fail "${scope}: work mappings"
        [[ "$(stat -c %a "${HOME}/keys/key")" == 600 ]] || fail "Secure copy mode"
    else
        [[ ! -e "${HOME}/links/work" && ! -e "${HOME}/work/destination" &&
           ! -e "${HOME}/keys" ]] || fail "Work mappings not skipped"
        hasLog "Skipping work mapping"
    fi
    if [[ "${scope}" == personal || "${scope}" == both ]]; then
        [[ -L "${HOME}/links/personal" && -L "${HOME}/links/personal-braced" &&
           -L "${HOME}/personal/destination" ]] || fail "${scope}: personal mappings"
    else
        [[ ! -e "${HOME}/links/personal" && ! -e "${HOME}/personal/destination" ]] ||
            fail "Personal mappings not skipped"
        hasLog "Skipping personal mapping"
    fi
done

newHome cleanup-none
rm -- "${HOME}/work/source" "${HOME}/work/keys/key" "${HOME}/personal/source"
rmdir -- "${HOME}/work/keys" "${HOME}/work" "${HOME}/personal"
for skipped in work personal; do
    ln -s "${HOME}/${skipped}/missing" "${HOME}/links/${skipped}-absolute"
    ln -s "../${skipped}/missing" "${HOME}/links/${skipped}-relative"
done
ln -s "${HOME}/missing" "${HOME}/links/unprotected"
printf '\n' | deploy --scope none --debug
[[ -L "${HOME}/links/common" && ! -L "${HOME}/links/unprotected" ]] ||
    fail "None scope common mapping or cleanup"
for skipped in work personal; do
    [[ -L "${HOME}/links/${skipped}-absolute" && -L "${HOME}/links/${skipped}-relative" ]] ||
        fail "None scope cleanup protection for ${skipped}"
done
if grep -Fq 'Continue without an available' "${fixture}/output"; then
    fail "None scope prompted for unavailable roots"
fi

newHome default
DOTFILES_SCOPE= deploy </dev/null
[[ -L "${HOME}/links/work" && -L "${HOME}/links/personal" ]] || fail "Default both"

newHome override
DOTFILES_SCOPE=personal deploy -s work --dry-run --debug --verbose </dev/null
hasLog "Mapping scope: work"
[[ ! -e "${HOME}/links/common" && ! -e "${HOME}/keys" ]] || fail "Dry run wrote mappings"

newHome test-mode
deploy --scope both --test </dev/null
[[ -L "${HOME}/links/test-only" && ! -e "${HOME}/links/common" ]] || fail "Test mode"

for invalid in invalid ""; do
    if deploy --scope "${invalid}" </dev/null; then fail "Accepted invalid scope"; fi
done
if deploy --scope </dev/null; then fail "Accepted missing scope"; fi
if DOTFILES_SCOPE=invalid deploy </dev/null; then fail "Accepted invalid env scope"; fi

for scope in work personal; do
    newHome "cleanup-${scope}"
    if [[ "${scope}" == work ]]; then skipped=personal; else skipped=work; fi
    # An unavailable unselected root must neither prompt nor lose its old links.
    rm -- "${HOME}/${skipped}/source"
    if [[ "${skipped}" == work ]]; then
        rm -- "${HOME}/work/keys/key"
        rmdir -- "${HOME}/work/keys"
    fi
    ln -s "${HOME}/${skipped}/missing" "${HOME}/links/protected-absolute"
    ln -s "../${skipped}/nested/../missing" "${HOME}/links/protected-relative"
    ln -s "${HOME}/${skipped}" "${HOME}/links/protected-root"
    rmdir -- "${HOME}/${skipped}"
    mkdir -p "${HOME}/${skipped}-other"
    ln -s "${HOME}/${skipped}-other/missing" "${HOME}/links/unprotected"
    printf '\n' | deploy --scope "${scope}" --debug
    [[ -L "${HOME}/links/protected-absolute" && -L "${HOME}/links/protected-relative" &&
       -L "${HOME}/links/protected-root" && ! -L "${HOME}/links/unprotected" ]] ||
        fail "Cleanup protection for ${scope}"
    hasLog "Skipping cleanup of unselected scope symlink"
done

newHome unavailable
rm -- "${HOME}/personal/source"
if deploy --scope personal </dev/null; then fail "Empty root accepted without confirmation"; fi
hasLog "Deployment cancelled"
hasLog "Continue without an available personal root? [y/N]"
[[ ! -e "${HOME}/links/common" ]] || fail "Mapped before root confirmation"
printf 'n\n' | { if deploy --scope personal; then fail "Root refusal ignored"; fi; }
printf 'yes\n' | deploy --scope personal
[[ -L "${HOME}/links/common" ]] || fail "Root confirmation ignored"
rm -- "${HOME}/personal/destination"
rmdir -- "${HOME}/personal"
if deploy --scope personal </dev/null; then fail "Missing root accepted"; fi
printf 'DOTFILES_WORK=%s/work\n' "${HOME}" > "${fixture}/repo/.env.linux"
cp "${fixture}/repo/.env.linux" "${fixture}/repo/.env.wsl"
unset DOTFILES_CLOUD
if deploy --scope personal </dev/null; then fail "Unset root accepted"; fi

printf '# No external roots configured\n' > "${fixture}/repo/.env.linux"
cp "${fixture}/repo/.env.linux" "${fixture}/repo/.env.wsl"
unset DOTFILES_WORK DOTFILES_CLOUD
deploy -s none </dev/null
hasLog "Mapping scope: none"

printf 'All scope deployment tests passed.\n'
