require 'rubygems'
require 'pp'
require 'optparse'

def help
  ARGV.unshift '--help'
  parse_options
end

def convert
  puts convert_internal($stdin.read)
end

def convert_internal(string)
  emit = Emit.new
  emit.instance_eval(string)
  emit.emit
end

def disk
  parse_options
  print makedisk($stdin.read, @options[:disk_name])
end

def test
  puts 'testing...'
end

def parse_options
  @options = {}
  @options[:disk_files] = []
  @options[:rbs_files] = []
  @options[:disk_name] = 'disk1'
  @options[:devkit_dir] = '.'
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby -r ./dcpu -e command -- [options]"

    opts.separator ""
    opts.separator %w(Commands: devkit disk help convert).join("\n\t")

    opts.separator ""
    opts.separator "-- Specific Options --"
    opts.separator ""
    opts.separator "devkit command options:"

    opts.on("--devkit-dir DIR", "output files to DIR (devkit only)") do |dir|
      @options[:devkit_dir] = dir
    end

    opts.on("--disk-files FILES", Array,
            "FILES (comma sep list) are turned into .10cdisk files.",
            "Can be specified any number of times (devkit only)") do |files|
      @options[:disk_files].push(*files)
    end

    opts.on("--rbs-files FILES", Array, "FILE (comma sep list) to be turned into .10c files") do |files|
      @options[:rbs_files].push(*files)
    end

    opts.separator ""
    opts.separator "disk command options:"

    opts.on("--disk_name NAME", "name of the disk to make") do |name|
      @options[:disk_name] = name
    end

    opts.separator ""
    opts.separator "-- Common Options --"

    opts.on("--[no-]exec", "Do not execute, just show what would be done") do |v|
      @options[:exec] = v
    end

    opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
      @options[:verbose] = v
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end

  end.parse!
end

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
    code << %(jsr #{e name})
    opts[:saves].reverse.each do |reg|
      code << %(set #{reg}, pop)
    end
  end

  def w(*n)
    code << "dat #{n.join(', ').upcase}"
  end

  def forth(s)
    s.split(/\s*\n\s*/).each do |line|
      line.gsub!(/\s+/, ' ')
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


  def define(name, arg)
    code.push %(\#define #{name} #{arg})
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
    code.join("\n        ").gsub(/^\s*([:\#])/, '\1').gsub(/(^\s*if.*\n)/, '\1  ')
  end

end

require 'base64'
require 'zlib'

def makedisk(string, disk_name = 'disk1')

  header_template = %(BIEF/0.1
media-type: AuthenticHIT
words-per-sector: 512
sectors-per-track: 18
tracks: 80
access: Read-Write
type: Floppy
disk-name: %s
Compression: Zlib
Encoding: Base64
Payload-Length: %s

%s)
  deflate = Zlib::Deflate.new

  total_bytes = 512 * 2 * 18 * 80

  string.each_char do |c|
    deflate << "\x00"
    deflate << c
    total_bytes -= 2
  end

  while total_bytes > 0
    deflate << "\x00"
    total_bytes -= 1
  end

  disk_bytes = deflate.finish
  deflate.close

  b64_bytes = Base64.encode64(disk_bytes).chomp
  header_template % [disk_name, b64_bytes.length, b64_bytes]
end

def devkit
  parse_options
  dcpu_dir = File.dirname(__FILE__)

  @options[:rbs_files].each do |fname|
    basename = File.basename(fname, ".rbs")
    emit = Emit.new
    File.open(fname) {|f| emit.instance_eval(f.read) }
    File.open(File.join(@options[:devkit_dir], basename + ".10c"), "w") { |f| f.print emit.emit }
  end

  @options[:disk_files].each do |in_disk_file|
    out_disk_file = File.basename(in_disk_file)
    out_disk_file.gsub!(/\..*?$/, '')
    File.open(File.join(@options[:devkit_dir], out_disk_file + ".10cdisk"), "wb") do |ofile|
      ofile.print makedisk(File.open(in_disk_file) {|f| f.read}, out_disk_file)
    end
  end
end



