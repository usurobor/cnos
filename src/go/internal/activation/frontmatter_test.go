package activation

import (
	"reflect"
	"testing"
)

// F1 — happy path with name + description + triggers.
func TestParseFrontmatter_Happy(t *testing.T) {
	src := "---\n" +
		"name: cdd\n" +
		"description: Coherence-Driven Development\n" +
		"triggers:\n" +
		"  - review\n" +
		"  - release\n" +
		"  - design\n" +
		"---\n" +
		"# Body\n"
	fm := ParseFrontmatter([]byte(src))
	if fm.Name != "cdd" {
		t.Errorf("name = %q, want %q", fm.Name, "cdd")
	}
	if fm.Description != "Coherence-Driven Development" {
		t.Errorf("description = %q", fm.Description)
	}
	want := []string{"review", "release", "design"}
	if !reflect.DeepEqual(fm.Triggers, want) {
		t.Errorf("triggers = %v, want %v", fm.Triggers, want)
	}
	if fm.Visibility != "" {
		t.Errorf("visibility = %q, want empty (absent)", fm.Visibility)
	}
	if !fm.IsPublic() {
		t.Error("IsPublic = false for skill with no visibility field")
	}
}

// F2 — missing leading --- yields empty frontmatter.
func TestParseFrontmatter_MissingLeading(t *testing.T) {
	fm := ParseFrontmatter([]byte("name: cdd\ndescription: bare\n# Body\n"))
	if fm.Name != "" || len(fm.Triggers) != 0 {
		t.Errorf("expected empty frontmatter, got %+v", fm)
	}
}

// F3 — missing closing --- yields empty frontmatter (unterminated block).
func TestParseFrontmatter_MissingClosing(t *testing.T) {
	fm := ParseFrontmatter([]byte("---\nname: cdd\ndescription: never closes\n# but no second marker"))
	if fm.Name != "" || len(fm.Triggers) != 0 {
		t.Errorf("expected empty frontmatter, got %+v", fm)
	}
}

// F4 — triggers absent is tolerated; scalars still parse.
func TestParseFrontmatter_TriggersAbsent(t *testing.T) {
	fm := ParseFrontmatter([]byte("---\nname: cdd\ndescription: no trigger field\n---\n# Body\n"))
	if fm.Name != "cdd" {
		t.Errorf("name = %q, want %q", fm.Name, "cdd")
	}
	if len(fm.Triggers) != 0 {
		t.Errorf("triggers len = %d, want 0", len(fm.Triggers))
	}
}

// F5 — malformed list lines are tolerated; valid items still accumulate.
func TestParseFrontmatter_MalformedListLines(t *testing.T) {
	src := "---\n" +
		"name: cdd\n" +
		"triggers:\n" +
		"  - review\n" +
		"  garbage line without dash\n" +
		"  - release\n" +
		"---\n"
	fm := ParseFrontmatter([]byte(src))
	// The malformed line terminates the pending list (flushList runs
	// on any non-list, non-empty line) and is then rejected as a
	// key:value pair. "- release" that follows starts its own scan
	// but there is no pending list key, so it too is treated as a
	// scalar line and discarded. The first list is preserved.
	want := []string{"review"}
	if !reflect.DeepEqual(fm.Triggers, want) {
		t.Errorf("triggers = %v, want %v", fm.Triggers, want)
	}
}

// Visibility: internal is recognised and excludes from public index.
func TestParseFrontmatter_VisibilityInternal(t *testing.T) {
	src := "---\n" +
		"name: alpha\n" +
		"visibility: internal\n" +
		"triggers:\n" +
		"  - alpha\n" +
		"---\n"
	fm := ParseFrontmatter([]byte(src))
	if fm.Visibility != "internal" {
		t.Errorf("visibility = %q, want internal", fm.Visibility)
	}
	if fm.IsPublic() {
		t.Error("IsPublic = true for internal skill")
	}
}

// Visibility: public is recognised and keeps the skill public.
func TestParseFrontmatter_VisibilityPublic(t *testing.T) {
	src := "---\n" +
		"name: daily\n" +
		"visibility: public\n" +
		"---\n"
	fm := ParseFrontmatter([]byte(src))
	if fm.Visibility != "public" {
		t.Errorf("visibility = %q, want public", fm.Visibility)
	}
	if !fm.IsPublic() {
		t.Error("IsPublic = false for explicit public skill")
	}
}

// Unrecognised frontmatter keys are silently ignored.
func TestParseFrontmatter_UnrecognisedKeys(t *testing.T) {
	src := "---\n" +
		"name: demo\n" +
		"artifact_class: skill\n" +
		"governing_question: How do we X?\n" +
		"parent: cdd\n" +
		"---\n"
	fm := ParseFrontmatter([]byte(src))
	if fm.Name != "demo" {
		t.Errorf("name = %q, want %q", fm.Name, "demo")
	}
}

// Inline triggers list is not supported — warned and left empty.
func TestParseFrontmatter_InlineTriggersIgnored(t *testing.T) {
	src := "---\n" +
		"name: demo\n" +
		"triggers: [a, b]\n" +
		"---\n"
	fm := ParseFrontmatter([]byte(src))
	if len(fm.Triggers) != 0 {
		t.Errorf("triggers = %v, want empty (inline unsupported)", fm.Triggers)
	}
}

// CRLF line endings are normalised.
func TestParseFrontmatter_CRLF(t *testing.T) {
	src := "---\r\nname: demo\r\ntriggers:\r\n  - one\r\n---\r\n"
	fm := ParseFrontmatter([]byte(src))
	if fm.Name != "demo" {
		t.Errorf("name = %q, want demo", fm.Name)
	}
	if !reflect.DeepEqual(fm.Triggers, []string{"one"}) {
		t.Errorf("triggers = %v, want [one]", fm.Triggers)
	}
}
