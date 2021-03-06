#!/usr/bin/env ruby
#
# main.rb
# Copyright (C) 2018 diskshima <diskshima@gmail.com>
#
# Distributed under terms of the MIT license.
#

require 'fileutils'
require 'json'
require 'optparse'
require 'tempfile'
require 'uri'

require 'faraday'
require 'git'

IGNORE_PATH = File.join(ENV['HOME'], '.r2gignore')

def get_redash_queries(base_url, key)
  headers = {
    'Authorization' => "Key #{key}",
    'Content-Type' => 'application/json',
  }

  conn = Faraday.new(url: "#{base_url.scheme}://#{base_url.host}:#{base_url.port}",
                     headers: headers)

  results = []
  page = 1

  loop do
    params = { page: page }
    response = conn.get("#{base_url.path.gsub(%r{[\/]+$}, '')}/api/queries", params)
    content = JSON.parse(response.body)
    done = page * content['page_size'] + 1 > content['count']
    results += content['results']
    break if done

    page += 1
  end

  results
end

def to_file_name(redash_query)
  "#{redash_query['id']}_#{redash_query['name']}.sql"
end

def write_to_file(redash_results, output_dir)
  redash_results.map do |e|
    file_path = File.join(output_dir, to_file_name(e))
    File.open(file_path, 'w') { |f| f.write(e['query']) }
  end
end

def is_git_dir?(dir)
  File.directory?(File.join(dir, '.git'))
end

def ask_commit_message
  content = ''
  Tempfile.create do |f|
    system(ENV['EDITOR'], f.path)
    content = File.read(f)
  end
  content
end

def has_diff?(git)
  stats = git.diff('--cached').stats
  stats[:files].any?
end

def with_git_configs(git, configs, &block)
  prev_configs = {}
  configs.each do |k, v|
    prev_configs[k] = git.config(k)
    git.config(k, v)
  end

  yield

  prev_configs.each do |k, v|
    git.config(k, v)
  end
end

def read_ignores
  return [] unless File.exist?(IGNORE_PATH)

  entries = File.readlines(IGNORE_PATH, chomp: true)
  entries.map { |e| Dir.glob(e) }.flatten
end

options = {
  key: ENV['REDASH_API_KEY'],
  output_dir: 'data',
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"

  opts.on('-u URL', '--url URL', 'Redash URL.') do |u|
    options[:url] = u
  end
  opts.on('-k API_KEY', '--key API_KEY', 'Redash API Key.') do |k|
    options[:key] = k
  end
  opts.on('-o OUTPUT_DIR', '--output-dir OUTPUT_DIR', 'Output directory. Defaults to "data/"') do |o|
    options[:output_dir] = o
  end
  opts.on('-c', '--[no-]commit', 'Create a commit.') do |c|
    options[:commit] = c
  end
  opts.on('-h', '--help', 'Display this help.') do
    puts opts
    exit
  end
end.parse!

output_dir = options[:output_dir]
dir_exists = File.directory?(output_dir)

FileUtils.mkdir_p(output_dir) unless dir_exists

base_url = URI::parse(options[:url])
results = get_redash_queries(base_url, options[:key])
write_to_file(results, output_dir)
file_names = results.map { |e| to_file_name(e) }

ignores = read_ignores

git = is_git_dir?(output_dir) ? Git.open(output_dir) : Git.init(output_dir)

with_git_configs(git, { 'core.quotepath' => true }) do
  git.add(file_names - ignores)

  git_files = git.ls_files('.').keys
  only_files = git_files.reject { |f| f.include?('/') }
  files_diff = only_files - file_names - ignores
  git.remove(files_diff) if files_diff.count > 0

  if has_diff?(git)
    if options[:commit]
      message = ask_commit_message
      git.commit(message)
    end
  else
    puts 'No diff detected. Doing nothing.'
  end
end
