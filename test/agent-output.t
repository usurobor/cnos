# Agent Output Tests
# Tests for cn out command - the ONLY way agent can output decisions

Setup:
  $ export PATH="$TESTDIR:$PATH"
  $ source "$TESTDIR/prelude.sh"

# =============================================================================
# cn out help
# =============================================================================

cn out should show help:
  $ cn out --help
  cn out - Agent decision output
  
  Usage: cn out <gtd> [op] [options]
  
  GTD (only 4 options):
    do <op>              Complete with operation
    defer                Postpone
    delegate             Forward to peer
    delete               Discard
  
  Operations (for do):
    reply --message      Append to current thread
    send --to --message  Send to peer
    noop --reason        Acknowledge, no action
    ack --reason         Explicit acknowledgment
    surface --desc       Surface MCA for community
    commit --artifact    Reference artifact hash
  
  Examples:
    cn out do reply --message "LGTM"
    cn out do send --to pi --message "hello"
    cn out defer --reason "waiting on review"
    cn out delegate --to pi
    cn out delete --reason "duplicate"

# =============================================================================
# cn out do reply
# =============================================================================

cn out do reply should write output.md:
  $ cn out do reply --message "LGTM"
  \xe2\x9c\x93 Output: Do Reply "LGTM" (esc)

# =============================================================================
# cn out do send
# =============================================================================

cn out do send should write output.md with send op:
  $ cn out do send --to pi --message "hello"
  \xe2\x9c\x93 Output: Do Send to=pi "hello" (esc)

cn out do send with body:
  $ cn out do send --to pi --message "summary" --body "full response"
  \xe2\x9c\x93 Output: Do Send to=pi "summary" (body: 13 chars) (esc)

# =============================================================================
# cn out defer
# =============================================================================

cn out defer should write output.md:
  $ cn out defer --reason "waiting on review"
  \xe2\x9c\x93 Output: Defer "waiting on review" (esc)

cn out defer requires reason:
  $ cn out defer
  \xe2\x9c\x97 defer requires --reason (esc)
  [1]

# =============================================================================
# cn out delegate
# =============================================================================

cn out delegate should write output.md:
  $ cn out delegate --to pi
  \xe2\x9c\x93 Output: Delegate to=pi (esc)

cn out delegate requires --to:
  $ cn out delegate
  \xe2\x9c\x97 delegate requires --to (esc)
  [1]

# =============================================================================
# cn out delete
# =============================================================================

cn out delete should write output.md:
  $ cn out delete --reason "duplicate"
  \xe2\x9c\x93 Output: Delete "duplicate" (esc)

cn out delete requires reason:
  $ cn out delete
  \xe2\x9c\x97 delete requires --reason (esc)
  [1]

# =============================================================================
# Invalid commands
# =============================================================================

cn out with invalid gtd:
  $ cn out invalid
  \xe2\x9c\x97 Unknown GTD: invalid. Must be: do, defer, delegate, delete (esc)
  [1]

cn out do with invalid op:
  $ cn out do invalid
  \xe2\x9c\x97 Unknown operation: invalid (esc)
  [1]
