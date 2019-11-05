# frozen_string_literal: true

require 'time'
require 'json'
require 'shellwords'
require 'net/http'

## GitHub API

http = Net::HTTP.new('api.github.com', Net::HTTP.https_default_port)
http.use_ssl = true

CHECKS_PATH = "repos/#{ENV.fetch('GITHUB_REPOSITORY')}/check-runs"
HEADERS = {
  'Content-Type'  => 'application/json',
  'Accept'        => 'application/vnd.github.antiope-preview+json',
  'Authorization' => "Bearer #{ENV.fetch('ACTIONS_RUNTIME_TOKEN')}",
  'User-Agent'    => 'rubocop-action',
}.freeze

## Create check run

body = {
  'name'       => 'Rubocop',
  'status'     => 'in_progress',
  'head_sha'   => ENV.fetch('GITHUB_SHA'),
  'started_at' => Time.now.utc.iso8601,
}
response = http.post(CHECKS_PATH, body.to_json, HEADERS)

if response.is_a? Net::HTTPSuccess
  data = JSON.parse(response.body)
  puts 'Check run created:', JSON.pretty_generate(data)
else
  warn 'Check run creation failed:', response.message,
    JSON.pretty_generate(response.each_header.to_h), response.body
  exit 1
end

check_path = "#{CHECKS_PATH}/#{data.fetch('id')}"

## Get list of changed files if needed

if ENV['INPUT_CHANGES-ONLY'] =~ /\A(?:true|yes|on|1|\s*)\z/i
  base_ref = ENV.fetch('GITHUB_BASE_REF', 'master').shellescape
  head_ref = ENV.fetch('GITHUB_REF',      'HEAD').shellescape

  diff_files  = `git diff --name-only --diff-filter=ACMRT #{base_ref}...#{head_ref}`
  exit_status = $?.exitstatus

  unless exit_status.zero?
    warn 'Something wrong with git diff'
    exit exit_status # TODO: close check run (conclusion == 'failure'?)
  end

  diff_files = diff_files.shellsplit
  puts 'Only files:', JSON.pretty_generate(diff_files)
end

## Run Rubocop

result      = `rubocop -fj #{diff_files.shelljoin if diff_files}`
exit_status = $?.exitstatus
data        = JSON.parse(result)

puts 'Result:', JSON.pretty_generate(data)

## Process results

annotations = data.fetch('files').flat_map do |file_data|
  file_path = file_data.fetch('path')

  file_data.fetch('offenses').map do |offense_data|
    location   = offense_data.fetch('location')
    start_line = location.fetch('start_line')
    end_line   = location.fetch('last_line')
    severity   = offense_data.fetch('severity')

    {
      'path'             => file_path,
      'start_line'       => start_line,
      'end_line'         => end_line,
      'annotation_level' => severity == 'warning' ? 'warning' : 'failure',
      'message'          => offense_data.fetch('message'),
      'title'            => offense_data.fetch('cop_name'),
    }.tap do |annotation|
      annotation.merge!({
        'start_column' => location.fetch('start_column'),
        'end_column'   => location.fetch('last_column'),
      }) if start_line == end_line
    end
  end
end

## Close check run

summary        = data.fetch('summary')
offenses_count = summary.fetch('offense_count')
files_count    = summary.fetch('inspected_file_count')

body = {
  'conclusion' => (exit_status.zero? ? 'success' : 'failure'), # TODO: 'action_required' ?
  'output'     => {
    'title'       => 'Rubocop',
    'summary'     => "Found #{offenses_count} offense(s) in #{files_count} inspected file(s).",
    'annotations' => annotations,
  },
}
puts 'Output:', JSON.pretty_generate(body)

response = http.patch(check_path, body.to_json, HEADERS)
puts 'Close:', response.inspect, '---', response.body, '---'

## Done

exit exit_status
