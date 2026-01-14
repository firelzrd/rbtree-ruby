require 'minitest/autorun'
require_relative '../lib/rbtree'

class TestRBTree < Minitest::Test
  def setup
    @tree = RBTree.new
  end

  def test_initialize
    tree = RBTree.new
    assert_empty tree
    assert_equal 0, tree.size

    tree = RBTree.new({1 => 'a', 2 => 'b'})
    assert_equal 2, tree.size
    assert_equal 'a', tree[1]
  end

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

  def test_clear_empty
    @tree[1] = 'one'
    refute_empty @tree
    @tree.clear
    assert_empty @tree
    assert_equal 0, @tree.size
  end

  def test_min_max
    assert_nil @tree.min
    assert_nil @tree.max

    @tree[10] = 'ten'
    @tree[5] = 'five'
    @tree[20] = 'twenty'

    assert_equal [5, 'five'], @tree.min
    assert_equal [20, 'twenty'], @tree.max
  end

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
  
  def test_enumerator_return
    assert_instance_of Enumerator, @tree.lt(10)
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
end

class TestMultiRBTree < Minitest::Test
  def setup
    @tree = MultiRBTree.new
  end

  def test_duplicate_keys
    @tree.insert(1, 'first')
    @tree.insert(1, 'second')
    @tree.insert(2, 'apple')

    assert_equal 3, @tree.size
    assert_equal 'first', @tree.get(1)
    assert_equal ['first', 'second'], @tree.get_all(1).to_a
  end

  def test_get_last_first
    @tree.insert(1, 'first')
    @tree.insert(1, 'second')

    assert_equal 'first', @tree.get_first(1)
    assert_equal 'second', @tree.get_last(1)
    
    assert_equal 'first', @tree.get(1)
    assert_equal 'second', @tree.get(1, last: true)
  end

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
end
