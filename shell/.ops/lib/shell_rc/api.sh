#!/bin/sh

: <<'MODULE'
API for managing persistent shell rc files.

Provides helpers to detect the user's shell rc file, check for existing
lines, append new lines (with or without interactive confirmation).
MODULE

__shell_rc__path() {
  case "$(basename "${SHELL:-}")" in
    bash) echo "$HOME/.bashrc" ;;
    zsh) echo "$HOME/.zshrc" ;;
    *)
      return 1
      ;;
  esac
}

__shell_rc__has_line() {
  __shell_rc__has_line__file="$1"
  __shell_rc__has_line__line="$2"

  if [ ! -f "$__shell_rc__has_line__file" ]; then
    @false __shell_rc__has_line__out
    println "$__shell_rc__has_line__out"
    return
  fi
  @succeeds __shell_rc__has_line__out grep -Fqx "$__shell_rc__has_line__line" "$__shell_rc__has_line__file"
  println "$__shell_rc__has_line__out"
}

__shell_rc__is_interactive() {
  @succeeds __shell_rc__is_interactive__out [ -t 0 ]
  println "$__shell_rc__is_interactive__out"
}

__shell_rc__append_line_to_file() {
  __shell_rc__append_line_to_file__file="$1"
  __shell_rc__append_line_to_file__line="$2"

  touch "$__shell_rc__append_line_to_file__file"
  if [ -s "$__shell_rc__append_line_to_file__file" ]; then
    echo "" >> "$__shell_rc__append_line_to_file__file"
  fi
  echo "$__shell_rc__append_line_to_file__line" >> "$__shell_rc__append_line_to_file__file"
}

: <<'PUB_FUN'
Offer to append a line to the user's shell rc file.

In interactive shells, prompts for confirmation. In non-interactive shells
or unsupported shells, prints a warning with the line to add manually.
Idempotent: skips if the line already exists.
PUB_FUN
shell_rc__offer_line() {
  __shell_rc__offer_line__description="$1"
  __shell_rc__offer_line__line="$2"

  __shell_rc__offer_line__rc_file="$(__shell_rc__path)" || {
    warn "Add $__shell_rc__offer_line__description to your shell rc manually:"
    warn "  $__shell_rc__offer_line__line"
    return 0
  }

  if @is_true "$(__shell_rc__has_line "$__shell_rc__offer_line__rc_file" "$__shell_rc__offer_line__line")"; then
    return 0
  fi

  if @is_false "$(__shell_rc__is_interactive)"; then
    warn "Add $__shell_rc__offer_line__description to $__shell_rc__offer_line__rc_file:"
    warn "  $__shell_rc__offer_line__line"
    return 0
  fi

  prompt "Add $__shell_rc__offer_line__description to $__shell_rc__offer_line__rc_file now? [y/N] "
  read -r __shell_rc__offer_line__reply
  case "$__shell_rc__offer_line__reply" in
    [Yy]) ;;
    *)
      warn "Add $__shell_rc__offer_line__description to $__shell_rc__offer_line__rc_file:"
      warn "  $__shell_rc__offer_line__line"
      return 0
      ;;
  esac

  __shell_rc__append_line_to_file \
    "$__shell_rc__offer_line__rc_file" \
    "$__shell_rc__offer_line__line"

  log "  Added $__shell_rc__offer_line__description to $__shell_rc__offer_line__rc_file"
}

: <<'PUB_FUN'
Append a line to the user's shell rc file without prompting.

Use this when intent has already been declared (e.g. via ops.lock postinstall)
and interactive confirmation would be redundant.
Idempotent: skips if the line already exists.
PUB_FUN
shell_rc__add_line() {
  __shell_rc__add_line__description="$1"
  __shell_rc__add_line__line="$2"

  __shell_rc__add_line__rc_file="$(__shell_rc__path)" || {
    warn "Add $__shell_rc__add_line__description to your shell rc manually:"
    warn "  $__shell_rc__add_line__line"
    return 0
  }

  if @is_true "$(__shell_rc__has_line "$__shell_rc__add_line__rc_file" "$__shell_rc__add_line__line")"; then
    return 0
  fi

  __shell_rc__append_line_to_file \
    "$__shell_rc__add_line__rc_file" \
    "$__shell_rc__add_line__line"

  log "  Added $__shell_rc__add_line__description to $__shell_rc__add_line__rc_file"
}
