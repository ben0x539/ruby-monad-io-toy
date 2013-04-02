# zero ruby IO happens here:

def assert_type(x, klass)
  return if x.kind_of?(klass)

  raise TypeError, "expected #{klass}, got #{x.inspect} :: #{x.class}"
end

class IOAction < Struct.new(:primop, :args)
end

def getChar()
  IOAction.new(:getChar, [])
end

def putChar(c)
  assert_type(c, Integer)
  IOAction.new(:putChar, [c])
end

def bind(k, f) # k >>= f
  assert_type(k, IOAction)
  assert_type(f, Proc)
  IOAction.new(:bind, [k, f])
end

def return_(x)
  IOAction.new(:return, [x])
end

def andThen(k1, k2) # k1 >> k2
  assert_type(k1, IOAction)
  assert_type(k2, IOAction)
  bind(k1, lambda { |_| k2 })
end

def putStrLn(s)
  assert_type(s, String)
  if s.empty?
    putChar("\n".ord)
  else
    rest = s.dup
    first = rest.slice!(0)
    andThen(putChar(first.ord), putStrLn(rest))
  end
end

def getLine()
  bind(getChar(),
       lambda do |c|
         if c == ?\n
           return_(c)
         else
           bind(getLine(),
                lambda do |line|
                  res = c + line.chomp
                  return_(res)
                end)
         end
       end)
end

main = andThen(putStrLn("Hello! What's your name??"),
               bind(getLine(),
                    lambda { |x| putStrLn("WELL HELLO #{x.upcase}!!!") }))

## END USER CODE ##
# actual IO happens here

def run_io(io)
  assert_type(io, IOAction)
  case io.primop
  when :return
    io.args.first
  when :bind
    k, f = io.args
    r = run_io(k)
    run_io(f.call(r))
  when :getChar
    STDIN.read(1)
  when :putChar
    STDOUT.print(io.args[0].chr)
    nil
  end
end

run_io(main)
