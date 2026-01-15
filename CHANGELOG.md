# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2026-01-15

### Added
- **Custom Node Allocator**: `RBTree#initialize` now accepts a `node_allocator:` keyword argument, allowing customization of the node pooling strategy.
- **AutoShrinkNodePool**: Introduced `RBTree::AutoShrinkNodePool` as the default allocator. It automatically releases memory back to the GC when the pool size exceeds the fluctuation range of recent active node counts, preventing memory bloat in long-running processes with variable loads.
- **Explicit Overwrite**: `overwrite: true` is now the explicit default for `initialize` and `insert`.

## [0.3.1] - 2026-01-15

### Added
- **`to_h`**: Added `to_h` method to `RBTree` and `MultiRBTree` for efficient conversion to Hash.
- **`merge!`**: Added `merge!` method to `RBTree` and `MultiRBTree`.
  - `RBTree#merge!`: Supports `overwrite` option (default: `true`). Raises `ArgumentError` if merging a `MultiRBTree` (incompatible value structures).
  - `MultiRBTree#merge!`: Always appends values from the source.

## [0.3.0] - 2026-01-15

### API Changes (Method Renaming & Deprecation)
> [!WARNING]
> The public API has been refactored to improve consistency. The following methods have been renamed.
> Old methods are preserved as aliases for backward compatibility but are **deprecated** and may be removed in future versions.

*   `get_all` -> `values` (Returns Enumerator by default)
*   `delete_one` -> `delete_value`
*   `delete` (MultiRBTree) -> `delete_key`
    *   *Note: `delete` is now an alias for `delete_key` in MultiRBTree for compatibility.*
*   `get` (MultiRBTree) -> *Behavior clarified*: Returns first value (alias for `first_value` or `value(key)`)
*   `get_first`/`get_last` -> `first_value`/`last_value`
*   `delete_first`/`delete_last` -> `delete_first_value`/`delete_last_value`

- **Visibility**: `insert_entry` (RBTree) and traversal helper methods (MultiRBTree) are now `private` instead of `protected`, as they are internal implementation details.

### Fixed
- **MultiRBTree Traversal Fix**: Fixed an issue where `MultiRBTree#each` and other traversal methods yielded `key, value` as separate arguments instead of a single `[key, value]` array. This ensures compatibility with `Enumerable` methods like `count` and consistent behavior with `RBTree` and standard `Hash`.

## [0.2.3] - 2026-01-14

### Added
- **Bulk Insert**: `insert` now supports bulk insertion from Hash, Array of pairs, Enumerator, or Block.
  - `tree.insert({1 => 'one', 2 => 'two'})`
  - `tree.insert([[1, 'one'], [2, 'two']])`
  - `tree.insert { source_data }`
- **Flexible Initialization**: `RBTree.new` and `MultiRBTree.new` now accept bulk data and an `overwrite:` option.
  - `RBTree.new([[1, 'a'], [1, 'b']], overwrite: false)`

## [0.2.2] - 2026-01-14

### Changed
- **Iterative Traversal (Complete)**: All traversal methods (`lt`, `lte`, `gt`, `gte`, `between` and their `_desc` variants) now use an iterative stack-based approach instead of recursion.
  - Ensures deep trees can be traversed without `SystemStackError`.
  - Applies to both `RBTree` and `MultiRBTree`.
- **Code Deduplication**: Unified traversal logic between `RBTree` and `MultiRBTree` for better maintainability.
- **Documentation**: Minor typo fixes.

### Fixed
- **MultiRBTree#prev / #succ**: Fixed incorrect use of bare `super` which forwarded keyword arguments to parent methods that don't accept them. Also fixed incorrect access to parent return value (was treating `[key, value]` pair as a node object).
- **MultiRBTree#shift / #pop hash index leak**: When `shift` or `pop` removed the last value for a key, the key remained in the internal hash index (`@hash_index`). Now correctly uses `delete_node(key)` instead of `remove_node(node)` to ensure hash index consistency.

## [0.2.1] - 2026-01-14

### Added
- **Enhanced iteration**: `each` now accepts `reverse:` and `safe:` options
  - `tree.each(reverse: true) { ... }` (same as `reverse_each`)
  - `tree.each(safe: true) { ... }` (modification-safe)
  - `tree.each(reverse: true, safe: true) { ... }` (reverse modification-safe)
  - In `MultiRBTree`, `reverse: true` also iterates over values in reverse insertion order.
- **Range query safe mode**: `safe:` option for `lt`, `lte`, `gt`, `gte`, `between`
  - `tree.lt(10, safe: true) { |k, _| tree.delete(k) if k.even? }`
  - Works with `:reverse` option: `tree.gt(5, reverse: true, safe: true)`
  - Returns Enumerator: `tree.between(1, 100, safe: true).select { ... }`

### Changed
- **MultiRBTree#get_all**: Now returns an `Enumerator` instead of an `Array` when no block is given.
  - Improves consistency with other iteration methods.
  - Safe handling for non-existent keys (returns empty Enumerator/nil logic handled safely).
  - Use `.to_a` to get an Array: `tree.get_all(key).to_a`

## [0.2.0] - 2026-01-14

### Added
- **MultiRBTree**: `nearest(key, last: false)` option to choose first or last value

## [0.1.8] - 2026-01-14

### Changed
- **Range Query Returns Enumerator**: `lt`, `lte`, `gt`, `gte`, `between` now return an `Enumerator` instead of an `Array` when no block is given
  - Enables lazy evaluation: `tree.gt(100).lazy.take(5).to_a`
  - Enables chaining: `tree.lt(50).map { |k, v| k }`
  - Use `.to_a` to get an Array: `tree.lt(50).to_a`
  - **Breaking**: Code using direct array access like `tree.lt(50)[0]` must change to `tree.lt(50).first`

## [0.1.7] - 2026-01-14

### Added
- **Predecessor/Successor Search**: New `prev(key)` and `succ(key)` methods
  - Returns the key-value pair immediately before/after the given key
  - Works even if the key doesn't exist in the tree (returns nearest neighbor)
  - Uses hash index for O(1) existence check, then O(log n) tree traversal
- **Reverse Range Queries**: All range query methods now support `:reverse` option
  - `lt(key, reverse: true)`, `lte`, `gt`, `gte`, `between` 
  - Returns results in descending order instead of ascending
- **MultiRBTree Enhancements**:
  - `get(key, last: false)` - Choose first or last value from array
  - `get_first(key)`, `get_last(key)` - Convenient aliases
  - `delete_one(key, last: false)` - Choose which end to delete from
  - `delete_first(key)`, `delete_last(key)` - Convenient aliases
  - `min(last: false)`, `max(last: false)` - Choose first or last value
  - `prev(key, last: false)`, `succ(key, last: false)` - Choose first or last value

### Changed
- **MultiRBTree Iteration**: Reverse iteration (`reverse_each`, `lt(..., reverse: true)`, etc.) now iterates each key's value array in reverse order (last to first), making it a true mirror of forward iteration

### Fixed
- **MultiRBTree size tracking**: Fixed bug where `insert` did not increment size when key already existed in hash index

## [0.1.6] - 2026-01-13

### Changed
- **Performance**: Standardized on Boolean colors (`true`/`false`) instead of Symbols (`:red`/`:black`) for faster checks.
- **Optimization**: `insert` operations now check the internal hash index first, allowing O(1) updates for existing keys (RBTree) and O(1) appends (MultiRBTree).

## [0.1.5] - 2026-01-13

### Changed
- **Iterative Traversal**: Replaced recursive tree traversal with iterative approach
  - `each`, `reverse_each`, and other traversal methods now use an explicit stack
  - Prevents `SystemStackError` (stack overflow) on extremely deep trees
  - Slightly improves iteration performance by removing recursion overhead
  - Applies to both `RBTree` and `MultiRBTree`

## [0.1.4] - 2026-01-13

### Changed
- **Memory Pool**: Implemented internal node recycling mechanism
  - Reuse `RBTree::Node` objects instead of creating new ones for every insertion
  - Significantly reduces GC pressure during frequent insert/delete operations
  - Automatically manages pool size (grows on delete, shrinks on insert)
  - Fully transparent to the user

## [0.1.3] - 2026-01-13

### Changed
- **Hybrid Hash Index**: Added internal `@hash_index` for O(1) key lookup
  - `get(key)` and `has_key?(key)` now use hash lookup instead of tree traversal
  - Search performance now matches Hash (within 10-20% overhead)
  - Benchmark: 10M elements, 1M lookups - RBTree 290ms vs Hash 271ms
  - Both RBTree and MultiRBTree benefit from this optimization
  - Memory trade-off: ~1.5x due to hash index storage

## [0.1.2] - 2026-01-13

### Changed
- **Replaced `RBTree::LinkedList` with Ruby Array** in MultiRBTree
  - 6-8x performance improvement for all operations (shift, pop, append)
  - Removed `RBTree::LinkedList` and `RBTree::LinkedList::Node` classes
  - `get_all` now returns Array instead of LinkedList
  - Benchmark results: 100K shift operations 452ms → 69ms

## [0.1.1] - 2026-01-13

### Fixed
- Fixed syntax error in `RBTree::LinkedList.[]` method (escaped newline issue)

## [0.1.0] - 2026-01-13

### Added
- Initial release of rbtree-ruby gem
- `RBTree` class: Pure Ruby Red-Black Tree implementation
  - **Core operations**: `insert`, `delete`, `get` (aliased as `[]`/`[]=`) - O(log n)
  - **Query methods**: `has_key?`, `empty?`, `size`, `min`, `max`
  - **Iteration**: `each`, `reverse_each` with Enumerable support (`first`, `last`, `to_a`, etc.)
  - **Stack operations**: `shift` (remove min), `pop` (remove max)
  - **Range queries**: `lt`, `lte`, `gt`, `gte`, `between` - all support block iteration
  - **Nearest search**: `nearest(key)` for finding closest numeric key
  - **Utility**: `clear`, `inspect`, `valid?` (tree property validation)
- `MultiRBTree` class: Red-Black Tree with multi-value support
  - **Extends RBTree**: Inherits all range query and iteration methods
  - **Multi-value storage**: Each key maps to a `RBTree::LinkedList` of values
  - **Value retrieval**: `get` (first value), `get_all` (all values as LinkedList)
  - **Flexible deletion**: `delete_one` (removes first value), `delete` (removes all values)
  - **Order preservation**: Values maintain insertion order per key
  - **Accurate sizing**: `size` reflects total key-value pairs, not unique keys
- `RBTree::LinkedList` class: Internal doubly-linked list for MultiRBTree
  - Supports `<<`, `shift`, `pop`, `first`, `last`, `empty?`, `each`, `reverse_each`
  - Maintains insertion order with O(1) operations at both ends
- Comprehensive RDoc documentation
  - All 4 classes fully documented (RBTree, MultiRBTree, Node, LinkedList)
  - 80%+ documentation coverage with type annotations
  - Method signatures with `@param`, `@return`, `@yield` tags
  - Practical usage examples for all public methods
  - ASCII diagrams for tree rotation operations
- MIT License (Copyright © 2026 Masahito Suzuki)

[0.3.2]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.3.2
[0.3.1]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.3.1
[0.3.0]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.3.0
[0.2.3]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.2.3
[0.2.2]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.2.2
[0.2.1]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.2.1
[0.2.0]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.2.0
[0.1.8]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.1.8
[0.1.7]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.1.7
[0.1.6]: https://github.com/firelzrd/rbtree-ruby/releases/tag/v0.1.6
