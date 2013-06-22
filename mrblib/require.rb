class LoadError < ScriptError; end

module Kernel
  def load(path)
    raise NotImplementedError.new "'require' method depends on File"  unless Object.const_defined?(:File)
    raise TypeError  unless path.class == String

    if File.exist?(path) && File.extname(path) == ".rb"
      _load_rb_str File.open(path).read, path
    elsif File.exist?(path) && File.extname(path) == ".mrb"
      _load_mrb_file path
    else
      raise LoadError.new "File not found -- #{path}"
    end
  end

  def require(path)
    raise NotImplementedError.new "'require' method depends on File"  unless Object.const_defined?(:File)
    raise TypeError  unless path.class == String

    if (path[0] == '/' || path[0] == '.') && File.exist?(path)
      realpath = File.realpath path
      $__mruby_loading_files__ << realpath
      load realpath
      $" << realpath
      $__mruby_loading_files__.delete realpath
    else
      filenames = [path]
      if File.extname(path).size == 0
        filenames << "#{path}.rb"
        filenames << "#{path}.mrb"
      end
      filename = nil
      dir = ($LOAD_PATH || []).find do |dir0|
        filename = filenames.find do |fname|
          path0 = File.join dir0, fname
          File.file?(path0) && File.exist?(path0)
        end
      end

      if dir && filename
        __require__(File.join dir, filename)
      else
        __require__(path)
      end
    end
  end

  def __require__(realpath)
    raise LoadError.new "File not found -- #{realpath}"  unless File.exist? realpath
    $" ||= []
    $__mruby_loading_files__ ||= []

    # already required
    return false  if ($" + $__mruby_loading_files__).include?(realpath)

    $__mruby_loading_files__ << realpath
    load realpath
    $" << realpath
    $__mruby_loading_files__.delete realpath

    true
  end
end


$LOAD_PATH ||= []
$LOAD_PATH << '.'

if Object.const_defined?(:ENV)
  $LOAD_PATH.unshift(*ENV['MRBLIB'].split(':')) unless ENV['MRBLIB'].nil?
end

$LOAD_PATH.uniq!

$" ||= []
$__mruby_loading_files__ ||= []
