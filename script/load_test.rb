#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

base_url = ENV.fetch("BASE_URL", "http://localhost:3000")
threads = Integer(ENV.fetch("THREADS", "50"))

uri = URI("#{base_url}/orders")

success = 0
conflict = 0
other = 0

mutex = Mutex.new

ts =
  threads.times.map do |i|
    Thread.new do
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req["Idempotency-Key"] = "loadtest-#{i}"
      req.body = { customer_email: "loadtest@example.com", lines: [{ sku_code: "WIDGET", quantity: 1 }] }.to_json

      res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }

      mutex.synchronize do
        case res.code.to_i
        when 201 then success += 1
        when 409 then conflict += 1
        else other += 1
        end
      end
    end
  end

ts.each(&:join)

puts({ success: success, conflict: conflict, other: other }.to_json)


