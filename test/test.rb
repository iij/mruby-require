


assert "Kernel#_load_rb_str" do
  assert_equal true, self.methods.include?(:_load_rb_str)
  assert_equal false, Object.const_defined?(:LOAD_RB_STR_TEST)
  _load_rb_str("LOAD_RB_STR_TEST = 1")
  assert_equal true, Object.const_defined?(:LOAD_RB_STR_TEST)
end

assert "$LOAD_PATH check" do
  assert_equal Array, $LOAD_PATH.class
end

assert '$" check' do
  assert_equal [], $"
end

assert('load - error check') do
  assert_raise TypeError, "load(nil) should raise TypeError" do
    load nil
  end
  assert_raise LoadError, "load('notfound') should raise LoadError" do
    load 'notfound'
  end
end

assert('require - error check') do
  assert_raise TypeError, "require(nil) should raise TypeError" do
    require nil
  end
  assert_raise LoadError, "require('notfound') should raise LoadError" do
    require "notfound"
  end
end

$require_test_dir = File.join(Dir.tmpdir, "mruby-require-test-#{Time.now.to_i}.#{Time.now.usec}")
Dir.mkdir($require_test_dir)

File.open(File.join($require_test_dir, "test.rb"), "w") do |fp|
  fp.puts "$require_test_variable = 123"
end

$LOAD_PATH = [$require_test_dir]

assert("load 'test.rb'") do
  assert_equal nil, $require_test_variable
  assert_equal true, File.exist?(File.join $require_test_dir, "test.rb")
  assert_equal true, load(File.join $require_test_dir, "test.rb")
  assert_equal 123, $require_test_variable
end

$require_test_variable = nil

assert("require 'test'") do
  assert_equal [], $"
  assert_equal nil, $require_test_variable
  assert_equal true, require("test")
  assert_equal 123, $require_test_variable
  assert_equal [File.join($require_test_dir, "test.rb")], $"
  $require_test_variable = 789
  assert_equal false, require("test")
  assert_equal 789, $require_test_variable
end

File.open(File.join($require_test_dir, "loop1.rb"), "w") do |fp|
  fp.puts "require 'loop2.rb'"
  fp.puts "$loop1 = 'loop1'"
end
File.open(File.join($require_test_dir, "loop2.rb"), "w") do |fp|
  fp.puts "require 'loop1.rb'"
  fp.puts "$loop2 = 'loop2'"
end

assert("require loop check") do
  require 'loop1'
  assert_equal 'loop1', $loop1
  assert_equal 'loop2', $loop2
end

$require_test_count = 10
(1..$require_test_count-1).each do |i|
  File.open(File.join($require_test_dir, "#{i+1}.rb"), "w") do |fp|
    fp.puts "require '#{i}'"
    fp.puts "s = 0"
    (0..100).each{|num| fp.puts "s += #{num}" }
  end
end
File.open(File.join($require_test_dir, "1.rb"), "w") do |fp|
  fp.puts "$require_test_0 = 123"
end

assert("require nest") do
  before = $".size
  require "#{$require_test_count}"
  assert_equal before + $require_test_count, $".size
end

def remove_file_recursive(path)
  if File.directory? path
    Dir.entries(path).each do |entry|
      next if ['.', '..'].include?(entry)
      remove_file_recursive File.join(path, entry)
    end
    Dir.unlink path
  else
    File.unlink path
  end
end

if $require_test_dir && File.exist?($require_test_dir)
  remove_file_recursive $require_test_dir
end

