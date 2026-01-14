require 'minitest/autorun'
require_relative '../lib/rbtree'

class TestRBTree < Minitest::Test
  def setup
    @tree = RBTree.new
  end

  # ============================================================
  # Initialization Tests
  # ============================================================

  def test_initialize
    tree = RBTree.new
    assert_empty tree
    assert_equal 0, tree.size

    tree = RBTree.new({1 => 'a', 2 => 'b'})
    assert_equal 2, tree.size
    assert_equal 'a', tree[1]
  end

  def test_initialize_from_array
    tree = RBTree.new([[3, 'three'], [1, 'one'], [2, 'two']])
    assert_equal 3, tree.size
    assert_equal 'one', tree[1]
    assert_equal 'two', tree[2]
    assert_equal 'three', tree[3]
    # Verify sorted order
    assert_equal [[1, 'one'], [2, 'two'], [3, 'three']], tree.to_a
  end

  def test_initialize_invalid_args
    assert_raises(ArgumentError) { RBTree.new("invalid") }
    assert_raises(ArgumentError) { RBTree.new(123) }
  end

  def test_bracket_syntax
    tree = RBTree[1 => 'one', 2 => 'two', 3 => 'three']
    assert_equal 3, tree.size
    assert_equal 'one', tree[1]
  end

  # ============================================================
  # Empty Tree Edge Cases
  # ============================================================

  def test_operations_on_empty_tree
    assert_empty @tree
    assert_equal 0, @tree.size
    assert_nil @tree.min
    assert_nil @tree.max
    assert_nil @tree.shift
    assert_nil @tree.pop
    assert_nil @tree.get(1)
    assert_nil @tree[1]
    assert_nil @tree.delete(1)
    assert_nil @tree.prev(1)
    assert_nil @tree.succ(1)
    assert_nil @tree.nearest(1)
    refute @tree.has_key?(1)
    
    # Range queries on empty tree
    assert_equal [], @tree.lt(10).to_a
    assert_equal [], @tree.lte(10).to_a
    assert_equal [], @tree.gt(0).to_a
    assert_equal [], @tree.gte(0).to_a
    assert_equal [], @tree.between(0, 10).to_a
    
    # Iteration on empty tree
    results = []
    @tree.each { |k, v| results << [k, v] }
    assert_equal [], results
    
    # Valid should return true
    assert @tree.valid?
  end

  # ============================================================
  # Single Element Operations
  # ============================================================

  def test_single_element_operations
    @tree[42] = 'answer'
    
    assert_equal 1, @tree.size
    refute_empty @tree
    assert_equal 'answer', @tree[42]
    assert_equal [42, 'answer'], @tree.min
    assert_equal [42, 'answer'], @tree.max
    assert @tree.has_key?(42)
    refute @tree.has_key?(1)
    
    # prev/succ on single element
    assert_nil @tree.prev(42)
    assert_nil @tree.succ(42)
    
    # nearest on single element
    assert_equal [42, 'answer'], @tree.nearest(0)
    assert_equal [42, 'answer'], @tree.nearest(100)
    assert_equal [42, 'answer'], @tree.nearest(42)
    
    # shift removes the only element
    result = @tree.shift
    assert_equal [42, 'answer'], result
    assert_empty @tree
    
    # pop on now-empty tree
    assert_nil @tree.pop
    
    # Re-add and test pop
    @tree[42] = 'answer'
    result = @tree.pop
    assert_equal [42, 'answer'], result
    assert_empty @tree
  end

  # ============================================================
  # Insert and Access Tests
  # ============================================================

  def test_insert_and_access
    @tree[1] = 'one'
    @tree.insert(2, 'two')
    
    assert_equal 'one', @tree[1]
    assert_equal 'two', @tree.get(2)
    assert_nil @tree[3]

    @tree[1] = 'ONE'
    assert_equal 'ONE', @tree[1]
    assert_equal 2, @tree.size
  end

  def test_insert_overwrite_false
    @tree.insert(1, 'first')
    result = @tree.insert(1, 'second', overwrite: false)
    assert_nil result
    assert_equal 'first', @tree[1]
    assert_equal 1, @tree.size
    
    # Overwrite true (default)
    result = @tree.insert(1, 'third')
    assert_equal true, result
    assert_equal 'third', @tree[1]
  end

  def test_insert_nil_value
    @tree[1] = nil
    assert_equal 1, @tree.size
    assert_nil @tree[1]
    assert @tree.has_key?(1)
  end

  def test_update_existing_key
    @tree[1] = 'original'
    @tree[1] = 'updated'
    assert_equal 1, @tree.size
    assert_equal 'updated', @tree[1]
  end

  # ============================================================
  # Delete Tests
  # ============================================================

  def test_delete
    @tree[1] = 'one'
    @tree[2] = 'two'
    @tree[3] = 'three'

    assert_equal 'two', @tree.delete(2)
    assert_nil @tree[2]
    assert_equal 2, @tree.size

    assert_nil @tree.delete(999)
    
    @tree.clear
    @tree[1] = 'one'
    assert_equal 'one', @tree.delete(1)
    assert_empty @tree
  end

  def test_delete_min_element
    (1..10).each { |i| @tree[i] = "val#{i}" }
    
    deleted = @tree.delete(1)
    assert_equal 'val1', deleted
    assert_equal [2, 'val2'], @tree.min
    assert_equal 9, @tree.size
    assert @tree.valid?
  end

  def test_delete_max_element
    (1..10).each { |i| @tree[i] = "val#{i}" }
    
    deleted = @tree.delete(10)
    assert_equal 'val10', deleted
    assert_equal [9, 'val9'], @tree.max
    assert_equal 9, @tree.size
    assert @tree.valid?
  end

  def test_delete_root
    # Build a tree and delete root multiple times
    (1..7).each { |i| @tree[i] = "val#{i}" }
    
    initial_size = @tree.size
    root_key = @tree.to_a[@tree.size / 2][0]
    
    @tree.delete(root_key)
    assert_equal initial_size - 1, @tree.size
    assert @tree.valid?
  end

  def test_delete_all_elements_one_by_one
    keys = (1..100).to_a.shuffle
    keys.each { |k| @tree[k] = "val#{k}" }
    
    keys.shuffle.each do |k|
      @tree.delete(k)
      assert @tree.valid?, "Tree should be valid after deleting key #{k}"
    end
    
    assert_empty @tree
  end

  # ============================================================
  # Clear and Empty Tests
  # ============================================================

  def test_clear_empty
    @tree[1] = 'one'
    refute_empty @tree
    @tree.clear
    assert_empty @tree
    assert_equal 0, @tree.size
  end

  # ============================================================
  # Min/Max Tests
  # ============================================================

  def test_min_max
    assert_nil @tree.min
    assert_nil @tree.max

    @tree[10] = 'ten'
    @tree[5] = 'five'
    @tree[20] = 'twenty'

    assert_equal [5, 'five'], @tree.min
    assert_equal [20, 'twenty'], @tree.max
  end

  def test_min_max_with_negative_keys
    @tree[-10] = 'neg_ten'
    @tree[0] = 'zero'
    @tree[10] = 'ten'
    
    assert_equal [-10, 'neg_ten'], @tree.min
    assert_equal [10, 'ten'], @tree.max
  end

  # ============================================================
  # Shift and Pop Tests
  # ============================================================

  def test_shift_pop
    @tree[10] = 'ten'
    @tree[5] = 'five'
    @tree[20] = 'twenty'

    assert_equal [5, 'five'], @tree.shift
    assert_equal [10, 'ten'], @tree.min
    assert_equal 2, @tree.size

    assert_equal [20, 'twenty'], @tree.pop
    assert_equal [10, 'ten'], @tree.max
    assert_equal 1, @tree.size

    @tree.shift
    assert_nil @tree.shift
    assert_nil @tree.pop
  end

  def test_shift_until_empty
    (1..10).each { |i| @tree[i] = "val#{i}" }
    
    10.times do |i|
      result = @tree.shift
      assert_equal [i + 1, "val#{i + 1}"], result
      assert @tree.valid?
    end
    
    assert_empty @tree
    assert_nil @tree.shift
  end

  def test_pop_until_empty
    (1..10).each { |i| @tree[i] = "val#{i}" }
    
    10.downto(1) do |i|
      result = @tree.pop
      assert_equal [i, "val#{i}"], result
      assert @tree.valid?
    end
    
    assert_empty @tree
    assert_nil @tree.pop
  end

  def test_mixed_shift_pop
    (1..10).each { |i| @tree[i] = "val#{i}" }
    
    assert_equal [1, 'val1'], @tree.shift
    assert_equal [10, 'val10'], @tree.pop
    assert_equal [2, 'val2'], @tree.shift
    assert_equal [9, 'val9'], @tree.pop
    
    assert_equal 6, @tree.size
    assert_equal [3, 'val3'], @tree.min
    assert_equal [8, 'val8'], @tree.max
    assert @tree.valid?
  end

  # ============================================================
  # Nearest Tests
  # ============================================================

  def test_nearest
    @tree[10] = 'ten'
    @tree[20] = 'twenty'
    @tree[30] = 'thirty'

    assert_equal [10, 'ten'], @tree.nearest(10)
    assert_equal [10, 'ten'], @tree.nearest(14)
    assert_equal [10, 'ten'], @tree.nearest(15)
    assert_equal [20, 'twenty'], @tree.nearest(16)
    
    assert_equal [10, 'ten'], @tree.nearest(0)
    assert_equal [30, 'thirty'], @tree.nearest(100)
  end

  def test_nearest_equidistant
    @tree[10] = 'ten'
    @tree[20] = 'twenty'
    
    # When equidistant, should return smaller key
    result = @tree.nearest(15)
    assert_equal [10, 'ten'], result
  end

  def test_nearest_edge_cases
    @tree[100] = 'hundred'
    
    # Far below
    assert_equal [100, 'hundred'], @tree.nearest(-1000)
    # Far above
    assert_equal [100, 'hundred'], @tree.nearest(10000)
    # Exact match
    assert_equal [100, 'hundred'], @tree.nearest(100)
  end

  def test_nearest_with_negative_keys
    @tree[-20] = 'neg_twenty'
    @tree[-10] = 'neg_ten'
    @tree[10] = 'ten'
    
    assert_equal [-10, 'neg_ten'], @tree.nearest(-5)
    assert_equal [-10, 'neg_ten'], @tree.nearest(-10)
    assert_equal [-20, 'neg_twenty'], @tree.nearest(-100)
  end

  # ============================================================
  # Prev/Succ Tests
  # ============================================================

  def test_prev_succ
    @tree[10] = 'ten'
    @tree[20] = 'twenty'

    assert_equal [10, 'ten'], @tree.prev(20)
    assert_nil @tree.prev(10)
    assert_equal [10, 'ten'], @tree.prev(15)

    assert_equal [20, 'twenty'], @tree.succ(10)
    assert_nil @tree.succ(20)
    assert_equal [20, 'twenty'], @tree.succ(15)
  end

  def test_prev_succ_edge_cases
    @tree[1] = 'one'
    @tree[5] = 'five'
    @tree[10] = 'ten'
    
    # Edge: no predecessor for min
    assert_nil @tree.prev(1)
    # Edge: no successor for max
    assert_nil @tree.succ(10)
    
    # Non-existent key below min
    assert_nil @tree.prev(0)
    assert_equal [1, 'one'], @tree.succ(0)
    
    # Non-existent key above max
    assert_equal [10, 'ten'], @tree.prev(100)
    assert_nil @tree.succ(100)
  end

  def test_prev_succ_non_existent_keys
    @tree[10] = 'ten'
    @tree[30] = 'thirty'
    @tree[50] = 'fifty'
    
    # Key 20 doesn't exist
    assert_equal [10, 'ten'], @tree.prev(20)
    assert_equal [30, 'thirty'], @tree.succ(20)
    
    # Key 40 doesn't exist
    assert_equal [30, 'thirty'], @tree.prev(40)
    assert_equal [50, 'fifty'], @tree.succ(40)
  end

  # ============================================================
  # Range Query Tests
  # ============================================================

  def test_range_queries_basic
    (1..5).each { |i| @tree[i] = i.to_s }

    assert_equal [[1, '1'], [2, '2']], @tree.lt(3).to_a
    assert_equal [[1, '1'], [2, '2'], [3, '3']], @tree.lte(3).to_a
    assert_equal [[4, '4'], [5, '5']], @tree.gt(3).to_a
    assert_equal [[3, '3'], [4, '4'], [5, '5']], @tree.gte(3).to_a
    assert_equal [[2, '2'], [3, '3'], [4, '4']], @tree.between(2, 4).to_a
  end

  def test_range_queries_reverse
    (1..5).each { |i| @tree[i] = i.to_s }

    assert_equal [[2, '2'], [1, '1']], @tree.lt(3, reverse: true).to_a
    assert_equal [[4, '4'], [3, '3'], [2, '2']], @tree.between(2, 4, reverse: true).to_a
  end

  def test_range_queries_safe
    (1..5).each { |i| @tree[i] = i.to_s }
    
    @tree.lt(4, safe: true) do |k, v|
      @tree.delete(k) if k.even?
    end

    assert_nil @tree[2]
    assert_equal '1', @tree[1]
    assert_equal '3', @tree[3]
    assert_equal '4', @tree[4]
  end

  def test_range_beyond_bounds
    (10..20).each { |i| @tree[i] = "val#{i}" }
    
    # All elements less than min
    assert_equal [], @tree.lt(5).to_a
    assert_equal [], @tree.lte(5).to_a
    
    # All elements greater than max
    assert_equal [], @tree.gt(100).to_a
    assert_equal [], @tree.gte(100).to_a
    
    # Range outside bounds
    assert_equal [], @tree.between(0, 5).to_a
    assert_equal [], @tree.between(100, 200).to_a
  end

  def test_between_exclusive
    (1..5).each { |i| @tree[i] = i.to_s }
    
    # Exclusive on both ends
    result = @tree.between(2, 4, include_min: false, include_max: false).to_a
    assert_equal [[3, '3']], result
    
    # Exclusive on min only
    result = @tree.between(2, 4, include_min: false, include_max: true).to_a
    assert_equal [[3, '3'], [4, '4']], result
    
    # Exclusive on max only
    result = @tree.between(2, 4, include_min: true, include_max: false).to_a
    assert_equal [[2, '2'], [3, '3']], result
  end

  def test_range_single_element
    @tree[5] = 'five'
    
    assert_equal [[5, 'five']], @tree.gte(5).to_a
    assert_equal [[5, 'five']], @tree.lte(5).to_a
    assert_equal [[5, 'five']], @tree.between(5, 5).to_a
    assert_equal [], @tree.lt(5).to_a
    assert_equal [], @tree.gt(5).to_a
  end

  def test_enumerator_return
    assert_instance_of Enumerator, @tree.lt(10)
  end

  def test_range_enumerator_lazy_evaluation
    (1..100).each { |i| @tree[i] = "val#{i}" }
    
    # Take only first 3 elements (lazy)
    result = @tree.gt(0).take(3)
    assert_equal [[1, 'val1'], [2, 'val2'], [3, 'val3']], result
    
    # first should also work
    assert_equal [1, 'val1'], @tree.gt(0).first
    assert_equal [100, 'val100'], @tree.lt(101, reverse: true).first
  end

  # ============================================================
  # Iteration Tests
  # ============================================================

  def test_each_ascending
    (1..5).each { |i| @tree[i] = "val#{i}" }
    
    results = []
    @tree.each { |k, v| results << [k, v] }
    
    assert_equal [[1, 'val1'], [2, 'val2'], [3, 'val3'], [4, 'val4'], [5, 'val5']], results
  end

  def test_each_descending
    (1..5).each { |i| @tree[i] = "val#{i}" }
    
    results = []
    @tree.each(reverse: true) { |k, v| results << [k, v] }
    
    assert_equal [[5, 'val5'], [4, 'val4'], [3, 'val3'], [2, 'val2'], [1, 'val1']], results
  end

  def test_reverse_each
    (1..5).each { |i| @tree[i] = "val#{i}" }
    
    results = []
    @tree.reverse_each { |k, v| results << [k, v] }
    
    assert_equal [[5, 'val5'], [4, 'val4'], [3, 'val3'], [2, 'val2'], [1, 'val1']], results
  end

  def test_safe_iteration_delete_all
    (1..10).each { |i| @tree[i] = "val#{i}" }
    
    @tree.each(safe: true) do |k, v|
      @tree.delete(k)
    end
    
    assert_empty @tree
  end

  def test_safe_iteration_modification_during_traverse
    (1..10).each { |i| @tree[i] = "val#{i}" }
    
    visited = []
    @tree.each(safe: true) do |k, v|
      visited << k
      @tree.delete(k + 1) if k.odd? && @tree.has_key?(k + 1)
    end
    
    # Odd keys should be visited, even keys may or may not depending on when deleted
    assert_includes visited, 1
    assert_includes visited, 3
    assert_includes visited, 5
  end

  # ============================================================
  # Different Key Types Tests
  # ============================================================

  def test_string_keys
    @tree['apple'] = 1
    @tree['banana'] = 2
    @tree['cherry'] = 3
    
    assert_equal 3, @tree.size
    assert_equal 1, @tree['apple']
    assert_equal ['apple', 1], @tree.min
    assert_equal ['cherry', 3], @tree.max
    
    # Range queries
    assert_equal [['apple', 1], ['banana', 2]], @tree.lt('cherry').to_a
    assert @tree.valid?
  end

  def test_negative_number_keys
    @tree[-100] = 'neg_hundred'
    @tree[-50] = 'neg_fifty'
    @tree[0] = 'zero'
    @tree[50] = 'fifty'
    @tree[100] = 'hundred'
    
    assert_equal [-100, 'neg_hundred'], @tree.min
    assert_equal [100, 'hundred'], @tree.max
    
    result = @tree.between(-50, 50).to_a
    assert_equal [[-50, 'neg_fifty'], [0, 'zero'], [50, 'fifty']], result
    
    assert @tree.valid?
  end

  def test_float_keys
    @tree[1.5] = 'one_half'
    @tree[2.5] = 'two_half'
    @tree[3.5] = 'three_half'
    
    assert_equal [1.5, 'one_half'], @tree.min
    assert_equal [3.5, 'three_half'], @tree.max
    assert_equal [2.5, 'two_half'], @tree.nearest(2.4)
    assert @tree.valid?
  end

  def test_custom_comparable_keys
    # Using Time objects as keys
    t1 = Time.new(2025, 1, 1)
    t2 = Time.new(2025, 6, 1)
    t3 = Time.new(2025, 12, 1)
    
    @tree[t2] = 'mid'
    @tree[t1] = 'early'
    @tree[t3] = 'late'
    
    assert_equal [t1, 'early'], @tree.min
    assert_equal [t3, 'late'], @tree.max
    assert @tree.valid?
  end

  # ============================================================
  # has_key? Tests
  # ============================================================

  def test_has_key_basic
    @tree[1] = 'one'
    @tree[3] = 'three'
    
    assert @tree.has_key?(1)
    assert @tree.has_key?(3)
    refute @tree.has_key?(2)
    refute @tree.has_key?(0)
  end

  def test_has_key_after_delete
    @tree[1] = 'one'
    assert @tree.has_key?(1)
    
    @tree.delete(1)
    refute @tree.has_key?(1)
  end

  # ============================================================
  # Inspect Tests
  # ============================================================

  def test_inspect_empty
    result = @tree.inspect
    assert_match(/RBTree/, result)
  end

  def test_inspect_small
    @tree[1] = 'one'
    @tree[2] = 'two'
    
    result = @tree.inspect
    assert_match(/size=2/, result)
    assert_match(/1=>/, result)
    assert_match(/2=>/, result)
  end

  def test_inspect_large
    (1..10).each { |i| @tree[i] = "val#{i}" }
    
    result = @tree.inspect
    assert_match(/size=10/, result)
    assert_match(/\.\.\./, result)  # Should be truncated
  end

  # ============================================================
  # Tree Validity Tests
  # ============================================================

  def test_valid_after_sequential_insert
    (1..100).each do |i|
      @tree[i] = "val#{i}"
      assert @tree.valid?, "Tree should be valid after inserting #{i}"
    end
  end

  def test_valid_after_random_insert
    keys = (1..100).to_a.shuffle
    keys.each do |k|
      @tree[k] = "val#{k}"
      assert @tree.valid?, "Tree should be valid after inserting #{k}"
    end
  end

  def test_valid_after_random_delete
    (1..100).each { |i| @tree[i] = "val#{i}" }
    
    keys = (1..100).to_a.shuffle
    keys.each do |k|
      @tree.delete(k)
      assert @tree.valid?, "Tree should be valid after deleting #{k}"
    end
  end

  def test_large_dataset_validity
    expected = {}
    1000.times do
      k = rand(10000)
      v = "val_#{k}"
      @tree[k] = v
      expected[k] = v
    end

    assert @tree.valid?, "Tree should be valid RBTree after insertions"
    assert_equal expected.size, @tree.size
    
    expected.keys.sample(500).each do |k|
      @tree.delete(k)
      expected.delete(k)
    end

    assert @tree.valid?, "Tree should be valid RBTree after deletions"
    assert_equal expected.size, @tree.size
    
    expected.each do |k, v|
      assert_equal v, @tree[k]
    end
  end

  # ============================================================
  # Stress Tests
  # ============================================================

  def test_large_sequential_insert_delete
    n = 5000
    
    # Sequential insert
    (1..n).each { |i| @tree[i] = "val#{i}" }
    assert_equal n, @tree.size
    assert @tree.valid?
    
    # Sequential delete
    (1..n).each { |i| @tree.delete(i) }
    assert_empty @tree
    assert @tree.valid?
  end

  def test_large_random_insert_delete
    n = 5000
    keys = (1..n).to_a.shuffle
    
    # Random insert
    keys.each { |k| @tree[k] = "val#{k}" }
    assert_equal n, @tree.size
    assert @tree.valid?
    
    # Random delete
    keys.shuffle!
    keys.each { |k| @tree.delete(k) }
    assert_empty @tree
    assert @tree.valid?
  end

  def test_alternating_insert_delete
    inserted = []
    
    1000.times do |i|
      key = rand(10000)
      @tree[key] = "val#{key}"
      inserted << key
      
      if i > 100 && rand < 0.5
        to_delete = inserted.sample
        @tree.delete(to_delete)
        inserted.delete_at(inserted.index(to_delete) || inserted.length)
      end
    end
    
    assert @tree.valid?
  end

  def test_zigzag_operations
    # Insert in zigzag pattern (1, 100, 2, 99, 3, 98, ...)
    keys = []
    (1..50).each do |i|
      keys << i
      keys << (101 - i)
    end
    
    keys.each { |k| @tree[k] = "val#{k}" }
    assert_equal 100, @tree.size
    assert @tree.valid?
    
    # Verify order
    sorted_keys = @tree.to_a.map(&:first)
    assert_equal (1..100).to_a, sorted_keys
  end

  def test_repeated_min_max_delete
    (1..100).each { |i| @tree[i] = "val#{i}" }
    
    50.times do
      @tree.shift
      @tree.pop
    end
    
    assert_empty @tree
    assert @tree.valid?
  end

  def test_stress_range_queries
    (1..1000).each { |i| @tree[i] = "val#{i}" }
    
    100.times do
      low = rand(1..500)
      high = low + rand(1..500)
      
      result = @tree.between(low, high).to_a
      expected_keys = (low..high).to_a.select { |k| k <= 1000 }
      actual_keys = result.map(&:first)
      
      assert_equal expected_keys, actual_keys
    end
  end

  # ============================================================
  # Bulk Insert Tests
  # ============================================================

  def test_bulk_insert_key_value
    @tree.insert(1, "one")
    assert_equal 1, @tree.size
    assert_equal "one", @tree[1]
  end

  def test_bulk_insert_key_value_overwrite_false
    @tree.insert(1, "one")
    @tree.insert(1, "uno", overwrite: false)
    assert_equal "one", @tree[1]
  end

  def test_bulk_insert_hash
    @tree.insert({1 => "one", 2 => "two"})
    assert_equal 2, @tree.size
    assert_equal "one", @tree[1]
    assert_equal "two", @tree[2]
  end

  def test_bulk_insert_hash_overwrite_false
    @tree.insert({1 => "one"})
    @tree.insert({1 => "uno", 2 => "two"}, overwrite: false)
    assert_equal "one", @tree[1]
    assert_equal "two", @tree[2]
  end

  def test_bulk_insert_array_pairs
    @tree.insert([[1, "one"], [2, "two"]])
    assert_equal 2, @tree.size
    assert_equal "one", @tree[1]
  end

  def test_bulk_insert_array_pairs_duplicates_overwrite_true
    @tree.insert([[1, "one"], [1, "uno"]])
    assert_equal 1, @tree.size
    assert_equal "uno", @tree[1]
  end

  def test_bulk_insert_array_pairs_duplicates_overwrite_false
    @tree.insert([[1, "one"], [1, "uno"]], overwrite: false)
    assert_equal 1, @tree.size
    assert_equal "one", @tree[1]
  end

  def test_bulk_insert_enumerator
    enum = {1 => "one", 2 => "two"}.each
    @tree.insert(enum)
    assert_equal 2, @tree.size
    assert_equal "one", @tree[1]
  end

  def test_bulk_insert_block
    @tree.insert { [[1, "one"]] }
    assert_equal 1, @tree.size
    assert_equal "one", @tree[1]
  end

  def test_bulk_insert_nil_noop
    @tree.insert(nil)
    assert_empty @tree
  end

  def test_bulk_insert_no_args_noop
    @tree.insert
    assert_empty @tree
  end

  def test_bulk_insert_block_nil_noop
    @tree.insert { nil }
    assert_empty @tree
  end

  def test_bulk_insert_error_non_iterable
    assert_raises(ArgumentError) { @tree.insert(123) }
  end

  def test_bulk_insert_error_flat_array
    assert_raises(ArgumentError) { @tree.insert([1]) }
  end

  def test_bulk_insert_error_invalid_pair_size
    assert_raises(ArgumentError) { @tree.insert([[1]]) }
  end

  def test_bulk_insert_error_too_many_args
    assert_raises(ArgumentError) { @tree.insert(1, 2, 3) }
  end

  def test_initialize_bulk_hash
    tree = RBTree.new({1 => "one"})
    assert_equal "one", tree[1]
  end

  def test_initialize_bulk_array
    tree = RBTree.new([[1, "one"]])
    assert_equal "one", tree[1]
  end

  def test_initialize_block
    tree = RBTree.new { [[1, "one"]] }
    assert_equal "one", tree[1]
  end

  def test_initialize_overwrite_false
    tree = RBTree.new([[1, "one"], [1, "uno"]], overwrite: false)
    assert_equal "one", tree[1]
  end
end

# ============================================================
# MultiRBTree Tests
# ============================================================

class TestMultiRBTree < Minitest::Test
  def setup
    @tree = MultiRBTree.new
  end

  # ============================================================
  # Empty Tree Operations
  # ============================================================

  def test_multi_empty_tree_operations
    assert_empty @tree
    assert_equal 0, @tree.size
    assert_nil @tree.min
    assert_nil @tree.max
    assert_nil @tree.shift
    assert_nil @tree.pop
    assert_nil @tree.get(1)
    assert_nil @tree.get_first(1)
    assert_nil @tree.get_last(1)
    assert_nil @tree.delete(1)
    assert_nil @tree.delete_one(1)
    
    # get_all returns nil for non-existent
    result = []
    @tree.get_all(1) { |v| result << v }
    assert_equal [], result
  end

  # ============================================================
  # Duplicate Key Tests
  # ============================================================

  def test_duplicate_keys
    @tree.insert(1, 'first')
    @tree.insert(1, 'second')
    @tree.insert(2, 'apple')

    assert_equal 3, @tree.size
    assert_equal 'first', @tree.get(1)
    assert_equal ['first', 'second'], @tree.get_all(1).to_a
  end

  def test_many_values_same_key
    100.times { |i| @tree.insert(1, "val#{i}") }
    
    assert_equal 100, @tree.size
    assert_equal 'val0', @tree.get_first(1)
    assert_equal 'val99', @tree.get_last(1)
    assert_equal 100, @tree.get_all(1).to_a.size
    assert @tree.valid?
  end

  # ============================================================
  # Get Operations
  # ============================================================

  def test_get_last_first
    @tree.insert(1, 'first')
    @tree.insert(1, 'second')

    assert_equal 'first', @tree.get_first(1)
    assert_equal 'second', @tree.get_last(1)
    
    assert_equal 'first', @tree.get(1)
    assert_equal 'second', @tree.get(1, last: true)
  end

  def test_get_all_enumerator
    @tree.insert(1, 'a')
    @tree.insert(1, 'b')
    @tree.insert(1, 'c')
    
    enum = @tree.get_all(1)
    assert_instance_of Enumerator, enum
    assert_equal ['a', 'b', 'c'], enum.to_a
  end

  def test_get_all_empty_key
    @tree.insert(1, 'val')
    
    result = []
    @tree.get_all(999) { |v| result << v }
    assert_equal [], result
  end

  # ============================================================
  # Delete Operations
  # ============================================================

  def test_delete_one_all
    @tree.insert(1, 'first')
    @tree.insert(1, 'second')
    @tree.insert(1, 'third')

    assert_equal 'first', @tree.delete_one(1)
    assert_equal ['second', 'third'], @tree.get_all(1).to_a
    assert_equal 2, @tree.size

    assert_equal 'third', @tree.delete_last(1)
    assert_equal ['second'], @tree.get_all(1).to_a
    
    @tree.insert(1, 'fourth')
    @tree.delete(1)
    assert_nil @tree.get(1)
    assert_equal 0, @tree.size
  end

  def test_delete_first_last
    @tree.insert(1, 'a')
    @tree.insert(1, 'b')
    @tree.insert(1, 'c')
    
    assert_equal 'a', @tree.delete_first(1)
    assert_equal 'c', @tree.delete_last(1)
    assert_equal ['b'], @tree.get_all(1).to_a
    assert_equal 1, @tree.size
  end

  def test_delete_one_order
    @tree.insert(1, 'a')
    @tree.insert(1, 'b')
    @tree.insert(1, 'c')
    
    # Default deletes first
    assert_equal 'a', @tree.delete_one(1)
    assert_equal 'b', @tree.delete_one(1)
    assert_equal 'c', @tree.delete_one(1)
    assert_nil @tree.delete_one(1)
    assert_empty @tree
  end

  def test_delete_nonexistent
    @tree.insert(1, 'val')
    
    assert_nil @tree.delete(999)
    assert_nil @tree.delete_one(999)
    assert_nil @tree.delete_first(999)
    assert_nil @tree.delete_last(999)
    assert_equal 1, @tree.size
  end

  # ============================================================
  # Iteration Tests
  # ============================================================

  def test_iteration
    @tree.insert(1, 'a1')
    @tree.insert(1, 'a2')
    @tree.insert(2, 'b1')
    
    res = []
    @tree.each { |k, v| res << [k, v] }
    assert_equal [[1, 'a1'], [1, 'a2'], [2, 'b1']], res
  end
  
  def test_reverse_iteration
    @tree.insert(1, 'a1')
    @tree.insert(1, 'a2')
    @tree.insert(2, 'b1')

    res = []
    @tree.reverse_each { |k, v| res << [k, v] } 
    assert_equal [[2, 'b1'], [1, 'a2'], [1, 'a1']], res
  end

  def test_multi_each_value_order
    @tree.insert(1, 'x')
    @tree.insert(1, 'y')
    @tree.insert(1, 'z')
    @tree.insert(2, 'a')
    @tree.insert(2, 'b')
    
    results = []
    @tree.each { |k, v| results << [k, v] }
    
    # Forward: values in insertion order
    assert_equal [
      [1, 'x'], [1, 'y'], [1, 'z'],
      [2, 'a'], [2, 'b']
    ], results
  end

  def test_multi_reverse_each_value_order
    @tree.insert(1, 'x')
    @tree.insert(1, 'y')
    @tree.insert(1, 'z')
    @tree.insert(2, 'a')
    @tree.insert(2, 'b')
    
    results = []
    @tree.reverse_each { |k, v| results << [k, v] }
    
    # Reverse: values in reverse insertion order
    assert_equal [
      [2, 'b'], [2, 'a'],
      [1, 'z'], [1, 'y'], [1, 'x']
    ], results
  end

  def test_safe_iteration_expansion
    @tree.insert(1, 'a1')
    @tree.insert(1, 'a2')

    res = []
    @tree.each(safe: true) { |k, v| res << v }
    assert_equal ['a1', 'a2'], res
    
    @tree.each(safe: true) do |k, v|
      @tree.delete(2)
    end
  end

  def test_multi_safe_iteration
    @tree.insert(1, 'a')
    @tree.insert(1, 'b')
    @tree.insert(2, 'c')
    @tree.insert(3, 'd')
    
    visited = []
    @tree.each(safe: true) do |k, v|
      visited << [k, v]
      @tree.delete(2) if k == 1
    end
    
    # Key 2 deleted, but iteration continues
    assert_includes visited.map(&:first), 1
    assert_includes visited.map(&:first), 3
  end

  # ============================================================
  # Min/Max Tests
  # ============================================================
  
  def test_min_max_multi
    @tree.insert(1, 'min1')
    @tree.insert(1, 'min2')
    @tree.insert(5, 'max1')
    @tree.insert(5, 'max2')

    assert_equal [1, 'min1'], @tree.min
    assert_equal [1, 'min2'], @tree.min(last: true)
    
    assert_equal [5, 'max1'], @tree.max
    assert_equal [5, 'max1'], @tree.max(last: false)
  end

  # ============================================================
  # Shift/Pop Tests
  # ============================================================

  def test_multi_shift_pop_comprehensive
    @tree.insert(1, 'a')
    @tree.insert(1, 'b')
    @tree.insert(10, 'x')
    @tree.insert(10, 'y')
    
    # shift removes first value of min key
    assert_equal [1, 'a'], @tree.shift
    assert_equal 3, @tree.size
    assert_equal [1, 'b'], @tree.min
    
    # pop removes last value of max key
    assert_equal [10, 'y'], @tree.pop
    assert_equal 2, @tree.size
    assert_equal [10, 'x'], @tree.max
    
    # Continue until empty
    assert_equal [1, 'b'], @tree.shift
    assert_equal [10, 'x'], @tree.pop
    assert_empty @tree
  end

  def test_shift_last_value
    @tree.insert(1, 'only')
    
    result = @tree.shift
    assert_equal [1, 'only'], result
    assert_empty @tree
    refute @tree.has_key?(1)  # hash_index should be cleared
  end

  def test_pop_first_value
    @tree.insert(1, 'only')
    
    result = @tree.pop
    assert_equal [1, 'only'], result
    assert_empty @tree
  end

  # ============================================================
  # prev/succ Tests
  # ============================================================

  def test_multi_prev_succ_with_last
    @tree.insert(1, 'a')
    @tree.insert(1, 'b')
    @tree.insert(3, 'x')
    @tree.insert(3, 'y')
    
    # prev returns first value by default
    assert_equal [1, 'a'], @tree.prev(3)
    # prev with last: true returns last value
    assert_equal [1, 'b'], @tree.prev(3, last: true)
    
    # succ returns first value by default
    assert_equal [3, 'x'], @tree.succ(1)
    # succ with last: true returns last value
    assert_equal [3, 'y'], @tree.succ(1, last: true)
  end

  # ============================================================
  # nearest Tests
  # ============================================================

  def test_multi_nearest_with_last
    @tree.insert(10, 'a')
    @tree.insert(10, 'b')
    @tree.insert(20, 'x')
    @tree.insert(20, 'y')
    
    assert_equal [10, 'a'], @tree.nearest(12)
    assert_equal [10, 'b'], @tree.nearest(12, last: true)
  end

  # ============================================================
  # Range Query Tests
  # ============================================================

  def test_multi_lt_lte_gt_gte
    @tree.insert(1, 'a')
    @tree.insert(1, 'b')
    @tree.insert(3, 'x')
    @tree.insert(5, 'p')
    @tree.insert(5, 'q')
    
    # lt(3) should include all values for key 1
    assert_equal [[1, 'a'], [1, 'b']], @tree.lt(3).to_a
    
    # lte(3) should include key 3
    assert_equal [[1, 'a'], [1, 'b'], [3, 'x']], @tree.lte(3).to_a
    
    # gt(3) should include all values for key 5
    assert_equal [[5, 'p'], [5, 'q']], @tree.gt(3).to_a
    
    # gte(3) should include key 3
    assert_equal [[3, 'x'], [5, 'p'], [5, 'q']], @tree.gte(3).to_a
  end

  def test_multi_between
    @tree.insert(1, 'a')
    @tree.insert(2, 'b1')
    @tree.insert(2, 'b2')
    @tree.insert(3, 'c')
    @tree.insert(4, 'd')
    
    result = @tree.between(2, 3).to_a
    assert_equal [[2, 'b1'], [2, 'b2'], [3, 'c']], result
  end

  def test_multi_range_reverse
    @tree.insert(1, 'a')
    @tree.insert(1, 'b')
    @tree.insert(2, 'x')
    @tree.insert(2, 'y')
    
    result = @tree.lt(3, reverse: true).to_a
    # Reverse: highest key first, then values in reverse order
    assert_equal [[2, 'y'], [2, 'x'], [1, 'b'], [1, 'a']], result
  end

  # ============================================================
  # Stress Tests
  # ============================================================

  def test_multi_large_dataset
    keys = (1..100).to_a
    
    # Insert multiple values per key
    keys.each do |k|
      5.times { |i| @tree.insert(k, "#{k}_#{i}") }
    end
    
    assert_equal 500, @tree.size
    assert @tree.valid?
    
    # Verify order
    count = 0
    prev_key = nil
    @tree.each do |k, v|
      assert prev_key.nil? || k >= prev_key
      prev_key = k
      count += 1
    end
    assert_equal 500, count
  end

  def test_multi_random_operations
    operations = []
    
    500.times do
      op = rand(3)
      key = rand(50)
      
      case op
      when 0 # insert
        @tree.insert(key, rand(1000))
      when 1 # delete_one
        @tree.delete_one(key)
      when 2 # delete all
        @tree.delete(key) if rand < 0.2
      end
    end
    
    assert @tree.valid?
  end

  def test_multi_valid_after_operations
    # Many inserts on same key
    100.times { |i| @tree.insert(1, "first_#{i}") }
    100.times { |i| @tree.insert(2, "second_#{i}") }
    assert @tree.valid?
    
    # Delete some from each
    50.times { @tree.delete_one(1) }
    50.times { @tree.delete_one(2) }
    assert @tree.valid?
    
    # Range query should still work
    result = @tree.between(1, 2).to_a
    assert_equal 100, result.size
    
    # Delete all
    @tree.delete(1)
    @tree.delete(2)
    assert_empty @tree
    assert @tree.valid?
  end

  def test_multi_stress_shift_pop
    100.times { |i| @tree.insert(1, "min_#{i}") }
    100.times { |i| @tree.insert(100, "max_#{i}") }
    
    50.times { @tree.shift }
    50.times { @tree.pop }
    
    assert_equal 100, @tree.size
    assert_equal [1, 'min_50'], @tree.min
    # pop removes last value, so max_99 through max_50 are removed, leaving max_49 as the last
    assert_equal [100, 'max_49'], @tree.max(last: true)
    assert @tree.valid?
  end

  # ============================================================
  # Bulk Insert Tests
  # ============================================================

  def test_multi_initialize_bulk_array_duplicates
    tree = MultiRBTree.new([[1, "one"], [1, "uno"]])
    assert_equal 2, tree.size
    assert_equal ["one", "uno"], tree.get_all(1).to_a
  end

  def test_multi_insert_hash
    @tree.insert({1 => "one", 2 => "two"})
    assert_equal 2, @tree.size
  end

  def test_multi_insert_ignores_overwrite
    @tree.insert({1 => "one"}, overwrite: false)
    @tree.insert({1 => "uno"}, overwrite: false)
    assert_equal 2, @tree.size
    assert_equal ["one", "uno"], @tree.get_all(1).to_a
  end
end
