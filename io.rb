def assert_type(where, x, klass)
  return x if !klass || x.kind_of?(klass)

  raise TypeError, "in #{where}: expected #{klass}, got #{x.inspect} :: #{x.class}"
end

def assert_arg_types(where, args, arg_types)
  arg_types.each_index do |i|
    assert_type("#{where} arg #{i+1}", args[i], arg_types[i])
  end
end

class Char < Struct.new(:ord)
  def to_s()
    ord.chr
  end
end

class IOPrim < Struct.new(:tag, :result_type, :arg_types, :handler)
  @ops = {}
  def self.register(tag, *arg_types, result_type, &handler)
    arg_types ||= []
    op = @ops[tag] = IOPrim.new(tag, result_type, arg_types, handler)
    Kernel.send(:define_method, tag) do |*args|
      assert_arg_types(tag.to_s, args, arg_types)
      IOAction.new(op, args)
    end
  end

  def perform(*args)
    r = self.handler.call(*args)
    assert_type(self.tag.to_s + " result", r, self.result_type)
  end

  def inspect
    self.tag.to_s
  end
  alias to_s inspect
end

class IOAction < Struct.new(:primop, :args)
  def perform()
    primop.perform(*self.args)
  end

  def inspect
    "#{self.primop}(#{args.map(&:inspect).join(", ")})"
  end
  alias to_s inspect
end

IOPrim.register(:getChar, Char)           {     Char.new(STDIN.read(1).ord) }
IOPrim.register(:putChar, Char, NilClass) { |c| STDOUT.print(c.to_s)        }

IOPrim.register(:return_, nil, nil) { |x| x }
IOPrim.register(:bind, IOAction, Proc, nil) do |k, f|
  f.call(k.perform).perform
end

END { $main.perform() }

def def_fn(name, *arg_types, ret_type, &body)
  arg_types ||= []
  Kernel.send(:define_method, name) do |*args|
    assert_arg_types(name.to_s, args, arg_types)
    r = body.call(*args)
    assert_type(name.to_s + " result", r, ret_type)
  end
end

def fn(*arg_types, ret_type, &body)
  pos = caller[0]
  lambda do |*args|
    assert_arg_types("fn #{pos}", args, arg_types)
    assert_type("fn #{pos} result", body.call(*args), ret_type)
  end
end

## user code, no actual IO happens

def_fn(:andThen, IOAction, IOAction, IOAction) do |k1, k2| # k1 >> k2
  bind(k1, fn(nil, IOAction) { |_| k2 })
end

def_fn(:putStrLn, String, IOAction) do |s|
  if s.empty?
    putChar(Char.new("\n".ord))
  else
    rest = s.dup
    first = rest.slice!(0)
    andThen(putChar(Char.new(first.ord)), putStrLn(rest))
  end
end

def_fn(:getLine, IOAction) do
  bind(getChar(),
       fn(Char, IOAction) do |c|
         if c.ord == "\n".ord
           return_(c.to_s)
         else
           bind(getLine(),
                fn(String, IOAction) do |line|
                  res = c.to_s + line.chomp
                  return_(res)
                end)
         end
       end)
end

$main = andThen(putStrLn("Hello! What's your name??"),
                bind(getLine(),
                     fn(String, IOAction) do |x|
                      putStrLn("WELL HELLO #{x.upcase}!!!")
                     end))
