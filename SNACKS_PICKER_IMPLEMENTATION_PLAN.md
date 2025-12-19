# Snacks Picker Implementation Plan

## Overview

This document outlines the plan to add support for the snacks.nvim picker to obsidian.nvim.

## Background

### Current Picker System

obsidian.nvim has a flexible picker abstraction supporting three implementations:
1. **Telescope** (`pickers/_telescope.lua`) - Most popular, 286 lines
2. **FZF-Lua** (`pickers/_fzf.lua`) - Fastest option, 212 lines
3. **Mini.Pick** (`pickers/_mini.lua`) - Lightweight alternative, 121 lines

All pickers extend an abstract base class (`pickers/picker.lua`, 522 lines) that defines:
- **Abstract methods**: `find_files()`, `grep()`, `pick()` - must be implemented
- **Concrete methods**: `find_notes()`, `grep_notes()`, `pick_note()`, `pick_tag()` - use abstract methods
- **Entry format**: Standardized `obsidian.PickerEntry` with display, value, filename, line/col
- **Mapping system**: Custom keybindings for actions like creating notes, inserting links/tags

### Snacks.nvim Picker

**Snacks.nvim** is a modern QoL plugin collection by folke that includes a fuzzy-finder with:
- 40+ built-in sources
- Fast fuzzy matching with fzf syntax
- Async finders and matchers
- Multiple layout options
- Treesitter highlighting
- Main API: `Snacks.picker.pick(source, opts)`

## Implementation Phases

### Phase 1: Create Snacks Picker Implementation

**File**: `lua/obsidian/pickers/_snacks.lua` (estimated ~200-250 lines)

**Tasks**:
1. Create new `SnacksPicker` class extending the base `Picker` class
2. Implement required abstract methods:
   - `find_files(opts)` - Use `Snacks.picker.pick("files", ...)` with appropriate directory filtering
   - `grep(opts)` - Use `Snacks.picker.pick("grep", ...)` with search pattern and directory
   - `pick(values, opts)` - Create custom picker with items list
3. Convert obsidian entries to snacks item format:
   - Map `obsidian.PickerEntry` → `snacks.picker.finder.Item`
   - Ensure `text`, `file`, `pos` fields are properly populated
4. Implement action mappings:
   - Map obsidian query/selection mappings to snacks action system
   - Handle callbacks for creating notes (`<C-x>`), inserting links (`<C-l>`), etc.
   - Adapt keymap format (obsidian uses `<C-x>` while snacks may need different format)

**Key Challenges**:
- Understanding snacks' async finder API for custom items
- Mapping between obsidian's callback-based actions and snacks' action system
- Ensuring proper formatter configuration for note/tag display

**Verification**:
- Manual testing with `:ObsidianQuickSwitch` and `:ObsidianSearch`
- Verify keybindings work correctly
- Test preview functionality

---

### Phase 2: Update Picker Registry

**File**: `lua/obsidian/pickers/init.lua`

**Tasks**:
1. Add snacks detection to auto-detection logic in `M.get()`:
   - Check for `pcall(require, "snacks")` and verify picker module exists
   - Add to detection order: telescope → fzf-lua → snacks → mini.pick
2. Register "snacks.nvim" as a valid picker name option
3. Update picker instantiation to handle snacks picker class

**Changes Required**:
```lua
-- Add to picker detection
if picker_name == "snacks" or picker_name == "snacks.nvim" then
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.picker then
    return require("obsidian.pickers._snacks").new(client)
  end
end
```

**Verification**:
- Test auto-detection works when snacks.nvim is installed
- Test explicit configuration with `picker.name = "snacks.nvim"`
- Verify fallback to other pickers when snacks not available

---

### Phase 3: Configuration Updates

**File**: `lua/obsidian/config.lua`

**Tasks**:
1. Update config schema to include "snacks.nvim" as valid picker option
2. Add documentation for snacks-specific config options (if needed)
3. Ensure backward compatibility with existing picker configs

**No breaking changes** - just add to allowed values for `picker.name`

**Verification**:
- Test config validation accepts "snacks.nvim"
- Verify existing configs still work

---

### Phase 4: Documentation

**Files**:
- `doc/obsidian.txt` - User documentation
- `README.md` - Setup guide

**Tasks**:
1. Add snacks.nvim to list of supported pickers in README
2. Update installation section with snacks dependency:
   ```lua
   { "folke/snacks.nvim" }  -- Optional: picker
   ```
3. Document any snacks-specific configuration options
4. Add snacks to picker configuration examples
5. Update `doc/obsidian.txt` help file with snacks picker info

**Verification**:
- Review documentation for accuracy
- Ensure examples are correct

---

### Phase 5: Testing

**Files**: `test/obsidian/pickers/` (may need new test file)

**Tasks**:
1. Write unit tests for `SnacksPicker` class:
   - Test entry conversion (obsidian → snacks format)
   - Test action mapping configuration
   - Mock snacks API to verify correct calls
2. Manual testing:
   - Test all commands that use pickers (`:ObsidianSearch`, `:ObsidianQuickSwitch`, etc.)
   - Verify keybindings work (create note, insert link, insert tag)
   - Test multi-selection scenarios
   - Verify preview functionality
3. Edge case testing:
   - Empty vault
   - Large vaults (performance)
   - Missing snacks.nvim dependency

**Verification**:
- All tests pass
- Manual testing confirms all features work
- No regressions in existing pickers

---

## Implementation Order

1. **Phase 1: Core Implementation** - Create `_snacks.lua`
   - Study existing `_telescope.lua`, `_fzf.lua`, `_mini.lua` for patterns
   - Implement basic `find_files()` and `grep()` first
   - Add custom `pick()` with action mapping
   - Test incrementally with manual commands

2. **Phase 2: Registry** - Update `init.lua`
   - Add detection logic
   - Test auto-detection works

3. **Phase 3: Configuration** - Update `config.lua`
   - Add to valid picker names
   - Test config validation

4. **Phase 4: Documentation** - User-facing updates
   - README, help docs

5. **Phase 5: Testing** - Verification
   - Unit tests, manual testing, edge cases

---

## Files to Create/Modify

| File | Action | Estimated Lines |
|------|--------|----------------|
| `lua/obsidian/pickers/_snacks.lua` | **CREATE** | ~200-250 |
| `lua/obsidian/pickers/init.lua` | **MODIFY** | +10-15 |
| `lua/obsidian/config.lua` | **MODIFY** | +5-10 |
| `README.md` | **MODIFY** | +10-20 |
| `doc/obsidian.txt` | **MODIFY** | +15-30 |
| `test/obsidian/pickers/snacks_spec.lua` | **CREATE** (optional) | ~100-150 |

**Total new code**: ~350-400 lines
**Total modifications**: ~40-75 lines

---

## Key Design Decisions

### 1. Picker Priority
Where should snacks appear in auto-detection order?
- **Decision**: After fzf-lua, before mini.pick
- **Reasoning**: Telescope is most popular, fzf-lua is fastest, snacks is modern but newer

### 2. Action Mapping Strategy
How to handle obsidian's custom actions in snacks?
- **Approach**: Use snacks' action system with custom action definitions
- Define actions for `new_note`, `insert_link`, `insert_tag`, `tag_note`

### 3. Entry Formatter
Should we use snacks' built-in formatters or custom?
- **Recommendation**: Use built-in "file" formatter where possible
- Customize for tags and special note metadata

### 4. Async Handling
How to handle snacks' async finder API?
- **Approach**: Leverage snacks' native async support
- Use custom finder functions that return items asynchronously

---

## Dependencies

**Required for snacks picker**:
- `folke/snacks.nvim` - Must have picker module enabled
- No changes to existing required dependencies

**Testing dependencies**:
- `nvim-lua/plenary.nvim` - Already required for obsidian.nvim
- Snacks.nvim installed for integration tests

---

## Compatibility Considerations

1. **Neovim Version**: Snacks requires recent Neovim (likely 0.9.0+)
   - obsidian.nvim requires 0.8.0+
   - May need version check in snacks picker

2. **Graceful Degradation**: If snacks not available, fall back to other pickers
   - Auto-detection handles this automatically

3. **Config Migration**: No breaking changes to existing configs
   - Users can opt-in by setting `picker.name = "snacks.nvim"`

---

## Success Criteria

- ✅ Users can configure `picker.name = "snacks.nvim"`
- ✅ All picker-based commands work (search, quick switch, backlinks, tags, etc.)
- ✅ Custom keybindings work (create note, insert link/tag)
- ✅ Auto-detection finds snacks if installed
- ✅ Preview functionality works for notes
- ✅ Documentation updated with snacks support
- ✅ No regressions to existing pickers

---

## Summary

The implementation is **straightforward** thanks to obsidian.nvim's well-designed picker abstraction. The main work involves:

1. Creating `_snacks.lua` (~250 lines) that implements three methods and maps actions
2. Minor updates to registry, config, and docs (~100 lines total)
3. Optional testing (~150 lines)

The plugin will then support **four picker options**: telescope, fzf-lua, snacks, and mini.pick, giving users maximum flexibility.

---

## References

- [GitHub - folke/snacks.nvim](https://github.com/folke/snacks.nvim)
- [snacks.nvim picker documentation](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md)
- Existing picker implementations in `lua/obsidian/pickers/`
