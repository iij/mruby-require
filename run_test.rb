#!/usr/bin/env ruby
#
# mrbgems test runner
#

DEPEND_GEMS = {
  'tmp/mruby-io'       => 'https://github.com/iij/mruby-io.git',
  'tmp/mruby-dir'      => 'https://github.com/iij/mruby-dir.git',
  'tmp/mruby-tempfile' => 'https://github.com/iij/mruby-tempfile.git',
}
gemname = File.basename(File.dirname(File.expand_path __FILE__))

if __FILE__ == $0
  repository, dir = 'https://github.com/mruby/mruby.git', 'tmp/mruby'

  build_args = ARGV
  build_args = ['all', 'test']  if build_args.nil? or build_args.empty?

  Dir.mkdir 'tmp'  unless File.exist?('tmp')
  unless File.exist?(dir)
    system "git clone #{repository} #{dir}"
  end

  DEPEND_GEMS.each do |path, url|
    unless File.exist?(path)
      system "git clone #{url} #{path}"
    end
  end

  exit system(%Q[cd #{dir}; MRUBY_CONFIG=#{File.expand_path __FILE__} ruby minirake #{build_args.join(' ')}])
end

MRuby::Build.new do |conf|
  toolchain :gcc
  conf.gems.clear

  conf.gem "#{root}/mrbgems/mruby-sprintf"
  conf.gem "#{root}/mrbgems/mruby-print"

  Dir.glob("#{root}/mrbgems/mruby-*") do |x|
    conf.gem x unless x =~ /\/mruby-(print|sprintf)$/
  end

  DEPEND_GEMS.each do |path, url|
    conf.gem path
  end

  conf.gem File.expand_path(File.dirname(__FILE__))
end
