package cli

// Registry holds all registered commands and provides lookup + filtering.
// Registration order is preserved for deterministic help output.
type Registry struct {
	commands map[string]Command
	order    []string // insertion order
}

// NewRegistry creates an empty command registry.
func NewRegistry() *Registry {
	return &Registry{
		commands: make(map[string]Command),
	}
}

// Register adds a command to the registry. If a command with the same
// name already exists, the higher-priority tier wins (lower Tier value).
// Equal tiers: first registration wins.
func (r *Registry) Register(cmd Command) {
	name := cmd.Spec().Name
	if existing, ok := r.commands[name]; ok {
		if cmd.Spec().Tier >= existing.Spec().Tier {
			return // existing has equal or higher priority
		}
	}
	r.commands[name] = cmd
	// Append to order only if this is a new name.
	found := false
	for _, n := range r.order {
		if n == name {
			found = true
			break
		}
	}
	if !found {
		r.order = append(r.order, name)
	}
}

// Lookup finds a command by name.
func (r *Registry) Lookup(name string) (Command, bool) {
	cmd, ok := r.commands[name]
	return cmd, ok
}

// All returns every registered command in registration order.
//
// Callers decide how to present commands to the user. Help and
// status are the two consumers today and they have different
// policies: help always lists the full kernel surface (annotating
// hub-needing commands), status lists only what is usable now.
// Keeping a single, unfiltered accessor avoids hiding that policy
// inside the registry.
func (r *Registry) All() []Command {
	result := make([]Command, 0, len(r.order))
	for _, name := range r.order {
		if cmd, ok := r.commands[name]; ok {
			result = append(result, cmd)
		}
	}
	return result
}
