# Graduated section tests
# Graduated folders (symlink left in tries dir, or dirs in TRY_PROJECTS)
# are listed after ungraduated tries, below a "🎓 Graduated" separator.

section "graduated-section"

# Hermetic: ignore any TRY_PROJECTS from the caller's environment except
# where a test sets it explicitly.
_saved_try_projects=${TRY_PROJECTS-}
unset TRY_PROJECTS

strip_ansi() {
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | sed 's/\x1b\[[?][0-9]*[a-zA-Z]//g'
}

GL_ROOT=$(mktemp -d)
GL_TRIES="$GL_ROOT/tries"
GL_PROJECTS="$GL_ROOT/projects"
mkdir -p "$GL_TRIES/2025-01-01-fresh-try" "$GL_PROJECTS/graduated-proj" "$GL_PROJECTS/loose-proj"
ln -s "$GL_PROJECTS/graduated-proj" "$GL_TRIES/2025-06-01-old-try"
# Make the graduated entries most-recent so only grouping (not score)
# can place them below the ungraduated try.
touch "$GL_PROJECTS/graduated-proj" "$GL_PROJECTS/loose-proj"
touch -t 202501010000 "$GL_TRIES/2025-01-01-fresh-try"

line_of() { echo "$1" | grep -n "$2" | head -1 | cut -d: -f1; }

# Test: separator present, ungraduated first, graduated below it
output=$(try_run --path="$GL_TRIES" --and-exit exec 2>&1 | strip_ansi)
fresh_line=$(line_of "$output" "fresh-try")
sep_line=$(line_of "$output" "🎓 Graduated")
grad_line=$(line_of "$output" "old-try")
if [ -n "$fresh_line" ] && [ -n "$sep_line" ] && [ -n "$grad_line" ] && \
   [ "$fresh_line" -lt "$sep_line" ] && [ "$sep_line" -lt "$grad_line" ]; then
    pass
else
    fail "graduated should render below separator, after ungraduated" "fresh < separator < old-try" "$output" "graduate"
fi

# Test: without TRY_PROJECTS, projects-dir-only folders are not listed
if echo "$output" | grep -q "loose-proj"; then
    fail "unlinked project should not list without TRY_PROJECTS" "no loose-proj" "$output" "graduate"
else
    pass
fi

# Test: with TRY_PROJECTS, unlinked project shows in graduated section (deduped)
output=$(TRY_PROJECTS="$GL_PROJECTS" try_run --path="$GL_TRIES" --and-exit exec 2>&1 | strip_ansi)
sep_line=$(line_of "$output" "🎓 Graduated")
loose_line=$(line_of "$output" "loose-proj")
linked_count=$(echo "$output" | grep -c "old-try")
if [ -n "$loose_line" ] && [ "$sep_line" -lt "$loose_line" ] && [ "$linked_count" -eq 1 ]; then
    pass
else
    fail "TRY_PROJECTS project should list once, below separator" "loose-proj below separator, old-try once" "$output" "graduate"
fi

# Test: Enter on a direct graduated project cds to its real path
real_loose=$(cd "$GL_PROJECTS/loose-proj" && pwd -P)
output=$(TRY_PROJECTS="$GL_PROJECTS" try_run --path="$GL_TRIES" --and-keys='DOWN,DOWN,DOWN,ENTER' exec 2>/dev/null)
if echo "$output" | grep -q "cd '$real_loose'"; then
    pass
else
    fail "Enter on graduated project should cd to it" "cd '$real_loose'" "$output" "graduate"
fi

# Test: Ctrl-G on an already-graduated entry emits no move script
output=$(try_run --path="$GL_TRIES" --and-keys='DOWN,CTRL-G,ESC' exec 2>/dev/null)
if echo "$output" | grep -q "mv "; then
    fail "Ctrl-G on graduated entry should not graduate again" "no mv" "$output" "graduate"
else
    pass
fi

# Test: fuzzy filter still finds graduated entries, still separated
output=$(TRY_PROJECTS="$GL_PROJECTS" try_run --path="$GL_TRIES" --and-type=loose --and-exit exec 2>&1 | strip_ansi)
if echo "$output" | grep -q "🎓 Graduated" && echo "$output" | grep -q "loose-proj"; then
    pass
else
    fail "filtered graduated entry should keep its separator" "separator + loose-proj" "$output" "graduate"
fi

rm -rf "$GL_ROOT"
if [ -n "$_saved_try_projects" ]; then TRY_PROJECTS=$_saved_try_projects; export TRY_PROJECTS; fi
unset _saved_try_projects
