# frozen_string_literal: true

require_relative "rbtree/version"

# A Red-Black Tree implementation providing efficient ordered key-value storage.
#
# RBTree is a self-balancing binary search tree that maintains sorted order of keys
# and provides O(log n) time complexity for insertion, deletion, and lookup operations.
# The tree enforces the following red-black properties to maintain balance:
#
# 1. Every node is either red or black
# 2. The root is always black
# 3. All leaves (nil nodes) are black
# 4. Red nodes cannot have red children
# 5. All paths from root to leaves contain the same number of black nodes
#
# == Features
#
# * Ordered iteration over key-value pairs
# * Range queries (less than, greater than, between)
# * Efficient min/max retrieval
# * Nearest key search for numeric keys
# * Tree integrity validation
#
# == Usage
#
#   # Create an empty tree
#   tree = RBTree.new
#
#   # Create from a hash
#   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
#
#   # Create from an array of key-value pairs
#   tree = RBTree.new([[3, 'three'], [1, 'one'], [2, 'two']])
#
#   # Create using bracket notation
#   tree = RBTree[3 => 'three', 1 => 'one', 2 => 'two']
#
#   # Insert and retrieve values
#   tree.insert(5, 'five')
#   tree[4] = 'four'
#   puts tree[4]  # => "four"
#
#   # Iterate in sorted order
#   tree.each { |key, value| puts "#{key}: #{value}" }
#
# == Performance
#
# All major operations (insert, delete, search) run in O(log n) time.
# Iteration over all elements takes O(n) time.
#
# @author Masahito Suzuki
# @since 0.1.0
class RBTree
  include Enumerable

  # Returns the number of key-value pairs stored in the tree.
  # @return [Integer] the number of entries in the tree
  attr_reader :key_count

  # Creates a new RBTree from the given arguments.
  #
  # This is a convenience method equivalent to RBTree.new(*args).
  #
  # @param args [Hash, Array] optional initial data
  # @return [RBTree] a new RBTree instance
  # @example
  #   tree = RBTree[1 => 'one', 2 => 'two', 3 => 'three']
  def self.[](*args)
    new(*args)
  end

  # Initializes a new RBTree.
  #
  # The tree can be initialized empty or populated with initial data from a Hash, Array, or Enumerator.
  # A block can also be provided to supply the initial data.
  #
  # @param args [Hash, Array, nil] optional initial data
  # @param overwrite [Boolean] whether to overwrite existing keys (default: true)
  # @param node_allocator [NodeAllocator] allocator instance to use (default: AutoShrinkNodePool.new)
  # @yieldreturn [Object] optional initial data
  #   - If a Hash is provided, each key-value pair is inserted into the tree
  #   - If an Array is provided, it should contain [key, value] pairs
  #   - If a block is provided, it is yielded to get the source data
  #   - If no arguments are provided, an empty tree is created
  # @raise [ArgumentError] if arguments are invalid
  # @example Create an empty tree
  #   tree = RBTree.new
  # @example Create from a hash
  #   tree = RBTree.new({1 => 'one', 2 => 'two'})
  # @example Create from an array
  #   tree = RBTree.new([[1, 'one'], [2, 'two']])
  # @example Create with overwrite: false
  #   tree = RBTree.new([[1, 'one'], [1, 'uno']], overwrite: false)
  def initialize(*args, overwrite: true, node_allocator: AutoShrinkNodePool.new, &block)
    @nil_node = Node.new
    @nil_node.color = Node::BLACK
    @nil_node.left = @nil_node
    @nil_node.right = @nil_node
    @root = @nil_node
    @min_node = @nil_node
    @max_node = @nil_node
    @hash_index = {}  # Hash index for O(1) key lookup
    @node_allocator = node_allocator
    @key_count = 0

    @overwrite = overwrite

    if args.size > 0 || block_given?
      insert(*args, overwrite: overwrite, &block)
    end
  end

  # Creates a deep copy of the tree.
  # Called automatically by `dup` and `clone`.
  #
  # @param orig [RBTree] the original tree to copy
  # @return [void]
  def initialize_copy(orig)
    initialize(overwrite: orig.instance_variable_get(:@overwrite))
    orig.each { |k, v| insert(k, v) }
  end

  # Returns a Hash containing all key-value pairs from the tree.
  #
  # @return [Hash] a new Hash with the tree's contents
  def to_h = @hash_index.transform_values(&:value)

  # Checks if the tree is empty.
  #
  # @return [Boolean] true if the tree contains no elements, false otherwise
  def empty? = @hash_index.empty?

  # Returns the number of key-value pairs stored in the tree.
  # @return [Integer] the number of entries in the tree
  def size = @key_count
  alias :value_count :size

  # Returns the minimum key without removing it.
  #
  # @return [Object, nil] the minimum key, or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.min_key  # => 1
  def min_key = min_node&.key

  # Returns the minimum key-value pair without removing it.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.min  # => [1, "one"]
  def min = min_node&.pair

  # Returns the maximum key without removing it.
  #
  # @return [Object, nil] the maximum key, or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.max_key  # => 3
  def max_key = max_node&.key

  # Returns the maximum key-value pair without removing it.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.max  # => [3, "three"]
  def max = max_node&.pair

  # Returns the first key-value pair without removing it.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.first  # => [1, "one"]
  def first = min

  # Returns the last key-value pair without removing it.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.last  # => [3, "three"]
  def last = max

  # Checks if the tree contains the given key.
  #
  # @param key [Object] the key to search for
  # @return [Boolean] true if the key exists in the tree, false otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two'})
  #   tree.key?(1)  # => true
  #   tree.key?(3)  # => false
  def has_key?(key) = @hash_index.key?(key)
  alias :key? :has_key?

  # Retrieves the value associated with the given key.
  #
  # @param key [Object] the key to look up
  # @return [Object, nil] the associated value, or nil if the key is not found
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two'})
  #   tree.get(1)  # => "one"
  def value(key) = @hash_index[key]&.value
  alias :get :value

  # Retrieves a value associated with the given key, or a range of entries if a Range is provided.
  #
  # @param key_or_range [Object, Range] the key to look up or a Range for query
  # @param ... [Hash] additional options to pass to the respective lookup method
  # @return [Object, Enumerator, nil]
  #   - If a key is provided: the associated value, or nil if not found
  #   - If a Range is provided: an Enumerator yielding [key, value] pairs
  # @example Single key lookup
  #   tree[2]      # => "two"
  # @example Range lookup
  #   tree[2..4].to_a  # => [[2, "two"], [3, "three"], [4, "four"]]
  #   tree[...3].to_a  # => [[1, "one"], [2, "two"]]
  def [](key_or_range, **)
    return value(key_or_range, **) if !key_or_range.is_a?(Range)

    r = key_or_range
    r.begin ? (
      r.end ?
        between(r.begin, r.end, include_max: !r.exclude_end?, **) :
        gte(r.begin, **)
    ) : (
      r.end ?
        (r.exclude_end? ? lt(r.end, **) : lte(r.end, **)) :
        each(**)
    )
  end

  # Returns the key with the key closest to the given key.
  #
  # This method requires keys to be numeric or support subtraction and abs methods.
  #
  # @param key [Numeric] the target key
  # @return [Object, nil] the key, or nil if tree is empty
  # @example
  #   tree = RBTree.new({1 => 'one', 5 => 'five', 10 => 'ten'})
  #   tree.nearest_key(4)   # => 5
  #   tree.nearest_key(7)   # => 5
  #   tree.nearest_key(8)   # => 10
  def nearest_key(key) = ((n = find_nearest_node(key)) == @nil_node)? nil : n.key

  # Returns the key-value pair with the key closest to the given key.
  #
  # This method requires keys to be numeric or support subtraction and abs methods.
  # If multiple keys have the same distance, the one with the smaller key is returned.
  #
  # @param key [Numeric] the target key
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({1 => 'one', 5 => 'five', 10 => 'ten'})
  #   tree.nearest(4)   # => [5, "five"]
  #   tree.nearest(7)   # => [5, "five"]
  #   tree.nearest(8)   # => [10, "ten"]
  def nearest(key) = ((n = find_nearest_node(key)) == @nil_node)? nil : n.pair

  # Returns the key with the largest key that is smaller than the given key.
  #
  # If the key exists in the tree, returns the predecessor (previous element).
  # If the key does not exist, returns the largest key with key < given key.
  #
  # @param key [Object] the reference key
  # @return [Object, nil] the key, or nil if no predecessor exists
  # @example
  #   tree = RBTree.new({1 => 'one', 3 => 'three', 5 => 'five', 7 => 'seven'})
  #   tree.prev_key(5)   # => 3
  #   tree.prev_key(4)   # => 3 (4 does not exist)
  #   tree.prev_key(1)   # => nil (no predecessor)
  def prev_key(key) = ((n = find_predecessor_node(key)) == @nil_node)? nil : n.key

  # Returns the key-value pair with the largest key that is smaller than the given key.
  #
  # If the key exists in the tree, returns the predecessor (previous element).
  # If the key does not exist, returns the largest key-value pair with key < given key.
  #
  # @param key [Object] the reference key
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if no predecessor exists
  # @example
  #   tree = RBTree.new({1 => 'one', 3 => 'three', 5 => 'five', 7 => 'seven'})
  #   tree.prev(5)   # => [3, "three"]
  #   tree.prev(4)   # => [3, "three"] (4 does not exist)
  #   tree.prev(1)   # => nil (no predecessor)
  def prev(key) = ((n = find_predecessor_node(key)) == @nil_node)? nil : n.pair

  # Returns the key with the smallest key that is larger than the given key.
  #
  # If the key exists in the tree, returns the successor (next element).
  # If the key does not exist, returns the smallest key with key > given key.
  #
  # @param key [Object] the reference key
  # @return [Object, nil] the key, or nil if no successor exists
  # @example
  #   tree = RBTree.new({1 => 'one', 3 => 'three', 5 => 'five', 7 => 'seven'})
  #   tree.succ_key(5)   # => 7
  #   tree.succ_key(4)   # => 5 (4 does not exist)
  #   tree.succ_key(1)   # => 3 (1 does not exist)
  def succ_key(key) = ((n = find_successor_node(key)) == @nil_node)? nil : n.key

  # Returns the key-value pair with the smallest key that is larger than the given key.
  #
  # If the key exists in the tree, returns the successor (next element).
  # If the key does not exist, returns the smallest key-value pair with key > given key.
  #
  # @param key [Object] the reference key
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if no successor exists
  # @example
  #   tree = RBTree.new({1 => 'one', 3 => 'three', 5 => 'five', 7 => 'seven'})
  #   tree.succ(5)   # => [7, "seven"]
  #   tree.succ(4)   # => [5, "five"] (4 does not exist)
  #   tree.succ(7)   # => nil (no successor)
  def succ(key) = ((n = find_successor_node(key)) == @nil_node)? nil : n.pair

  # Inserts one or more key-value pairs into the tree.
  #
  # This method supports both single entry insertion and bulk insertion.
  #
  # Single insertion:
  #   insert(key, value, overwrite: true)
  #
  # Bulk insertion:
  #   insert(hash, overwrite: true)
  #   insert(array_of_pairs, overwrite: true)
  #   insert(enumerator, overwrite: true)
  #   insert { data_source }
  #
  # If the key already exists and overwrite is true (default), the value is updated.
  # If overwrite is false and the key exists, the operation returns nil without modification.
  #
  # @param args [Object] key (and value) or source object
  # @param overwrite [Boolean] whether to overwrite existing keys (default: true)
  # @yieldreturn [Object] data source for bulk insertion
  # @return [Boolean, nil] true if inserted/updated, nil if key exists and overwrite is false (for single insert)
  # @example Single insert
  #   tree.insert(1, 'one')
  # @example Bulk insert from Hash
  #   tree.insert({1 => 'one', 2 => 'two'})
  # @example Bulk insert from Array
  #   tree.insert([[1, 'one'], [2, 'two']])
  def insert(*args, overwrite: @overwrite, &block)
    if args.size == 2
      key, value = args
      insert_entry(key, value, overwrite: overwrite)
    else
      source = nil
      if args.empty? && block_given?
        source = yield
      elsif args.size == 1
        source = args[0]
      elsif args.empty?
        return # No-op
      else
        raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0..2)"
      end

      return if source.nil?

      unless source.respond_to?(:each)
        raise ArgumentError, "Source must be iterable"
      end

      source.each do |*pair|
        key, value = nil, nil
        if pair.size == 1 && pair[0].is_a?(Array)
          key, value = pair[0]
          raise ArgumentError, "Invalid pair size: #{pair[0].size} (expected 2)" unless pair[0].size == 2
        elsif pair.size == 2
          key, value = pair
        else
          raise ArgumentError, "Invalid pair format: #{pair.inspect}"
        end
        insert_entry(key, value, overwrite: overwrite)
      end
    end
  end
  alias :[]= :insert
  
  # Returns a new tree containing the merged contents of self and other.
  #
  # When a block is given, it is called with (key, old_value, new_value) for
  # duplicate keys, and the block's return value is used.
  #
  # @param other [RBTree, Hash, Enumerable] the source to merge from
  # @yield [key, old_value, new_value] called for duplicate keys when block given
  # @return [RBTree] a new tree with merged contents
  def merge(other, &block)
    dup.merge!(other, &block)
  end

  # Merges the contents of another tree, hash, or enumerable into this tree.
  #
  # When a block is given, it is called with (key, old_value, new_value) for
  # duplicate keys, and the block's return value is used.
  #
  # @param other [RBTree, Hash, Enumerable] the source to merge from
  # @param overwrite [Boolean] whether to overwrite existing keys (default: true). Ignored if block given.
  # @yield [key, old_value, new_value] called for duplicate keys when block given
  # @return [RBTree] self
  def merge!(other, overwrite: true, &block)
    if defined?(MultiRBTree) && other.is_a?(MultiRBTree)
      raise ArgumentError, "Cannot merge MultiRBTree into RBTree"
    end
    if block
      other_enum = other.is_a?(Hash) || other.is_a?(RBTree) ? other : other.each
      other_enum.each do |k, v|
        if has_key?(k)
          insert_entry(k, block.call(k, value(k), v), overwrite: true)
        else
          insert_entry(k, v)
        end
      end
    else
      insert(other, overwrite: overwrite)
    end
    self
  end

  # Deletes the key-value pair with the specified key.
  #
  # @param key [Object] the key to delete
  # @return [Object, nil] the value associated with the deleted key, or nil if not found
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two'})
  #   tree.delete(1)  # => "one"
  #   tree.delete(3)  # => nil
  def delete_key(key)
    return nil unless (value = (z = @hash_index[key])&.value)
    delete_indexed_node(key)
    value
  end
  alias :delete :delete_key

  # Removes and returns the minimum key-value pair.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.shift  # => [1, "one"]
  #   tree.shift  # => [2, "two"]
  def shift
    return nil unless (n = @min_node) != @nil_node
    pair = n.pair
    delete(n.key)
    pair
  end

  # Removes and returns the maximum key-value pair.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.pop  # => [3, "three"]
  #   tree.pop  # => [2, "two"]
  def pop
    return nil unless (n = @max_node) != @nil_node
    pair = n.pair
    delete(n.key)
    pair
  end

  # Removes all key-value pairs from the tree.
  #
  # @return [RBTree] self
  def clear
    @root = @min_node = @max_node = @nil_node
    @hash_index.clear
    @key_count = 0
    self
  end

  # Iterates over all keys in ascending (or descending) order.
  #
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @param safe [Boolean] if true, safe for modifications during iteration (default: false)
  # @yield [key] each key in the tree
  # @return [Enumerator, RBTree] an Enumerator if no block is given, self otherwise
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.keys { |k| puts k }
  #   # Output:
  #   # 1
  #   # 2
  #   # 3
  #
  #   # Reverse iteration
  #   tree.keys(reverse: true) { |k| ... }
  #
  #   # Safe iteration for modifications
  #   tree.keys(safe: true) do |k|
  #     tree.delete(k) if k.even?
  #   end
  def keys(reverse: false, safe: false, &block)
    return enum_for(__method__, reverse: reverse, safe: safe) { @key_count } unless block_given?
    each(reverse: reverse, safe: safe) { |key, _| yield key }
    self
  end

  # Iterates over all key-value pairs in ascending (or descending) order.
  #
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @param safe [Boolean] if true, safe for modifications during iteration (default: false)
  # @yield [key, value] each key-value pair in the tree
  # @return [Enumerator, RBTree] an Enumerator if no block is given, self otherwise
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.each { |k, v| puts "#{k}: #{v}" }
  #   # Output:
  #   # 1: one
  #   # 2: two
  #   # 3: three
  #
  #   # Reverse iteration
  #   tree.each(reverse: true) { |k, v| ... }
  #
  #   # Safe iteration for modifications
  #   tree.each(safe: true) do |k, v|
  #     tree.delete(k) if k.even?
  #   end
  def each(reverse: false, safe: false, &block)
    return enum_for(__method__, reverse: reverse, safe: safe) { size } unless block_given?
    traverse_range(reverse, nil, nil, false, false, safe: safe, &block)
    self
  end

  # Iterates over all key-value pairs in descending order of keys.
  #
  # @yield [key, value] each key-value pair in the tree
  # @return [Enumerator, RBTree] an Enumerator if no block is given, self otherwise
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.reverse_each { |k, v| puts "#{k}: #{v}" }
  #   # Output:
  #   # 3: three
  #   # 2: two
  #   # 1: one
  # Iterates over all key-value pairs in descending order of keys.
  #
  # This is an alias for `each(reverse: true)`.
  #
  # @param safe [Boolean] if true, safe for modifications during iteration (default: false)
  # @yield [key, value] each key-value pair in the tree
  # @return [Enumerator, RBTree] an Enumerator if no block is given, self otherwise
  # @see #each
  def reverse_each(safe: false, &block)
    return enum_for(__method__, safe: safe) { size } unless block_given?
    each(reverse: true, safe: safe, &block)
  end

  # Retrieves all key-value pairs with keys less than the specified key.
  #
  # @param key [Object] the upper bound (exclusive)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @param safe [Boolean] if true, safe for modifications during iteration (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})
  #   tree.lt(3).to_a  # => [[1, "one"], [2, "two"]]
  #   tree.lt(3, reverse: true).first  # => [2, "two"]
  #   tree.lt(3, safe: true) { |k, _| tree.delete(k) if k.even? }  # safe to delete
  def lt(key, reverse: false, safe: false, &block)
    return enum_for(__method__, key, reverse: reverse, safe: safe) unless block_given?
    traverse_range(reverse, nil, key, false, false, safe: safe, &block)
    self
  end

  # Retrieves all key-value pairs with keys less than or equal to the specified key.
  #
  # @param key [Object] the upper bound (inclusive)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @param safe [Boolean] if true, safe for modifications during iteration (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})
  #   tree.lte(3).to_a  # => [[1, "one"], [2, "two"], [3, "three"]]
  #   tree.lte(3, reverse: true).first  # => [3, "three"]
  def lte(key, reverse: false, safe: false, &block)
    return enum_for(__method__, key, reverse: reverse, safe: safe) unless block_given?
    traverse_range(reverse, nil, key, false, true, safe: safe, &block)
    self
  end

  # Retrieves all key-value pairs with keys greater than the specified key.
  #
  # @param key [Object] the lower bound (exclusive)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @param safe [Boolean] if true, safe for modifications during iteration (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})
  #   tree.gt(2).to_a  # => [[3, "three"], [4, "four"]]
  #   tree.gt(2, reverse: true).first  # => [4, "four"]
  def gt(key, reverse: false, safe: false, &block)
    return enum_for(__method__, key, reverse: reverse, safe: safe) unless block_given?
    traverse_range(reverse, key, nil, false, false, safe: safe, &block)
    self
  end

  # Retrieves all key-value pairs with keys greater than or equal to the specified key.
  #
  # @param key [Object] the lower bound (inclusive)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @param safe [Boolean] if true, safe for modifications during iteration (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})
  #   tree.gte(2).to_a  # => [[2, "two"], [3, "three"], [4, "four"]]
  #   tree.gte(2, reverse: true).first  # => [4, "four"]
  def gte(key, reverse: false, safe: false, &block)
    return enum_for(__method__, key, reverse: reverse, safe: safe) unless block_given?
    traverse_range(reverse, key, nil, true, false, safe: safe, &block)
    self
  end

  # Retrieves all key-value pairs with keys within the specified range.
  #
  # @param min [Object] the lower bound
  # @param max [Object] the upper bound
  # @param include_min [Boolean] whether to include the lower bound (default: true)
  # @param include_max [Boolean] whether to include the upper bound (default: true)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @param safe [Boolean] if true, safe for modifications during iteration (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four', 5 => 'five'})
  #   tree.between(2, 4).to_a  # => [[2, "two"], [3, "three"], [4, "four"]]
  #   tree.between(2, 4, reverse: true).first  # => [4, "four"]
  def between(min, max, include_min: true, include_max: true, reverse: false, safe: false, &block)
    return enum_for(__method__, min, max, include_min: include_min, include_max: include_max, reverse: reverse, safe: safe) unless block_given?
    traverse_range(reverse, min, max, include_min, include_max, safe: safe, &block)
    self
  end

  # Returns a new tree containing key-value pairs for which the block returns true.
  #
  # @yield [key, value] each key-value pair
  # @return [RBTree, Enumerator] a new tree with selected pairs, or Enumerator if no block
  def select(&block)
    return enum_for(__method__) { size } unless block_given?
    result = self.class.new
    each { |k, v| result.insert(k, v) if block.call(k, v) }
    result
  end

  # Returns a new tree containing key-value pairs for which the block returns false.
  #
  # @yield [key, value] each key-value pair
  # @return [RBTree, Enumerator] a new tree with non-rejected pairs, or Enumerator if no block
  def reject(&block)
    return enum_for(__method__) { size } unless block_given?
    result = self.class.new
    each { |k, v| result.insert(k, v) unless block.call(k, v) }
    result
  end

  # Deletes key-value pairs for which the block returns true. Returns nil if no changes were made.
  #
  # @yield [key, value] each key-value pair
  # @return [RBTree, nil, Enumerator] self if changed, nil if unchanged, or Enumerator if no block
  def reject!(&block)
    return enum_for(__method__) { size } unless block_given?
    size_before = size
    delete_if(&block)
    size == size_before ? nil : self
  end

  # Keeps key-value pairs for which the block returns true, deleting the rest. Modifies the tree in place.
  #
  # @yield [key, value] each key-value pair
  # @return [RBTree, Enumerator] self, or Enumerator if no block
  def keep_if(&block)
    return enum_for(__method__) { size } unless block_given?
    each(safe: true) { |k, v| delete(k) unless block.call(k, v) }
    self
  end

  # Deletes key-value pairs for which the block returns true. Modifies the tree in place.
  #
  # @yield [key, value] each key-value pair
  # @return [RBTree, Enumerator] self, or Enumerator if no block
  def delete_if(&block)
    return enum_for(__method__) { size } unless block_given?
    each(safe: true) { |k, v| delete(k) if block.call(k, v) }
    self
  end

  # Returns a new tree with keys and values swapped.
  #
  # For RBTree, duplicate values result in later keys overwriting earlier ones.
  # For MultiRBTree, all key-value pairs are preserved.
  # Values must implement <=> to serve as keys in the new tree.
  #
  # @return [RBTree, MultiRBTree] a new tree with keys and values inverted
  def invert
    result = self.class.new
    each { |k, v| result.insert(v, k) }
    result
  end

  # Returns a string representation of the tree.
  #
  # Shows the first 5 entries and total size. Useful for debugging.
  #
  # @return [String] a human-readable representation of the tree
  def inspect
    content = take(5).map { |k, v| "#{k.inspect}=>#{v.inspect}" }.join(", ")
    suffix = size > 5 ? ", ..." : ""
    "#<#{self.class}:0x#{object_id.to_s(16)} size=#{size} {#{content}#{suffix}}>"
  end

  # Validates the red-black tree properties.
  #
  # Checks that:
  # 1. Root is black
  # 2. All paths from root to leaves have the same number of black nodes
  # 3. No red node has a red child
  # 4. Keys are properly ordered
  #
  # @return [Boolean] true if all properties are satisfied, false otherwise
  def valid?
    return false if @root.color == Node::RED
    return false if check_black_height(@root) == -1
    return false unless check_order(@root)
    true
  end

  # @!visibility private
  private

  def min_node = (@min_node == @nil_node) ? nil : @min_node
  def max_node = (@max_node == @nil_node) ? nil : @max_node

  # Inserts a single key-value pair.
  #
  # @param key [Object] the key to insert
  # @param value [Object] the value to associate with the key
  # @param overwrite [Boolean] whether to overwrite existing keys (default: true)
  # @return [Boolean, nil] true if inserted/updated, nil if key exists and overwrite is false
  def insert_entry(key, value, overwrite: true)
    insert_entry_generic(key) do |node, is_new|
      if is_new
        value
      else
        if overwrite
          node.value = value
          true
        else
          nil
        end
      end
    end
  end

  # Generic entry insertion logic shared between RBTree and MultiRBTree.
  #
  # @param key [Object] the key to insert
  # @yield [node, is_new] yields the existing node (if any) and whether it's a new insertion
  # @yieldparam node [Node, nil] the existing node or nil
  # @yieldparam is_new [Boolean] true if no node with the key exists
  # @yieldreturn [Object]
  #   - if is_new: the initial value for the new node
  #   - if !is_new: the value to return from insert_entry
  def insert_entry_generic(key)
    if (node = @hash_index[key])
      return yield(node, false)
    end

    y = @nil_node
    x = @root
    while x != @nil_node
      y = x
      cmp = key <=> x.key
      if cmp == 0
        return yield(x, false)
      elsif cmp < 0
        x = x.left
      else
        x = x.right
      end
    end

    initial_value = yield(nil, true)

    z = allocate_node(key, initial_value, Node::RED, @nil_node, @nil_node, @nil_node)
    z.parent = y
    if y == @nil_node
      @root = z
    elsif (key <=> y.key) < 0
      y.left = z
    else
      y.right = z
    end
    z.left = @nil_node
    z.right = @nil_node
    z.color = Node::RED
    insert_fixup(z)
    
    if @min_node == @nil_node || (key <=> @min_node.key) < 0
      @min_node = z
    end
    if @max_node == @nil_node || (key <=> @max_node.key) > 0
      @max_node = z
    end
    
    @hash_index[key] = z
    true
  end

  # Traverses the tree in a specified direction (ascending or descending).
  #
  # @param direction [Boolean] true for descending, false for ascending
  # @param min [Object] the lower bound (inclusive)
  # @param max [Object] the upper bound (inclusive)
  # @param include_min [Boolean] whether to include the lower bound
  # @param include_max [Boolean] whether to include the upper bound
  # @param safe [Boolean] whether to use safe traversal
  # @yield [key, value] each key-value pair in the specified direction
  # @return [void]
  def traverse_range(direction, min, max, include_min, include_max, safe: false, &block)
    if direction
      traverse_range_desc(min, max, include_min, include_max, safe: safe, &block)
    else
      traverse_range_asc(min, max, include_min, include_max, safe: safe, &block)
    end
  end

  # Traverses the tree in ascending order (in-order traversal).
  #
  # @param min [Object] the lower bound (inclusive)
  # @param max [Object] the upper bound (inclusive)
  # @param include_min [Boolean] whether to include the lower bound
  # @param include_max [Boolean] whether to include the upper bound
  # @param safe [Boolean] whether to use safe traversal
  # @yield [key, value] each key-value pair in ascending order
  # @return [void]
  def traverse_range_asc(min, max, include_min, include_max, safe: false, &block)
    # O(1) Range Rejection
    return if min && @max_node != @nil_node && (min <=> @max_node.key) > 0
    return if min && @max_node != @nil_node && !include_min && (min <=> @max_node.key) == 0

    # O(1) Bound Optimization
    max = nil if max && @max_node != @nil_node && (cmp = max <=> @max_node.key) >= 0 && (cmp > 0 || include_max)

    if safe
      pair = !min ? find_min :
        include_min && @hash_index[min]&.pair || find_successor(min)
      while pair && (!max || pair[0] < max)
        current_key = pair[0]
        yield pair
        pair = find_successor(current_key)
      end
      yield pair if pair && max && include_max && pair[0] == max
    else
      start_node, stack = resolve_startup_asc(min, include_min)
      traverse_from_asc(start_node, stack, max, include_max, &block)
    end
  end

  # Traverses the tree in descending order (reverse in-order traversal).
  #
  # @param min [Object] the lower bound (inclusive)
  # @param max [Object] the upper bound (inclusive)
  # @param include_min [Boolean] whether to include the lower bound
  # @param include_max [Boolean] whether to include the upper bound
  # @param safe [Boolean] whether to use safe traversal
  # @yield [key, value] each key-value pair in descending order
  # @return [void]
  def traverse_range_desc(min, max, include_min, include_max, safe: false, &block)
    # O(1) Range Rejection
    return if max && @min_node != @nil_node && (max <=> @min_node.key) < 0
    return if max && @min_node != @nil_node && !include_max && (max <=> @min_node.key) == 0

    # O(1) Bound Optimization
    min = nil if min && @min_node != @nil_node && (cmp = min <=> @min_node.key) <= 0 && (cmp < 0 || include_min)

    if safe
      pair = !max ? find_max :
        include_max && @hash_index[max]&.pair || find_predecessor(max)
      while pair && (!min || pair[0] > min)
        current_key = pair[0]
        yield pair
        pair = find_predecessor(current_key)
      end
      yield pair if pair && min && include_min && pair[0] == min
    else
      start_node, stack = resolve_startup_desc(max, include_max)
      traverse_from_desc(start_node, stack, min, include_min, &block)
    end
  end

  private
  
  # Returns the predecessor of the given node.
  #
  # @param node [Node] the node to find the predecessor of
  # @return [Node] the predecessor node
  def predecessor_node_of(node)
    if node.left != @nil_node
      return rightmost(node.left)
    end
    y = node.parent
    while y != @nil_node && node == y.left
      node = y
      y = y.parent
    end
    y
  end

  # Returns the successor of the given node.
  #
  # @param node [Node] the node to find the successor of
  # @return [Node] the successor node
  def successor_node_of(node)
    if node.right != @nil_node
      return leftmost(node.right)
    end
    y = node.parent
    while y != @nil_node && node == y.right
      node = y
      y = y.parent
    end
    y
  end

  # Resolves the startup node for ascending traversal.
  #
  # @param min [Object] the minimum key to traverse from
  # @param include_min [Boolean] whether to include the minimum key
  # @return [Array(Node, Array)] the starting node and stack
  def resolve_startup_asc(min, include_min)
    # 1. Use cached min if no lower bound or if min is less than tree min
    if @min_node != @nil_node && (!min || (min <=> @min_node.key) < 0)
      return [@min_node, reconstruct_stack_asc(@min_node)]
    end
    
    # 2. Use Hash index if key exists
    if min && (node = @hash_index[min])
      start_node = include_min ? node : successor_node_of(node)
      return [start_node, reconstruct_stack_asc(start_node)]
    end

    # 3. Fallback to tree search from root
    stack = []
    current = @root
    while current != @nil_node
      if min && ((current.key <=> min) < 0 || (!include_min && (current.key <=> min) == 0))
        current = current.right
      else
        stack << current
        current = current.left
      end
    end
    [@nil_node, stack]
  end

  # Reconstructs the stack for ascending traversal.
  #
  # @param node [Node] the node to reconstruct the stack from
  # @return [Array] the reconstructed stack
  def reconstruct_stack_asc(node)
    return [] if node == @nil_node
    stack = []
    curr = node
    while (p = curr.parent) != @nil_node
      stack << p if curr == p.left
      curr = p
    end
    stack.reverse!
    stack
  end

  # Traverses the tree in ascending order.
  #
  # @param current [Node] the current node
  # @param stack [Array] the stack of nodes to traverse
  # @param max [Object] the maximum key to traverse to
  # @param include_max [Boolean] whether to include the maximum key
  # @yield [Array(Object, Object)] each key-value pair
  # @yieldparam key [Object] the key
  # @yieldparam val [Object] the value
  def traverse_from_asc(current, stack, max, include_max, &block)
    while current != @nil_node || !stack.empty?
      if current != @nil_node
        if max
          cmp = current.key <=> max
          if cmp >= 0
            yield current.pair if include_max && cmp == 0
            return
          end
        end
        yield current.pair
        current = current.right
        while current != @nil_node
          stack << current
          current = current.left
        end
      else
        current = stack.pop
      end
    end
  end

  # Resolves the startup node for descending traversal.
  #
  # @param max [Object] the maximum key to traverse from
  # @param include_max [Boolean] whether to include the maximum key
  # @return [Array(Node, Array)] the starting node and stack
  def resolve_startup_desc(max, include_max)
    # 1. Use cached max if no upper bound or if max is greater than tree max
    if @max_node != @nil_node && (!max || (max <=> @max_node.key) > 0)
      return [@max_node, reconstruct_stack_desc(@max_node)]
    end
  
    # 2. Use Hash index if key exists
    if max && (node = @hash_index[max])
      start_node = include_max ? node : predecessor_node_of(node)
      return [start_node, reconstruct_stack_desc(start_node)]
    end

    # 3. Fallback to tree search from root
    stack = []
    current = @root
    while current != @nil_node
      if max && ((current.key <=> max) > 0 || (!include_max && (current.key <=> max) == 0))
        current = current.left
      else
        stack << current
        current = current.right
      end
    end
    [@nil_node, stack]
  end

  # Reconstructs the stack for descending traversal.
  #
  # @param node [Node] the node to reconstruct the stack from
  # @return [Array] the reconstructed stack
  def reconstruct_stack_desc(node)
    return [] if node == @nil_node
    stack = []
    curr = node
    while (p = curr.parent) != @nil_node
      stack << p if curr == p.right
      curr = p
    end
    stack.reverse!
    stack
  end

  # Traverses the tree in descending order.
  #
  # @param current [Node] the current node
  # @param stack [Array] the stack of nodes to traverse
  # @param min [Object] the minimum key to traverse to
  # @param include_min [Boolean] whether to include the minimum key
  # @yield [Array(Object, Object)] each key-value pair
  # @yieldparam key [Object] the key
  # @yieldparam val [Object] the value
  def traverse_from_desc(current, stack, min, include_min, &block)
    while current != @nil_node || !stack.empty?
      if current != @nil_node
        if min
          cmp = current.key <=> min
          if cmp <= 0
            yield current.pair if include_min && cmp == 0
            return
          end
        end
        yield current.pair
        current = current.left
        while current != @nil_node
          stack << current
          current = current.right
        end
      else
        current = stack.pop
      end
    end
  end

  # Restores red-black tree properties after insertion.
  #
  # This method fixes any violations of red-black properties that may occur
  # after inserting a new node (which is always colored red).
  #
  # @param z [Node] the newly inserted node
  # @return [void]
  def insert_fixup(z)
    while z.parent.color == Node::RED
      if z.parent == z.parent.parent.left
        y = z.parent.parent.right
        if y.color == Node::RED
          z.parent.color = Node::BLACK
          y.color = Node::BLACK
          z.parent.parent.color = Node::RED
          z = z.parent.parent
        else
          if z == z.parent.right
            z = z.parent
            left_rotate(z)
          end
          z.parent.color = Node::BLACK
          z.parent.parent.color = Node::RED
          right_rotate(z.parent.parent)
        end
      else
        y = z.parent.parent.left
        if y.color == Node::RED
          z.parent.color = Node::BLACK
          y.color = Node::BLACK
          z.parent.parent.color = Node::RED
          z = z.parent.parent
        else
          if z == z.parent.left
            z = z.parent
            right_rotate(z)
          end
          z.parent.color = Node::BLACK
          z.parent.parent.color = Node::RED
          left_rotate(z.parent.parent)
        end
      end
    end
    @root.color = Node::BLACK
  end

  # Finds and removes a node by key, returning its value.
  #
  # @param key [Object] the key to delete
  # @return [Object, nil] the value of the deleted node, or nil if not found
  def delete_indexed_node(key) = (z = @hash_index.delete(key)) && delete_node(z)

  # Removes a node from the tree and restores red-black properties.
  #
  # Handles three cases:
  # 1. Node has no left child
  # 2. Node has no right child
  # 3. Node has both children (replace with inorder successor)
  #
  # @param z [Node] the node to remove
  # @return [Object] the value of the removed node
  def delete_node(z)
    next_min_node = nil
    if z == @min_node
      if z.right != @nil_node
        next_min_node = leftmost(z.right)
      else
        next_min_node = z.parent
      end
    end

    y = z
    y_original_color = y.color
    if z.left == @nil_node
      x = z.right
      transplant(z, z.right)
    elsif z.right == @nil_node
      x = z.left
      transplant(z, z.left)
    else
      y = leftmost(z.right)
      y_original_color = y.color
      x = y.right
      if y.parent == z
        x.parent = y
      else
        transplant(y, y.right)
        y.right = z.right
        y.right.parent = y
      end
      transplant(z, y)
      y.left = z.left
      y.left.parent = y
      y.color = z.color
    end
    if y_original_color == Node::BLACK
      delete_fixup(x)
    end
    
    if next_min_node
      @min_node = next_min_node
    end
    if z == @max_node
       next_max_node = predecessor_node_of(z)
       @max_node = next_max_node
    end

    value = z.value
    release_node(z)
    value
  end

  # Restores red-black tree properties after deletion.
  #
  # This method fixes any violations of red-black properties that may occur
  # after removing a black node from the tree.
  #
  # @param x [Node] the node that needs rebalancing
  # @return [void]
  def delete_fixup(x)
    while x != @root && x.color == Node::BLACK
      if x == x.parent.left
        w = x.parent.right
        if w.color == Node::RED
          w.color = Node::BLACK
          x.parent.color = Node::RED
          left_rotate(x.parent)
          w = x.parent.right
        end
        if w.left.color == Node::BLACK && w.right.color == Node::BLACK
          w.color = Node::RED
          x = x.parent
        else
          if w.right.color == Node::BLACK
            w.left.color = Node::BLACK
            w.color = Node::RED
            right_rotate(w)
            w = x.parent.right
          end
          w.color = x.parent.color
          x.parent.color = Node::BLACK
          w.right.color = Node::BLACK
          left_rotate(x.parent)
          x = @root
        end
      else
        w = x.parent.left
        if w.color == Node::RED
          w.color = Node::BLACK
          x.parent.color = Node::RED
          right_rotate(x.parent)
          w = x.parent.left
        end
        if w.right.color == Node::BLACK && w.left.color == Node::BLACK
          w.color = Node::RED
          x = x.parent
        else
          if w.left.color == Node::BLACK
            w.right.color = Node::BLACK
            w.color = Node::RED
            left_rotate(w)
            w = x.parent.left
          end
          w.color = x.parent.color
          x.parent.color = Node::BLACK
          w.left.color = Node::BLACK
          right_rotate(x.parent)
          x = @root
        end
      end
    end
    x.color = Node::BLACK
  end

  # Replaces subtree rooted at node u with subtree rooted at node v.
  #
  # @param u [Node] the node to be replaced
  # @param v [Node] the replacement node
  # @return [void]
  def transplant(u, v)
    if u.parent == @nil_node
      @root = v
    elsif u == u.parent.left
      u.parent.left = v
    else
      u.parent.right = v
    end
    v.parent = u.parent
  end

  # Finds the node with the closest key to the given key.
  #
  # Uses numeric distance (absolute difference) to determine proximity.
  # If multiple nodes have the same distance, returns the one with the smaller key.
  #
  # @param key [Numeric] the target key
  # @return [Node] the nearest node, or @nil_node if tree is empty
  def find_nearest_node(key)
    raise ArgumentError, "key must be Numeric" unless key.is_a?(Numeric)

    # If key is larger than max_key, return max_node
    return @max_node if @max_node != @nil_node && key >= @max_node.key
    # If key is smaller than min_key, return min_node
    return @min_node if @min_node != @nil_node && key <= @min_node.key

    current = @root
    closest = @nil_node
    min_dist = nil

    while current != @nil_node
      cmp = key <=> current.key
      if cmp == 0
        return current
      end

      # For nearest, we still typically rely on numeric distance.
      # If keys are strings, this part will fail unless they support -.
      dist = (current.key - key).abs

      if closest == @nil_node || dist < min_dist
        min_dist = dist
        closest = current
      elsif dist == min_dist
        if (current.key <=> closest.key) < 0
          closest = current
        end
      end

      if cmp < 0
        current = current.left
      else
        current = current.right
      end
    end
    closest
  end

  # Finds the node with the largest key that is smaller than the given key.
  #
  # If the key exists in the tree, returns its predecessor node.
  # If the key does not exist, returns the largest node with key < given key.
  #
  # @param key [Object] the reference key
  # @return [Node] the predecessor node, or @nil_node if none exists
  def find_predecessor_node(key)
    # If key is larger than max_key, return max_node
    return @max_node if max_key && (key <=> max_key) > 0
    # If key exists using O(1) hash lookup, return predecessor node
    if (node = @hash_index[key])
      return predecessor_node_of(node)
    end

    # Key doesn't exist: descend tree tracking the best candidate
    current = @root
    predecessor = @nil_node
    while current != @nil_node
      cmp = key <=> current.key
      if cmp > 0
        predecessor = current  # This node's key < given key
        current = current.right
      else
        current = current.left
      end
    end
    predecessor
  end

  # Finds the node with the largest key that is smaller than the given key.
  # Returns the key-value pair if found, or nil if the tree is empty.
  #
  # @param key [Object] the reference key
  # @return [Array(Object, Object), nil] the key-value pair, or nil if tree is empty
  def find_predecessor(key)
    n = find_predecessor_node(key)
    n == @nil_node ? nil : n.pair
  end

  # Finds the node with the smallest key that is larger than the given key.
  #
  # If the key exists in the tree, returns its successor node.
  # If the key does not exist, returns the smallest node with key > given key.
  #
  # @param key [Object] the reference key
  # @return [Node] the successor node, or @nil_node if none exists
  def find_successor_node(key)
    # If key is larger than or equal to max_key, return nil
    return @nil_node if max_key && (key <=> max_key) >= 0
    # If key is smaller than min_key, return min_node
    return @min_node if min_key && (key <=> min_key) < 0
    # If key exists using O(1) hash lookup, return successor node
    if (node = @hash_index[key])
      return successor_node_of(node)
    end
    # Key doesn't exist: descend tree tracking the best candidate
    current = @root
    successor = @nil_node
    while current != @nil_node
      cmp = key <=> current.key
      if cmp < 0
        successor = current  # This node's key > given key
        current = current.left
      else
        current = current.right
      end
    end
    successor
  end

  # Finds the node with the smallest key that is larger than the given key.
  # Returns the key-value pair if found, or nil if the tree is empty.
  #
  # @param key [Object] the reference key
  # @return [Array(Object, Object), nil] the key-value pair, or nil if tree is empty
  def find_successor(key)
    n = find_successor_node(key)
    n == @nil_node ? nil : n.pair
  end

  # Finds the leftmost (minimum) node in a subtree.
  #
  # @param node [Node] the root of the subtree
  # @return [Node] the leftmost node
  def leftmost(node)
    while node.left != @nil_node
      node = node.left
    end
    node
  end

  # Returns the minimum key-value pair.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  def find_min = ((n = @min_node) != @nil_node) && n.pair

  # Finds the rightmost (maximum) node in a subtree.
  #
  # @param node [Node] the root of the subtree
  # @return [Node] the rightmost node
  def rightmost(node)
    while node.right != @nil_node
      node = node.right
    end
    node
  end

  # Returns the maximum key-value pair.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  def find_max = ((n = @max_node) != @nil_node) && n.pair

  # Performs a left rotation on the given node.
  #
  # Transforms the tree structure:
  #     x                y
  #    / \              / \
  #   a   y     =>     x   c
  #      / \          / \
  #     b   c        a   b
  #
  # @param x [Node] the node to rotate
  # @return [void]
  def left_rotate(x)
    y = x.right
    x.right = y.left
    if y.left != @nil_node
      y.left.parent = x
    end
    y.parent = x.parent
    if x.parent == @nil_node
      @root = y
    elsif x == x.parent.left
      x.parent.left = y
    else
      x.parent.right = y
    end
    y.left = x
    x.parent = y
  end

  # Performs a right rotation on the given node.
  #
  # Transforms the tree structure:
  #       y            x
  #      / \          / \
  #     x   c   =>   a   y
  #    / \              / \
  #   a   b            b   c
  #
  # @param y [Node] the node to rotate
  # @return [void]
  def right_rotate(y)
    x = y.left
    y.left = x.right
    if x.right != @nil_node
      x.right.parent = y
    end
    x.parent = y.parent
    if y.parent == @nil_node
      @root = x
    elsif y == y.parent.right
      y.parent.right = x
    else
      y.parent.left = x
    end
    x.right = y
    y.parent = x
  end

  # Allocates a new node or recycles one from the pool.
  # @return [Node]
  def allocate_node(key, value, color, left, right, parent)
    node = @node_allocator.allocate(key, value, color, left, right, parent)
    @key_count += 1
    node
  end

  # Releases a node back to the pool.
  # @param node [Node] the node to release
  # Releases a node back to the pool.
  # @param node [Node] the node to release
  def release_node(node)
    @node_allocator.release(node)
    @key_count -= 1
  end

  # Recursively checks black height consistency.
  #
  # Verifies that:
  # - No red node has a red child
  # - All paths have the same black height
  #
  # @param node [Node] the current node
  # @return [Integer] the black height, or -1 if invalid
  def check_black_height(node)
    return 0 if node == @nil_node

    if node.color == Node::RED
      return -1 if node.left.color == Node::RED || node.right.color == Node::RED
    end

    left_h = check_black_height(node.left)
    right_h = check_black_height(node.right)

    return -1 if left_h == -1 || right_h == -1 || left_h != right_h

    left_h + (node.color == Node::BLACK ? 1 : 0)
  end

  def check_order(node)
    return true if node == @nil_node
    if node.left != @nil_node && (node.left.key <=> node.key) >= 0
      return false
    end
    if node.right != @nil_node && (node.right.key <=> node.key) <= 0
      return false
    end
    check_order(node.left) && check_order(node.right)
  end
end

# A Multi Red-Black Tree that allows duplicate keys.
#
# MultiRBTree extends RBTree to support multiple values per key. Each key maps to
# an array of values rather than a single value. The size reflects the total
# number of key-value pairs (not unique keys).
#
# == Features
#
# * Multiple values per key using arrays
# * Separate methods for single deletion (`delete_value`) vs. all deletions (`delete_key`)
# * Values for each key maintain insertion order
# * Configurable access to first or last value via `:last` option
#
# == Value Array Access
#
# For each key, values are stored in insertion order. Methods that access
# a single value support a `:last` option to choose which end of the array:
#
# * +get(key)+, +first_value(key)+ - returns first value (oldest)
# * +get(key, last: true)+, +last_value(key)+ - returns last value (newest)
# * +delete_value(key)+, +delete_first_value(key)+ - removes first value
# * +delete_value(key, last: true)+, +delete_last_value(key)+ - removes last value
# * +prev(key)+, +succ(key)+ - returns first value of adjacent key
# * +prev(key, last: true)+, +succ(key, last: true)+ - returns last value
#
# == Boundary Operations
#
# * +min+, +max+ - return [key, first_value] by default
# * +min(last: true)+, +max(last: true)+ - return [key, last_value]
# * +shift+ - removes and returns [smallest_key, first_value]
# * +pop+ - removes and returns [largest_key, last_value]
#
# == Iteration Order
#
# When iterating over values, the order depends on the direction:
#
# * Forward iteration (+each+, +lt+, +gt+, etc.): Each key's values are
#   yielded in insertion order (first to last).
#
# * Reverse iteration (+reverse_each+, +lt(key, reverse: true)+, etc.):
#   Each key's values are yielded in reverse insertion order (last to first).
#
# This ensures consistent behavior where reverse iteration is truly the
# mirror image of forward iteration.
#
# == Usage
#
#   tree = MultiRBTree.new
#   tree.insert(1, 'first one')
#   tree.insert(1, 'second one')
#   tree.insert(2, 'two')
#
#   tree.size             # => 3 (total key-value pairs)
#   tree.get(1)           # => "first one" (first value)
#   tree.get(1, last: true)  # => "second one" (last value)
#   tree.values(1)        # => ["first one", "second one"] (all values)
#
#   tree.delete_value(1)   # removes only "first one"
#   tree.get(1)           # => "second one"
#
#   tree.delete(1)        # removes all remaining values for key 1
#
# @author Masahito Suzuki
# @since 0.1.2
class MultiRBTree < RBTree
  def initialize(*args, **kwargs)
    @value_count = 0
    super
  end

  # Returns the number of values stored in the tree.
  # @return [Integer] the number of values in the tree
  def size = @value_count

  # Removes all elements from the tree.
  # @return [MultiRBTree] self
  def clear
    @value_count = 0
    super
  end
  
  # Returns the minimum key-value pair without removing it.
  #
  # @param last [Boolean] whether to return the last value (default: false)
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = MultiRBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.min  # => [1, "one"]
  def min(last: false) = (n = min_node) && [n.key, n.value.send(last ? :last : :first)]

  # Returns the maximum key-value pair without removing it.
  #
  # @param last [Boolean] whether to return the last value (default: false)
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = MultiRBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.max  # => [3, "three"]
  def max(last: false) = (n = max_node) && [n.key, n.value.send(last ? :last : :first)]

  # Returns the last key-value pair without removing it.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = MultiRBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.last  # => [3, "three"]
  def last = max(last: true)

  # Returns the number of values for a given key or the total number of key-value pairs if no key is given.
  #
  # @param key [Object, nil] the key to look up, or nil for total count
  # @return [Integer] the number of values for the key, or total count if no key is given
  def value_count(key = nil) = !key ? size : (@hash_index[key]&.value&.size || 0)

  # Retrieves a value associated with the given key.
  #
  # @param key [Object] the key to look up
  # @param last [Boolean] if true, return the last value; otherwise return the first (default: false)
  # @return [Object, nil] the value for the key, or nil if not found
  # @example
  #   tree = MultiRBTree.new
  #   tree.insert(1, 'first')
  #   tree.insert(1, 'second')
  #   tree.get(1)              # => "first"
  #   tree.get(1, last: true)  # => "second"
  def value(key, last: false) = @hash_index[key]&.value&.send(last ? :last : :first)
  alias :get :value

  # Retrieves the first value associated with the given key.
  #
  # @param key [Object] the key to look up
  # @return [Object, nil] the first value for the key, or nil if not found
  def first_value(key) = value(key)
  alias :get_first :first_value

  # Retrieves the last value associated with the given key.
  #
  # @param key [Object] the key to look up
  # @return [Object, nil] the last value for the key, or nil if not found
  def last_value(key) = value(key, last: true)
  alias :get_last :last_value

  # Retrieves all values associated with the given key.
  #
  # @param key [Object] the key to look up
  # @return [Array, nil] an Array containing all values, or nil if not found
  # @example
  #   tree = MultiRBTree.new
  #   tree.insert(1, 'first')
  #   tree.insert(1, 'second')
  #   tree.values(1).to_a   # => ["first", "second"]
  def values(key, reverse: false)
    return enum_for(__method__, key) { value_count(key) } unless block_given?
    @hash_index[key]&.value&.send(reverse ? :reverse_each : :each) { |v| yield v }
  end
  alias :get_all :values

  # Returns the nearest key-value pair without removing it.
  #
  # @param key [Object] the target key
  # @param last [Boolean] whether to return the last value (default: false)
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = MultiRBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.nearest(4)   # => [5, "five"]
  def nearest(key, last: false) = (pair = super(key)) && [pair[0], pair[1].send(last ? :last : :first)]

  # Returns the previous key-value pair without removing it.
  #
  # @param key [Object] the target key
  # @param last [Boolean] whether to return the last value (default: false)
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = MultiRBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.prev(4)   # => [5, "five"]
  def prev(key, last: false) = (pair = super(key)) && [pair[0], pair[1].send(last ? :last : :first)]

  # Returns the next key-value pair without removing it.
  #
  # @param key [Object] the target key
  # @param last [Boolean] whether to return the last value (default: false)
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = MultiRBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.succ(4)   # => [5, "five"]
  def succ(key, last: false) = (pair = super(key)) && [pair[0], pair[1].send(last ? :last : :first)]

  # Merges the contents of another tree, hash, or enumerable into this tree.
  #
  # Appends values from the other source to the existing values for each key.
  #
  # @param other [RBTree, Hash, Enumerable] the source to merge from
  # @return [MultiRBTree] self
  def merge!(other)
    insert(other)
    self
  end

  # Deletes a single value for the specified key.
  #
  # If the key has multiple values, removes only one value.
  # If this was the last value for the key, the node is removed from the tree.
  #
  # @param key [Object] the key to delete from
  # @param last [Boolean] if true, remove the last value; otherwise remove the first (default: false)
  # @return [Object, nil] the deleted value, or nil if key not found
  # @example
  #   tree = MultiRBTree.new
  #   tree.insert(1, 'first')
  #   tree.insert(1, 'second')
  #   tree.delete_value(1)            # => "first"
  #   tree.delete_value(1, last: true)  # => "second" (if more values existed)
  def delete_value(key, last: false)
    (z = @hash_index[key]) or return nil
    value = z.value.send(last ? :pop : :shift)
    z.value.empty? && delete_indexed_node(key)
    @value_count -= 1
    value
  end
  alias :delete_one :delete_value

  # Deletes the first value for the specified key.
  #
  # @param key [Object] the key to delete from
  # @return [Object, nil] the deleted value, or nil if key not found
  def delete_first_value(key) = delete_value(key)
  alias :delete_first :delete_first_value

  # Deletes the last value for the specified key.
  #
  # @param key [Object] the key to delete from
  # @return [Object, nil] the deleted value, or nil if key not found
  def delete_last_value(key) = delete_value(key, last: true)
  alias :delete_last :delete_last_value

  # Deletes all values for the specified key.
  #
  # Removes the node and all associated values.
  #
  # @param key [Object] the key to delete
  # @return [Array, nil] the array of all deleted values, or nil if not found
  # @example
  #   tree = MultiRBTree.new
  #   tree.insert(1, 'first')
  #   tree.insert(1, 'second')
  #   vals = tree.delete(1)  # removes both values
  #   vals.size  # => 2
  def delete_key(key)
    return nil unless (z = @hash_index[key])
    @value_count -= (value = z.value).size
    delete_indexed_node(z.key)
    value
  end
  alias :delete :delete_key

  # Removes and returns the first key-value pair.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = MultiRBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.shift  # => [1, "one"]
  def shift
    (key, vals = min_node&.pair) or return nil
    val = vals.shift
    vals.empty? && delete_indexed_node(key)
    @value_count -= 1
    [key, val]
  end

  # Removes and returns the last key-value pair.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = MultiRBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.pop  # => [3, "three"]
  def pop
    (key, vals = max_node&.pair) or return nil
    val = vals.pop
    vals.empty? && delete_indexed_node(key)
    @value_count -= 1
    [key, val]
  end

  # Keeps key-value pairs for which the block returns true, deleting the rest.
  # Unlike RBTree, this removes individual values rather than entire keys.
  #
  # @yield [key, value] each key-value pair
  # @return [MultiRBTree, Enumerator] self, or Enumerator if no block
  def keep_if(&block)
    return enum_for(__method__) { size } unless block_given?
    filter_values! { |k, v| block.call(k, v) }
    self
  end

  # Deletes key-value pairs for which the block returns true.
  # Unlike RBTree, this removes individual values rather than entire keys.
  #
  # @yield [key, value] each key-value pair
  # @return [MultiRBTree, Enumerator] self, or Enumerator if no block
  def delete_if(&block)
    return enum_for(__method__) { size } unless block_given?
    filter_values! { |k, v| !block.call(k, v) }
    self
  end

  # @!visibility private
  private

  # Filters values in-place across all nodes.
  # Keeps only values for which the block returns true.
  # Removes nodes whose value arrays become empty.
  # Updates @value_count accordingly.
  def filter_values!
    keys_to_delete = []
    @hash_index.each do |key, node|
      before = node.value.size
      node.value.select! { |v| yield key, v }
      @value_count -= before - node.value.size
      keys_to_delete << key if node.value.empty?
    end
    keys_to_delete.each { |k| delete_indexed_node(k) }
  end

  # Inserts a value for the given key.
  #
  # If the key already exists, the value is appended to its list.
  # If the key doesn't exist, a new node is created.
  #
  # @param key [Object] the key (must implement <=>)
  # @param value [Object] the value to insert
  # @param overwrite [Boolean] ignored for MultiRBTree which always appends
  # @return [Boolean] always returns true
  # @example
  #   tree = MultiRBTree.new
  #   tree.insert(1, 'first')
  #   tree.insert(1, 'second')  # adds another value for key 1
  def insert_entry(key, value, **)
    insert_entry_generic(key) do |node, is_new|
      @value_count += 1
      if is_new
        [value]
      else
        node.value << value
        true
      end
    end
  end

  # Traverses the tree in ascending order, yielding each key-value pair.
  #
  # @param range [Range] the range of keys to traverse
  # @yield [Array(Object, Object)] each key-value pair
  # @yieldparam key [Object] the key
  # @yieldparam val [Object] the value
  def traverse_range_asc(...)
    super { |k, vals| vals.each { |v| yield [k, v] } }
  end

  # Traverses the tree in descending order, yielding each key-value pair.
  #
  # @param range [Range] the range of keys to traverse
  # @yield [Array(Object, Object)] each key-value pair
  # @yieldparam key [Object] the key
  # @yieldparam val [Object] the value
  def traverse_range_desc(...)
    super { |k, vals| vals.reverse_each { |v| yield [k, v] } }
  end
end

# Internal node structure for RBTree.
#
# Each node stores a key-value pair, color (red or black), and references
# to parent, left child, and right child nodes.
#
# @!attribute [rw] key
#   @return [Object] the key stored in this node
# @!attribute [rw] value
#   @return [Object] the value stored in this node
# @!attribute [rw] color
#   @return [Symbol] the color of the node (:red or :black)
# @!attribute [rw] left
#   @return [Node] the left child node
# @!attribute [rw] right
#   @return [Node] the right child node
# @!attribute [rw] parent
#   @return [Node] the parent node
#
# @api private
class RBTree::Node
  attr_accessor :key, :value, :color, :left, :right, :parent

  # Red color constant (true)
  RED = true
  # Black color constant (false)
  BLACK = false

  # Creates a new Node.
  #
  # @param key [Object] the key
  # @param value [Object] the value
  # @param color [Boolean] the color (true=red, false=black)
  # @param left [Node] the left child
  # @param right [Node] the right child
  # @param parent [Node] the parent node
  def initialize(key = nil, value = nil, color = BLACK, left = nil, right = nil, parent = nil)
    @key = key
    @value = value
    @color = color
    @left = left
    @right = right
    @parent = parent
  end

  # Returns the key-value pair.
  # @return [Array(Object, Object)] the key-value pair
  def pair = [key, value]
end

# Allocator for RBTree nodes.
#
# @api private
class RBTree::NodeAllocator
  # Allocates a new node.
    #
  # @param key [Object] the key
  # @param value [Object] the value
  # @param color [Boolean] the color (true=red, false=black)
  # @param left [Node] the left child
  # @param right [Node] the right child
  # @param parent [Node] the parent node
  def allocate(key, value, color, left, right, parent) = RBTree::Node.new(key, value, color, left, right, parent)

  # Releases a node.
  #
  # @param node [Node] the node to release
  def release(node) = nil
end

# Internal node pool for RBTree.
#
# Manages recycling of Node objects to reduce object allocation overhead.
#
# @api private
class RBTree::NodePool < RBTree::NodeAllocator
  def initialize
    @pool = []
  end

  # Allocates a new node or recycles one from the pool.
  #
  # @param key [Object] the key
  # @param value [Object] the value
  # @param color [Boolean] the color (true=red, false=black)
  # @param left [Node] the left child
  # @param right [Node] the right child
  # @param parent [Node] the parent node
  def allocate(key, value, color, left, right, parent)
    node = @pool.pop
    if node
      node.key = key
      node.value = value
      node.color = color
      node.left = left
      node.right = right
      node.parent = parent
      node
    else
      super
    end
  end

  # Releases a node back to the pool.
  #
  # @param node [Node] the node to release
  def release(node)
    node.left = node.right = node.parent = node.value = node.key = nil
    @pool << node
  end
end

# Internal node pool for RBTree.
#
# Manages recycling of Node objects to reduce object allocation overhead.
# Includes an auto-shrink mechanism to release memory back to GC when
# the pool size exceeds the fluctuation range of recent active node count.
#
# This class can be used to customize the node allocation strategy by passing
# an instance to {RBTree#initialize}.
class RBTree::AutoShrinkNodePool < RBTree::NodePool
  # Initializes a new AutoShrinkNodePool.
  #
  # @param max_maintenance_interval [Integer] maximum interval between maintenance checks (default: 1000)
  # @param target_check_interval [Float] target interval in seconds for maintenance checks (default: 1.0)
  # @param history_size [Integer] duration in seconds to keep history for fluctuation analysis (default: 120)
  # @param buffer_factor [Float] buffer factor to apply to observed fluctuation (default: 1.25)
  # @param reserve_ratio [Float] minimum reserve capacity as a ratio of max active nodes (default: 0.1)
  def initialize(
      max_maintenance_interval: 1000,
      target_check_interval: 1.0,
      history_size: 120,
      buffer_factor: 1.25,
      reserve_ratio: 0.1)
    @pool = []
    
    @max_maintenance_interval = max_maintenance_interval
    @target_check_interval = target_check_interval
    @history_limit = history_size
    @buffer_ratio = buffer_factor
    @reserve_ratio = reserve_ratio
    
    @maintenance_count = 0
    @check_interval = 1000
    @check_count = 0
    @avg_release_rate = nil
    @last_check_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    
    @active_nodes = 0
    @global_max_active = 0
    @global_min_active = 0
    @max_active_in_interval = 0
    @min_active_in_interval = 0
    @history = []
    @current_target_capacity = Float::INFINITY
  end

  # Allocates a new node or recycles one from the pool.
  #
  # @param key [Object] the key
  # @param value [Object] the value
  # @param color [Boolean] the color (true=red, false=black)
  # @param left [Node] the left child
  # @param right [Node] the right child
  # @param parent [Node] the parent node
  def allocate(key, value, color, left, right, parent)
    @active_nodes += 1
    @max_active_in_interval = @active_nodes if @active_nodes > @max_active_in_interval
    super
  end

  # Releases a node back to the pool.
  #
  # Checks auto-shrink logic to decide whether to keep the node or let it be GC'd.
  #
  # @param node [Node] the node to release
  def release(node)
    @active_nodes -= 1
    @min_active_in_interval = @active_nodes if @active_nodes < @min_active_in_interval

    @check_count += 1
    
    perform_maintenance if @check_count >= @check_interval

    super if @pool.size < @current_target_capacity
  end

  private

  def perform_maintenance
    @maintenance_count += 1
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed = now - @last_check_time
    return if elapsed <= 0
    
    current_rate = @check_count / elapsed
    
    if @avg_release_rate.nil?
      @avg_release_rate = current_rate
    else
      @avg_release_rate = (@avg_release_rate * 3 + current_rate) / 4
    end
    
    @check_interval = [[(@avg_release_rate * @target_check_interval).to_i, 1].max, @max_maintenance_interval].min
    
    expired_min = false
    expired_max = false
    needs_recalc = false

    cutoff_time = now - @history_limit
    while !@history.empty? && @history.first[0] < cutoff_time
      if !expired_min && @history.first[1] == @global_min_active
        expired_min = true
        needs_recalc = true
      end
      if !expired_max && @history.first[2] == @global_max_active
        expired_max = true
        needs_recalc = true
      end
      @history.shift
    end

    @history << [now, @min_active_in_interval, @max_active_in_interval]

    if @min_active_in_interval < @global_min_active
      @global_min_active = @min_active_in_interval
      expired_min = false
      needs_recalc = true
    end
    if @max_active_in_interval > @global_max_active
      @global_max_active = @max_active_in_interval
      expired_max = false
      needs_recalc = true
    end

    @global_min_active = @history.map { |_, min, _| min }.min if expired_min
    @global_max_active = @history.map { |_, _, max| max }.max if expired_max
    if needs_recalc
      fluctuation = @global_max_active - @global_min_active
      reserve = (@reserve_ratio * @global_max_active).to_i
      @current_target_capacity = [(fluctuation * @buffer_ratio).to_i, reserve].max
    end
    
    @check_count = 0
    @last_check_time = now
    @max_active_in_interval = @active_nodes
    @min_active_in_interval = @active_nodes
  end
end
