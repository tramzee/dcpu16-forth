require 'rubygems'
require 'pp'


class EString < String
  def +(s)
    EString.new("#{self} + #{s}")
  end

end

class String
  def -@
    '0x' + self.ord.to_s(16)
  end
end

class Emit
  attr_accessor :code

  LENGTH_MASK = 0x1f
  HIDDEN_MASK = 0x20
  IMMEDIATE_MASK = 0x40
  KBD_CR = 0x11

  def initialize
    @code = []
  end

  def method_missing(m, *args)
    if args.length > 0
      m = m.to_s
      code.push "#{m.sub(/^(.*?)_*$/, '\1')} " + args.collect {|a| e(a)}.join(", ")
      yield if m.to_s =~ /^if/ && block_given?
    else
      EString.new(m.to_s.sub(/^(.*?)_*$/, '\1'))
    end
  end

  def s(arg)
    "0x" + arg.ord.to_s(16)
  end

  def e(arg)
    case arg
    when Array
      "[#{arg[0]}]"
    else
      EString.new(arg.to_s)
    end
  end

  def space(len, name = nil)
    label(name) if name
    Array.new(len, 0).each_slice(10).each {|l| code << 'dat ' + l.each_slice(5).collect {|lg| lg.join(',')}.join(', ')}
  end

  def label(lab)
    code << ":#{lab}"
  end

  def jsr(name, opts = {})
    opts[:saves] ||= []
    opts[:saves].each do |reg|
      code << %(set push, #{reg})
    end
    code << %(jsr #{name})
    opts[:saves].reverse.each do |reg|
      code << %(set #{reg}, pop)
    end
  end

  def w(*n)
    code << "dat #{n.join(', ').upcase}"
  end

  def forth(s)
    s.split(/\s*\n\s*/).each do |line|
      line.gsub!(/\s{2,}/, ' ')
      dquote = '"'.ord.to_s
      line.gsub!(/"/, "\", #{dquote}, \"")
      code << %(dat "#{line}", #{KBD_CR})
    end
  end

  def defsubr(name, opts = {})
    opts[:saves] ||= []
    label name
    opts[:saves].each do |reg|
      set push, reg
    end
    yield
    label "#{name}_end"

    opts[:saves].reverse.each do |reg|
      set reg, pop
    end

    set pc, pop
  end


  def defword(name, *opts)
    if opts[0].is_a?(Hash) && opts.length == 1
      opts = opts[0]
    else
      opts = {:lab => opts[0], :flags => opts[1]}
    end

    opts[:lab] ||= name
    name = name.upcase
    opts[:lab] = opts[:lab].upcase

    opts[:flags] ||= 0
    code.push ":name_#{opts[:lab]}"
    code.push %(dat #{@last_lab ? "name_#{@last_lab}" : 0})
    code.push %(dat #{name.length | opts[:flags]})
    code.push %(dat "#{name}")
    code.push %(:#{opts[:lab]})
    code.push %(dat DOCOL_CODE)
    yield
    w exit_
    @last_lab = opts[:lab]
  end

  def defcode(name, *opts)
    if opts[0].is_a?(Hash) && opts.length == 1
      opts = opts[0]
    else
      opts = {:lab => opts[0], :flags => opts[1]}
    end

    opts[:lab] ||= name
    name = name.upcase
    opts[:lab] = opts[:lab].upcase

    opts[:flags] ||= 0

    code.push ":name_#{opts[:lab]}"
    code.push %(dat #{@last_lab ? "name_#{@last_lab}" : 0})
    code.push %(dat #{name.length | opts[:flags]})
    code.push %(dat "#{name}")
    code.push %(:#{opts[:lab]})
    code.push %(dat #{opts[:lab]}+1)
    yield
    set pc, :next
    @last_lab = opts[:lab]
  end

  def defvar(name, val=0, lab=name)
    lab.upcase!
    var_lab = "var_#{lab}"
    defcode(name, lab) do
      set push, var_lab
    end
    code << %(:#{var_lab})
    code << %(dat #{val})
  end

  def defconst(name, val, *opts)
    if opts[0].is_a?(Hash) && opts.length == 1
      opts = opts[0]
    else
      opts = {:lab => opts[0], :flags => opts[1]}
    end

    defcode(name, opts) do
      set push, val
    end
  end

  def emit
    code.join("\n        ").gsub(/^\s*:/, ':').gsub(/(^\s*if.*\n)/, '\1  ')
  end

end

emit = Emit.new
emit.instance_eval($stdin.read)
puts emit.emit

