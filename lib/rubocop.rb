# frozen_string_literal: true

require 'json'

puts 'ARGV:', JSON.pretty_generate(ARGV)
puts 'ENV:',  JSON.pretty_generate(ENV.to_h)
puts 'pwd:',  `pwd`
puts 'ls:',   `ls -lah ../**/`