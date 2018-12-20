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

headers = {
  'Authorization' => "Key #{options[:key]}",
  'Content-Type' => 'application/json',
}

uri = URI::parse(options[:url])

conn = Faraday.new(url: "#{uri.scheme}://#{uri.host}:#{uri.port}", headers: headers)

results = []
page = 1

loop do
  params = { page: page }
  response = conn.get("#{uri.path}/api/queries", params)
  content = JSON.parse(response.body)
  done = page * content['page_size'] + 1 > content['count']
  results += content['results']
  break if done
  page += 1
end

results.map do |e|
  file_name = "#{e['id']}_#{e['name']}.sql"
  file_path = File.join(output_dir, file_name)
  File.open(file_path, 'w') { |f| f.write(e['query']) }
  puts "Wrote query to #{file_path}."
end
