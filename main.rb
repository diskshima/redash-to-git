#!/usr/bin/env ruby
#
# main.rb
# Copyright (C) 2018 diskshima <diskshima@gmail.com>
#
# Distributed under terms of the MIT license.
#

require 'faraday'
require 'fileutils'
require 'json'
require 'optparse'

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

def to_file_list(redash_results, output_dir)
  redash_results.map do |e|
    file_name = "#{e['id']}_#{e['name']}.sql"
    file_path = File.join(output_dir, file_name)
    File.open(file_path, 'w') { |f| f.write(e['query']) }
    file_path
  end
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
if dir_exists && !Dir.empty?(output_dir)
  puts "#{output_dir} is not empty."
  exit(-1)
end

FileUtils.mkdir_p(output_dir) unless dir_exists

base_url = URI::parse(options[:url])
results = get_redash_queries(base_url, options[:key])
files_list = to_file_list(results, output_dir)
