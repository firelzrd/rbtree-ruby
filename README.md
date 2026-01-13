# rbtree-ruby

🌍 *[English](README.md) | [日本語](README.ja.md)*

A pure Ruby implementation of the Red-Black Tree data structure, providing efficient ordered key-value storage with O(log n) time complexity for insertion, deletion, and lookup operations.

## Features

- **Self-Balancing Binary Search Tree**: Maintains optimal performance through red-black tree properties
- **Ordered Operations**: Efficient range queries, min/max retrieval, and sorted iteration
- **Multi-Value Support**: `MultiRBTree` class for storing multiple values per key
- **Pure Ruby**: No C extensions required, works on any Ruby implementation
- **Well-Documented**: Comprehensive RDoc documentation with examples

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rbtree-ruby'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install rbtree-ruby
```

## Usage

### Basic RBTree

```ruby
require 'rbtree'

# Create an empty tree
tree = RBTree.new

# Or initialize with data
tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
tree = RBTree[[5, 'five'], [4, 'four']]

# Insert and retrieve values
tree.insert(10, 'ten')
tree[20] = 'twenty'
puts tree[10]  # => "ten"

# Iterate in sorted order
tree.each { |key, value| puts "#{key}: #{value}" }
# Output:
# 1: one
# 2: two
# 3: three
# 10: ten
# 20: twenty

# Min and max
tree.min  # => [1, "one"]
tree.max  # => [20, "twenty"]

# Range queries (return Enumerator, use .to_a for Array)
tree.lt(10).to_a   # => [[1, "one"], [2, "two"], [3, "three"]]
tree.gte(10).to_a  # => [[10, "ten"], [20, "twenty"]]
tree.between(2, 10).to_a  # => [[2, "two"], [3, "three"], [10, "ten"]]

# Shift and pop
tree.shift  # => [1, "one"] (removes minimum)
tree.pop    # => [20, "twenty"] (removes maximum)

# Delete
tree.delete(3)  # => "three"

# Check membership
tree.has_key?(2)  # => true
tree.size         # => 2
```

### MultiRBTree with Duplicate Keys

```ruby
require 'rbtree'

tree = MultiRBTree.new

# Insert multiple values for the same key
tree.insert(1, 'first one')
tree.insert(1, 'second one')
tree.insert(1, 'third one')
tree.insert(2, 'two')

tree.size  # => 4 (total number of key-value pairs)

# Get first value
tree.get(1)      # => "first one"
tree[1]          # => "first one"

# Get all values for a key
tree.get_all(1)  # => ["first one", "second one", "third one"]

# Iterate over all key-value pairs
tree.each { |k, v| puts "#{k}: #{v}" }
# Output:
# 1: first one
# 1: second one
# 1: third one
# 2: two

# Delete only first value
tree.delete_one(1)  # => "first one"
tree.get(1)         # => "second one"

# Delete all values for a key
tree.delete(1)      # removes all remaining values
```

### Nearest Key Search

```ruby
tree = RBTree.new({1 => 'one', 5 => 'five', 10 => 'ten'})

tree.nearest(4)   # => [5, "five"]  (closest key to 4)
tree.nearest(7)   # => [5, "five"]  (same distance, returns smaller key)
tree.nearest(8)   # => [10, "ten"]
```

### Predecessor/Successor Search

Find the next or previous key in the tree:

```ruby
tree = RBTree.new({1 => 'one', 3 => 'three', 5 => 'five', 7 => 'seven'})

tree.prev(5)   # => [3, "three"]  (largest key < 5)
tree.succ(5)   # => [7, "seven"]  (smallest key > 5)

# Works even if the key doesn't exist
tree.prev(4)   # => [3, "three"]  (4 doesn't exist, returns largest key < 4)
tree.succ(4)   # => [5, "five"]   (4 doesn't exist, returns smallest key > 4)

# Returns nil at boundaries
tree.prev(1)   # => nil (no key smaller than 1)
tree.succ(7)   # => nil (no key larger than 7)
```

### Reverse Range Queries

All range queries return an `Enumerator` (use `.to_a` for Array) and support a `:reverse` option:

```ruby
tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})

tree.lt(3).to_a                    # => [[1, "one"], [2, "two"]]
tree.lt(3, reverse: true).to_a     # => [[2, "two"], [1, "one"]]
tree.lt(3).first                   # => [1, "one"] (lazy, no array created)

# Lazy evaluation
tree.gt(0).lazy.take(2).to_a  # => [[1, "one"], [2, "two"]] (only computes first 2)
```

### MultiRBTree Value Array Access

For keys with multiple values, choose which value to access:

```ruby
tree = MultiRBTree.new
tree.insert(1, 'first')
tree.insert(1, 'second')
tree.insert(1, 'third')

# Access first or last value
tree.get(1)               # => "first"
tree.get(1, last: true)   # => "third"
tree.get_first(1)         # => "first"
tree.get_last(1)          # => "third"

# Delete from either end
tree.delete_first(1)      # => "first"
tree.delete_last(1)       # => "third"  
tree.get(1)               # => "second"

# min/max with :last option
tree.insert(2, 'a')
tree.insert(2, 'b')
tree.min                  # => [1, "second"] (first value of min key)
tree.max(last: true)      # => [2, "b"]      (last value of max key)
```

## Performance

All major operations run in **O(log n)** time:

- `insert(key, value)` - O(log n)
- `delete(key)` - O(log n)
- `get(key)` / `[]` - **O(1)** (hybrid hash index)
- `has_key?` - **O(1)** (hybrid hash index)
- `min` - **O(1)**
- `max` - O(log n)
- `shift` / `pop` - O(log n)
- `prev` / `succ` - O(log n) with O(1) hash check

Iteration over all elements takes O(n) time.

### Memory Efficiency

RBTree uses an internal **Memory Pool** to recycle node objects. 
- Significantly reduces Garbage Collection (GC) pressure during frequent insertions and deletions (e.g., in high-throughput queues).
- In benchmarks with 100,000 cyclic operations, **GC time was 0.0s** compared to significant pauses without pooling.

### RBTree vs Hash vs Array (Overwhelming Power)

For ordered and spatial operations, RBTree is not just faster—it is in a completely different class. The following benchmarks were conducted with **500,000 items**:

| Operation | RBTree | Hash/Array | Speedup | Why? |
|-----------|--------|------------|---------|------|
| **Nearest Key Search** | **O(log n)** | O(n) scan | **~8,600x faster** | Spatial binary search vs full scan |
| **Range Queries** | **O(log n + k)** | O(n) filter | **~540x faster** | Direct subtree jump vs full scan |
| **Min Extraction** | **O(log n)** | O(n) search | **~160x faster** | Continuous rebalancing vs full scan |
| **Sorted Iteration** | **O(n)** | O(n log n) | **FREE** | Always sorted vs explicit `sort` |
| **Key Lookup** | **O(1)** | O(1) | **Equal** | Optimized Hybrid Hash Index |

### When to Use RBTree

✅ **Use RBTree when you need:**
- Ordered iteration by key
- Fast min/max retrieval  
- Range queries (`between`, `lt`, `gt`, `lte`, `gte`)
- Nearest key search
- Priority queue behavior (shift/pop by key order)

✅ **Use Hash when you only need:**
- Fast key-value lookup (RBTree is now equally fast!)
- No ordering requirements

Run `ruby demo.rb` for a full benchmark demonstration.

## API Documentation

Full RDoc documentation is available. Generate it locally with:

```bash
rdoc lib/rbtree.rb
```

Then open `doc/index.html` in your browser.

## Development

After checking out the repo, run `bundle install` to install dependencies.can then run:

```bash
# Generate RDoc documentation
rake rdoc

# Build the gem
rake build

# Install locally
rake install
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/firelzrd/rbtree-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Author

Masahito Suzuki (firelzrd@gmail.com)

Copyright © 2026 Masahito Suzuki
