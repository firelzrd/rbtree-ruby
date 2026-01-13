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
  attr_reader :size

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
  # The tree can be initialized empty or populated with initial data from a Hash or Array.
  #
  # @param args [Hash, Array, nil] optional initial data
  #   - If a Hash is provided, each key-value pair is inserted into the tree
  #   - If an Array is provided, it should contain [key, value] pairs
  #   - If no arguments are provided, an empty tree is created
  # @raise [ArgumentError] if arguments are invalid
  # @example Create an empty tree
  #   tree = RBTree.new
  # @example Create from a hash
  #   tree = RBTree.new({1 => 'one', 2 => 'two'})
  # @example Create from an array
  #   tree = RBTree.new([[1, 'one'], [2, 'two']])
  def initialize(*args)
    @nil_node = Node.new
    @nil_node.color = Node::BLACK
    @nil_node.left = @nil_node
    @nil_node.right = @nil_node
    @root = @nil_node
    @min_node = @nil_node
    @hash_index = {}  # Hash index for O(1) key lookup
    @node_pool = []   # Memory pool for recycling nodes
    @size = 0

    if args.any?
      source = args.size == 1 ? args.first : args
      case source
      when Hash
        source.each { |k, v| insert(k, v) }
      when Array
        source.each do |arg| 
          key, value = arg
          insert(key, value)
        end
      else
        raise ArgumentError, "Invalid arguments"
      end
    end
  end

  # Returns a string representation of the tree.
  #
  # Shows the first 5 entries and total size. Useful for debugging.
  #
  # @return [String] a human-readable representation of the tree
  def inspect
    if @size > 0
      content = first(5).map { |k, v| "#{k.inspect}=>#{v.inspect}" }.join(", ")
      suffix = @size > 5 ? ", ..." : ""
      "#<#{self.class}:0x#{object_id.to_s(16)} size=#{@size} {#{content}#{suffix}}>"
    else
      super
    end
  end

  # Checks if the tree is empty.
  #
  # @return [Boolean] true if the tree contains no elements, false otherwise
  def empty? = @root == @nil_node

  # Checks if the tree contains the given key.
  #
  # @param key [Object] the key to search for
  # @return [Boolean] true if the key exists in the tree, false otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two'})
  #   tree.has_key?(1)  # => true
  #   tree.has_key?(3)  # => false
  def has_key?(key)
    @hash_index.key?(key)
  end

  # Retrieves the value associated with the given key.
  #
  # @param key [Object] the key to look up
  # @return [Object, nil] the associated value, or nil if the key is not found
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two'})
  #   tree.get(1)  # => "one"
  #   tree[2]      # => "two"
  #   tree[3]      # => nil
  def get(key)
    @hash_index[key]&.value
  end
  alias_method :[], :get

  # Inserts or updates a key-value pair in the tree.
  #
  # If the key already exists and overwrite is true (default), the value is updated.
  # If overwrite is false and the key exists, the operation returns nil without modification.
  #
  # @param key [Object] the key to insert (must implement <=>)
  # @param value [Object] the value to associate with the key
  # @param overwrite [Boolean] whether to overwrite existing keys (default: true)
  # @return [Boolean, nil] true if inserted/updated, nil if key exists and overwrite is false
  # @example
  #   tree = RBTree.new
  #   tree.insert(1, 'one')        # => true
  #   tree.insert(1, 'ONE')        # => true (overwrites)
  #   tree.insert(1, 'uno', overwrite: false)  # => nil (no change)
  #   tree[2] = 'two'              # using alias
  def insert(key, value, overwrite: true)
    if (node = @hash_index[key])
      return nil unless overwrite
      node.value = value
      return true
    end
    y = @nil_node
    x = @root
    while x != @nil_node
      y = x
      cmp = key <=> x.key
      if cmp == 0
        return nil unless overwrite
        x.value = value
        return true
      elsif cmp < 0
        x = x.left
      else
        x = x.right
      end
    end
    z = allocate_node(key, value, Node::RED, @nil_node, @nil_node, @nil_node)
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
    @size += 1
    
    if @min_node == @nil_node || (key <=> @min_node.key) < 0
      @min_node = z
    end
    
    @hash_index[key] = z  # Add to hash index
    true
  end
  alias_method :[]=, :insert

  # Deletes the key-value pair with the specified key.
  #
  # @param key [Object] the key to delete
  # @return [Object, nil] the value associated with the deleted key, or nil if not found
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two'})
  #   tree.delete(1)  # => "one"
  #   tree.delete(3)  # => nil
  def delete(key)
    value = delete_node(key)
    return nil unless value
    @size -= 1
    value
  end

  # Removes all key-value pairs from the tree.
  #
  # @return [RBTree] self
  def clear
    @root = @nil_node
    @min_node = @nil_node
    @hash_index.clear
    @size = 0
    self
  end

  # Removes and returns the minimum key-value pair.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.shift  # => [1, "one"]
  #   tree.shift  # => [2, "two"]
  def shift
    return nil if @min_node == @nil_node
    result = [@min_node.key, @min_node.value]
    delete(@min_node.key)
    result
  end

  # Removes and returns the maximum key-value pair.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.pop  # => [3, "three"]
  #   tree.pop  # => [2, "two"]
  def pop
    n = rightmost(@root)
    return nil if n == @nil_node
    result = [n.key, n.value]
    delete(n.key)
    result
  end

  # Iterates over all key-value pairs in ascending order of keys.
  #
  # @yield [key, value] each key-value pair in the tree
  # @return [Enumerator, RBTree] an Enumerator if no block is given, self otherwise
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.each { |k, v| puts "#{k}: #{v}" }
  #   # Output:
  #   # 1: one
  #   # 2: two
  #   # 3: three
  def each(&block)
    return enum_for(:each) unless block_given?
    traverse_asc(@root, &block)
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
  def reverse_each(&block)
    return enum_for(:reverse_each) unless block_given?
    traverse_desc(@root, &block)
  end

  # Returns the minimum key-value pair without removing it.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.min  # => [1, "one"]
  def min
    @min_node == @nil_node ? nil : [@min_node.key, @min_node.value]
  end

  # Returns the maximum key-value pair without removing it.
  #
  # @return [Array(Object, Object), nil] a two-element array [key, value], or nil if tree is empty
  # @example
  #   tree = RBTree.new({3 => 'three', 1 => 'one', 2 => 'two'})
  #   tree.max  # => [3, "three"]
  def max
    n = rightmost(@root)
    n == @nil_node ? nil : [n.key, n.value]
  end

  # Retrieves all key-value pairs with keys less than the specified key.
  #
  # @param key [Object] the upper bound (exclusive)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})
  #   tree.lt(3).to_a  # => [[1, "one"], [2, "two"]]
  #   tree.lt(3, reverse: true).first  # => [2, "two"]
  #   tree.lt(3) { |k, v| puts k }  # prints keys, returns self
  def lt(key, reverse: false, &block)
    return enum_for(:lt, key, reverse: reverse) unless block_given?
    if reverse
      traverse_lt_desc(@root, key, &block)
    else
      traverse_lt(@root, key, &block)
    end
    self
  end

  # Retrieves all key-value pairs with keys less than or equal to the specified key.
  #
  # @param key [Object] the upper bound (inclusive)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})
  #   tree.lte(3).to_a  # => [[1, "one"], [2, "two"], [3, "three"]]
  #   tree.lte(3, reverse: true).first  # => [3, "three"]
  def lte(key, reverse: false, &block)
    return enum_for(:lte, key, reverse: reverse) unless block_given?
    if reverse
      traverse_lte_desc(@root, key, &block)
    else
      traverse_lte(@root, key, &block)
    end
    self
  end

  # Retrieves all key-value pairs with keys greater than the specified key.
  #
  # @param key [Object] the lower bound (exclusive)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})
  #   tree.gt(2).to_a  # => [[3, "three"], [4, "four"]]
  #   tree.gt(2, reverse: true).first  # => [4, "four"]
  def gt(key, reverse: false, &block)
    return enum_for(:gt, key, reverse: reverse) unless block_given?
    if reverse
      traverse_gt_desc(@root, key, &block)
    else
      traverse_gt(@root, key, &block)
    end
    self
  end

  # Retrieves all key-value pairs with keys greater than or equal to the specified key.
  #
  # @param key [Object] the lower bound (inclusive)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four'})
  #   tree.gte(2).to_a  # => [[2, "two"], [3, "three"], [4, "four"]]
  #   tree.gte(2, reverse: true).first  # => [4, "four"]
  def gte(key, reverse: false, &block)
    return enum_for(:gte, key, reverse: reverse) unless block_given?
    if reverse
      traverse_gte_desc(@root, key, &block)
    else
      traverse_gte(@root, key, &block)
    end
    self
  end

  # Retrieves all key-value pairs with keys within the specified range.
  #
  # @param min [Object] the lower bound
  # @param max [Object] the upper bound
  # @param include_min [Boolean] whether to include the lower bound (default: true)
  # @param include_max [Boolean] whether to include the upper bound (default: true)
  # @param reverse [Boolean] if true, iterate in descending order (default: false)
  # @yield [key, value] each matching key-value pair (if block given)
  # @return [Enumerator, RBTree] Enumerator if no block given, self otherwise
  # @example
  #   tree = RBTree.new({1 => 'one', 2 => 'two', 3 => 'three', 4 => 'four', 5 => 'five'})
  #   tree.between(2, 4).to_a  # => [[2, "two"], [3, "three"], [4, "four"]]
  #   tree.between(2, 4, reverse: true).first  # => [4, "four"]
  def between(min, max, include_min: true, include_max: true, reverse: false, &block)
    return enum_for(:between, min, max, include_min: include_min, include_max: include_max, reverse: reverse) unless block_given?
    if reverse
      traverse_between_desc(@root, min, max, include_min, include_max, &block)
    else
      traverse_between(@root, min, max, include_min, include_max, &block)
    end
    self
  end

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
  def nearest(key)
    return nil unless key.respond_to?(:-)
    n = find_nearest_node(key)
    n == @nil_node ? nil : [n.key, n.value]
  end

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
  def prev(key)
    n = find_predecessor_node(key)
    n == @nil_node ? nil : [n.key, n.value]
  end

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
  def succ(key)
    n = find_successor_node(key)
    n == @nil_node ? nil : [n.key, n.value]
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

  # Traverses the tree in ascending order (in-order traversal).
  #
  # @param node [Node] the current node
  # @yield [key, value] each key-value pair in ascending order
  # @return [void]
  def traverse_asc(node, &block)
    stack = []
    current = node
    while current != @nil_node || !stack.empty?
      while current != @nil_node
        stack << current
        current = current.left
      end
      current = stack.pop
      yield current.key, current.value
      current = current.right
    end
  end

  # Traverses the tree in descending order (reverse in-order traversal).
  #
  # @param node [Node] the current node
  # @yield [key, value] each key-value pair in descending order
  # @return [void]
  def traverse_desc(node, &block)
    stack = []
    current = node
    while current != @nil_node || !stack.empty?
      while current != @nil_node
        stack << current
        current = current.right
      end
      current = stack.pop
      yield current.key, current.value
      current = current.left
    end
  end

  # Traverses nodes with keys less than the specified key.
  #
  # @param node [Node] the current node
  # @param key [Object] the upper bound (exclusive)
  # @yield [key, value] each matching key-value pair
  # @return [void]
  def traverse_lt(node, key, &block)
    return if node == @nil_node
    
    traverse_lt(node.left, key, &block)
    if (node.key <=> key) < 0
      yield node.key, node.value
      traverse_lt(node.right, key, &block)
    end
  end

  # Traverses nodes with keys less than or equal to the specified key.
  #
  # @param node [Node] the current node
  # @param key [Object] the upper bound (inclusive)
  # @yield [key, value] each matching key-value pair
  # @return [void]
  def traverse_lte(node, key, &block)
    return if node == @nil_node
    
    traverse_lte(node.left, key, &block)
    if (node.key <=> key) <= 0
      yield node.key, node.value
      traverse_lte(node.right, key, &block)
    end
  end

  # Traverses nodes with keys greater than the specified key.
  #
  # @param node [Node] the current node
  # @param key [Object] the lower bound (exclusive)
  # @yield [key, value] each matching key-value pair
  # @return [void]
  def traverse_gt(node, key, &block)
    return if node == @nil_node
    
    if (node.key <=> key) > 0
      traverse_gt(node.left, key, &block)
      yield node.key, node.value
    end
    traverse_gt(node.right, key, &block)
  end

  # Traverses nodes with keys greater than or equal to the specified key.
  #
  # @param node [Node] the current node
  # @param key [Object] the lower bound (inclusive)
  # @yield [key, value] each matching key-value pair
  # @return [void]
  def traverse_gte(node, key, &block)
    return if node == @nil_node
    
    if (node.key <=> key) >= 0
      traverse_gte(node.left, key, &block)
      yield node.key, node.value
    end
    traverse_gte(node.right, key, &block)
  end

  # Traverses nodes with keys within the specified range.
  #
  # @param node [Node] the current node
  # @param min [Object] the lower bound
  # @param max [Object] the upper bound
  # @param include_min [Boolean] whether to include the lower bound
  # @param include_max [Boolean] whether to include the upper bound
  # @yield [key, value] each matching key-value pair
  # @return [void]
  def traverse_between(node, min, max, include_min, include_max, &block)
    return if node == @nil_node
    if (node.key <=> min) > 0
      traverse_between(node.left, min, max, include_min, include_max, &block)
    end
    
    greater = include_min ? (node.key <=> min) >= 0 : (node.key <=> min) > 0
    less = include_max ? (node.key <=> max) <= 0 : (node.key <=> max) < 0
    
    if greater && less
      yield node.key, node.value
    end
    
    if (node.key <=> max) < 0
      traverse_between(node.right, min, max, include_min, include_max, &block)
    end
  end

  # Traverses nodes with keys less than the specified key in descending order.
  #
  # @param node [Node] the current node
  # @param key [Object] the upper bound (exclusive)
  # @yield [key, value] each matching key-value pair in descending order
  # @return [void]
  def traverse_lt_desc(node, key, &block)
    return if node == @nil_node
    
    if (node.key <=> key) < 0
      traverse_lt_desc(node.right, key, &block)
      yield node.key, node.value
    end
    traverse_lt_desc(node.left, key, &block)
  end

  # Traverses nodes with keys less than or equal to the specified key in descending order.
  #
  # @param node [Node] the current node
  # @param key [Object] the upper bound (inclusive)
  # @yield [key, value] each matching key-value pair in descending order
  # @return [void]
  def traverse_lte_desc(node, key, &block)
    return if node == @nil_node
    
    if (node.key <=> key) <= 0
      traverse_lte_desc(node.right, key, &block)
      yield node.key, node.value
    end
    traverse_lte_desc(node.left, key, &block)
  end

  # Traverses nodes with keys greater than the specified key in descending order.
  #
  # @param node [Node] the current node
  # @param key [Object] the lower bound (exclusive)
  # @yield [key, value] each matching key-value pair in descending order
  # @return [void]
  def traverse_gt_desc(node, key, &block)
    return if node == @nil_node
    
    traverse_gt_desc(node.right, key, &block)
    if (node.key <=> key) > 0
      yield node.key, node.value
      traverse_gt_desc(node.left, key, &block)
    end
  end

  # Traverses nodes with keys greater than or equal to the specified key in descending order.
  #
  # @param node [Node] the current node
  # @param key [Object] the lower bound (inclusive)
  # @yield [key, value] each matching key-value pair in descending order
  # @return [void]
  def traverse_gte_desc(node, key, &block)
    return if node == @nil_node
    
    traverse_gte_desc(node.right, key, &block)
    if (node.key <=> key) >= 0
      yield node.key, node.value
      traverse_gte_desc(node.left, key, &block)
    end
  end

  # Traverses nodes with keys within the specified range in descending order.
  #
  # @param node [Node] the current node
  # @param min [Object] the lower bound
  # @param max [Object] the upper bound
  # @param include_min [Boolean] whether to include the lower bound
  # @param include_max [Boolean] whether to include the upper bound
  # @yield [key, value] each matching key-value pair in descending order
  # @return [void]
  def traverse_between_desc(node, min, max, include_min, include_max, &block)
    return if node == @nil_node
    
    if (node.key <=> max) < 0
      traverse_between_desc(node.right, min, max, include_min, include_max, &block)
    end
    
    greater = include_min ? (node.key <=> min) >= 0 : (node.key <=> min) > 0
    less = include_max ? (node.key <=> max) <= 0 : (node.key <=> max) < 0
    
    if greater && less
      yield node.key, node.value
    end
    
    if (node.key <=> min) > 0
      traverse_between_desc(node.left, min, max, include_min, include_max, &block)
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
  def delete_node(key)
    z = @hash_index.delete(key)  # O(1) lookup and remove from index
    return nil unless z
    remove_node(z)
  end

  # Removes a node from the tree and restores red-black properties.
  #
  # Handles three cases:
  # 1. Node has no left child
  # 2. Node has no right child
  # 3. Node has both children (replace with inorder successor)
  #
  # @param z [Node] the node to remove
  # @return [Object] the value of the removed node
  def remove_node(z)
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

  # Searches for a node with the given key.
  #
  # @param key [Object] the key to search for
  # @return [Node] the found node, or @nil_node if not found
  def find_node(key)
    current = @root
    while current != @nil_node
      cmp = key <=> current.key
      if cmp == 0
        return current
      elsif cmp < 0
        current = current.left
      else
        current = current.right
      end
    end
    @nil_node
  end

  # Finds the node with the closest key to the given key.
  #
  # Uses numeric distance (absolute difference) to determine proximity.
  # If multiple nodes have the same distance, returns the one with the smaller key.
  #
  # @param key [Numeric] the target key
  # @return [Node] the nearest node, or @nil_node if tree is empty
  def find_nearest_node(key)
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
    # Check if key exists using O(1) hash lookup
    if (node = @hash_index[key])
      # Key exists: find predecessor in subtree or ancestors
      if node.left != @nil_node
        return rightmost(node.left)
      else
        # Walk up to find first ancestor where we came from the right
        current = node
        parent = current.parent
        while parent != @nil_node && current == parent.left
          current = parent
          parent = parent.parent
        end
        return parent
      end
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

  # Finds the node with the smallest key that is larger than the given key.
  #
  # If the key exists in the tree, returns its successor node.
  # If the key does not exist, returns the smallest node with key > given key.
  #
  # @param key [Object] the reference key
  # @return [Node] the successor node, or @nil_node if none exists
  def find_successor_node(key)
    # Check if key exists using O(1) hash lookup
    if (node = @hash_index[key])
      # Key exists: find successor in subtree or ancestors
      if node.right != @nil_node
        return leftmost(node.right)
      else
        # Walk up to find first ancestor where we came from the left
        current = node
        parent = current.parent
        while parent != @nil_node && current == parent.right
          current = parent
          parent = parent.parent
        end
        return parent
      end
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
    if (node = @node_pool.pop)
      node.key = key
      node.value = value
      node.color = color
      node.left = left
      node.right = right
      node.parent = parent
      node
    else
      Node.new(key, value, color, left, right, parent)
    end
  end

  # Releases a node back to the pool.
  # @param node [Node] the node to release
  def release_node(node)
    node.left = nil
    node.right = nil
    node.parent = nil
    node.value = nil # Help GC
    @node_pool << node
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
# * Separate methods for single deletion (`delete_one`) vs. all deletions (`delete`)
# * Values for each key maintain insertion order
# * Configurable access to first or last value via `:last` option
#
# == Value Array Access
#
# For each key, values are stored in insertion order. Methods that access
# a single value support a `:last` option to choose which end of the array:
#
# * +get(key)+, +get_first(key)+ - returns first value (oldest)
# * +get(key, last: true)+, +get_last(key)+ - returns last value (newest)
# * +delete_one(key)+, +delete_first(key)+ - removes first value
# * +delete_one(key, last: true)+, +delete_last(key)+ - removes last value
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
#   tree.get_all(1)       # => ["first one", "second one"] (all values)
#
#   tree.delete_one(1)    # removes only "first one"
#   tree.get(1)           # => "second one"
#
#   tree.delete(1)        # removes all remaining values for key 1
#
# @author Masahito Suzuki
# @since 0.1.2
class MultiRBTree < RBTree
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
  def get(key, last: false)
    n = find_node(key)
    return nil if n == @nil_node || n.value.empty?
    last ? n.value.last : n.value.first
  end

  # Retrieves the first value associated with the given key.
  #
  # @param key [Object] the key to look up
  # @return [Object, nil] the first value for the key, or nil if not found
  def get_first(key) = get(key, last: false)

  # Retrieves the last value associated with the given key.
  #
  # @param key [Object] the key to look up
  # @return [Object, nil] the last value for the key, or nil if not found
  def get_last(key) = get(key, last: true)

  # Returns the first value for the given key (for Hash-like access).
  #
  # Note: Unlike get(), this method does not accept options.
  #
  # @param key [Object] the key to look up
  # @return [Object, nil] the first value for the key, or nil if not found
  def [](key) = get(key)

  # Retrieves all values associated with the given key.
  #
  # @param key [Object] the key to look up
  # @return [Array, nil] an Array containing all values, or nil if not found
  # @example
  #   tree = MultiRBTree.new
  #   tree.insert(1, 'first')
  #   tree.insert(1, 'second')
  #   tree.get_all(1).to_a  # => ["first", "second"]
  def get_all(key)
    n = find_node(key)
    n == @nil_node || n.value.empty? ? nil : n.value
  end

  # Inserts a value for the given key.
  #
  # If the key already exists, the value is appended to its list.
  # If the key doesn't exist, a new node is created.
  #
  # @param key [Object] the key (must implement <=>)
  # @param value [Object] the value to insert
  # @return [Boolean] always returns true
  # @example
  #   tree = MultiRBTree.new
  #   tree.insert(1, 'first')
  #   tree.insert(1, 'second')  # adds another value for key 1
  def insert(key, value)
    if (node = @hash_index[key])
      node.value << value
      @size += 1
      return true
    end
    y = @nil_node
    x = @root
    while x != @nil_node
      y = x
      cmp = key <=> x.key
      if cmp == 0
        x.value << value
        @size += 1
        return true
      elsif cmp < 0
        x = x.left
      else
        x = x.right
      end
    end
    z = allocate_node(key, [value], Node::RED, @nil_node, @nil_node, @nil_node)
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
    @size += 1
    
    if @min_node == @nil_node || (key <=> @min_node.key) < 0
      @min_node = z
    end
    
    @hash_index[key] = z  # Add to hash index
    true
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
  #   tree.delete_one(1)              # => "first"
  #   tree.delete_one(1, last: true)  # => "second" (if more values existed)
  def delete_one(key, last: false)
    z = @hash_index[key]  # O(1) lookup
    return nil unless z

    value = last ? z.value.pop : z.value.shift
    @size -= 1
    if z.value.empty?
      @hash_index.delete(key)  # Remove from index when node removed
      remove_node(z)
    end
    value
  end

  # Deletes the first value for the specified key.
  #
  # @param key [Object] the key to delete from
  # @return [Object, nil] the deleted value, or nil if key not found
  def delete_first(key) = delete_one(key, last: false)

  # Deletes the last value for the specified key.
  #
  # @param key [Object] the key to delete from
  # @return [Object, nil] the deleted value, or nil if key not found
  def delete_last(key) = delete_one(key, last: true)

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
  def delete(key)
    z = @hash_index.delete(key)  # O(1) lookup and remove from index
    return nil unless z
    
    count = z.value.size
    remove_node(z)
    @size -= count
    z.value
  end

  def shift
    return nil if @min_node == @nil_node
    node = @min_node
    key = node.key
    val = node.value.first
    node.value.shift
    @size -= 1
    if node.value.empty?
      remove_node(node)
    end
    [key, val]
  end

  def pop
    n = rightmost(@root)
    return nil if n == @nil_node
    val = n.value.last
    n.value.pop
    @size -= 1
    if n.value.empty?
      remove_node(n)
    end
    [n.key, val]
  end

  def min(last: false)
    return nil if @min_node == @nil_node || @min_node.value.empty?
    [@min_node.key, last ? @min_node.value.last : @min_node.value.first]
  end

  def max(last: false)
    n = rightmost(@root)
    return nil if n == @nil_node || n.value.empty?
    [n.key, last ? n.value.last : n.value.first]
  end

  def nearest(key)
    n = find_nearest_node(key)
    n == @nil_node || n.value.empty? ? nil : [n.key, n.value.first]
  end

  def prev(key, last: false)
    n = find_predecessor_node(key)
    return nil if n == @nil_node || n.value.empty?
    [n.key, last ? n.value.last : n.value.first]
  end

  def succ(key, last: false)
    n = find_successor_node(key)
    return nil if n == @nil_node || n.value.empty?
    [n.key, last ? n.value.last : n.value.first]
  end

  private

  def traverse_asc(node, &block)
    stack = []
    current = node
    while current != @nil_node || !stack.empty?
      while current != @nil_node
        stack << current
        current = current.left
      end
      current = stack.pop
      current.value.each { |v| yield current.key, v }
      current = current.right
    end
  end

  def traverse_desc(node, &block)
    stack = []
    current = node
    while current != @nil_node || !stack.empty?
      while current != @nil_node
        stack << current
        current = current.right
      end
      current = stack.pop
      current.value.reverse_each { |v| yield current.key, v }
      current = current.left
    end
  end

  def traverse_lt(node, key, &block)
    return if node == @nil_node
    
    traverse_lt(node.left, key, &block)
    if (node.key <=> key) < 0
      node.value.each { |v| yield node.key, v }
      traverse_lt(node.right, key, &block)
    end
  end

  def traverse_lte(node, key, &block)
    return if node == @nil_node
    
    traverse_lte(node.left, key, &block)
    if (node.key <=> key) <= 0
      node.value.each { |v| yield node.key, v }
      traverse_lte(node.right, key, &block)
    end
  end

  def traverse_gt(node, key, &block)
    return if node == @nil_node
    
    if (node.key <=> key) > 0
      traverse_gt(node.left, key, &block)
      node.value.each { |v| yield node.key, v }
    end
    traverse_gt(node.right, key, &block)
  end

  def traverse_gte(node, key, &block)
    return if node == @nil_node
    
    if (node.key <=> key) >= 0
      traverse_gte(node.left, key, &block)
      node.value.each { |v| yield node.key, v }
    end
    traverse_gte(node.right, key, &block)
  end

  def traverse_between(node, min, max, include_min, include_max, &block)
    return if node == @nil_node
    if (node.key <=> min) > 0
      traverse_between(node.left, min, max, include_min, include_max, &block)
    end
    
    greater = include_min ? (node.key <=> min) >= 0 : (node.key <=> min) > 0
    less = include_max ? (node.key <=> max) <= 0 : (node.key <=> max) < 0
    
    if greater && less
      node.value.each { |v| yield node.key, v }
    end
    
    if (node.key <=> max) < 0
      traverse_between(node.right, min, max, include_min, include_max, &block)
    end
  end

  def traverse_lt_desc(node, key, &block)
    return if node == @nil_node
    
    if (node.key <=> key) < 0
      traverse_lt_desc(node.right, key, &block)
      node.value.reverse_each { |v| yield node.key, v }
    end
    traverse_lt_desc(node.left, key, &block)
  end

  def traverse_lte_desc(node, key, &block)
    return if node == @nil_node
    
    if (node.key <=> key) <= 0
      traverse_lte_desc(node.right, key, &block)
      node.value.reverse_each { |v| yield node.key, v }
    end
    traverse_lte_desc(node.left, key, &block)
  end

  def traverse_gt_desc(node, key, &block)
    return if node == @nil_node
    
    traverse_gt_desc(node.right, key, &block)
    if (node.key <=> key) > 0
      node.value.reverse_each { |v| yield node.key, v }
      traverse_gt_desc(node.left, key, &block)
    end
  end

  def traverse_gte_desc(node, key, &block)
    return if node == @nil_node
    
    traverse_gte_desc(node.right, key, &block)
    if (node.key <=> key) >= 0
      node.value.reverse_each { |v| yield node.key, v }
      traverse_gte_desc(node.left, key, &block)
    end
  end

  def traverse_between_desc(node, min, max, include_min, include_max, &block)
    return if node == @nil_node
    
    if (node.key <=> max) < 0
      traverse_between_desc(node.right, min, max, include_min, include_max, &block)
    end
    
    greater = include_min ? (node.key <=> min) >= 0 : (node.key <=> min) > 0
    less = include_max ? (node.key <=> max) <= 0 : (node.key <=> max) < 0
    
    if greater && less
      node.value.reverse_each { |v| yield node.key, v }
    end
    
    if (node.key <=> min) > 0
      traverse_between_desc(node.left, min, max, include_min, include_max, &block)
    end
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

  # Checks if the node is red.
  # @return [Boolean] true if red, false otherwise
  def red? = @color == RED
  
  # Checks if the node is black.
  # @return [Boolean] true if black, false otherwise
  def black? = @color == BLACK
end
