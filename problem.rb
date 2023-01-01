# require 'dbm'
# db = DBM.open('solutions', 0666, DBM::WRCREAT)

# https://arxiv.org/abs/1302.1479

OPERATIONS = {
  addition: {
    execute: lambda { |a, b| a + b },
    symbol: '+',
    points: 0
  },
  subtraction: {
    execute: lambda { |a, b| a - b },
    symbol: '-',
    points: -1
  },
  concatenation: {
    execute: lambda { |a, b| (a * 10) + b },
    symbol: '',
    points: 0
  },
  multiplication: {
    execute: lambda { |a, b| a * b },
    symbol: '*',
    points: 0
  },
  potentiation: {
    execute: lambda { |a, b| a ** b }, # unless a.zero? && b.negative?
    symbol: '^',
    points: 0
  },
  division: {
    execute: lambda { |a, b| a / b unless (a % b) != 0 }, # unless b.zero? || (a % b) != 0
    symbol: '/',
    points: -1
  }
}

DIGITS = (1..5).to_a.freeze

LIMIT = 11111

# the total number of possible equations (including illegal ones
# with concat operations not coming first)
# (ops ^ steps) * steps!
# for 9 digits (8 steps) with 6 operations, including equivalent and
# illegal permutations, total space is (6^8) * 8! = 67,722,117,120
STEPS = DIGITS.size - 1
SPACE = OPERATIONS.size ** STEPS
SPACE_W_PERMUTATIONS = SPACE * (STEPS.downto(1).inject(:*))

# in ruby, 500ms to do 31104 (4 steps), so ~12 days to do the whole set
#          9s to do 933,120 (5 steps), so ~7 days

# Concat operations must apply before other operations,
# and must apply from left-to-right when next to each other.
# that is, (1||2)||3 = 123 is legal, 1||(2||3) => 1023 is not

def all_operation_combinations
  (0...SPACE).map do |i|
    s = ("%0#{STEPS}d" % i.to_s(OPERATIONS.size)).chars
    s.each_with_index.map do |j, k|
      [k, OPERATIONS.keys[j.to_i]]
    end
  end
end

def order_permutations(operations)
  # all concat operations must come first, and be in order
  # [[0, :concat], [1, :plus], [2, :concat], [3, :minus]]
  # TODO: commutative operations can be consolidated
  concat_ops, other_ops = operations.reduce([[],[]]) do |acc,oo|
    c, n = acc
    _, o = oo
    o == :concatenation ? [ c + [oo], n ] : [ c, n + [oo] ]
  end
  other_ops.permutation.map { |oo| concat_ops + oo }.lazy
end

def score(operations)
  operations.map { |_,o| OPERATIONS[o][:points] }.sum
end

# Tree data structure:
# ((1||2)+(3-4)+5)
# {
#   a: {
#     a: {
#       a: 1,
#       b: 2,
#       operation: :concatenation
#     },
#     b: {
#       a: 3,
#       b: 4,
#       operation: :minus
#     },
#     operation: :plus
#   },
#   b: 5,
#   operation: :plus
# }
# Array of pairs data structure
# (operation and position in execution order)
# ((1||2)+(3-4)+5)
#    0   1  2  3     <= position
#    0   2  1  3     <= idx
#    c   +  -  +     <= op
# operations: [[0,:concatenation],[2,:minus],[1,:plus],[3, :plus]]

# [[0, :plus], [2, :plus], [3, :plus], [1, :plus]]
#    1       2       3       4       5
#   (1   +   2)      3       4       5
#   (1   +   2)     (3   +   4)      5
#   (1   +   2)    ((3   +   4)  +   5)
#  ((1   +   2)  + ((3   +   4)  +   5))
# tree: {{1,2,+},{{3,4,+},5,+},+}

# 1     2      3     4      5
# 12    nil    3     4      5
# 12    nil   -1    nil     5
# 11    nil   nil   nil     5
# 16    nil   nil   nil    nil
def to_tree(operations, state = DIGITS.dup)
  o, *rest = operations
  i, operation = o
  a, a_i = state[0..i].each_with_index.to_a.reverse.find { |o,_| !o.nil? }
  b = state[i + 1]
  t = { a: a, b: b, operation: operation }
  state[a_i] = t
  state[i + 1] = nil
  return t if rest.empty?
  to_tree(rest, state)
end

def evaluate(tree)
  a = tree[:a].is_a?(Hash) ? evaluate(tree[:a]) : tree[:a]
  b = tree[:b].is_a?(Hash) ? evaluate(tree[:b]) : tree[:b]
  return nil if a.nil? || b.nil?
  begin
    r = OPERATIONS[tree[:operation]][:execute].call(a, b)
    r unless r.negative? || r > LIMIT || a.to_i != a
  rescue
    # no solution (divide by zero, etc)
    nil
  end
end

def human_format(tree)
  a = tree[:a].is_a?(Hash) ? (tree[:operation] == :concatenation ? human_format(tree[:a]) : "(#{human_format(tree[:a])})") : tree[:a]
  b = tree[:b].is_a?(Hash) ? (tree[:operation] == :concatenation ? human_format(tree[:b]) : "(#{human_format(tree[:b])})") : tree[:b]
  o = OPERATIONS[tree[:operation]][:symbol]
  "#{a}#{o}#{b}"
end

results = {}
all_operation_combinations.each do |oo|
  r = {}
  order_permutations(oo).each do |operations|
    s = score(operations)
    t = to_tree(operations)
    a = evaluate(t)
    r[a] = [human_format(t), s] unless a.nil? || r[a]
  end
  r.each do |a, o|
    results[a] ||= []
    results[a].push(o)
  end
end
results.keys.sort.each { |k| puts "#{k}:   #{results[k].sort_by { |_,s| s }.reverse}" }

