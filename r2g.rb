#!/usr/bin/env ruby
#
# main.rb
# Copyright (C) 2018 diskshima <diskshima@gmail.com>
#
# Distributed under terms of the MIT license.
#

require 'faraday'
require 'fileutils'
require 'git'
require 'json'
require 'optparse'
require 'tempfile'

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
    response = conn.get("#{base_url.path}/api/queries", params)
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

git = is_git_dir?(output_dir) ? Git.open(output_dir) : Git.init(output_dir)
git.add(file_names)

existing_files = git.ls_files('.').keys
git.remove(existing_files - file_names)

message = ask_commit_message
git.commit(message)

# TODO: git_push
