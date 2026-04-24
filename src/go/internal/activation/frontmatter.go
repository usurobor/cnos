// Package activation builds the skill activation index from installed
// packages and validates its health.
//
// Go equivalent of src/ocaml/lib/cn_frontmatter.ml (pure parser) plus
// src/ocaml/cmd/cn_activation.ml (IO-side index + doctor), reshaped
// around filesystem-authoritative discovery (issue #261):
//
//   - Skills are discovered by walking <pkg>/skills/ for SKILL.md files.
//     The `skills` field in cn.package.json is not read — filesystem
//     presence is the single source of truth (DESIGN-CONSTRAINTS.md §1,
//     PACKAGE-SYSTEM.md §3).
//
//   - Visibility is declared per-skill in SKILL.md frontmatter. Skills
//     with `visibility: internal` are excluded from the public activation
//     index; skills with no visibility field default to public.
//
// Purity boundary (eng/go §2.17): frontmatter.go is pure — it takes
// bytes and returns typed values, with no os/filesystem imports. IO
// lives in index.go.
package activation

import (
	"bytes"
	"log/slog"
	"strings"
)

// Visibility values recognised by the activation index. Any string
// other than these two is treated as the raw frontmatter value; only
// "internal" excludes a skill from the public index.
const (
	VisibilityPublic   = "public"
	VisibilityInternal = "internal"
)

// Frontmatter is the parsed SKILL.md YAML-subset frontmatter.
//
// Only the fields the activation index consumes are materialised here;
// unrecognised keys (artifact_class, governing_question, parent, ...)
// are intentionally ignored.
type Frontmatter struct {
	Name        string
	Description string
	Triggers    []string
	// Visibility is the raw string from the `visibility:` field. Empty
	// string means the field was absent — callers should treat that as
	// public via IsPublic.
	Visibility string
}

// IsPublic reports whether the skill should appear in the public
// activation index. Absent or empty visibility defaults to public;
// only the canonical literal "internal" excludes a skill.
func (f Frontmatter) IsPublic() bool {
	return f.Visibility != VisibilityInternal
}

// ParseFrontmatter parses a SKILL.md's YAML-subset frontmatter from
// raw bytes. Always succeeds: missing or malformed input yields a
// zero-valued Frontmatter or a partially populated record. Malformed
// lines are logged via slog.Warn and skipped.
//
// Supported grammar (mirrors Cn_frontmatter.parse_frontmatter):
//   - --- markers delimit the frontmatter block (both required)
//   - "key: value" sets a scalar
//   - "key:" followed by indented "- item" lines builds a block list
//   - inline lists (key: [a, b]) are not supported
func ParseFrontmatter(data []byte) Frontmatter {
	block, ok := extractBlock(splitLines(data))
	if !ok {
		return Frontmatter{}
	}

	var fm Frontmatter
	var pendingListKey string
	var triggersAcc []string

	flushList := func() {
		if pendingListKey == "triggers" {
			fm.Triggers = triggersAcc
		}
		pendingListKey = ""
		triggersAcc = nil
	}

	for _, line := range block {
		if strings.TrimSpace(line) == "" {
			continue
		}
		if isListItem(line) && pendingListKey != "" {
			triggersAcc = append(triggersAcc, listItemValue(line))
			continue
		}
		flushList()
		key, value, okKV := parseKeyValue(line)
		if !okKV {
			slog.Warn("activation: skipping malformed frontmatter line",
				slog.String("line", line))
			continue
		}
		if value == "" {
			pendingListKey = key
			continue
		}
		switch key {
		case "name":
			fm.Name = value
		case "description":
			fm.Description = value
		case "visibility":
			fm.Visibility = value
		case "triggers":
			slog.Warn("activation: inline triggers list not supported; use block list",
				slog.String("value", value))
		}
	}
	flushList()
	return fm
}

// splitLines splits on \n, accepting either \n or \r\n line endings.
func splitLines(data []byte) []string {
	// Strip BOM and normalise CRLF so downstream trim/compare is simple.
	data = bytes.TrimPrefix(data, []byte{0xEF, 0xBB, 0xBF})
	text := strings.ReplaceAll(string(data), "\r\n", "\n")
	return strings.Split(text, "\n")
}

// extractBlock returns the lines between the first two "---" markers.
// Returns (nil, false) if either marker is missing.
func extractBlock(lines []string) ([]string, bool) {
	if len(lines) == 0 || strings.TrimSpace(lines[0]) != "---" {
		return nil, false
	}
	var out []string
	for _, l := range lines[1:] {
		if strings.TrimSpace(l) == "---" {
			return out, true
		}
		out = append(out, l)
	}
	return nil, false
}

// parseKeyValue splits "key: value" on the first colon. Returns
// (key, value, true) on success; (""/""/false) when there is no colon
// or the key is empty.
func parseKeyValue(line string) (string, string, bool) {
	i := strings.IndexByte(line, ':')
	if i < 0 {
		return "", "", false
	}
	key := strings.TrimSpace(line[:i])
	if key == "" {
		return "", "", false
	}
	value := strings.TrimSpace(line[i+1:])
	return key, value, true
}

// isListItem reports whether a line is a YAML block-list item ("  - x").
func isListItem(line string) bool {
	trimmed := strings.TrimSpace(line)
	return len(trimmed) >= 2 && trimmed[:2] == "- "
}

// listItemValue returns the payload of a block-list item, trimmed.
func listItemValue(line string) string {
	trimmed := strings.TrimSpace(line)
	return strings.TrimSpace(trimmed[2:])
}
